import Foundation
import AVFoundation
import SwiftUI

/// Plays a list of Thai strings sequentially with a 1-second pause between each.
/// Usage: create once (e.g. `@StateObject private var ttsPlayer = TTSQueuePlayer()`)
/// and call `ttsPlayer.play(texts: [String])`.
@MainActor
final class TTSQueuePlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var queue: [String] = []
    private var currentIndex: Int = 0
    private var isActive: Bool = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Begins playing the provided Thai texts sequentially.
    /// Any existing playback is stopped and the new queue starts immediately.
    func play(texts: [String]) {
        guard !texts.isEmpty else { return }
        // Stop any ongoing speech immediately.
        synthesizer.stopSpeaking(at: .immediate)
        queue = texts
        currentIndex = 0
        isActive = true
        speakCurrent()
    }

    private func speakCurrent() {
        guard isActive, currentIndex < queue.count else {
            isActive = false
            return
        }
        let utterance = AVSpeechUtterance(string: queue[currentIndex])
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        utterance.rate = 0.45
        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Hop back to the main actor because the class is @MainActor.
        Task { @MainActor in
            self.currentIndex += 1
            // Wait 1 second before speaking the next word.
            try? await Task.sleep(for: .seconds(1))
            self.speakCurrent()
        }
    }
}
