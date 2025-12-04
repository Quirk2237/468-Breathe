import SwiftUI
import Observation
import UserNotifications

// MARK: - Timer State
enum TimerState {
    case idle
    case running
    case paused
    case completed
}

// MARK: - Timer Manager
@Observable
class TimerManager {
    // State
    var state: TimerState = .idle
    var remainingSeconds: Int = 30 * 60 // Default 30 minutes
    var totalSeconds: Int = 30 * 60
    
    // Settings
    var intervalMinutes: Int = 30 {
        didSet {
            if state == .idle {
                totalSeconds = intervalMinutes * 60
                remainingSeconds = totalSeconds
            }
        }
    }
    
    // Computed
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
    
    // Private
    private var timer: Timer?
    
    // Callbacks
    var onTimerComplete: (() -> Void)?
    
    init() {
        requestNotificationPermission()
    }
    
    // MARK: - Notification Permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    // MARK: - Timer Controls
    func start() {
        guard state != .running else { return }
        
        if state == .idle || state == .completed {
            remainingSeconds = totalSeconds
        }
        
        state = .running
        startTimer()
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
        // Skip timer and trigger breathwork immediately
        stopTimer()
        state = .completed
        onTimerComplete?()
    }
    
    // MARK: - Internal Timer
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
        
        // Send notification
        sendCompletionNotification()
        
        // Trigger callback
        onTimerComplete?()
    }
    
    // MARK: - Notifications
    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Breathe"
        content.body = "Your breathing session is ready. Take a moment to relax."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Restart After Breathing
    func restartAfterBreathing() {
        reset()
        start()
    }
}

