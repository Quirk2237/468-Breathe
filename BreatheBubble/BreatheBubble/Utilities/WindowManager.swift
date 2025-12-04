import SwiftUI
import AppKit

// MARK: - Window Manager
class WindowManager: ObservableObject {
    // Windows
    private var floatingBubbleWindow: NSWindow?
    private var breathingPanelWindow: NSWindow?
    private var settingsWindow: NSWindow?
    
    // Shared state
    @Published var timerManager = TimerManager()
    @Published var breathingSession = BreathingSession()
    @Published var settings = AppSettings.shared
    @Published var audioManager = AudioManager.shared
    
    // Panel state
    @Published var isPanelOpen: Bool = false
    
    private var windowMoveObserver: Any?
    private var snapDebounceTimer: Timer?
    private let widgetSize: CGFloat = 100
    private let panelSize: CGFloat = 340
    private let edgePadding: CGFloat = 20
    private let orbitGap: CGFloat = 10
    
    // Track widget position relative to panel
    private var widgetOrbitPosition: OrbitPosition = .right
    
    enum OrbitPosition {
        case top, bottom, left, right
    }
    
    init() {
        setupTimerCallback()
        setupSessionCallback()
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
                self?.openBreathingPanel()
            }
        }
    }
    
    private func setupSessionCallback() {
        breathingSession.onComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.closeBreathingPanel()
            }
        }
    }
    
    // MARK: - Floating Bubble Window
    func showFloatingBubble() {
        if floatingBubbleWindow != nil { return }
        
        // Create floating panel (120x120 to accommodate settings icon on hover)
        let windowSize: CGFloat = 120
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: windowSize, height: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            // Position using window size (120) to properly account for settings icon area
            let x = screenFrame.maxX - windowSize - edgePadding
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
        
        // Start timer automatically
        timerManager.start()
    }
    
    // MARK: - Handle Widget Movement
    private func handleWidgetMove() {
        if isPanelOpen {
            scheduleOrbitSnap()
        } else {
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
              let panelWindow = breathingPanelWindow else { return }
        
        let widgetFrame = widgetWindow.frame
        let panelFrame = panelWindow.frame
        
        // Calculate widget center relative to panel center
        let widgetCenter = NSPoint(x: widgetFrame.midX, y: widgetFrame.midY)
        let panelCenter = NSPoint(x: panelFrame.midX, y: panelFrame.midY)
        
        let dx = widgetCenter.x - panelCenter.x
        let dy = widgetCenter.y - panelCenter.y
        
        // Determine which side the widget should snap to based on drag direction
        let newOrbitPosition: OrbitPosition
        if abs(dx) > abs(dy) {
            newOrbitPosition = dx > 0 ? .right : .left
        } else {
            newOrbitPosition = dy > 0 ? .top : .bottom
        }
        
        widgetOrbitPosition = newOrbitPosition
        
        // Calculate snap position around the panel
        let snapPoint = calculateOrbitSnapPoint(panelFrame: panelFrame, position: newOrbitPosition)
        
        // Animate widget to orbit position
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
        
        // Clamp to screen bounds
        point.x = max(screenFrame.minX + edgePadding, min(point.x, screenFrame.maxX - widgetSize - edgePadding))
        point.y = max(screenFrame.minY + edgePadding, min(point.y, screenFrame.maxY - widgetSize - edgePadding))
        
        return point
    }
    
    // MARK: - Breathing Panel Window
    func openBreathingPanel() {
        guard !isPanelOpen else { return }
        guard let bubbleWindow = floatingBubbleWindow else { return }
        
        // Calculate panel position (centered on screen, clamped to visible area)
        let bubbleFrame = bubbleWindow.frame
        let panelPosition = calculateCenteredPanelPosition(widgetFrame: bubbleFrame)
        
        // Create panel (independent window, not a child)
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
        
        let contentView = BreathingPanelView(windowManager: self)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        
        panel.contentView = hostingView
        
        // Animate in (panel is independent, not a child window)
        panel.alphaValue = 0
        panel.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1
        }
        
        breathingPanelWindow = panel
        isPanelOpen = true
        
        // Position widget to the side of the panel
        positionWidgetAroundPanel(panelFrame: panel.frame)
        
        // Configure breathing session
        breathingSession.totalCycles = settings.breathingCycles
        breathingSession.includeHoldEmpty = settings.includeHoldEmpty
        
        // Start audio if enabled
        if settings.soundEnabled {
            audioManager.play(track: settings.selectedTrack, volume: settings.volume)
        }
        
        // Pause timer while breathing
        timerManager.pause()
    }
    
    // Calculate panel position centered near widget but clamped to screen
    private func calculateCenteredPanelPosition(widgetFrame: NSRect) -> NSPoint {
        guard let screen = NSScreen.main else {
            return NSPoint(x: widgetFrame.minX - panelSize - orbitGap, y: widgetFrame.midY - panelSize / 2)
        }
        
        let screenFrame = screen.visibleFrame
        
        // Try to center panel near the widget
        var panelX = widgetFrame.midX - panelSize / 2
        var panelY = widgetFrame.midY - panelSize / 2
        
        // Clamp to screen bounds with padding
        panelX = max(screenFrame.minX + edgePadding, min(panelX, screenFrame.maxX - panelSize - edgePadding))
        panelY = max(screenFrame.minY + edgePadding, min(panelY, screenFrame.maxY - panelSize - edgePadding))
        
        return NSPoint(x: panelX, y: panelY)
    }
    
    // Position widget around panel based on available space
    private func positionWidgetAroundPanel(panelFrame: NSRect) {
        guard let widgetWindow = floatingBubbleWindow,
              let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        
        // Determine best orbit position based on available space
        let spaceRight = screenFrame.maxX - panelFrame.maxX
        let spaceLeft = panelFrame.minX - screenFrame.minX
        let spaceTop = screenFrame.maxY - panelFrame.maxY
        let spaceBottom = panelFrame.minY - screenFrame.minY
        
        let requiredSpace = widgetSize + orbitGap + edgePadding
        
        // Choose position with most space
        if spaceRight >= requiredSpace {
            widgetOrbitPosition = .right
        } else if spaceLeft >= requiredSpace {
            widgetOrbitPosition = .left
        } else if spaceBottom >= requiredSpace {
            widgetOrbitPosition = .bottom
        } else if spaceTop >= requiredSpace {
            widgetOrbitPosition = .top
        } else {
            widgetOrbitPosition = .right // Fallback
        }
        
        let snapPoint = calculateOrbitSnapPoint(panelFrame: panelFrame, position: widgetOrbitPosition)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            widgetWindow.animator().setFrameOrigin(snapPoint)
        }
    }
    
    func closeBreathingPanel() {
        guard let panel = breathingPanelWindow else { return }
        
        // Stop breathing
        breathingSession.reset()
        
        // Stop audio
        audioManager.stop()
        
        // Animate out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.breathingPanelWindow = nil
            self?.isPanelOpen = false
            
            // Restart timer
            self?.timerManager.restartAfterBreathing()
        })
    }
    
    // MARK: - Toggle Panel
    func toggleBreathingPanel() {
        if isPanelOpen {
            closeBreathingPanel()
        } else {
            openBreathingPanel()
        }
    }
    
    // MARK: - Focus Breathing Panel
    func focusBreathingPanel() {
        breathingPanelWindow?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Settings Window
    func openSettings() {
        // If settings window already exists, bring it to front
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Calculate centered position
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let settingsWidth: CGFloat = 320
        let settingsHeight: CGFloat = 500
        
        let x = screenFrame.midX - settingsWidth / 2
        let y = screenFrame.midY - settingsHeight / 2
        
        // Create settings window
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: settingsWidth, height: settingsHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Breathe Bubble Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        
        let contentView = SettingsView(
            settings: settings,
            audioManager: audioManager,
            session: isPanelOpen ? breathingSession : nil,
            onDismiss: { [weak self] in
                self?.closeSettings()
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        window.contentView = hostingView
        
        // Animate in
        window.alphaValue = 0
        window.orderFront(nil)
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }
        
        settingsWindow = window
        
        // Watch for window close
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

