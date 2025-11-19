import Foundation
import AVFoundation
import SwiftUI

final class TTSQueuePlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    // Publishes the zero-based index of the item currently being spoken when playing a queue.
    @Published var currentQueueIndex: Int = 0
    @Published var isSpeakingQueue: Bool = false
    @Published var repeatMode: Bool = false
    private var synthesizer = AVSpeechSynthesizer()
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // Play a single utterance (helper used by UI for one-off playback)
    func play(texts: [String], rate: Float = 0.45) {
        playQueue(texts: texts, rate: rate, delay: 0) // delegate handles first item immediately
    }

    // MARK: – Queue playback
    private var queueTexts: [String] = []
    private var queueDelay: TimeInterval = 1
    private var queueRate: Float = 0.45
    
    // MARK: – Pause / Resume
    /// Pause current speech without clearing the queue. Returns true if paused.
    @discardableResult
    func pause() -> Bool {
        let success = synthesizer.pauseSpeaking(at: .immediate)
        if success { isSpeakingQueue = false }
        return success
    }
    /// Resume after a pause. Returns true if resumed.
    @discardableResult
    func resume() -> Bool {
        guard synthesizer.isPaused else { return false }
        let success = synthesizer.continueSpeaking()
        if success { isSpeakingQueue = true }
        return success
    }
    /// Indicates if the synthesizer is currently paused.
    var isPaused: Bool { synthesizer.isPaused }

    /// Speaks all texts sequentially with a pause `delay` seconds between them.
    func playQueue(texts: [String], rate: Float = 0.45, delay: TimeInterval = 1) {
        stop()
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        queueTexts = texts
        queueRate = rate
        queueDelay = delay
        guard !texts.isEmpty else { return }
        currentQueueIndex = 0
        isSpeakingQueue = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.speakCurrent()
        }
    }
    
    // Speak the utterance at currentQueueIndex
    private func speakCurrent() {
        guard queueTexts.indices.contains(currentQueueIndex) else { return }
        let text = queueTexts[currentQueueIndex]
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        utterance.rate = queueRate
        synthesizer.speak(utterance)
    }
    // MARK: – AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [self] in
            if currentQueueIndex < queueTexts.count - 1 {
                // advance to next after optional delay
                currentQueueIndex += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + queueDelay) {
                    self.speakCurrent()
                }
            } else {
                if repeatMode && !queueTexts.isEmpty {
                    currentQueueIndex = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + queueDelay) {
                        self.speakCurrent()
                    }
                } else {
                    isSpeakingQueue = false
                }
            }
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.delegate = nil
        queueTexts.removeAll()
        isSpeakingQueue = false
    }
    
    deinit {
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.delegate = nil
    }
}

// MARK: - Preview
#if DEBUG
struct TTSQueuePlayer_Previews: PreviewProvider {
    static var previews: some View {
        TTSPlayerTestView()
            .previewDisplayName("TTS Player Test")
    }
}

struct TTSPlayerTestView: View {
    @StateObject private var player = TTSQueuePlayer()
    @State private var isPlaying = false
    
    let testWords = ["สวัสดี", "ขอบคุณ", "ลาก่อน", "สบายดีไหม", "ฉันชื่อ"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("TTS Queue Player Test")
                .font(.headline)
                .padding()
            
            Text("Words to play:")
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(testWords, id: \.self) { word in
                    Text("• \(word)")
                        .font(.body)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Button(action: {
                if isPlaying {
                    player.stop()
                } else {
                    player.play(texts: testWords)
                }
                isPlaying.toggle()
            }) {
                HStack {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    Text(isPlaying ? "Stop" : "Play First Word")
                }
                .frame(minWidth: 200)
                .padding()
                .background(isPlaying ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
            
            Text("Note: Should only play the first word")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
}
#endif
