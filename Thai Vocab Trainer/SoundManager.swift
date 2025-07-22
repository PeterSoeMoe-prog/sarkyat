import AudioToolbox
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private let fadeStep: Float = 0.1
    private let fadeInterval: TimeInterval = 0.05
    #if os(iOS)
    private let audioSession = AVAudioSession.sharedInstance()
    #endif
    
    private override init() {
        super.init()
        #if os(iOS)
        setupAudioSession()
        #endif
    }
    
    #if os(iOS)
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    #endif
    
    // Play system sound with fade-out capability
    static func playSound(_ soundID: SystemSoundID) {
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else { return }
        
        // Stop any currently playing sound with fade out
        shared.fadeOut()
        
        // Play the new sound
        AudioServicesPlaySystemSound(soundID)
    }
    
    // Play audio file with fade in/out capability
    static func playAudioFile(named filename: String, withExtension: String = "mp3", fadeIn: Bool = true) {
        guard UserDefaults.standard.bool(forKey: "soundEnabled"),
              let url = Bundle.main.url(forResource: filename, withExtension: withExtension) else {
            return
        }
        
        // Stop any currently playing sound with fade out
        shared.fadeOut()
        
        do {
            shared.audioPlayer = try AVAudioPlayer(contentsOf: url)
            shared.audioPlayer?.delegate = shared
            shared.audioPlayer?.prepareToPlay()
            
            if fadeIn {
                shared.audioPlayer?.volume = 0
                shared.audioPlayer?.play()
                shared.fadeIn()
            } else {
                shared.audioPlayer?.volume = 1.0
                shared.audioPlayer?.play()
            }
        } catch {
            print("Error playing audio file: \(error)")
        }
    }
    
    // Fade in the current audio player
    private func fadeIn() {
        audioPlayer?.volume = 0
        fadeTimer?.invalidate()
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            
            if player.volume < 1.0 {
                player.volume = min(player.volume + self.fadeStep, 1.0)
            } else {
                self.fadeTimer?.invalidate()
                self.fadeTimer = nil
            }
        }
    }
    
    // Fade out the current audio player
    private func fadeOut() {
        fadeTimer?.invalidate()
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            
            if player.volume > 0.1 {
                player.volume = max(0, player.volume - self.fadeStep * 2) // Faster fade out
            } else {
                player.stop()
                self.audioPlayer = nil
                self.fadeTimer?.invalidate()
                self.fadeTimer = nil
            }
        }
    }
    
    // Public method to fade out current sound
    static func fadeOutCurrentSound() {
        shared.fadeOut()
    }
    
    // Stop all sounds immediately
    static func stopAllSounds() {
        shared.audioPlayer?.stop()
        shared.audioPlayer = nil
        shared.fadeTimer?.invalidate()
        shared.fadeTimer = nil
    }
    
    // Play vibration (iOS only)
    static func playVibration() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayer = nil
        fadeTimer?.invalidate()
        fadeTimer = nil
    }
}
