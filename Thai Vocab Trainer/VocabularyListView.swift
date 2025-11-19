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

// Notification for reopening CounterView after editing
extension Notification.Name {
    static let openCounter = Notification.Name("openCounter")
    static let play10X = Notification.Name("play10X")
    static let playRecent10 = Notification.Name("playRecent10")
    static let homeAction = Notification.Name("homeAction")
    static let addWord = Notification.Name("addWord")
}

struct VocabularyListView: View {
    @EnvironmentObject var ttsGlobal: TTSQueuePlayer
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

    @State private var counterItem: VocabularyEntry?      // drives the sheet
    @State private var lastCounterID: UUID? = nil        // tracks previously shown vocab
    @State private var historyIDs: [UUID] = []           // navigation history
    @State private var historyIndex: Int = -1
    @State private var lastCategory: String? = nil
    @AppStorage("lastCategory") private var storedLastCategory: String = ""
    @AppStorage("lastVocabID") private var storedLastVocabID: String = ""
    @State private var selectedDetent: PresentationDetent = .large
    @State private var draggingItem: VocabularyEntry? = nil
    @State private var draggingItemID: UUID? = nil
    @AppStorage("sessionPaused") private var sessionPaused: Bool = false
    @State private var showCompletionAlert = false
    @State private var isLoading: Bool = true
    @State private var queuedEditID: UUID? = nil
    @State private var queuedEditThai: String? = nil
    @State private var saveDebounce: DispatchWorkItem? = nil
    // Pending target when we need to close current CounterView first
    @State private var pendingTargetID: UUID? = nil
    @State private var pendingTargetThai: String? = nil
    // Guard against immediately reopening the same CounterView right after dismissal
    @State private var lastDismissedID: UUID? = nil
    @State private var lastDismissedTime: Date? = nil

    // MARK: – Helpers
    private func normalized(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
    }
    // Returns true if the given id matches the most recently dismissed CounterView
    // within a short cooldown window to avoid ghost reopens of the same vocab.
    private func shouldSuppressOpen(for id: UUID?) -> Bool {
        guard let id, let lastID = lastDismissedID, let lastTime = lastDismissedTime else { return false }
        // 1 second cooldown window after dismissal
        let interval = Date().timeIntervalSince(lastTime)
        return id == lastID && interval < 1.0
    }
    private func color(for status: VocabularyStatus) -> Color {
        switch status {
        case .queue: return Color.red.opacity(0.5)
        case .drill: return Color.yellow.opacity(0.5)
        case .ready: return Color.green.opacity(0.5)
        }
    }

    // Ensure consistent visual weight between Thai and Burmese (Myanmar) scripts
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
        // Listen for "Next" events from CounterView
        let _ = Self._printChanges()

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
                                            counterItem = items[realIndex]
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
                                            counterItem = items[realIndex]
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
            // Prefer deep link target FIRST to avoid showing previous vocab momentarily
            var handledDeepLink = false
            if let (targetID, targetThai) = DeepLinkStore.consume() {
                if let item = items.first(where: { $0.id == targetID }) {
                    // Open exact target
                    let target = item
                    counterItem = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        counterItem = target
                    }
                    handledDeepLink = true
                } else if let thai = targetThai {
                    let nThai = normalized(thai)
                    if let match = items.first(where: { normalized($0.thai) == nThai }) {
                        let target = match
                        counterItem = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            counterItem = target
                        }
                        handledDeepLink = true
                    } else {
                        // Items not yet loaded or target not found; process later
                        queuedEditID = targetID
                        queuedEditThai = targetThai
                        processQueuedEditIfPossible()
                        handledDeepLink = true
                    }
                } else {
                    // Items not yet loaded or target not found; process later
                    queuedEditID = targetID
                    queuedEditThai = targetThai
                    processQueuedEditIfPossible()
                    handledDeepLink = true
                }
            }

            // Restore last category from storage
            if !storedLastCategory.trimmingCharacters(in: .whitespaces).isEmpty {
                lastCategory = storedLastCategory
            }
            // Restore last vocab only if no deep link was handled and not ready
            let suppressRestoreOnce = UserDefaults.standard.bool(forKey: "suppressCounterRestoreOnce")
            if suppressRestoreOnce {
                // Consume the one-shot suppress toggle
                UserDefaults.standard.set(false, forKey: "suppressCounterRestoreOnce")
            }
            if !handledDeepLink && !suppressRestoreOnce,
               let uuid = UUID(uuidString: storedLastVocabID),
               !shouldSuppressOpen(for: uuid),
               let item = items.first(where: { $0.id == uuid && $0.status != .ready }) {
                counterItem = item
            }
            // Simulate loading delay if items are empty (replace with your real loading logic)
            if items.isEmpty {
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = false
                }
            } else {
                isLoading = false
            }
            // Deep link (if any) already handled above
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextVocabulary)) { _ in
            // Debug: Check if we have category context
            print("🔍 VocabularyListView: nextVocabulary received, lastCategory = \(lastCategory ?? "nil")")
            
            // Only handle nextVocabulary if we have a specific category context
            guard let cat = lastCategory else { 
                print("🔍 VocabularyListView: No category context, skipping")
                return 
            }
            // 1. If we have forward history, move forward
            if historyIndex + 1 < historyIDs.count {
                historyIndex += 1
                let nextID = historyIDs[historyIndex]
                if let nextItem = items.first(where: { $0.id == nextID }) {
                    counterItem = nextItem
                    return
                }
            }
            // 2. Prefer a new vocab from the same category if possible (drill -> queue -> ready)
            // Check if the current category is fully completed first
            print("🔍 VocabularyListView: Searching in category '\(cat)'")
            let categoryItems = items.filter { $0.category == cat }
            print("🔍 VocabularyListView: Found \(categoryItems.count) items in category '\(cat)'")
            
            if true { // We already have cat from guard above
                // categoryItems already defined above
                let allInCategoryAreReady = !categoryItems.isEmpty && categoryItems.allSatisfy { $0.status == .ready }

                if allInCategoryAreReady {
                    // Find the next category with words that are not 'ready'
                    let allCats = Array(Set(items.compactMap { $0.category })).sorted()
                    if let currentIndex = allCats.firstIndex(of: cat) {
                        for i in 1..<allCats.count {
                            let nextCatIndex = (currentIndex + i) % allCats.count
                            let nextCategory = allCats[nextCatIndex]
                            
                            // Check if this next category has any non-ready items
                            if items.contains(where: { $0.category == nextCategory && $0.status != .ready }) {
                                // Found a new category, now find a word in it
                                let drill = items.first { $0.category == nextCategory && $0.status == .drill && !historyIDs.contains($0.id) }
                                let queue = items.first { $0.category == nextCategory && $0.status == .queue && !historyIDs.contains($0.id) }
                                
                                if let candidate = drill ?? queue {
                                    counterItem = candidate
                                    return // Exit after finding the new word
                                }
                            }
                        }
                    }
                    // If no other category has words, fall through to global search which will show completion alert if needed
                }

                // Same category priority by status
                let sameDrill = items.filter { $0.category == cat && $0.status == .drill && !historyIDs.contains($0.id) }
                if let candidate = sameDrill.first {
                    counterItem = candidate
                    return
                }
                let sameQueue = items.filter { $0.category == cat && $0.status == .queue && !historyIDs.contains($0.id) }
                if let candidate = sameQueue.first {
                    counterItem = candidate
                    return
                }
                // Skip ready items in same category - they should not be selected again
                // Only select ready items if ALL items in category are ready (handled above)
            }
            // 3. Otherwise, fallback to global status priority: drill → queue only (no ready items)
            let ordered = items.filter { $0.status == .drill } +
                          items.filter { $0.status == .queue }
            if let newItem = ordered.first(where: { !historyIDs.contains($0.id) }) {
                counterItem = newItem
            } else {
                showCompletionAlert = true
            }
        }
        // Explicitly close any open CounterView before opening a new one (e.g., from notifications)
        .onReceive(NotificationCenter.default.publisher(for: .closeCounter)) { _ in
            if counterItem != nil {
                counterItem = nil
            }
            // Clear stored last ID to avoid auto-restore while switching
            storedLastVocabID = ""
        }
        // Sync navigation history when the displayed vocab changes
        .onChange(of: counterItem) { _, newItem in
            print("🧪 VocabularyListView: counterItem changed to \(newItem?.id.uuidString ?? "nil")")
            guard let item = newItem else { return }
            lastCounterID = item.id
            lastCategory = item.category
                 // Persist category
                 storedLastCategory = item.category ?? ""
                 storedLastVocabID = item.id.uuidString
            if let existingIdx = historyIDs.firstIndex(of: item.id) {
                // Navigated within history – just update index
                historyIndex = existingIdx
            } else {
                // New vocab – append and set index to end
                historyIDs.append(item.id)
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
        // Open specific CounterView after editing or deep link
        .onReceive(NotificationCenter.default.publisher(for: .openCounter)) { notification in
            print("🧪 VocabularyListView: .openCounter received object = \(String(describing: notification.object))")
            var resolvedID: UUID? = nil
            var fallbackThai: String? = nil
            if let id = notification.object as? UUID {
                resolvedID = id
            } else if let dict = notification.object as? [String: Any] {
                if let id = dict["id"] as? UUID { resolvedID = id }
                if let thai = dict["thai"] as? String { fallbackThai = thai }
            }
            print("🧪 VocabularyListView: resolvedID=\(String(describing: resolvedID)), fallbackThai=\(fallbackThai ?? "nil")")
            // If a sheet is currently showing, queue and close first to avoid SwiftUI race
            if counterItem != nil {
                pendingTargetID = resolvedID
                pendingTargetThai = fallbackThai
                print("🧪 VocabularyListView: CounterView already open, queuing target id=\(String(describing: resolvedID)), thai=\(fallbackThai ?? "nil")")
                counterItem = nil
                return
            }
            // Respect recent-dismiss guard to avoid ghost reopens of the same vocab
            if shouldSuppressOpen(for: resolvedID) {
                print("🧪 VocabularyListView: suppressing .openCounter for id=\(String(describing: resolvedID)) due to recent dismissal")
                return
            }
            // Resolve target by ID first, then by Thai text
            var target: VocabularyEntry? = nil
            if let id = resolvedID {
                target = items.first(where: { $0.id == id })
            }
            if target == nil, let thai = fallbackThai {
                let nThai = normalized(thai)
                target = items.first(where: { normalized($0.thai) == nThai })
            }
            if let t = target {
                print("🧪 VocabularyListView: will open CounterView for id=\(t.id), count=\(t.count)")
                // Force a transition so SwiftUI presents the sheet reliably
                counterItem = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    counterItem = t
                }
            } else if let id = resolvedID {
                // Not loaded yet; queue for later processing
                queuedEditID = id
                queuedEditThai = fallbackThai
                print("🧪 VocabularyListView: queued target id=\(id), thai=\(fallbackThai ?? "nil") for later")
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
            scheduleSave()
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
                .presentationDetents([.large], selection: $selectedDetent)
                .interactiveDismissDisabled(false)
                .presentationDragIndicator(.visible)
                .onDisappear {
                    print("🧪 VocabularyListView: CounterView dismissed for id=\(entry.id), count=\(entry.count) at \(Date())")
                    // Force a save when closing the sheet to avoid losing recent edits
                    scheduleSave()
                    // Clear the persisted last-vocab ID so ContentView/auto-resume logic
                    // won’t re-open the same CounterView right after dismissal.
                    storedLastVocabID = ""
                    // Record which vocab was just dismissed and when, so that
                    // delayed notifications/deep-links cannot immediately reopen
                    // the same CounterView with stale state.
                    lastDismissedID = entry.id
                    lastDismissedTime = Date()
                }
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

    private func processQueuedEditIfPossible() {
        guard !isLoading else { return }
        if let queuedID = queuedEditID, let target = items.first(where: { $0.id == queuedID }) {
            // Open exact target if found by ID
            if counterItem?.id != target.id && !shouldSuppressOpen(for: target.id) {
                counterItem = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    counterItem = target
                    queuedEditID = nil
                    queuedEditThai = nil
                }
            } else {
                queuedEditID = nil
                queuedEditThai = nil
            }
            return
        }
        if let thai = queuedEditThai {
            let nThai = normalized(thai)
            if let match = items.first(where: { normalized($0.thai) == nThai }) {
                if counterItem?.id != match.id && !shouldSuppressOpen(for: match.id) {
                    counterItem = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        counterItem = match
                        queuedEditID = nil
                        queuedEditThai = nil
                    }
                } else {
                    queuedEditID = nil
                    queuedEditThai = nil
                }
            }
        }
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
                NotificationCenter.default.post(name: .editVocabularyEntry, object: item.id)
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
