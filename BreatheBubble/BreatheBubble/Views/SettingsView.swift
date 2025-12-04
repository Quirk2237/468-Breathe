import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Bindable var settings: AppSettings
    var audioManager: AudioManager
    var timerManager: TimerManager?
    var session: BreathingSession?
    var onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var environmentDismiss
    
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
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    settingsSection("Breathing") {
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
                            .tint(.cyan)
                            
                            Divider()
                            
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
                                                    .fill(settings.widgetSize == size ? Color.cyan : Color.clear)
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
                                
                                // Reset button
                                Button {
                                    session.reset()
                                    handleDismiss()
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
            .tint(.cyan)
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

