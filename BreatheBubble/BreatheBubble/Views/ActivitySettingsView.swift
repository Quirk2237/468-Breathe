import SwiftUI

// MARK: - Activity Settings View
struct ActivitySettingsView: View {
    @Bindable var settings: AppSettings
    let activity: ActivityType
    @Environment(\.dismiss) private var dismiss
    
    private let accentColor = Color(red: 53/255.0, green: 211/255.0, blue: 153/255.0)
    
    private var config: ActivityConfig {
        settings.activityPlan.getConfig(for: activity)
    }
    
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
                    
                    Image(systemName: activity.icon)
                        .foregroundStyle(accentColor)
                        .font(.system(size: 24))
                    Text(activity.displayName)
                        .font(.system(size: 20, weight: .semibold))
                }
                .padding(.horizontal)
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 16) {
                    if activity != .breathwork {
                        // Exercise settings (Reps)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Reps")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(config.repCount)")
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { Double(config.repCount) },
                                    set: { newValue in
                                        let updatedConfig = ActivityConfig(
                                            enabled: config.enabled,
                                            repCount: Int(newValue),
                                            breathingCycles: config.breathingCycles,
                                            includeHoldEmpty: config.includeHoldEmpty
                                        )
                                        settings.updateActivityConfig(for: activity, config: updatedConfig)
                                    }
                                ),
                                in: 5...50,
                                step: 5
                            )
                            .tint(accentColor)
                        }
                    } else {
                        // Breathwork settings (Cycles and Hold Empty)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Cycles")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(config.breathingCycles)")
                                    .fontWeight(.medium)
                                    .monospacedDigit()
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
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ActivitySettingsView(settings: AppSettings.shared, activity: .pushups)
    }
}
