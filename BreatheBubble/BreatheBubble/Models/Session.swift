import SwiftUI
import Observation
import UserNotifications

// MARK: - Breath State
enum BreathState: String, CaseIterable {
    case idle = "IDLE"
    case inhale = "INHALE"
    case holdFull = "HOLD_FULL"
    case exhale = "EXHALE"
    case holdEmpty = "HOLD_EMPTY"
    case completed = "COMPLETED"
}

// MARK: - Timer State
enum TimerState {
    case idle
    case running
    case paused
    case completed
}

// MARK: - Phase Configuration
struct BreathPhaseConfig {
    let label: String
    let duration: TimeInterval
    let instruction: String
    let color: SIMD3<Float>
    
    var swiftUIColor: Color {
        Color(red: Double(color.x), green: Double(color.y), blue: Double(color.z))
    }
}

// MARK: - Phase Configurations
let phaseConfigs: [BreathState: BreathPhaseConfig] = [
    .idle: BreathPhaseConfig(
        label: "Ready",
        duration: 0,
        instruction: "Tap to start",
        color: SIMD3<Float>(0.2, 0.6, 1.0)
    ),
    .inhale: BreathPhaseConfig(
        label: "Inhale",
        duration: 4,
        instruction: "Inhale quietly through nose",
        color: SIMD3<Float>(0.4, 0.8, 1.0)
    ),
    .holdFull: BreathPhaseConfig(
        label: "Hold",
        duration: 6,
        instruction: "Hold your breath",
        color: SIMD3<Float>(0.6, 0.5, 1.0)
    ),
    .exhale: BreathPhaseConfig(
        label: "Exhale",
        duration: 8,
        instruction: "Exhale slowly through mouth",
        color: SIMD3<Float>(1.0, 0.4, 0.6)
    ),
    .holdEmpty: BreathPhaseConfig(
        label: "Rest",
        duration: 4,
        instruction: "Hold empty",
        color: SIMD3<Float>(0.2, 0.3, 0.5)
    ),
    .completed: BreathPhaseConfig(
        label: "Done",
        duration: 0,
        instruction: "Session Complete",
        color: SIMD3<Float>(0.2, 0.8, 0.4)
    )
]

// MARK: - Breathing Session
@Observable
class BreathingSession {
    var breathState: BreathState = .idle
    var isActive: Bool = false
    var elapsedTime: TimeInterval = 0
    var cycleCount: Int = 0
    
    var totalCycles: Int = 4
    var includeHoldEmpty: Bool = false
    var onComplete: (() -> Void)?
    
    var currentConfig: BreathPhaseConfig {
        phaseConfigs[breathState] ?? phaseConfigs[.idle]!
    }
    
    var expansion: Float {
        calculateExpansion()
    }
    
    var currentColor: SIMD3<Float> {
        currentConfig.color
    }
    
    var progress: Double {
        guard currentConfig.duration > 0 else { return 0 }
        return min(elapsedTime / currentConfig.duration, 1.0)
    }
    
    private var displayLink: CVDisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    
    init() {
        setupDisplayLink()
    }
    
    deinit {
        stopDisplayLink()
    }
    
    private func setupDisplayLink() {
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        guard let link = displayLink else { return }
        self.displayLink = link
        
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let session = Unmanaged<BreathingSession>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                session.tick()
            }
            return kCVReturnSuccess
        }
        
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, callback, userInfo)
        CVDisplayLinkStart(link)
    }
    
    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
    }
    
    private func tick() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = lastFrameTime == 0 ? 0.016 : currentTime - lastFrameTime
        lastFrameTime = currentTime
        
        guard isActive && breathState != .completed else { return }
        
        elapsedTime += deltaTime
        
        if elapsedTime >= currentConfig.duration {
            advancePhase()
        }
    }
    
    private func advancePhase() {
        let nextState = nextPhase(from: breathState)
        
        if nextState == .inhale {
            cycleCount += 1
            if cycleCount >= totalCycles {
                breathState = .completed
                isActive = false
                onComplete?()
                return
            }
        }
        
        breathState = nextState
        elapsedTime = 0
    }
    
    private func nextPhase(from current: BreathState) -> BreathState {
        switch current {
        case .idle: return .inhale
        case .inhale: return .holdFull
        case .holdFull: return .exhale
        case .exhale: return includeHoldEmpty ? .holdEmpty : .inhale
        case .holdEmpty: return .inhale
        case .completed: return .idle
        }
    }
    
    private func calculateExpansion() -> Float {
        switch breathState {
        case .idle, .completed:
            return 0.1
        case .inhale:
            return Float(sin((progress * .pi) / 2))
        case .holdFull:
            return 1.0
        case .exhale:
            return Float(1.0 - sin((progress * .pi) / 2))
        case .holdEmpty:
            return 0.0
        }
    }
    
    func toggle() {
        if breathState == .completed {
            reset()
            breathState = .inhale
            isActive = true
        } else if breathState == .idle {
            breathState = .inhale
            isActive = true
        } else {
            isActive.toggle()
        }
    }
    
    func start() {
        if breathState == .idle || breathState == .completed {
            reset()
            breathState = .inhale
        }
        isActive = true
    }
    
    func pause() {
        isActive = false
    }
    
    func reset() {
        isActive = false
        breathState = .idle
        elapsedTime = 0
        cycleCount = 0
    }
}

// MARK: - Timer Manager
@Observable
class TimerManager {
    var state: TimerState = .idle
    var remainingSeconds: Int = 30 * 60
    var totalSeconds: Int = 30 * 60
    
    var dayStarted: Bool = false {
        didSet {
            UserDefaults.standard.set(dayStarted, forKey: "dayStarted")
        }
    }
    var dayStartTime: Date? {
        didSet {
            if let date = dayStartTime {
                UserDefaults.standard.set(date, forKey: "dayStartTime")
            } else {
                UserDefaults.standard.removeObject(forKey: "dayStartTime")
            }
        }
    }
    var dayEndTime: Date? {
        didSet {
            if let date = dayEndTime {
                UserDefaults.standard.set(date, forKey: "dayEndTime")
            } else {
                UserDefaults.standard.removeObject(forKey: "dayEndTime")
            }
        }
    }
    
    var isDayActive: Bool {
        dayStarted && dayStartTime != nil
    }
    
    var intervalMinutes: Int = 30 {
        didSet {
            if state == .idle {
                totalSeconds = intervalMinutes * 60
                remainingSeconds = totalSeconds
            }
        }
    }
    
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
    
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedTimeShort: String {
        let minutes = remainingSeconds / 60
        if remainingSeconds < 60 {
            return "\(remainingSeconds)s"
        }
        return "\(minutes)m"
    }
    
    var isRunning: Bool {
        state == .running
    }
    
    private var timer: Timer?
    var onTimerComplete: (() -> Void)?
    var onDayEnd: (() -> Void)?
    
    init() {
        requestNotificationPermission()
        loadPersistedDayStatus()
    }
    
    private func loadPersistedDayStatus() {
        let defaults = UserDefaults.standard
        
        // Load persisted day started status
        if defaults.object(forKey: "dayStarted") != nil {
            dayStarted = defaults.bool(forKey: "dayStarted")
        }
        
        // Load persisted day start time
        if let persistedDate = defaults.object(forKey: "dayStartTime") as? Date {
            // Check if the persisted day is still valid (same calendar day)
            if Calendar.current.isDate(persistedDate, inSameDayAs: Date()) {
                dayStartTime = persistedDate
            } else {
                // Day has changed, reset the status
                dayStarted = false
                dayStartTime = nil
            }
        }
        
        // Load persisted day end time
        if let persistedEndDate = defaults.object(forKey: "dayEndTime") as? Date {
            // Check if the persisted end time is from today
            if Calendar.current.isDate(persistedEndDate, inSameDayAs: Date()) {
                dayEndTime = persistedEndDate
            } else {
                dayEndTime = nil
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func start() {
        guard state != .running else { return }
        
        if !dayStarted {
            startDay()
        }
        
        if state == .idle || state == .completed {
            remainingSeconds = totalSeconds
        }
        
        state = .running
        startTimer()
    }
    
    func startDay() {
        dayStarted = true
        dayStartTime = Date()
        dayEndTime = nil
        
        if state == .idle || state == .completed {
            remainingSeconds = totalSeconds
        }
        
        if state != .running {
            state = .running
            startTimer()
        }
    }
    
    func endDay() {
        stopTimer()
        state = .idle
        remainingSeconds = totalSeconds
        
        dayEndTime = Date()
        dayStarted = false
        
        onDayEnd?()
    }
    
    func pause() {
        guard state == .running else { return }
        state = .paused
        stopTimer()
    }
    
    func resume() {
        guard state == .paused else { return }
        state = .running
        startTimer()
    }
    
    func toggle() {
        switch state {
        case .idle, .completed:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        }
    }
    
    func reset() {
        stopTimer()
        state = .idle
        remainingSeconds = totalSeconds
    }
    
    func skip() {
        stopTimer()
        state = .completed
        onTimerComplete?()
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        guard remainingSeconds > 0 else {
            complete()
            return
        }
        remainingSeconds -= 1
        
        if remainingSeconds == 0 {
            complete()
        }
    }
    
    private func complete() {
        stopTimer()
        state = .completed
        sendCompletionNotification()
        onTimerComplete?()
    }
    
    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Breathe"
        content.body = "Your breathing session is ready. Take a moment to relax."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func restartAfterBreathing() {
        reset()
        start()
    }
}

// MARK: - Exercise Session State
enum ExerciseState {
    case idle
    case active
    case completed
}

// MARK: - Exercise Session
@Observable
class ExerciseSession {
    var exerciseType: ActivityType = .pushups
    var targetReps: Int = 10
    var state: ExerciseState = .idle
    var onComplete: (() -> Void)?
    
    var exerciseName: String {
        exerciseType.displayName
    }
    
    var exerciseIcon: String {
        exerciseType.icon
    }
    
    var exerciseInstruction: String {
        exerciseType.instruction
    }
    
    var exerciseColor: SIMD3<Float> {
        switch exerciseType {
        case .breathwork:
            return SIMD3<Float>(0.4, 0.8, 1.0)
        case .pushups:
            return SIMD3<Float>(1.0, 0.5, 0.3)
        case .situps:
            return SIMD3<Float>(0.3, 0.8, 0.5)
        }
    }
    
    func configure(exerciseType: ActivityType, repCount: Int) {
        self.exerciseType = exerciseType
        self.targetReps = repCount
        reset()
    }
    
    func start() {
        state = .active
    }
    
    func complete() {
        state = .completed
        onComplete?()
    }
    
    func reset() {
        state = .idle
    }
}


