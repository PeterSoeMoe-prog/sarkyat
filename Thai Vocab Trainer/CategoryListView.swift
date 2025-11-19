import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// Delegate to handle speech completion so we can reliably advance to the next word
private final class SpeechDelegate: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    var onFinishUtterance: (() -> Void)?
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.onFinishUtterance?()
        }
    }
}

struct CategoryListView: View {
    @Binding var items: [VocabularyEntry]
    let category: String
    @State private var editingItem: VocabularyEntry? = nil
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var currentIndex = 0
    @AppStorage("ttsRate") private var ttsRate: Double = 0.5
    @State private var progress: Double = 0.0
    @State private var isRepeating = false
    @Environment(\.dismiss) private var dismiss
    private let synthesizer = AVSpeechSynthesizer()
    @StateObject private var speechDelegate = SpeechDelegate()
    
    private var filteredItems: [VocabularyEntry] {
        items.filter { $0.category == category }
    }
    
    var body: some View {
        List {
            // Words List
            Section {
                ForEach(filteredItems.indices, id: \.self) { index in
                    let entry = filteredItems[index]
                    Button {
                        // Add haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Select the word for editing with animation
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if let itemIndex = items.firstIndex(where: { $0.id == entry.id }) {
                                editingItem = items[itemIndex]
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                // Thai word with larger tap area
                                Text(entry.thai)
                                    .font(.headline)
                                    .foregroundColor(index == currentIndex && (isPlaying || isPaused) ? .blue : .primary)
                                
                                // Burmese translation
                                if let burmese = entry.burmese, !burmese.isEmpty {
                                    Text(burmese)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Counter and status with visual container
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(entry.count)")
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.blue.opacity(0.8)))
                                
                                Text(entry.status.rawValue.uppercased())
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(entry.status == .ready ? Color.green : 
                                                  entry.status == .drill ? Color.orange : 
                                                  Color.red)
                                    )
                            }
                            .padding(.leading, 8)
                            
                            // Current word indicator or chevron
                            if index == currentIndex && (isPlaying || isPaused) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.blue)
                                    .padding(.leading, 4)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let index = items.firstIndex(where: { $0.id == entry.id }) {
                                items.remove(at: index)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            editingItem = entry
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("\(category) (\(filteredItems.filter { $0.status == .queue || $0.status == .drill }.count)/\(filteredItems.count))")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if isPlaying {
                        stopPlayback()
                    } else {
                        startPlayback()
                    }
                } label: {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                }
                .accessibilityLabel("Play category")
            }
        }
        .onAppear {
            setupDelegate()
        }
        .sheet(item: $editingItem) { item in
            NavigationView {
                AddEditWordSheet(
                    isAdding: false,
                    item: binding(for: item),
                    onSave: { updated in
                        saveItems()
                        editingItem = nil
                    },
                    onCancel: { editingItem = nil }
                )
            }
        }
        .onDisappear {
            stopPlayback()
        }
        .safeAreaInset(edge: .bottom) {
            if isPlaying || isPaused {
                MiniPlayerBarView(
                    thaiWord: currentIndex < filteredItems.count ? filteredItems[currentIndex].thai : "",
                    positionText: "\(currentIndex + 1) of \(filteredItems.count)",
                    burmeseWord: currentIndex < filteredItems.count ? (filteredItems[currentIndex].burmese ?? "") : "",
                    rate: $ttsRate,
                    isPlaying: isPlaying,
                    isPaused: isPaused,
                    hasPrevious: currentIndex > 0,
                    hasNext: currentIndex < filteredItems.count - 1,
                    previousAction: previousWord,
                    togglePlayPauseAction: togglePlayPause,
                    nextAction: nextWord,
                    repeatAllAction: { isRepeating.toggle() },
                    isRepeating: isRepeating
                )
            }
        }
    }
    
    // MARK: - Playback Control Methods
    
    private func togglePlayPause() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isPlaying {
            if isPaused {
                // Resume playback
                isPaused = false
                speakCurrentWord()
            } else {
                // Pause playback
                isPaused = true
                synthesizer.pauseSpeaking(at: .immediate)
            }
        } else {
            // Start playback
            startPlayback()
        }
    }
    
    private func previousWord() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        speakCurrentWord()
    }
    
    private func nextWord() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard currentIndex < filteredItems.count - 1 else {
            stopPlayback()
            return
        }
        currentIndex += 1
        speakCurrentWord()
    }
    
    private func selectWord(at index: Int) {
        guard index < filteredItems.count else { return }
        currentIndex = index
        speakCurrentWord()
    }
    
    private func startPlayback() {
        stopPlayback()
        isPlaying = true
        isPaused = false
        speakCurrentWord()
    }
    
    private func stopPlayback() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
    }
    

    private func speakCurrentWord() {
        guard currentIndex < filteredItems.count else {
            stopPlayback()
            return
        }
        
        let word = filteredItems[currentIndex].thai
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "th-TH")
        utterance.rate = Float(ttsRate)
        
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
        
        // speech completion handled by delegate
    }
    
    // MARK: - Delegate helpers
    private func setupDelegate() {
        synthesizer.delegate = speechDelegate
        speechDelegate.onFinishUtterance = {
            autoAdvance()
        }
    }
    
    private func autoAdvance() {
        guard isPlaying && !isPaused else { return }
        if currentIndex < filteredItems.count - 1 {
            currentIndex += 1
            progress = 0
            withAnimation(.linear(duration: 2.0)) {
                progress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                speakCurrentWord()
            }
        } else if isRepeating && !filteredItems.isEmpty {
            currentIndex = 0
            speakCurrentWord()
        } else {
            stopPlayback()
        }
    }
    // MARK: - Helper Methods
    
    private func binding(for entry: VocabularyEntry) -> Binding<VocabularyEntry> {
        if let idx = items.firstIndex(where: { $0.id == entry.id }) {
            return $items[idx]
        } else {
            return .constant(entry)
        }
    }
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "vocab_items")
        }
    }
}
