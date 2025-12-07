import SwiftUI

// MARK: - Activity Selection View
struct ActivitySelectionView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    private let accentColor = Color(red: 53/255.0, green: 211/255.0, blue: 153/255.0)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(accentColor)
                            .font(.system(size: 18, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: "figure.walk")
                        .foregroundStyle(accentColor)
                        .font(.system(size: 24))
                    Text("Activities")
                        .font(.system(size: 20, weight: .semibold))
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Activities Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose activities for your daily routine")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    VStack(spacing: 0) {
                        ForEach(ActivityType.allCases) { activity in
                            Toggle(isOn: Binding(
                                get: { settings.activityPlan.activities[activity]?.enabled ?? false },
                                set: { newValue in
                                    var config = settings.activityPlan.getConfig(for: activity)
                                    config.enabled = newValue
                                    settings.updateActivityConfig(for: activity, config: config)
                                }
                            )) {
                                Label(activity.displayName, systemImage: activity.icon)
                            }
                            .tint(accentColor)
                            .padding(.vertical, 8)
                            
                            if activity != ActivityType.allCases.last {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                
                // Intervals Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Intervals")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Reminder Interval")
                            Spacer()
                            Text("\(settings.timerIntervalMinutes) min")
                                .fontWeight(.medium)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
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
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ActivitySelectionView(settings: AppSettings.shared)
    }
}
