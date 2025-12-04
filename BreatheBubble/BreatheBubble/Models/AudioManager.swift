import AVFoundation
import Observation

// MARK: - Audio Manager
@Observable
class AudioManager {
    static let shared = AudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    
    var isPlaying: Bool = false
    var currentTrackId: String?
    var targetVolume: Float = 0.5
    
    // MARK: - Playback Control
    func play(track: SoundTrack, volume: Float = 0.5) {
        if isPlaying && currentTrackId == track.id {
            setVolume(volume, fadeDuration: 0.5)
            return
        }
        
        if isPlaying {
            fadeOut(duration: 0.5) { [weak self] in
                self?.loadAndPlay(track: track, volume: volume)
            }
        } else {
            loadAndPlay(track: track, volume: volume)
        }
    }
    
    private func loadAndPlay(track: SoundTrack, volume: Float) {
        guard let url = Bundle.main.url(forResource: track.filename, withExtension: "mp3") else {
            print("Audio file not found: \(track.filename).mp3")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            currentTrackId = track.id
            isPlaying = true
            
            fadeIn(to: volume, duration: 2.0)
        } catch {
            print("Error loading audio: \(error)")
        }
    }
    
    func stop() {
        guard isPlaying else { return }
        
        fadeOut(duration: 2.0) { [weak self] in
            self?.audioPlayer?.stop()
            self?.audioPlayer = nil
            self?.currentTrackId = nil
            self?.isPlaying = false
        }
    }
    
    func pause() {
        fadeOut(duration: 0.5) { [weak self] in
            self?.audioPlayer?.pause()
        }
    }
    
    func resume() {
        audioPlayer?.play()
        fadeIn(to: targetVolume, duration: 0.5)
    }
    
    // MARK: - Volume Control
    func setVolume(_ volume: Float, fadeDuration: TimeInterval = 0.3) {
        targetVolume = volume
        
        guard let player = audioPlayer else { return }
        
        fadeTimer?.invalidate()
        
        let startVolume = player.volume
        let volumeDelta = volume - startVolume
        let steps = Int(fadeDuration / 0.05)
        var currentStep = 0
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            self?.audioPlayer?.volume = startVolume + (volumeDelta * progress)
            
            if currentStep >= steps {
                timer.invalidate()
                self?.audioPlayer?.volume = volume
            }
        }
    }
    
    // MARK: - Fade Effects
    private func fadeIn(to volume: Float, duration: TimeInterval) {
        targetVolume = volume
        fadeTimer?.invalidate()
        
        let steps = Int(duration / 0.05)
        var currentStep = 0
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            self?.audioPlayer?.volume = volume * progress
            
            if currentStep >= steps {
                timer.invalidate()
                self?.audioPlayer?.volume = volume
            }
        }
    }
    
    private func fadeOut(duration: TimeInterval, completion: @escaping () -> Void) {
        fadeTimer?.invalidate()
        
        guard let player = audioPlayer else {
            completion()
            return
        }
        
        let startVolume = player.volume
        let steps = Int(duration / 0.05)
        var currentStep = 0
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            self?.audioPlayer?.volume = startVolume * (1 - progress)
            
            if currentStep >= steps {
                timer.invalidate()
                self?.audioPlayer?.volume = 0
                completion()
            }
        }
    }
}


