import SwiftUI
import AudioToolbox
import UIKit
import AVFoundation

// Notification for reopening CounterView after editing
extension Notification.Name {
    static let openCounter = Notification.Name("openCounter")
    static let play10X = Notification.Name("play10X")
    static let playRecent10 = Notification.Name("playRecent10")
    static let homeAction = Notification.Name("homeAction")
    static let addWord = Notification.Name("addWord")
}

struct VocabularyListView: View {
    @Binding var items: [VocabularyEntry]
    @Binding var filteredItems: [VocabularyEntry]
    @Binding var showBurmeseForID: UUID?
    @Binding var selectedStatus: VocabularyStatus?
    var playTapSound: () -> Void
    var saveItems: () -> Void
    var showThaiPrimary: Bool

    // Actions passed from ContentView for additional buttons
    var plusAction: () -> Void
    var homeAction: () -> Void
    var resumeAction: () -> Void

    @State private var counterItem: VocabularyEntry?      // drives the sheet
    @State private var lastCounterID: UUID? = nil        // tracks previously shown vocab
    @State private var historyIDs: [UUID] = []           // navigation history
    @State private var historyIndex: Int = -1
    @StateObject private var ttsPlayer = TTSQueuePlayer()
    @State private var selectedDetent: PresentationDetent = .large
    @AppStorage("sessionPaused") private var sessionPaused: Bool = false
    @State private var showCompletionAlert = false
    @State private var isLoading: Bool = true
    @State private var queuedEditID: UUID? = nil

    // MARK: – Helpers
    private func color(for status: VocabularyStatus) -> Color {
        switch status {
        case .queue: return Color.red.opacity(0.5)
        case .drill: return Color.yellow.opacity(0.5)
        case .ready: return Color.green.opacity(0.5)
        }
    }

    private var totalVocabCount: Int {
        items.reduce(0) { $0 + $1.count }
    }

    // MARK: – Body
    var body: some View {
        // Listen for "Next" events from CounterView
        let _ = Self._printChanges()

        ZStack {
            if isLoading {
                ProgressView("Loading vocabulary...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredItems) { item in
                        if let realIndex = items.firstIndex(where: { $0.id == item.id }) {
                            Button(action: {
                                // Only allow navigation if items are loaded and valid
                                if !isLoading && items.indices.contains(realIndex) {
                                    counterItem = items[realIndex]
                                }
                            }) {
                                row(for: item, realIndex: realIndex)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }

        .alert("🎉 You learned everything!", isPresented: $showCompletionAlert) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            // Simulate loading delay if items are empty (replace with your real loading logic)
            if items.isEmpty {
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = false
                }
            } else {
                isLoading = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextVocabulary)) { _ in
            // 1. If we have forward history, move forward
            if historyIndex + 1 < historyIDs.count {
                historyIndex += 1
                let nextID = historyIDs[historyIndex]
                if let nextItem = items.first(where: { $0.id == nextID }) {
                    counterItem = nextItem
                    return
                }
            }
            // 2. Otherwise, pick a new item not yet in history, priority: drill → queue → ready
            let ordered = items.filter { $0.status == .drill } +
                          items.filter { $0.status == .queue } +
                          items.filter { $0.status == .ready }
            if let newItem = ordered.first(where: { !historyIDs.contains($0.id) }) {
                counterItem = newItem
            } else {
                showCompletionAlert = true
            }
        }
        // Sync navigation history when the displayed vocab changes
        .onChange(of: counterItem) { _, newItem in
            guard let id = newItem?.id else { return }
            lastCounterID = id
            if let existingIdx = historyIDs.firstIndex(of: id) {
                // Navigated within history – just update index
                historyIndex = existingIdx
            } else {
                // New vocab – append and set index to end
                historyIDs.append(id)
                historyIndex = historyIDs.count - 1
            }
        }
        // Handle Prev navigation
        .onReceive(NotificationCenter.default.publisher(for: .prevVocabulary)) { _ in
            guard historyIndex > 0 else { return }
            historyIndex -= 1
            let prevID = historyIDs[historyIndex]
            if let prevItem = items.first(where: { $0.id == prevID }) {
                counterItem = prevItem
            }
        }
        // Open specific CounterView after editing
        .onReceive(NotificationCenter.default.publisher(for: .openCounter)) { notification in
            if let id = notification.object as? UUID {
                if !isLoading, let item = items.first(where: { $0.id == id }) {
                    counterItem = item
                } else {
                    queuedEditID = id
                }
            }
        }
        // Try to process queued edit whenever items or loading state changes
        .onChange(of: isLoading) { _, _ in
            processQueuedEditIfPossible()
        }
        .onReceive(NotificationCenter.default.publisher(for: .play10X)) { _ in
            play10X()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playRecent10)) { _ in
            playRecent10()
        }
        .onChange(of: items) { _, _ in
            processQueuedEditIfPossible()
        }
        .sheet(item: $counterItem) { entry in
            let itemBinding: Binding<VocabularyEntry> = {
                if let idx = items.firstIndex(where: { $0.id == entry.id }) {
                    return $items[idx]
                } else {
                    // Fallback binding to avoid "Error loading item" flash
                    return .constant(entry)
                }
            }()
            CounterView(item: itemBinding,
                        allItems: $items,
                        totalVocabCount: totalVocabCount)
                .presentationDetents([.large, .height(160)], selection: $selectedDetent)
                .interactiveDismissDisabled(false)
                .presentationDragIndicator(.visible)
                .onChange(of: selectedDetent) { _, newDetent in
                    sessionPaused = (newDetent == .height(160))
                }
        }
    }

    // Helper function MUST be outside the body
    private func play10X() {
        let texts = filteredItems.prefix(10).map { $0.thai }
        ttsPlayer.play(texts: texts)
    }

    private func playRecent10() {
        let recentIDs = RecentCountRecorder.shared.recentIDs()
        let recentVocabs = recentIDs.compactMap { id in items.first(where: { $0.id == id }) }
        let texts = recentVocabs.prefix(10).map { $0.thai }
        ttsPlayer.play(texts: texts)
    }

    private func processQueuedEditIfPossible() {
        guard !isLoading, let queuedID = queuedEditID, let item = items.first(where: { $0.id == queuedID }) else { return }
        if counterItem?.id != queuedID {
            // If error sheet is showing, dismiss first
            counterItem = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                counterItem = item
                queuedEditID = nil
            }
        } else {
            queuedEditID = nil
        }
    }

    // MARK: – Row
    @ViewBuilder
    private func row(for item: VocabularyEntry, realIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color(for: item.status))
                        .frame(width: 14, height: 14)

                    Text(showThaiPrimary ? item.thai
                                         : (item.burmese ?? "No Burmese translation available"))
                        .font(.system(size: 18, weight: .medium))
                }
                

                Spacer()

                Text("\(items[realIndex].count)")
                    .foregroundColor(.gray)
            }

            if showBurmeseForID == item.id {
                Text(showThaiPrimary ? (item.burmese ?? "No Burmese translation available")
                                     : item.thai)
                    .foregroundColor(.yellow)
                    .padding(.leading, 28)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            playTapSound()
            counterItem = item
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Queue") { updateStatus(for: item.id, to: .queue) }
            Button("Drill") { updateStatus(for: item.id, to: .drill) }
            Button("Ready") { updateStatus(for: item.id, to: .ready) }
            Button("Edit") {
                NotificationCenter.default.post(name: .editVocabularyEntry, object: item.id)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                UIPasteboard.general.string = showThaiPrimary ? item.thai : (item.burmese ?? "")
                playTapSound()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteItem(id: item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: – Mutations
    private func deleteItem(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
            saveItems()
            playTapSound()
        }
    }

    private func updateStatus(for id: UUID, to newStatus: VocabularyStatus) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = newStatus
            saveItems()
            playTapSound()
        }
    }
}

