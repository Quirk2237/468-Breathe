import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Bindable var settings: AppSettings
    var timerManager: TimerManager?
    var onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var environmentDismiss
    @State private var navigationPath = NavigationPath()
    
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
                        ForEach(settings.activityPlan.enabledActivities, id: \.self) { activity in
                            ActivityRowView(
                                activity: activity,
                                accentColor: accentColor,
                                onSettingsTap: {
                                    navigationPath.append(activity)
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                        }
                        .onMove { source, destination in
                            var enabledActivities = settings.activityPlan.enabledActivities
                            enabledActivities.move(fromOffsets: source, toOffset: destination)
                            
                            var newOrder: [ActivityType] = []
                            var remainingActivities = Set(settings.activityPlan.activityOrder)
                            
                            for activity in enabledActivities {
                                newOrder.append(activity)
                                remainingActivities.remove(activity)
                            }
                            
                            for activity in settings.activityPlan.activityOrder {
                                if remainingActivities.contains(activity) {
                                    newOrder.append(activity)
                                }
                            }
                            
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
    let onSettingsTap: () -> Void
    
    @State private var isHovering = false
    
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
            
            // Settings icon (shown on hover)
            Button {
                onSettingsTap()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView(settings: AppSettings.shared)
}

