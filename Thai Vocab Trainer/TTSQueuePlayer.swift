import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class TTSQueuePlayer: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    func play(texts: [String]) {
        // Stop any current playback
        stop()
        
        // Play only the first word
        guard let firstWord = texts.first else { return }
        
        let utterance = AVSpeechUtterance(string: firstWord)
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        utterance.rate = 0.45
        
        print("🔊 Playing: \(firstWord)")
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
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
