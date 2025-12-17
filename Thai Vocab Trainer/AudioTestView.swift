import SwiftUI
import AVFoundation

struct AudioTestView: View {
    @State private var audioPlayer: AVAudioPlayer? // This is the correct name here

    init() {
        // This 'init' runs when the view is created
        if let soundURL = Bundle.main.url(forResource: "gamewin", withExtension: "mp3") { // Make sure this name matches YOUR file
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL) // CORRECTED: Use audioPlayer here
                audioPlayer?.prepareToPlay() // Pre-load the audio
                print("✅ gamewin.mp3 found and player initialized.")
            } catch {
                print("❌ ERROR INITIALIZING AUDIO PLAYER: \(error.localizedDescription)")
                audioPlayer = nil
            }
        } else {
            print("❌ Sound file 'gamewin.mp3' not found in bundle.")
        }
    }
    var body: some View {
        VStack {
            Text("Audio Test")
                .font(.largeTitle)
                .padding()

            Button("Play Sound (gamewin.mp3)") {
                if let player = audioPlayer {
                    player.play()
                    print("Attempting to play sound.")
                } else {
                    print("Audio player is nil. Sound not loaded.")
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .onAppear {
            // Optionally set audio session category when view appears
            #if os(iOS)
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                print("Audio session set to ambient.")
            } catch {
                print("Failed to set audio session category. Error: \(error.localizedDescription)")
            }
            #endif
        }
        .onDisappear {
            // Deactivate audio session when view disappears to prevent conflicts
            #if os(iOS)
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                print("Audio session deactivated.")
            } catch {
                print("Failed to deactivate audio session. Error: \(error.localizedDescription)")
            }
            #endif
        }
    }
}

struct AudioTestView_Previews: PreviewProvider {
    static var previews: some View {
        AudioTestView()
    }
}
