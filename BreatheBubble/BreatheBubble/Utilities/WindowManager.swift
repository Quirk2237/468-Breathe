import SwiftUI
import AppKit
import QuartzCore

// MARK: - Window Manager
class WindowManager: ObservableObject {
    // Windows
    private var floatingBubbleWindow: NSWindow?
    private var exercisePanelWindow: NSWindow?
    private var settingsWindow: NSWindow?
    
    // Shared state
    @Published var timerManager = TimerManager()
    @Published var breathingSession = BreathingSession()
    @Published var exerciseSession = ExerciseSession()
    @Published var settings = AppSettings.shared
    
    // Panel state
    @Published var isPanelOpen: Bool = false
    @Published var currentActivityType: ActivityType?
    @Published var currentActivityEnabledIndex: Int?
    
    private var windowMoveObserver: Any?
    private var snapDebounceTimer: Timer?
    private var widgetSize: CGFloat = 100
    private var widgetWindowSize: CGFloat = 120
    private let panelSize: CGFloat = 340
    private let edgePadding: CGFloat = 20
    private let orbitGap: CGFloat = 10
    
    // Track widget position relative to panel
    private var widgetOrbitPosition: OrbitPosition = .right
    
    enum OrbitPosition {
        case top, bottom, left, right
    }
    
    init() {
        widgetSize = settings.widgetSize.dimension
        widgetWindowSize = settings.widgetSize.windowSize
        
        setupTimerCallback()
        setupSessionCallback()
        setupExerciseSessionCallback()
        setupWidgetSizeCallback()
    }
    
    private func setupWidgetSizeCallback() {
        settings.onWidgetSizeChange = { [weak self] newSize in
            self?.updateWidgetSize(newSize)
        }
    }
    
    private func updateWidgetSize(_ size: WidgetSize) {
        widgetSize = size.dimension
        widgetWindowSize = size.windowSize
        
        guard let window = floatingBubbleWindow else { return }
        
        let oldFrame = window.frame
        let oldCenter = NSPoint(x: oldFrame.midX, y: oldFrame.midY)
        let newOrigin = NSPoint(
            x: oldCenter.x - widgetWindowSize / 2,
            y: oldCenter.y - widgetWindowSize / 2
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(
                NSRect(x: newOrigin.x, y: newOrigin.y, width: widgetWindowSize, height: widgetWindowSize),
                display: true
            )
        } completionHandler: { [weak self] in
            self?.snapWidgetToNearestPoint()
        }
    }
    
    deinit {
        if let observer = windowMoveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        snapDebounceTimer?.invalidate()
    }
    
    private func setupTimerCallback() {
        timerManager.onTimerComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.selectAndOpenActivity()
            }
        }
    }
    
    private func setupSessionCallback() {
        breathingSession.onComplete = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.settings.recordCompletion(.breathwork, for: Date())
                self.settings.activityPlan.markActivityCompleted(.breathwork)
                self.closeBreathingPanel()
            }
        }
    }
    
    private func setupExerciseSessionCallback() {
        exerciseSession.onComplete = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.settings.recordCompletion(self.exerciseSession.exerciseType, for: Date())
                self.settings.activityPlan.markActivityCompleted(self.exerciseSession.exerciseType)
            }
        }
    }
    
    // MARK: - Activity Selection
    private func selectAndOpenActivity() {
        guard let selectedActivity = settings.activityPlan.getNextActivity(),
              let selectedIndex = settings.activityPlan.getNextActivityIndex() else {
            timerManager.restartAfterBreathing()
            return
        }
        
        currentActivityType = selectedActivity
        currentActivityEnabledIndex = selectedIndex
        
        switch selectedActivity {
        case .breathwork:
            openBreathingPanel()
        case .pushups, .situps, .squats:
            openExercisePanel(for: selectedActivity)
        }
    }
    
    // MARK: - Floating Bubble Window
    func showFloatingBubble() {
        if floatingBubbleWindow != nil { return }
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: widgetWindowSize, height: widgetWindowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - widgetWindowSize - edgePadding
            let y = screenFrame.minY + edgePadding
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        let contentView = ControlWidgetView(windowManager: self)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        
        panel.contentView = hostingView
        panel.orderFront(nil)
        
        floatingBubbleWindow = panel
        
        windowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.handleWidgetMove()
        }
    }
    
    // MARK: - Day Management
    func startDay() {
        let wasDayActive = timerManager.isDayActive
        timerManager.startDay()
        
        settings.recordDayStart(for: Date())
        
        if !wasDayActive {
            selectAndOpenActivity()
        }
    }
    
    func endDay() {
        settings.recordDayEnd(for: Date())
        
        timerManager.endDay()
        settings.activityPlan.resetCompletionTracking()
    }
    
    // MARK: - Handle Widget Movement
    private func handleWidgetMove() {
        if !isPanelOpen {
            scheduleSnap()
        }
    }
    
    // MARK: - Snap Points
    private func getSnapPoints() -> [NSPoint] {
        guard let screen = NSScreen.main else { return [] }
        let frame = screen.visibleFrame
        
        let minX = frame.minX + edgePadding
        let maxX = frame.maxX - widgetSize - edgePadding
        let midX = frame.midX - widgetSize / 2
        
        let minY = frame.minY + edgePadding
        let maxY = frame.maxY - widgetSize - edgePadding
        let midY = frame.midY - widgetSize / 2
        
        return [
            NSPoint(x: minX, y: minY),
            NSPoint(x: maxX, y: minY),
            NSPoint(x: minX, y: maxY),
            NSPoint(x: maxX, y: maxY),
            NSPoint(x: midX, y: minY),
            NSPoint(x: midX, y: maxY),
            NSPoint(x: minX, y: midY),
            NSPoint(x: maxX, y: midY),
        ]
    }
    
    private func findNearestSnapPoint(to position: NSPoint) -> NSPoint {
        let snapPoints = getSnapPoints()
        guard !snapPoints.isEmpty else { return position }
        
        var nearestPoint = snapPoints[0]
        var minDistance = CGFloat.infinity
        
        for point in snapPoints {
            let dx = position.x - point.x
            let dy = position.y - point.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < minDistance {
                minDistance = distance
                nearestPoint = point
            }
        }
        
        return nearestPoint
    }
    
    private func scheduleSnap() {
        snapDebounceTimer?.invalidate()
        snapDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.snapWidgetToNearestPoint()
        }
    }
    
    private func snapWidgetToNearestPoint() {
        guard let window = floatingBubbleWindow else { return }
        
        let currentOrigin = window.frame.origin
        let snapPoint = findNearestSnapPoint(to: currentOrigin)
        
        let dx = abs(currentOrigin.x - snapPoint.x)
        let dy = abs(currentOrigin.y - snapPoint.y)
        if dx < 1 && dy < 1 { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrameOrigin(snapPoint)
        }
    }
    
    // MARK: - Orbit Snapping (when panel is open)
    private func scheduleOrbitSnap() {
        snapDebounceTimer?.invalidate()
        snapDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.snapWidgetToOrbitPosition()
        }
    }
    
    private func snapWidgetToOrbitPosition() {
        guard let widgetWindow = floatingBubbleWindow,
              let panelWindow = exercisePanelWindow else { return }
        
        let widgetFrame = widgetWindow.frame
        let panelFrame = panelWindow.frame
        
        let widgetCenter = NSPoint(x: widgetFrame.midX, y: widgetFrame.midY)
        let panelCenter = NSPoint(x: panelFrame.midX, y: panelFrame.midY)
        
        let dx = widgetCenter.x - panelCenter.x
        let dy = widgetCenter.y - panelCenter.y
        
        let newOrbitPosition: OrbitPosition
        if abs(dx) > abs(dy) {
            newOrbitPosition = dx > 0 ? .right : .left
        } else {
            newOrbitPosition = dy > 0 ? .top : .bottom
        }
        
        widgetOrbitPosition = newOrbitPosition
        
        let snapPoint = calculateOrbitSnapPoint(panelFrame: panelFrame, position: newOrbitPosition)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            widgetWindow.animator().setFrameOrigin(snapPoint)
        }
    }
    
    private func calculateOrbitSnapPoint(panelFrame: NSRect, position: OrbitPosition) -> NSPoint {
        guard let screen = NSScreen.main else { return panelFrame.origin }
        let screenFrame = screen.visibleFrame
        
        var point: NSPoint
        
        switch position {
        case .right:
            point = NSPoint(
                x: panelFrame.maxX + orbitGap,
                y: panelFrame.midY - widgetSize / 2
            )
        case .left:
            point = NSPoint(
                x: panelFrame.minX - widgetSize - orbitGap,
                y: panelFrame.midY - widgetSize / 2
            )
        case .top:
            point = NSPoint(
                x: panelFrame.midX - widgetSize / 2,
                y: panelFrame.maxY + orbitGap
            )
        case .bottom:
            point = NSPoint(
                x: panelFrame.midX - widgetSize / 2,
                y: panelFrame.minY - widgetSize - orbitGap
            )
        }
        
        point.x = max(screenFrame.minX + edgePadding, min(point.x, screenFrame.maxX - widgetSize - edgePadding))
        point.y = max(screenFrame.minY + edgePadding, min(point.y, screenFrame.maxY - widgetSize - edgePadding))
        
        return point
    }
    
    // MARK: - Breathing Panel Window
    func openBreathingPanel() {
        guard !isPanelOpen else { return }
        guard let bubbleWindow = floatingBubbleWindow else { return }
        
        let bubbleFrame = bubbleWindow.frame
        let panelPosition = calculatePanelPosition(widgetFrame: bubbleFrame)
        
        let panel = NSPanel(
            contentRect: NSRect(x: panelPosition.x, y: panelPosition.y, width: panelSize, height: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        
        let contentView = ExerciseBubble(windowManager: self)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        
        panel.contentView = hostingView
        
        panel.alphaValue = 0
        hostingView.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
        panel.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            panel.animator().alphaValue = 1
            
            if let layer = hostingView.layer {
                let animation = CABasicAnimation(keyPath: "transform")
                animation.fromValue = CATransform3DMakeScale(0.8, 0.8, 1.0)
                animation.toValue = CATransform3DIdentity
                animation.duration = 0.4
                animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                layer.add(animation, forKey: "transform")
                layer.transform = CATransform3DIdentity
            }
        })
        
        exercisePanelWindow = panel
        isPanelOpen = true
        currentActivityType = .breathwork
        
        // The enabled index should already be set by selectAndOpenActivity
        // If not set (e.g., if called directly), find the first occurrence
        if currentActivityEnabledIndex == nil {
            let enabledActivities = settings.activityPlan.enabledActivities
            currentActivityEnabledIndex = enabledActivities.firstIndex(of: .breathwork)
        }
        
        let breathworkConfig = settings.activityPlan.getConfig(for: .breathwork)
        breathingSession.totalCycles = breathworkConfig.breathingCycles
        breathingSession.includeHoldEmpty = breathworkConfig.includeHoldEmpty
        
        timerManager.pause()
    }
    
    private func calculatePanelPosition(widgetFrame: NSRect) -> NSPoint {
        guard let screen = NSScreen.main else {
            return NSPoint(x: widgetFrame.midX - panelSize / 2, y: widgetFrame.maxY + orbitGap)
        }
        
        let screenFrame = screen.visibleFrame
        
        switch settings.exerciseBubblePosition {
        case .center:
            let centerX = screenFrame.midX - panelSize / 2
            let centerY = screenFrame.midY - panelSize / 2
            return NSPoint(x: centerX, y: centerY)
            
        case .nextToWidget:
            let gap: CGFloat = 20
            
            var panelX = widgetFrame.midX - panelSize / 2
            var panelY = widgetFrame.maxY + gap
            
            panelX = max(screenFrame.minX + edgePadding, min(panelX, screenFrame.maxX - panelSize - edgePadding))
            
            if panelY + panelSize > screenFrame.maxY - edgePadding {
                panelY = widgetFrame.minY - panelSize - gap
            }
            panelY = max(screenFrame.minY + edgePadding, min(panelY, screenFrame.maxY - panelSize - edgePadding))
            
            return NSPoint(x: panelX, y: panelY)
        }
    }
    
    private func closePanelWithAnimation() {
        guard let panel = exercisePanelWindow else { return }
        guard let hostingView = panel.contentView as? NSHostingView<ExerciseBubble> else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            panel.animator().alphaValue = 0
            
            if let layer = hostingView.layer {
                let animation = CABasicAnimation(keyPath: "transform")
                animation.fromValue = layer.transform
                animation.toValue = CATransform3DMakeScale(0.8, 0.8, 1.0)
                animation.duration = 0.3
                animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                layer.add(animation, forKey: "transform")
                layer.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
            }
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.exercisePanelWindow = nil
            self?.isPanelOpen = false
            self?.currentActivityType = nil
            self?.currentActivityEnabledIndex = nil
            self?.timerManager.restartAfterBreathing()
        })
    }
    
    func closeBreathingPanel() {
        guard exercisePanelWindow != nil else { return }
        
        breathingSession.reset()
        closePanelWithAnimation()
    }
    
    // MARK: - Exercise Panel Window
    func openExercisePanel(for activity: ActivityType) {
        guard !isPanelOpen else { return }
        guard let bubbleWindow = floatingBubbleWindow else { return }
        
        let bubbleFrame = bubbleWindow.frame
        let panelPosition = calculatePanelPosition(widgetFrame: bubbleFrame)
        
        let config = settings.activityPlan.getConfig(for: activity)
        exerciseSession.configure(exerciseType: activity, repCount: config.repCount)
        
        let panel = NSPanel(
            contentRect: NSRect(x: panelPosition.x, y: panelPosition.y, width: panelSize, height: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        
        let contentView = ExerciseBubble(windowManager: self)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        
        panel.contentView = hostingView
        
        panel.alphaValue = 0
        hostingView.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
        panel.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            panel.animator().alphaValue = 1
            
            if let layer = hostingView.layer {
                let animation = CABasicAnimation(keyPath: "transform")
                animation.fromValue = CATransform3DMakeScale(0.8, 0.8, 1.0)
                animation.toValue = CATransform3DIdentity
                animation.duration = 0.4
                animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                layer.add(animation, forKey: "transform")
                layer.transform = CATransform3DIdentity
            }
        })
        
        exercisePanelWindow = panel
        isPanelOpen = true
        currentActivityType = activity
        
        // The enabled index should already be set by selectAndOpenActivity
        // If not set (e.g., if called directly), find the first occurrence
        if currentActivityEnabledIndex == nil {
            let enabledActivities = settings.activityPlan.enabledActivities
            currentActivityEnabledIndex = enabledActivities.firstIndex(of: activity)
        }
        
        timerManager.pause()
    }
    
    func closeExercisePanel() {
        guard exercisePanelWindow != nil else { return }
        
        exerciseSession.reset()
        closePanelWithAnimation()
    }
    
    func skipExercise() {
        guard exercisePanelWindow != nil else { return }
        
        if let currentActivity = currentActivityType {
            settings.activityPlan.markActivitySkipped(currentActivity)
        }
        
        exerciseSession.reset()
        closePanelWithAnimation()
    }
    
    // MARK: - Toggle Panel
    func toggleBreathingPanel() {
        if isPanelOpen {
            if exercisePanelWindow != nil {
                if currentActivityType == .breathwork {
                    closeBreathingPanel()
                } else {
                    closeExercisePanel()
                }
            }
        } else {
            openBreathingPanel()
        }
    }
    
    // MARK: - Focus Breathing Panel
    func focusBreathingPanel() {
        exercisePanelWindow?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Settings Window
    func openSettings() {
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let settingsWidth: CGFloat = 400
        let settingsHeight: CGFloat = 580
        
        let x = screenFrame.midX - settingsWidth / 2
        let y = screenFrame.midY - settingsHeight / 2
        
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: settingsWidth, height: settingsHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settings"
        window.level = .floating
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        
        let contentView = SettingsView(
            settings: settings,
            timerManager: timerManager,
            windowManager: self,
            onDismiss: { [weak self] in
                self?.closeSettings()
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        window.contentView = hostingView
        
        window.alphaValue = 0
        window.orderFront(nil)
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }
        
        settingsWindow = window
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
        }
    }
    
    func closeSettings() {
        guard let window = settingsWindow else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.settingsWindow = nil
        })
    }
    
    // MARK: - Quit App
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

