import SwiftUI

/// Displays all vocabulary items belonging to a single category.
/// It re-uses the canonical `loadCSV()` function so the data source
/// stays consistent with the rest of the app.
struct CategoryWordsView: View {
    let category: String

    // Full list and derived filtered list
    @State private var items: [VocabularyEntry] = []
    @State private var filteredItems: [VocabularyEntry] = []

    // UI states reused by VocabularyListView
    @State private var showBurmeseForID: UUID? = nil
    @State private var selectedStatus: VocabularyStatus? = nil
    @State private var showThaiPrimary = true
    // Editing sheet state
    @State private var editingItem: VocabularyEntry? = nil
    // TTS playback
    @StateObject private var ttsPlayer = TTSQueuePlayer()
    @State private var isPlaying = false
    @State private var currentIndex = 0
    @State private var speechRate: Float = 0.5
    @State private var showPlayerSheet = false
    private let availableRates: [Float] = [0.3, 0.5, 0.8, 1]
    // Save debounce
    @State private var saveDebounce: DispatchWorkItem? = nil
    // Filter token to avoid stale publishes
    @State private var filterToken: Int = 0
    // Editing state to allow drag-reorder without disabling swipe actions
    @State private var isEditing: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var router: AppRouter
    
    // Convenience to access currently selected item
    private var currentItem: VocabularyEntry? {
        guard filteredItems.indices.contains(currentIndex) else { return nil }
        return filteredItems[currentIndex]
    }

    var body: some View {
        Group {
            if isEditing {
                // Inline reorder list (EditMode + .onMove) only for CategoryWordsView
                List {
                    ForEach(filteredItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                // status dot
                                Circle()
                                    .fill({
                                        switch item.status {
                                        case .queue: return Color.red.opacity(0.5)
                                        case .drill: return Color.yellow.opacity(0.5)
                                        case .ready: return Color.green.opacity(0.5)
                                        }
                                    }())
                                    .frame(width: 14, height: 14)

                                // Primary text
                                Text(showThaiPrimary ? item.thai : (item.burmese ?? "No Burmese translation available"))
                                    .font(.system(size: 18, weight: .medium))

                                Spacer()

                                // Count
                                Text("\(item.count)")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }

                            // Secondary line (always show like normal view)
                            Text(showThaiPrimary ? (item.burmese ?? "No Burmese translation available") : item.thai)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.yellow)
                                .padding(.leading, 28)
                        }
                        .padding(.vertical, 6)
                    }
                    .onMove(perform: moveInCategory)
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
            } else {
                VocabularyListView(
                    items: $items,
                    filteredItems: $filteredItems,
                    showBurmeseForID: $showBurmeseForID,
                    selectedStatus: $selectedStatus,
                    playTapSound: playTapSound,
                    saveItems: saveItems,
                    showThaiPrimary: showThaiPrimary,
                    plusAction: {},
                    homeAction: {},
                    resumeAction: {},
                    allowReorder: false,
                    showContextMenu: false,
                    alwaysShowSecondary: true,
                    showCategoryLabel: false
                )
                .environmentObject(ttsPlayer)
            }
        }
        .navigationTitle("\(category) \(filteredItems.count)")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Reorder") {
                    SoundManager.playSound(1104)
                    isEditing.toggle()
                }
            }
        }
        .onAppear {
            // Load from UserDefaults first for freshest data; fallback to CSV
            if let savedData = UserDefaults.standard.data(forKey: "vocab_items"),
               let decoded = try? JSONDecoder().decode([VocabularyEntry].self, from: savedData),
               !decoded.isEmpty {
                items = decoded
            } else {
                items = loadCSV()
            }
            applyFilter()
        }
        .onChange(of: items) { _, _ in
            applyFilter()
            scheduleSave()
        } // keep filter updated if list mutates
        .onChange(of: scenePhase) { _, phase in
            // Flush pending writes when app is backgrounded/locked
            if phase == .inactive || phase == .background {
                saveItems()
            }
        }
        // Floating playback controls with Thai & Burmese lines
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let current = currentItem {
                    Text(current.thai)
                        .font(showThaiPrimary ? .system(size: 24, weight: .bold) : .headline)
                    Text(current.burmese ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(currentIndex+1) of \(filteredItems.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 32) {
                Button {
                    if currentIndex > 0 { currentIndex -= 1 }
                    isPlaying = false
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                Button {
                    if isPlaying {
                        // Pause – keep queue state
                        ttsPlayer.pause()
                        isPlaying = false
                    } else if ttsPlayer.isPaused {
                        // Resume where we left off
                        ttsPlayer.resume()
                        isPlaying = true
                    } else if !filteredItems.isEmpty {
                        // Fresh playback starting from currentIndex
                        let remaining = Array(filteredItems.dropFirst(currentIndex).map { $0.thai })
                        ttsPlayer.playQueue(texts: remaining, rate: speechRate, delay: 1)
                        isPlaying = true
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }
                // Repeat toggle
                Button {
                    ttsPlayer.repeatMode.toggle()
                } label: {
                    Image(systemName: ttsPlayer.repeatMode ? "repeat.circle.fill" : "repeat")
                        .font(.title2)
                        .foregroundColor(ttsPlayer.repeatMode ? .blue : .primary)
                }
                /* Play-All button removed – play is now queue */
                /*
                // Play all words sequentially
                Button {
                    if !filteredItems.isEmpty {
                        ttsPlayer.playQueue(texts: filteredItems.map { $0.thai }, rate: speechRate, delay: 1)
                        isPlaying = true
                        currentIndex = 0
                    }
                } label: {
                    Image(systemName: "text.line.first.and.arrowtriangle.down")
                        .font(.title2)
                }
                */
                Button {
                    if currentIndex + 1 < filteredItems.count { currentIndex += 1 }
                    isPlaying = false
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                                }
                }
                // Rate buttons
                HStack(spacing: 12) {
                    ForEach(availableRates, id: \.self) { rate in
                        Text(String(format: "%.1f", rate))
                            .font(.caption)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(rate == speechRate ? Color.blue : Color.black.opacity(0.3))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onTapGesture {
                                speechRate = rate
                            }
                    }
                }
                .padding(.bottom, 4)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .contentShape(Rectangle())
            .onTapGesture { showPlayerSheet = true }
        }
        // Sync UI with TTS playback progress
        .onReceive(ttsPlayer.$currentQueueIndex) { idx in
            if filteredItems.indices.contains(idx) {
                currentIndex = idx
            }
        }
        .onReceive(ttsPlayer.$isSpeakingQueue) { playing in
            isPlaying = playing
        }
        .onChange(of: router.sheet) { _, newValue in
            switch newValue {
            case .editWord(let id):
                if let item = items.first(where: { $0.id == id }) {
                    editingItem = item
                }
            default:
                break
            }
        }
        // Expanded player sheet
        .sheet(isPresented: $showPlayerSheet) {
            VStack(spacing: 16) {
                // drag indicator is automatic
                if let current = currentItem {
                    Text(current.thai)
                        .font(.largeTitle).bold()
                    Text(current.burmese ?? "")
                        .font(.title3).foregroundColor(.secondary)
                }
                // reuse playback controls
                // simple: call the same mini bar view
                Spacer()
                Text("Swipe down to collapse")
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding()
            .presentationDetents([.height(120), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingItem) { item in
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                AddEditWordSheet(
                    isAdding: false,
                    item: $items[idx],
                    onSave: { _ in
                        saveItems()
                        editingItem = nil
                    },
                    onCancel: { editingItem = nil }
                )
            }
        }
    }

    // MARK: – Helpers
    private func moveInCategory(from source: IndexSet, to destination: Int) {
        // Reorder within filtered list
        filteredItems.move(fromOffsets: source, toOffset: destination)
        // Mirror order back to items within this category slice
        let idsSet = Set(filteredItems.map { $0.id })
        let originalFirstIndex = items.enumerated()
            .filter { idsSet.contains($0.element.id) }
            .map { $0.offset }
            .min() ?? items.count
        items.removeAll { idsSet.contains($0.id) }
        let insertIndex = min(originalFirstIndex, items.count)
        items.insert(contentsOf: filteredItems, at: insertIndex)
        scheduleSave()
    }
    private func applyFilter() {
        let token = filterToken &+ 1
        filterToken = token
        let snapshot = items
        let cat = category
        DispatchQueue.global(qos: .userInitiated).async {
            // Keep original (persisted) order to respect manual reordering
            let result = snapshot.filter { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) == cat }
            DispatchQueue.main.async {
                guard token == filterToken else { return }
                self.filteredItems = result
            }
        }
    }
    
    private func playTapSound() {
        // Reuse global sound manager if available, else no-op
        #if canImport(AudioToolbox)
        SoundManager.playSound(1104)
        #endif
    }

    private func saveItems() {
        // Persist items like ContentView does, but off the main thread
        let snapshot = items
        DispatchQueue.global(qos: .utility).async {
            if let encoded = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(encoded, forKey: "vocab_items")
            }
            CSVManager.exportToDocuments(snapshot)
        }
    }

    private func scheduleSave() {
        saveDebounce?.cancel()
        let work = DispatchWorkItem { saveItems() }
        saveDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}

#Preview {
    CategoryWordsView(category: "Greeting")
}
