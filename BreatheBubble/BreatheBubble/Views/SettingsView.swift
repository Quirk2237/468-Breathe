import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Bindable var settings: AppSettings
    var audioManager: AudioManager
    var session: BreathingSession?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.quaternary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Timer Section
                    settingsSection("Timer") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Interval")
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
                            .tint(.cyan)
                        }
                    }
                    
                    // Breathing Section
                    settingsSection("Breathing") {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Cycles")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(settings.breathingCycles)")
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { Double(settings.breathingCycles) },
                                    set: { settings.breathingCycles = Int($0) }
                                ),
                                in: 1...10,
                                step: 1
                            )
                            .tint(.cyan)
                            
                            Divider()
                            
                            Toggle(isOn: $settings.includeHoldEmpty) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hold Empty")
                                    Text("4s pause after exhale")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.cyan)
                        }
                    }
                    
                    // Sound Section
                    settingsSection("Sound") {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $settings.soundEnabled) {
                                HStack {
                                    Image(systemName: settings.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                                        .foregroundStyle(settings.soundEnabled ? .cyan : .secondary)
                                    Text("Ambient Sound")
                                }
                            }
                            .tint(.cyan)
                            .onChange(of: settings.soundEnabled) { _, enabled in
                                if enabled {
                                    audioManager.play(track: settings.selectedTrack, volume: settings.volume)
                                } else {
                                    audioManager.stop()
                                }
                            }
                            
                            if settings.soundEnabled {
                                Divider()
                                
                                // Volume
                                HStack {
                                    Image(systemName: "speaker.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                    
                                    Slider(
                                        value: $settings.volume,
                                        in: 0...1
                                    )
                                    .tint(.cyan)
                                    .onChange(of: settings.volume) { _, newValue in
                                        audioManager.setVolume(newValue, fadeDuration: 0.2)
                                    }
                                    
                                    Image(systemName: "speaker.wave.3.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                
                                Divider()
                                
                                // Track Selection
                                VStack(spacing: 8) {
                                    ForEach(SoundTrack.tracks) { track in
                                        trackButton(track)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Session Section (only show when session is active)
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
                                
                                // Reset button
                                Button {
                                    session.reset()
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Reset Session")
                                    }
                                    .foregroundStyle(.orange)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.orange.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Info Section
                    settingsSection("About 4-6-8") {
                        Text("The 4-6-8 breathing technique acts as a natural tranquilizer for the nervous system. Inhale for 4 seconds, hold for 6, and exhale for 8. Practice regularly for best results.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .padding()
        }
        .frame(width: 320, height: 500)
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
    
    // MARK: - Track Button
    @ViewBuilder
    private func trackButton(_ track: SoundTrack) -> some View {
        let isSelected = settings.selectedTrackId == track.id
        
        Button {
            settings.selectedTrackId = track.id
            if settings.soundEnabled {
                audioManager.play(track: track, volume: settings.volume)
            }
        } label: {
            HStack {
                Circle()
                    .fill(isSelected ? Color.cyan : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.cyan : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                
                Text(track.label)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.cyan.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    SettingsView(settings: AppSettings.shared, audioManager: AudioManager.shared, session: nil)
}

