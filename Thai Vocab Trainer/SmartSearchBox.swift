import SwiftUI
import Speech

/// A fully self-contained smart search box with text and voice search (Thai only).
/// This does NOT interact with any existing search logic. Place it below your current search bar for comparison.
struct SmartSearchBox: View {
    @State private var searchText: String = ""
    @State private var isListening: Bool = false
    @State private var speechRecognizer = ThaiSpeechRecognizer()
    @State private var showPermissionAlert = false
    @State private var permissionDenied = false
    @State private var expanded: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // If expanded, add a transparent background to catch taps outside
            if expanded {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            expanded = false
                            isTextFieldFocused = false
                        }
                    }
            }
            HStack(spacing: 8) {
                if expanded {
                    HStack {
                        TextField("Search Thai or Burmese...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isTextFieldFocused)
                            .frame(minWidth: 120, maxWidth: 220)
                        Button(action: {
                            if permissionDenied {
                                showPermissionAlert = true
                                return
                            }
                            if isListening {
                                speechRecognizer.stopTranscribing()
                                isListening = false
                            } else {
                                speechRecognizer.startTranscribing { result in
                                    if let result = result {
                                        searchText = result
                                    }
                                    isListening = false
                                } onPermissionDenied: {
                                    permissionDenied = true
                                    showPermissionAlert = true
                                    isListening = false
                                }
                                isListening = true
                            }
                        }) {
                            Image(systemName: isListening ? "mic.fill" : "mic")
                                .foregroundColor(isListening ? .red : .blue)
                                .padding(8)
                        }
                        .accessibilityLabel(isListening ? "Stop Listening" : "Start Voice Search")

                        Button(action: {
                            withAnimation {
                                expanded = false
                                isTextFieldFocused = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 2)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    Button(action: {
                        withAnimation(.spring()) {
                            expanded = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isTextFieldFocused = true
                            }
                        }
                    }) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.accentColor)
                    }
                    .accessibilityLabel("Expand Smart Search")
                }
            }
            .padding(.horizontal, expanded ? 8 : 0)
            .padding(.vertical, 6)
            .background(
    ZStack {
        if expanded {
            Color(.systemBackground)
                .cornerRadius(12)
                .shadow(radius: 2)
        } else {
            Color.clear
        }
    }
)
.animation(.easeInOut, value: expanded)
            .alert(isPresented: $showPermissionAlert) {
                Alert(title: Text("Microphone or Speech Permission Denied"),
                      message: Text("Please enable microphone and speech recognition access in Settings to use voice search."),
                      dismissButton: .default(Text("OK")))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


/// Minimal Thai speech recognizer for voice search. This is self-contained and does not affect your existing code.
class ThaiSpeechRecognizer: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH"))

    /// Start transcribing and call onResult with the recognized string (or nil if cancelled).
    func startTranscribing(onResult: @escaping (String?) -> Void, onPermissionDenied: @escaping () -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self._startTranscribingInternal(onResult: onResult)
                default:
                    onPermissionDenied()
                }
            }
        }
    }

    private func _startTranscribingInternal(onResult: @escaping (String?) -> Void) {
        self.stopTranscribing()
        let request = SFSpeechAudioBufferRecognitionRequest()
        self.request = request
        let node = audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try? audioEngine.start()
        recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
            if let result = result, result.isFinal {
                onResult(result.bestTranscription.formattedString)
                self.stopTranscribing()
            } else if error != nil {
                onResult(nil)
                self.stopTranscribing()
            }
        }
    }

    /// Stop transcribing and clean up.
    func stopTranscribing() {
        recognitionTask?.cancel()
        recognitionTask = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    
    deinit {
        stopTranscribing()
    }
}

// Usage:
// In your list view, just add:
// SmartSearchBox()
// directly below your current search bar for comparison.
