import SwiftUI
import AudioToolbox
import UIKit
import AVFoundation
import UniformTypeIdentifiers

// Conditional context menu helper
extension View {
    @ViewBuilder
    func conditionalContextMenu<V: View>(_ enabled: Bool, @ViewBuilder menu: () -> V) -> some View {
        if enabled {
            self.contextMenu(menuItems: menu)
        } else {
            self
        }
    }
}

// MARK: - Custom Drop Delegate for Reordering
private struct ReorderDropDelegate: DropDelegate {
    let targetItem: VocabularyEntry
    @Binding var draggingItem: VocabularyEntry?
    @Binding var draggingItemID: UUID?
    @Binding var filteredItems: [VocabularyEntry]
    @Binding var items: [VocabularyEntry]
    var save: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        draggingItemID = nil
        save()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool { true }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem, dragging.id != targetItem.id else { return }

        if let fromIndex = filteredItems.firstIndex(where: { $0.id == dragging.id }),
           let toIndex = filteredItems.firstIndex(where: { $0.id == targetItem.id }) {
            if fromIndex != toIndex {
                withAnimation(.easeInOut(duration: 0.15)) {
                    filteredItems.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                }

                // Reflect the same order in the master items array within the same category block
                if targetItem.category?.trimmingCharacters(in: .whitespacesAndNewlines) != nil {
                    let ids = Set(filteredItems.map { $0.id })
                    // Find original first index of this category slice BEFORE removal
                    let originalFirstIndex = items.enumerated()
                        .filter { ids.contains($0.element.id) }
                        .map { $0.offset }
                        .min() ?? items.count
                    // Remove existing occurrences
                    items.removeAll { ids.contains($0.id) }
                    // Insert the filtered (reordered) slice back at the original anchor index
                    let insertIndex = min(originalFirstIndex, items.count)
                    items.insert(contentsOf: filteredItems, at: insertIndex)
                }
            }
        }
    }
}

struct VocabularyListView: View {
    @EnvironmentObject var ttsGlobal: TTSQueuePlayer
    @EnvironmentObject private var router: AppRouter
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
    var allowReorder: Bool = false
    var showContextMenu: Bool = true
    // When true, always show the secondary line (Thai/Burmese) under the primary text
    var alwaysShowSecondary: Bool = false
    // Controls whether to show the small category caption under the primary line
    var showCategoryLabel: Bool = true

    @AppStorage("lastVocabID") private var storedLastVocabID: String = ""
    @State private var draggingItem: VocabularyEntry? = nil
    @State private var draggingItemID: UUID? = nil
    @AppStorage("sessionPaused") private var sessionPaused: Bool = false
    @State private var showCompletionAlert = false
    @State private var isLoading: Bool = true
    @State private var saveDebounce: DispatchWorkItem? = nil

    // MARK: – Helpers
    private func color(for status: VocabularyStatus) -> Color {
        switch status {
        case .queue: return Color.red.opacity(0.5)
        case .drill: return Color.yellow.opacity(0.5)
        case .ready: return Color.green.opacity(0.5)
        }
    }

    private func isMyanmarScript(_ s: String) -> Bool {
        for scalar in s.unicodeScalars {
            switch scalar.value {
            case 0x1000...0x109F, 0xAA60...0xAA7F, 0xA9E0...0xA9FF:
                return true
            default:
                continue
            }
        }
        return false
    }

    private var totalVocabCount: Int {
        items.reduce(0) { $0 + $1.count }
    }

    // MARK: – Body
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading vocabulary...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if allowReorder {
                        ForEach(filteredItems) { item in
                            if let realIndex = items.firstIndex(where: { $0.id == item.id }) {
                                row(for: item, realIndex: realIndex)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        ttsGlobal.pause()
                                        if !isLoading && items.indices.contains(realIndex) {
                                            router.openCounter(id: items[realIndex].id)
                                        }
                                    }
                            }
                        }
                        .onMove(perform: move)
                    } else {
                        ForEach(filteredItems) { item in
                            if let realIndex = items.firstIndex(where: { $0.id == item.id }) {
                                row(for: item, realIndex: realIndex)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        ttsGlobal.pause()
                                        if !isLoading && items.indices.contains(realIndex) {
                                            router.openCounter(id: items[realIndex].id)
                                        }
                                    }
                            }
                        }
                        .onDelete(perform: deleteRows)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(allowReorder ? .active : .inactive))
            }
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
        .onChange(of: items) { _, _ in
            // persist the last vocab if it still exists
            if let uuid = UUID(uuidString: storedLastVocabID), !items.contains(where: { $0.id == uuid }) {
                storedLastVocabID = ""
            }
            scheduleSave()
        }
    }

    // Reordering helper for EditMode + .onMove
    private func move(from source: IndexSet, to destination: Int) {
        // Reorder within filtered list
        filteredItems.move(fromOffsets: source, toOffset: destination)
        // Reorder matching items array within same category range if possible
        if let firstCat = filteredItems.first?.category {
            let catTrim = firstCat.trimmingCharacters(in: .whitespacesAndNewlines)
            if let start = items.firstIndex(where: { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) == catTrim }) {
                // Remove all category items
                let catIDs = Set(filteredItems.map { $0.id })
                items.removeAll(where: { catIDs.contains($0.id) })
                // Insert back in new order
                items.insert(contentsOf: filteredItems, at: start)
            }
        }
        scheduleSave()
    }

    private func play10X() {
        let texts = filteredItems.prefix(10).map { $0.thai }
        ttsGlobal.play(texts: texts)
    }

    private func playRecent10() {
        let recentIDs = RecentCountRecorder.shared.recentIDs()
        let recentVocabs = recentIDs.compactMap { id in items.first(where: { $0.id == id }) }
        let texts = recentVocabs.prefix(10).map { $0.thai }
        ttsGlobal.play(texts: texts)
    }

    // Prefer non-ready from same category: drill -> queue; otherwise any non-ready globally
    private func pickReplacement(for target: VocabularyEntry) -> VocabularyEntry? {
        if let cat = target.category {
            if let drill = items.first(where: { $0.category == cat && $0.status == .drill }) { return drill }
            if let queue = items.first(where: { $0.category == cat && $0.status == .queue }) { return queue }
        }
        return items.first(where: { $0.status != .ready })
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
                        .font({
                            let text = showThaiPrimary ? item.thai : (item.burmese ?? "No Burmese translation available")
                            let isMM = isMyanmarScript(text)
                            // Burmese fonts render visually heavier; use regular and -1 size to match Thai
                            return .system(size: isMM ? 17 : 18, weight: isMM ? .regular : .medium)
                        }())
                }
                

                Spacer()

                HStack(spacing: 8) {
                    Text("\(items[realIndex].count)")
                }
            }

            if showCategoryLabel,
               let category = items[realIndex].category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
                Text(category)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
            }
            
            if alwaysShowSecondary || showBurmeseForID == item.id {
                Text(showThaiPrimary ? (item.burmese ?? "No Burmese translation available")
                                     : item.thai)
                    .font({
                        let text = showThaiPrimary ? (item.burmese ?? "No Burmese translation available") : item.thai
                        let isMM = isMyanmarScript(text)
                        // Keep secondary slightly smaller but normalize weight
                        return .system(size: alwaysShowSecondary ? 15 : 16, weight: isMM ? .regular : .regular)
                    }())
                    .foregroundColor(.yellow)
                    .padding(.leading, 28)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .conditionalContextMenu(showContextMenu) {
            Button("Queue") { updateStatus(for: item.id, to: .queue) }
            Button("Drill") { updateStatus(for: item.id, to: .drill) }
            Button("Ready") { updateStatus(for: item.id, to: .ready) }
            Button("Edit") {
                router.openEdit(id: item.id)
            }
        }
        .if(!allowReorder) { view in
            view.swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    UIPasteboard.general.string = showThaiPrimary ? item.thai : (item.burmese ?? "")
                    playTapSound()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .tint(.blue)
            }
        }
    }

    // MARK: – Mutations
    private func deleteRows(at offsets: IndexSet) {
        // Map offsets from filteredItems to actual item IDs
        let ids = offsets.compactMap { idx in
            filteredItems.indices.contains(idx) ? filteredItems[idx].id : nil
        }
        // Update filteredItems for immediate UI responsiveness
        filteredItems.removeAll { ids.contains($0.id) }
        // Remove from the canonical items array
        items.removeAll { ids.contains($0.id) }
        scheduleSave()
        playTapSound()
    }

    private func deleteItem(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
            scheduleSave()
            playTapSound()
        }
    }

    private func updateStatus(for id: UUID, to newStatus: VocabularyStatus) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = newStatus
            scheduleSave()
            playTapSound()
        }
    }
    
    // Debounced save to coalesce rapid edits into a single write
    private func scheduleSave() {
        saveDebounce?.cancel()
        let work = DispatchWorkItem { saveItems() }
        saveDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}

// Extension to conditionally apply modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
