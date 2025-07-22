import SwiftUI
import AVFoundation

struct CategoryListView: View {
    @Binding var items: [VocabularyEntry]
    let category: String
    @State private var editingItem: VocabularyEntry? = nil
    @State private var isPlaying = false
    @State private var isPaused = false
    @State private var currentIndex = 0
    @Environment(\.dismiss) private var dismiss
    private let synthesizer = AVSpeechSynthesizer()
    
    private var filteredItems: [VocabularyEntry] {
        items.filter { $0.category == category }
    }
    
    var body: some View {
        List {
            // Playback Controls Section
            Section {
                VStack(spacing: 12) {
                    // Current Word
                    Text(currentIndex < filteredItems.count ? filteredItems[currentIndex].thai : "")
                        .font(.title2)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    
                    // Progress Text
                    Text("\(currentIndex + 1) of \(filteredItems.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Controls
                    HStack(spacing: 40) {
                        // Previous Button
                        Button(action: previousWord) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                        }
                        .disabled(currentIndex <= 0)
                        .foregroundColor(currentIndex > 0 ? .blue : .gray)
                        
                        // Play/Pause Button
                        Button(action: togglePlayPause) {
                            Image(systemName: isPlaying ? (isPaused ? "play.circle.fill" : "pause.circle.fill") : "play.circle.fill")
                                .font(.system(size: 44))
                        }
                        .foregroundColor(.blue)
                        
                        // Next Button
                        Button(action: nextWord) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                        .disabled(currentIndex >= filteredItems.count - 1)
                        .foregroundColor(currentIndex < filteredItems.count - 1 ? .blue : .gray)
                    }
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 8)
            }
            .sheet(item: $editingItem) { item in
                NavigationView {
                    // Create a local copy to prevent potential race conditions
                    let safeItems = items
                    CounterView(
                        item: Binding(
                            get: { item },
                            set: { newValue in
                                DispatchQueue.main.async {
                                    if let index = items.firstIndex(where: { $0.id == newValue.id }) {
                                        items[index] = newValue
                                    }
                                }
                            }
                        ),
                        allItems: .constant(safeItems),
                        totalVocabCount: safeItems.reduce(0) { $0 + $1.count }
                    )
                    .transition(.opacity)
                    .onDisappear {
                        withAnimation(.easeOut(duration: 0.2)) {
                            editingItem = nil
                        }
                    }
                }
                .animation(.easeInOut, value: editingItem)
            }
            
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
        .navigationTitle("\(category) (\(filteredItems.count))")
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
    }
    
    // MARK: - Playback Control Methods
    
    private func togglePlayPause() {
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
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        speakCurrentWord()
    }
    
    private func nextWord() {
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
        utterance.rate = 0.5
        
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
        
        // Schedule next word
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.isPlaying && !self.isPaused {
                if self.currentIndex < self.filteredItems.count - 1 {
                    self.currentIndex += 1
                    self.speakCurrentWord()
                } else {
                    self.stopPlayback()
                }
            }
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
