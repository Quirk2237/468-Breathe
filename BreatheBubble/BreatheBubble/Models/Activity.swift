import SwiftUI
import Observation

// MARK: - Activity Type
enum ActivityType: String, CaseIterable, Identifiable, Codable, Hashable {
    case breathwork = "breathwork"
    case pushups = "pushups"
    case situps = "situps"
    case squats = "squats"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .breathwork:
            return "Breathwork"
        case .pushups:
            return "Push-ups"
        case .situps:
            return "Sit-ups"
        case .squats:
            return "Squats"
        }
    }
    
    var icon: String {
        switch self {
        case .breathwork:
            return "wind"
        case .pushups:
            return "hand.raised.fill"
        case .situps:
            return "arrow.up.arrow.down"
        case .squats:
            return "figure.walk"
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
        case .squats:
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
        .situps: ActivityConfig(enabled: false, repCount: 10),
        .squats: ActivityConfig(enabled: false, repCount: 10)
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
    
    func getNextActivityIndex() -> Int? {
        let enabled = enabledActivities
        guard !enabled.isEmpty else { return nil }
        
        guard let lastCompleted = lastCompletedActivity else {
            return 0
        }
        
        guard let lastIndex = enabled.firstIndex(of: lastCompleted) else {
            return 0
        }
        
        let nextIndex = (lastIndex + 1) % enabled.count
        return nextIndex
    }
    
    func markActivityCompleted(_ activity: ActivityType) {
        lastCompletedActivity = activity
        saveLastCompletedActivity()
    }
    
    func markActivitySkipped(_ activity: ActivityType) {
        lastCompletedActivity = activity
        saveLastCompletedActivity()
    }
    
    func resetCompletionTracking() {
        lastCompletedActivity = nil
        saveLastCompletedActivity()
    }
    
    private func saveLastCompletedActivity() {
        let defaults = UserDefaults.standard
        if let activity = lastCompletedActivity {
            defaults.set(activity.rawValue, forKey: "lastCompletedActivity")
        } else {
            defaults.removeObject(forKey: "lastCompletedActivity")
        }
    }
    
    func loadLastCompletedActivity() {
        let defaults = UserDefaults.standard
        if let activityRaw = defaults.string(forKey: "lastCompletedActivity"),
           let activity = ActivityType(rawValue: activityRaw) {
            lastCompletedActivity = activity
        } else {
            lastCompletedActivity = nil
        }
    }
    
    func reorderActivities(_ newOrder: [ActivityType]) {
        activityOrder = newOrder
    }
    
    func duplicateActivity(at index: Int) {
        guard index < activityOrder.count else { return }
        let activityToDuplicate = activityOrder[index]
        activityOrder.insert(activityToDuplicate, at: index + 1)
    }
    
    func removeActivity(at index: Int) {
        guard index < activityOrder.count else { return }
        activityOrder.remove(at: index)
    }
    
    func indexInActivityOrder(forEnabledIndex enabledIndex: Int) -> Int? {
        let enabled = enabledActivities
        guard enabledIndex >= 0 && enabledIndex < enabled.count else { return nil }
        
        let targetActivity = enabled[enabledIndex]
        var enabledCount = 0
        
        for (orderIndex, activity) in activityOrder.enumerated() {
            if activities[activity]?.enabled == true {
                if enabledCount == enabledIndex {
                    return orderIndex
                }
                enabledCount += 1
            }
        }
        
        return nil
    }
    
    func getConfig(for activity: ActivityType) -> ActivityConfig {
        activities[activity] ?? ActivityConfig()
    }
    
    func updateConfig(for activity: ActivityType, config: ActivityConfig) {
        activities[activity] = config
    }
}

