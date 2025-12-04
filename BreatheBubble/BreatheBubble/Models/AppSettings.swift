import SwiftUI
import Observation

// MARK: - Sound Track
struct SoundTrack: Identifiable, Equatable {
    let id: String
    let label: String
    let filename: String // MP3 filename in bundle
    
    static let tracks: [SoundTrack] = [
        SoundTrack(id: "ocean", label: "Ocean Waves", filename: "ocean"),
        SoundTrack(id: "rain", label: "Gentle Rain", filename: "rain"),
        SoundTrack(id: "forest", label: "Forest Birds", filename: "forest"),
        SoundTrack(id: "stream", label: "Flowing Stream", filename: "stream"),
    ]
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
    
    // Breathing Settings
    var breathingCycles: Int = 4 {
        didSet {
            UserDefaults.standard.set(breathingCycles, forKey: "breathingCycles")
        }
    }
    
    var includeHoldEmpty: Bool = false {
        didSet {
            UserDefaults.standard.set(includeHoldEmpty, forKey: "includeHoldEmpty")
        }
    }
    
    // Sound Settings
    var soundEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }
    
    var selectedTrackId: String = "ocean" {
        didSet {
            UserDefaults.standard.set(selectedTrackId, forKey: "selectedTrackId")
        }
    }
    
    var volume: Float = 0.5 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }
    
    // Computed
    var selectedTrack: SoundTrack {
        SoundTrack.tracks.first { $0.id == selectedTrackId } ?? SoundTrack.tracks[0]
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
        
        if defaults.object(forKey: "breathingCycles") != nil {
            breathingCycles = defaults.integer(forKey: "breathingCycles")
        }
        
        includeHoldEmpty = defaults.bool(forKey: "includeHoldEmpty")
        
        if defaults.object(forKey: "soundEnabled") != nil {
            soundEnabled = defaults.bool(forKey: "soundEnabled")
        } else {
            soundEnabled = true // Default
        }
        
        if let trackId = defaults.string(forKey: "selectedTrackId") {
            selectedTrackId = trackId
        }
        
        if defaults.object(forKey: "volume") != nil {
            volume = defaults.float(forKey: "volume")
        }
    }
    
    // MARK: - Reset
    func resetToDefaults() {
        timerIntervalMinutes = 30
        breathingCycles = 4
        includeHoldEmpty = false
        soundEnabled = true
        selectedTrackId = "ocean"
        volume = 0.5
    }
}

// MARK: - Shared Instance
extension AppSettings {
    static let shared = AppSettings()
}


