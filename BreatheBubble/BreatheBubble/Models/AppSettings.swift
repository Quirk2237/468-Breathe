import SwiftUI
import Observation

// MARK: - Day Times
struct DayTimes: Codable {
    var startTime: Date?
    var endTime: Date?
}

// MARK: - Widget Size
enum WidgetSize: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    
    var id: String { rawValue }
    
    var dimension: CGFloat {
        switch self {
        case .small: return 80
        case .medium: return 100
        case .large: return 120
        }
    }
    
    var windowSize: CGFloat {
        switch self {
        case .small: return 140
        case .medium: return 160
        case .large: return 180
        }
    }
}

// MARK: - Exercise Bubble Position
enum ExerciseBubblePosition: String, CaseIterable, Identifiable {
    case nextToWidget = "Next to Widget"
    case center = "Center of Screen"
    
    var id: String { rawValue }
}

// MARK: - App Settings
@Observable
class AppSettings {
    // Timer Settings
    var timerIntervalMinutes: Int = 30 {
        didSet {
            UserDefaults.standard.set(timerIntervalMinutes, forKey: "timerIntervalMinutes")
        }
    }
    
    // Widget Settings
    var widgetSize: WidgetSize = .medium {
        didSet {
            UserDefaults.standard.set(widgetSize.rawValue, forKey: "widgetSize")
            onWidgetSizeChange?(widgetSize)
        }
    }
    
    var onWidgetSizeChange: ((WidgetSize) -> Void)?
    
    // Exercise Bubble Settings
    var exerciseBubblePosition: ExerciseBubblePosition = .nextToWidget {
        didSet {
            UserDefaults.standard.set(exerciseBubblePosition.rawValue, forKey: "exerciseBubblePosition")
        }
    }
    
    // Notification Settings
    var playChimeOnTimerComplete: Bool = false {
        didSet {
            UserDefaults.standard.set(playChimeOnTimerComplete, forKey: "playChimeOnTimerComplete")
        }
    }
    
    // Activity Settings
    var activityPlan = ActivityPlan()
    
    // Daily completion tracking (keyed by "YYYY-MM-DD")
    var dailyCompletions: [String: [ActivityType: Int]] = [:] {
        didSet {
            saveDailyCompletions()
        }
    }
    
    // Daily time tracking (keyed by "YYYY-MM-DD")
    var dailyTimes: [String: DayTimes] = [:] {
        didSet {
            saveDailyTimes()
        }
    }
    
    func updateActivityConfig(for activity: ActivityType, config: ActivityConfig) {
        let wasEnabled = activityPlan.activities[activity]?.enabled ?? false
        activityPlan.updateConfig(for: activity, config: config)
        
        if !config.enabled && wasEnabled {
            activityPlan.activityOrder.removeAll { $0 == activity }
        } else if config.enabled && !wasEnabled && !activityPlan.activityOrder.contains(activity) {
            activityPlan.activityOrder.append(activity)
        }
        
        saveActivitySettings()
    }
    
    func saveActivitySettings() {
        let defaults = UserDefaults.standard
        
        for activity in ActivityType.allCases {
            let config = activityPlan.getConfig(for: activity)
            let key = "activity_\(activity.rawValue)_enabled"
            let repKey = "activity_\(activity.rawValue)_reps"
            
            defaults.set(config.enabled, forKey: key)
            defaults.set(config.repCount, forKey: repKey)
            
            if activity == .breathwork {
                defaults.set(config.breathingCycles, forKey: "activity_\(activity.rawValue)_cycles")
                defaults.set(config.includeHoldEmpty, forKey: "activity_\(activity.rawValue)_holdEmpty")
            }
        }
        
        let orderRawValues = activityPlan.activityOrder.map { $0.rawValue }
        defaults.set(orderRawValues, forKey: "activityOrder")
    }
    
    // MARK: - Completion Tracking
    func recordCompletion(_ activity: ActivityType, for date: Date) {
        let dateKey = dateKeyString(for: date)
        if dailyCompletions[dateKey] == nil {
            dailyCompletions[dateKey] = [:]
        }
        dailyCompletions[dateKey]?[activity, default: 0] += 1
    }
    
    func getCompletions(for date: Date) -> [ActivityType: Int] {
        let dateKey = dateKeyString(for: date)
        return dailyCompletions[dateKey] ?? [:]
    }
    
    func getCompletionPercentage(for date: Date) -> Double {
        let completions = getCompletions(for: date)
        let enabledActivities = activityPlan.enabledActivities
        
        guard !enabledActivities.isEmpty else { return 0 }
        
        let completedCount = enabledActivities.filter { activity in
            (completions[activity] ?? 0) > 0
        }.count
        
        return Double(completedCount) / Double(enabledActivities.count)
    }
    
    // MARK: - Day Times Tracking
    func recordDayStart(for date: Date) {
        let dateKey = dateKeyString(for: date)
        if dailyTimes[dateKey] == nil {
            dailyTimes[dateKey] = DayTimes()
        }
        dailyTimes[dateKey]?.startTime = date
    }
    
    func recordDayEnd(for date: Date) {
        let dateKey = dateKeyString(for: date)
        if dailyTimes[dateKey] == nil {
            dailyTimes[dateKey] = DayTimes()
        }
        dailyTimes[dateKey]?.endTime = date
    }
    
    func getDayTimes(for date: Date) -> DayTimes? {
        let dateKey = dateKeyString(for: date)
        return dailyTimes[dateKey]
    }
    
    private func dateKeyString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Initialization
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: "timerIntervalMinutes") != nil {
            timerIntervalMinutes = defaults.integer(forKey: "timerIntervalMinutes")
        }
        
        if let sizeRaw = defaults.string(forKey: "widgetSize"),
           let size = WidgetSize(rawValue: sizeRaw) {
            widgetSize = size
        }
        
        if let positionRaw = defaults.string(forKey: "exerciseBubblePosition"),
           let position = ExerciseBubblePosition(rawValue: positionRaw) {
            exerciseBubblePosition = position
        }
        
        if defaults.object(forKey: "playChimeOnTimerComplete") != nil {
            playChimeOnTimerComplete = defaults.bool(forKey: "playChimeOnTimerComplete")
        }
        
        loadActivitySettings()
        loadDailyCompletions()
        loadDailyTimes()
    }
    
    // MARK: - Activity Settings Persistence
    
    private func loadActivitySettings() {
        let defaults = UserDefaults.standard
        
        if let orderRawValues = defaults.array(forKey: "activityOrder") as? [String] {
            let loadedOrder = orderRawValues.compactMap { ActivityType(rawValue: $0) }
            activityPlan.activityOrder = loadedOrder.isEmpty ? ActivityType.allCases : loadedOrder
        } else {
            activityPlan.activityOrder = ActivityType.allCases
        }
        
        for activity in ActivityType.allCases {
            let enabledKey = "activity_\(activity.rawValue)_enabled"
            let repKey = "activity_\(activity.rawValue)_reps"
            
            let enabled: Bool
            if defaults.object(forKey: enabledKey) != nil {
                enabled = defaults.bool(forKey: enabledKey)
            } else {
                enabled = activity == .breathwork
            }
            
            let repCount: Int
            if defaults.object(forKey: repKey) != nil {
                repCount = defaults.integer(forKey: repKey)
            } else {
                repCount = 10
            }
            
            if activity == .breathwork {
                let cyclesKey = "activity_\(activity.rawValue)_cycles"
                let holdEmptyKey = "activity_\(activity.rawValue)_holdEmpty"
                
                let breathingCycles: Int
                if defaults.object(forKey: cyclesKey) != nil {
                    breathingCycles = defaults.integer(forKey: cyclesKey)
                } else if defaults.object(forKey: "breathingCycles") != nil {
                    breathingCycles = defaults.integer(forKey: "breathingCycles")
                    defaults.set(breathingCycles, forKey: cyclesKey)
                } else {
                    breathingCycles = 4
                }
                
                let includeHoldEmpty: Bool
                if defaults.object(forKey: holdEmptyKey) != nil {
                    includeHoldEmpty = defaults.bool(forKey: holdEmptyKey)
                } else if defaults.object(forKey: "includeHoldEmpty") != nil {
                    includeHoldEmpty = defaults.bool(forKey: "includeHoldEmpty")
                    defaults.set(includeHoldEmpty, forKey: holdEmptyKey)
                } else {
                    includeHoldEmpty = false
                }
                
                activityPlan.updateConfig(for: activity, config: ActivityConfig(
                    enabled: enabled,
                    repCount: repCount,
                    breathingCycles: breathingCycles,
                    includeHoldEmpty: includeHoldEmpty
                ))
            } else {
                activityPlan.updateConfig(for: activity, config: ActivityConfig(enabled: enabled, repCount: repCount))
            }
        }
        
        // Load last completed activity
        activityPlan.loadLastCompletedActivity()
    }
    
    // MARK: - Daily Completions Persistence
    private func saveDailyCompletions() {
        let defaults = UserDefaults.standard
        
        var serializable: [String: [String: Int]] = [:]
        for (dateKey, activities) in dailyCompletions {
            var activitiesDict: [String: Int] = [:]
            for (activity, count) in activities {
                activitiesDict[activity.rawValue] = count
            }
            serializable[dateKey] = activitiesDict
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: serializable) {
            defaults.set(data, forKey: "dailyCompletions")
        }
    }
    
    private func loadDailyCompletions() {
        let defaults = UserDefaults.standard
        
        guard let data = defaults.data(forKey: "dailyCompletions"),
              let serializable = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Int]] else {
            return
        }
        
        var completions: [String: [ActivityType: Int]] = [:]
        for (dateKey, activitiesDict) in serializable {
            var activities: [ActivityType: Int] = [:]
            for (activityRaw, count) in activitiesDict {
                if let activity = ActivityType(rawValue: activityRaw) {
                    activities[activity] = count
                }
            }
            completions[dateKey] = activities
        }
        
        dailyCompletions = completions
    }
    
    // MARK: - Daily Times Persistence
    private func saveDailyTimes() {
        let defaults = UserDefaults.standard
        
        if let data = try? JSONEncoder().encode(dailyTimes) {
            defaults.set(data, forKey: "dailyTimes")
        }
    }
    
    private func loadDailyTimes() {
        let defaults = UserDefaults.standard
        
        guard let data = defaults.data(forKey: "dailyTimes"),
              let times = try? JSONDecoder().decode([String: DayTimes].self, from: data) else {
            return
        }
        
        dailyTimes = times
    }
    
    // MARK: - Reset
    func resetToDefaults() {
        timerIntervalMinutes = 30
        widgetSize = .medium
        exerciseBubblePosition = .nextToWidget
        playChimeOnTimerComplete = false
        
        activityPlan = ActivityPlan()
        activityPlan.updateConfig(for: .breathwork, config: ActivityConfig(enabled: true, repCount: 0, breathingCycles: 4, includeHoldEmpty: false))
        activityPlan.updateConfig(for: .pushups, config: ActivityConfig(enabled: false, repCount: 10))
        activityPlan.updateConfig(for: .situps, config: ActivityConfig(enabled: false, repCount: 10))
        activityPlan.updateConfig(for: .squats, config: ActivityConfig(enabled: false, repCount: 10))
        saveActivitySettings()
    }
}

// MARK: - Shared Instance
extension AppSettings {
    static let shared = AppSettings()
}


