import SwiftUI
import Observation

// MARK: - Breath State Enum
enum BreathState: String, CaseIterable {
    case idle = "IDLE"
    case inhale = "INHALE"
    case holdFull = "HOLD_FULL"
    case exhale = "EXHALE"
    case holdEmpty = "HOLD_EMPTY"
    case completed = "COMPLETED"
}

// MARK: - Phase Configuration
struct BreathPhaseConfig {
    let label: String
    let duration: TimeInterval // seconds
    let instruction: String
    let color: SIMD3<Float> // RGB 0-1 for Metal shader
    
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
        color: SIMD3<Float>(0.4, 0.8, 1.0) // Cyan/Blue
    ),
    .holdFull: BreathPhaseConfig(
        label: "Hold",
        duration: 6,
        instruction: "Hold your breath",
        color: SIMD3<Float>(0.6, 0.5, 1.0) // Purple
    ),
    .exhale: BreathPhaseConfig(
        label: "Exhale",
        duration: 8,
        instruction: "Exhale slowly through mouth",
        color: SIMD3<Float>(1.0, 0.4, 0.6) // Pink/Orange
    ),
    .holdEmpty: BreathPhaseConfig(
        label: "Rest",
        duration: 4,
        instruction: "Hold empty",
        color: SIMD3<Float>(0.2, 0.3, 0.5) // Dark Blue/Grey
    ),
    .completed: BreathPhaseConfig(
        label: "Done",
        duration: 0,
        instruction: "Session Complete",
        color: SIMD3<Float>(0.2, 0.8, 0.4) // Green
    )
]

// MARK: - Breathing Session Model
@Observable
class BreathingSession {
    // State
    var breathState: BreathState = .idle
    var isActive: Bool = false
    var elapsedTime: TimeInterval = 0
    var cycleCount: Int = 0
    
    // Settings
    var totalCycles: Int = 4
    var includeHoldEmpty: Bool = false
    var onComplete: (() -> Void)?
    
    // Computed
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
    
    // Display link for smooth animation
    private var displayLink: CVDisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    
    init() {
        setupDisplayLink()
    }
    
    deinit {
        stopDisplayLink()
    }
    
    // MARK: - Display Link Setup
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
    
    // MARK: - Animation Tick
    private func tick() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = lastFrameTime == 0 ? 0.016 : currentTime - lastFrameTime
        lastFrameTime = currentTime
        
        guard isActive && breathState != .completed else { return }
        
        elapsedTime += deltaTime
        
        // Check phase completion
        if elapsedTime >= currentConfig.duration {
            advancePhase()
        }
    }
    
    // MARK: - Phase Management
    private func advancePhase() {
        let nextState = nextPhase(from: breathState)
        
        // Check for cycle completion
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
    
    // MARK: - Expansion Calculation
    private func calculateExpansion() -> Float {
        switch breathState {
        case .idle, .completed:
            return 0.1
        case .inhale:
            // Ease out sine
            return Float(sin((progress * .pi) / 2))
        case .holdFull:
            return 1.0
        case .exhale:
            // Ease in out
            return Float(1.0 - sin((progress * .pi) / 2))
        case .holdEmpty:
            return 0.0
        }
    }
    
    // MARK: - Controls
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

