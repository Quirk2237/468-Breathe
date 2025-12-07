import SwiftUI
import Observation

// MARK: - Activity Type
enum ActivityType: String, CaseIterable, Identifiable, Codable, Hashable {
    case breathwork = "breathwork"
    case pushups = "pushups"
    case situps = "situps"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .breathwork:
            return "Breathwork"
        case .pushups:
            return "Push-ups"
        case .situps:
            return "Sit-ups"
        }
    }
    
    var icon: String {
        switch self {
        case .breathwork:
            return "wind"
        case .pushups:
            return "figure.strengthtraining.traditional"
        case .situps:
            return "figure.core.training"
        }
    }
    
    var instruction: String {
        switch self {
        case .breathwork:
            return "Follow the breathing pattern"
        case .pushups:
            return "Complete the reps at your own pace"
        case .situps:
            return "Complete the reps at your own pace"
        }
    }
}

// MARK: - Activity Configuration
struct ActivityConfig: Codable, Equatable {
    var enabled: Bool
    var repCount: Int
    var breathingCycles: Int
    var includeHoldEmpty: Bool
    
    init(enabled: Bool = false, repCount: Int = 10, breathingCycles: Int = 4, includeHoldEmpty: Bool = false) {
        self.enabled = enabled
        self.repCount = repCount
        self.breathingCycles = breathingCycles
        self.includeHoldEmpty = includeHoldEmpty
    }
}

// MARK: - Activity Plan Manager
@Observable
class ActivityPlan {
    var activities: [ActivityType: ActivityConfig] = [
        .breathwork: ActivityConfig(enabled: true, repCount: 0, breathingCycles: 4, includeHoldEmpty: false),
        .pushups: ActivityConfig(enabled: false, repCount: 10),
        .situps: ActivityConfig(enabled: false, repCount: 10)
    ]
    
    var activityOrder: [ActivityType] = ActivityType.allCases
    var lastCompletedActivity: ActivityType?
    
    var enabledActivities: [ActivityType] {
        activityOrder.filter { activities[$0]?.enabled == true }
    }
    
    func selectRandomActivity() -> ActivityType? {
        let enabled = enabledActivities
        guard !enabled.isEmpty else { return nil }
        return enabled.randomElement()
    }
    
    func getNextActivity() -> ActivityType? {
        let enabled = enabledActivities
        guard !enabled.isEmpty else { return nil }
        
        guard let lastCompleted = lastCompletedActivity else {
            return enabled.first
        }
        
        guard let lastIndex = enabled.firstIndex(of: lastCompleted) else {
            return enabled.first
        }
        
        let nextIndex = (lastIndex + 1) % enabled.count
        return enabled[nextIndex]
    }
    
    func markActivityCompleted(_ activity: ActivityType) {
        lastCompletedActivity = activity
    }
    
    func resetCompletionTracking() {
        lastCompletedActivity = nil
    }
    
    func reorderActivities(_ newOrder: [ActivityType]) {
        let allActivities = Set(ActivityType.allCases)
        let newOrderSet = Set(newOrder)
        let missingActivities = allActivities.subtracting(newOrderSet)
        activityOrder = newOrder + Array(missingActivities)
    }
    
    func getConfig(for activity: ActivityType) -> ActivityConfig {
        activities[activity] ?? ActivityConfig()
    }
    
    func updateConfig(for activity: ActivityType, config: ActivityConfig) {
        activities[activity] = config
    }
}

