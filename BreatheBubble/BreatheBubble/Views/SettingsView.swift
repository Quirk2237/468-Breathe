import SwiftUI

// MARK: - Activity Status Indicator
enum ActivityStatusIndicator {
    case active
    case timerRunning
    case timerPaused
    case none
}

// MARK: - Settings View
struct SettingsView: View {
    @Bindable var settings: AppSettings
    var timerManager: TimerManager?
    var windowManager: WindowManager?
    var onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var environmentDismiss
    @State private var navigationPath = NavigationPath()
    
    private let accentColor = Color(red: 53/255.0, green: 211/255.0, blue: 153/255.0)
    
    // MARK: - Helper Functions
    private func getActivityStatus(activity: ActivityType, enabledIndex: Int) -> ActivityStatusIndicator {
        guard let windowManager = windowManager else { return .none }
        
        // Priority 1: If exercise bubble is open for this specific enabled index
        if windowManager.isPanelOpen,
           let currentIndex = windowManager.currentActivityEnabledIndex,
           currentIndex == enabledIndex {
            return .active
        }
        
        // Priority 2 & 3: Check if this is the next up activity (by index) and timer conditions
        guard let nextIndex = settings.activityPlan.getNextActivityIndex(),
              nextIndex == enabledIndex else {
            return .none
        }
        
        // Only show timer indicators if no bubble is open
        guard !windowManager.isPanelOpen else {
            return .none
        }
        
        // Priority 2: Timer running
        if let timerManager = timerManager,
           timerManager.isDayActive,
           timerManager.isRunning {
            return .timerRunning
        }
        
        // Priority 3: Timer paused
        if let timerManager = timerManager,
           timerManager.isDayActive,
           timerManager.state == .paused {
            return .timerPaused
        }
        
        return .none
    }
    
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
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                    // Activity History Section
                    settingsSection("Activity History") {
                        ActivityHistorySection(settings: settings, timerManager: timerManager)
                    }
                    
                    // Activities Section
                    activitiesSection
                    
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
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    settingsSection("Notifications") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Play chime when exercise is ready", isOn: $settings.playChimeOnTimerComplete)
                                .font(.system(size: 13))
                        }
                    }
                    
                    settingsSection("Exercise Bubble") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Position")
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(ExerciseBubblePosition.allCases) { position in
                                    Button {
                                        settings.exerciseBubblePosition = position
                                    } label: {
                                        Text(position.rawValue)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(settings.exerciseBubblePosition == position ? .white : .primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(settings.exerciseBubblePosition == position ? accentColor : Color.clear)
                                            )
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(settings.exerciseBubblePosition == position ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            }
            .frame(width: 400, height: 580)
            .background(.regularMaterial)
            .navigationDestination(for: String.self) { destination in
                if destination == "activitySelection" {
                    ActivitySelectionView(settings: settings)
                }
            }
            .navigationDestination(for: ActivityType.self) { activity in
                ActivitySettingsView(settings: settings, activity: activity)
            }
        }
    }
    
    // MARK: - Activities Section
    @ViewBuilder
    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with settings icon
            HStack {
                Text("Activities")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Button {
                    navigationPath.append("activitySelection")
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if settings.activityPlan.enabledActivities.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Text("No activities selected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            navigationPath.append("activitySelection")
                        } label: {
                            Text("Select Activities")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    List {
                        ForEach(Array(settings.activityPlan.enabledActivities.enumerated()), id: \.offset) { index, activity in
                            ActivityRowView(
                                activity: activity,
                                accentColor: accentColor,
                                statusIndicator: getActivityStatus(activity: activity, enabledIndex: index),
                                onEdit: {
                                    navigationPath.append(activity)
                                },
                                onDuplicate: {
                                    if let orderIndex = settings.activityPlan.indexInActivityOrder(forEnabledIndex: index) {
                                        settings.activityPlan.duplicateActivity(at: orderIndex)
                                        settings.saveActivitySettings()
                                    }
                                },
                                onDelete: {
                                    if let orderIndex = settings.activityPlan.indexInActivityOrder(forEnabledIndex: index) {
                                        settings.activityPlan.removeActivity(at: orderIndex)
                                        settings.saveActivitySettings()
                                    }
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                        }
                        .onMove { source, destination in
                            let enabledActivities = settings.activityPlan.enabledActivities
                            var reorderedEnabled = enabledActivities
                            reorderedEnabled.move(fromOffsets: source, toOffset: destination)
                            
                            // Rebuild activityOrder with the new enabled order, preserving disabled activities
                            var newOrder: [ActivityType] = []
                            let disabledActivities = settings.activityPlan.activityOrder.filter { 
                                settings.activityPlan.activities[$0]?.enabled != true 
                            }
                            
                            // Add enabled activities in the new order
                            for activity in reorderedEnabled {
                                newOrder.append(activity)
                            }
                            
                            // Add disabled activities at the end
                            newOrder.append(contentsOf: disabledActivities)
                            
                            settings.activityPlan.reorderActivities(newOrder)
                            settings.saveActivitySettings()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(height: CGFloat(settings.activityPlan.enabledActivities.count) * 40)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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
            DayStatusAndTodayView(settings: settings, timerManager: timerManager)
            CommitGridSection(settings: settings)
        }
    }
}

// MARK: - Day Status and Today View
struct DayStatusAndTodayView: View {
    @Bindable var settings: AppSettings
    var timerManager: TimerManager?
    
    private let accentColor = Color(red: 53/255.0, green: 211/255.0, blue: 153/255.0)
    
    private var statusText: String {
        guard let timerManager = timerManager else { return "" }
        if timerManager.isDayActive {
            return "Day Active"
        } else {
            return "Not started"
        }
    }
    
    private var isActive: Bool {
        timerManager?.isDayActive ?? false
    }
    
    var body: some View {
        Group {
            if timerManager != nil {
                HStack {
                    Text("Day Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(statusText)
                        .fontWeight(.medium)
                        .foregroundStyle(isActive ? accentColor : .secondary)
                }
            }
        }
    }
}

// MARK: - Commit Grid Section
struct CommitGridSection: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        CommitGridView(settings: settings)
            .frame(maxWidth: .infinity)
    }
}



// MARK: - Activity Row View
struct ActivityRowView: View {
    let activity: ActivityType
    let accentColor: Color
    let statusIndicator: ActivityStatusIndicator
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            // Activity icon and name
            HStack(spacing: 8) {
                Image(systemName: activity.icon)
                    .foregroundStyle(accentColor)
                    .font(.system(size: 14))
                Text(activity.displayName)
                    .font(.system(size: 14))
            }
            
            Spacer()
            
            // Status indicator
            Group {
                switch statusIndicator {
                case .active:
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(accentColor)
                case .timerRunning:
                    Circle()
                        .stroke(accentColor, lineWidth: 2)
                        .frame(width: 14, height: 14)
                case .timerPaused:
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(accentColor)
                case .none:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onDuplicate()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView(settings: AppSettings.shared)
}

