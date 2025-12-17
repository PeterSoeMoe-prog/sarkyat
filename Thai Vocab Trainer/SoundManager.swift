import AudioToolbox
import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private let fadeStep: Float = 0.1
    private let fadeInterval: TimeInterval = 0.05
    
    private override init() {
        super.init()
    }
    
    // Play system sound with fade-out capability
    static func playSound(_ soundID: SystemSoundID) {
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else { return }
        
        // Stop any currently playing sound with fade out
        shared.fadeOut()

        // Play the original iOS system sound
        AudioServicesPlaySystemSound(soundID)
    }

    static func playQuizSuccess() {
        guard UserDefaults.standard.bool(forKey: "soundEnabled") else { return }
        shared.fadeOut()
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            print("AudioSession error: \(error)")
        }
        #endif
        do {
            let data = shared.makeChimeWavData()
            shared.audioPlayer = try AVAudioPlayer(data: data)
            shared.audioPlayer?.delegate = shared
            shared.audioPlayer?.volume = 1.0
            shared.audioPlayer?.prepareToPlay()
            shared.audioPlayer?.play()
        } catch {
            AudioServicesPlaySystemSound(1025)
        }
    }

    private func makeChimeWavData() -> Data {
        let sampleRate: Double = 44100
        let duration: Double = 0.42
        let frames = Int(sampleRate * duration)
        let twoPi = 2.0 * Double.pi
        let maxI16 = Double(Int16.max)
        var samples = [Int16]()
        samples.reserveCapacity(frames)

        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let segDur = duration / 3.0
            let segIndex = min(2, Int(t / segDur))
            let segT = t - (Double(segIndex) * segDur)

            let baseFreq: Double
            switch segIndex {
            case 0:
                baseFreq = 880.0
            case 1:
                baseFreq = 1108.73
            default:
                baseFreq = 1318.51
            }

            let attack = min(1.0, segT / 0.012)
            let decay = exp(-4.2 * (segT / segDur))
            let env = attack * decay

            let glide = 1.0 + 0.04 * (segT / segDur)
            let freq = baseFreq * glide
            let phase = twoPi * freq * t

            let s1 = sin(phase)
            let s2 = sin(phase * 2.0) * 0.28
            let s3 = sin(phase * 3.0) * 0.12

            let mixed = (s1 + s2 + s3) * 0.55 * env
            let clipped = max(-1.0, min(1.0, mixed))
            let v = Int16(clipped * maxI16)
            samples.append(v)
        }

        return makeWavData(samples: samples, sampleRate: Int(sampleRate))
    }

    private func makeWavData(samples: [Int16], sampleRate: Int) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let riffSize = UInt32(36) + dataSize

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: riffSize.littleEndian) { Data($0) })
        data.append("WAVE".data(using: .ascii)!)

        data.append("fmt ".data(using: .ascii)!)
        var fmtChunkSize: UInt32 = 16
        var audioFormat: UInt16 = 1
        var sr = UInt32(sampleRate)
        var br = byteRate
        var ba = blockAlign
        var bps = bitsPerSample
        data.append(withUnsafeBytes(of: fmtChunkSize.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sr.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: br.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: ba.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bps.littleEndian) { Data($0) })

        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        for s in samples {
            var v = s.littleEndian
            data.append(withUnsafeBytes(of: &v) { Data($0) })
        }

        return data
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
