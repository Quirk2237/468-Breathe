import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Bindable var settings: AppSettings
    var timerManager: TimerManager?
    var session: BreathingSession?
    var onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var environmentDismiss
    
    private let accentColor = Color(red: 53/255.0, green: 211/255.0, blue: 153/255.0)
    
    private func handleDismiss() {
        if let timerManager = timerManager {
            let newTotalSeconds = settings.timerIntervalMinutes * 60
            let elapsedSeconds = timerManager.totalSeconds - timerManager.remainingSeconds
            
            timerManager.totalSeconds = newTotalSeconds
            timerManager.remainingSeconds = max(0, newTotalSeconds - elapsedSeconds)
            timerManager.intervalMinutes = settings.timerIntervalMinutes
        }
        
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            environmentDismiss()
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Activity History Section
                    settingsSection("Activity History") {
                        ActivityHistorySection(settings: settings, timerManager: timerManager)
                    }
                    
                    settingsSection("Intervals") {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Reminder Interval")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(settings.timerIntervalMinutes) min")
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { Double(settings.timerIntervalMinutes) },
                                    set: { settings.timerIntervalMinutes = Int($0) }
                                ),
                                in: 5...120,
                                step: 5
                            )
                            .tint(accentColor)
                        }
                    }
                    
                    // Activities Section
                    settingsSection("Activities") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose which activities to include in your daily routine")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                            
                            ForEach(ActivityType.allCases) { activity in
                                VStack(alignment: .leading, spacing: 12) {
                                    let config = settings.activityPlan.getConfig(for: activity)
                                    
                                    Toggle(isOn: Binding(
                                        get: { config.enabled },
                                        set: { newValue in
                                            let updatedConfig = ActivityConfig(enabled: newValue, repCount: config.repCount)
                                            settings.updateActivityConfig(for: activity, config: updatedConfig)
                                        }
                                    )) {
                                        HStack(spacing: 8) {
                                            Image(systemName: activity.icon)
                                                .foregroundStyle(accentColor)
                                                .font(.system(size: 14))
                                            Text(activity.displayName)
                                        }
                                    }
                                    .tint(accentColor)
                                    
                                    // Show rep count slider for exercises when enabled
                                    if activity != .breathwork && config.enabled {
                                        HStack {
                                            Text("Reps")
                                                .foregroundStyle(.secondary)
                                                .font(.caption)
                                            Spacer()
                                            Text("\(config.repCount)")
                                                .fontWeight(.medium)
                                                .monospacedDigit()
                                                .font(.caption)
                                        }
                                        
                                        Slider(
                                            value: Binding(
                                                get: { Double(config.repCount) },
                                                set: { newValue in
                                                    let updatedConfig = ActivityConfig(enabled: config.enabled, repCount: Int(newValue))
                                                    settings.updateActivityConfig(for: activity, config: updatedConfig)
                                                }
                                            ),
                                            in: 5...50,
                                            step: 5
                                        )
                                        .tint(accentColor)
                                    }
                                    
                                    // Show breathing settings for breathwork when enabled
                                    if activity == .breathwork && config.enabled {
                                        HStack {
                                            Text("Cycles")
                                                .foregroundStyle(.secondary)
                                                .font(.caption)
                                            Spacer()
                                            Text("\(config.breathingCycles)")
                                                .fontWeight(.medium)
                                                .monospacedDigit()
                                                .font(.caption)
                                        }
                                        
                                        Slider(
                                            value: Binding(
                                                get: { Double(config.breathingCycles) },
                                                set: { newValue in
                                                    let updatedConfig = ActivityConfig(
                                                        enabled: config.enabled,
                                                        repCount: config.repCount,
                                                        breathingCycles: Int(newValue),
                                                        includeHoldEmpty: config.includeHoldEmpty
                                                    )
                                                    settings.updateActivityConfig(for: activity, config: updatedConfig)
                                                }
                                            ),
                                            in: 1...10,
                                            step: 1
                                        )
                                        .tint(accentColor)
                                        
                                        Divider()
                                        
                                        Toggle(isOn: Binding(
                                            get: { config.includeHoldEmpty },
                                            set: { newValue in
                                                let updatedConfig = ActivityConfig(
                                                    enabled: config.enabled,
                                                    repCount: config.repCount,
                                                    breathingCycles: config.breathingCycles,
                                                    includeHoldEmpty: newValue
                                                )
                                                settings.updateActivityConfig(for: activity, config: updatedConfig)
                                            }
                                        )) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Hold Empty")
                                                    .font(.caption)
                                                Text("4s pause after exhale")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .tint(accentColor)
                                    }
                                    
                                    if activity != ActivityType.allCases.last {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                    
                    settingsSection("Widget") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Size")
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(WidgetSize.allCases) { size in
                                    Button {
                                        settings.widgetSize = size
                                    } label: {
                                        Text(size.rawValue)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(settings.widgetSize == size ? .white : .primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(settings.widgetSize == size ? accentColor : Color.clear)
                                            )
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(settings.widgetSize == size ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    if let session = session {
                        settingsSection("Session") {
                            VStack(alignment: .leading, spacing: 12) {
                                // Cycle indicator
                                HStack {
                                    Text("Current Cycle")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(min(session.cycleCount + 1, session.totalCycles)) / \(session.totalCycles)")
                                        .fontWeight(.medium)
                                        .monospacedDigit()
                                }
                                
                                Divider()
                                
                                Button {
                                    session.reset()
                                    handleDismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Reset Session")
                                    }
                                    .foregroundStyle(accentColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            Button {
                handleDismiss()
            } label: {
                Text("Done")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .padding()
        }
        .frame(width: 400, height: 580)
        .background(.regularMaterial)
    }
    
    // MARK: - Section Builder
    @ViewBuilder
    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Activity History Section
struct ActivityHistorySection: View {
    @Bindable var settings: AppSettings
    var timerManager: TimerManager?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DayStatusView(timerManager: timerManager)
            TodayProgressView(settings: settings)
            CommitGridSection(settings: settings)
        }
    }
}

// MARK: - Day Status View
struct DayStatusView: View {
    var timerManager: TimerManager?
    
    var body: some View {
        Group {
            if let timerManager = timerManager {
                HStack {
                    Text("Day Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    DayStatusText(timerManager: timerManager)
                }
                Divider()
            }
        }
    }
}

// MARK: - Day Status Text
struct DayStatusText: View {
    var timerManager: TimerManager
    
    private var statusText: String {
        if timerManager.isDayActive, let startTime = timerManager.dayStartTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Started at \(formatter.string(from: startTime))"
        } else {
            return "Not started"
        }
    }
    
    private var isActive: Bool {
        timerManager.isDayActive
    }
    
    var body: some View {
        Text(statusText)
            .fontWeight(.medium)
            .foregroundStyle(isActive ? Color(red: 53/255.0, green: 211/255.0, blue: 153/255.0) : .secondary)
    }
}

// MARK: - Commit Grid Section
struct CommitGridSection: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Last 90 Days")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            CommitGridView(settings: settings)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Today Progress View
struct TodayProgressView: View {
    @Bindable var settings: AppSettings
    
    private var todayPercentage: Int {
        Int(settings.getCompletionPercentage(for: Date()) * 100)
    }
    
    private var completedCount: Int {
        let completions = settings.getCompletions(for: Date())
        return completions.values.reduce(0, +)
    }
    
    private var enabledCount: Int {
        settings.activityPlan.enabledActivities.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(todayPercentage)%")
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            
            if enabledCount > 0 {
                Text("\(completedCount) activities completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


// MARK: - Preview
#Preview {
    SettingsView(settings: AppSettings.shared, session: nil)
}

