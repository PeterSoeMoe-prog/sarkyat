import SwiftUI
import AudioToolbox // Still needed for AudioServicesPlaySystemSound
#if canImport(UIKit)
import UIKit
#endif

// MARK: - App Enums and Structs (Assume these are defined elsewhere or defined here for completeness)

// If these are not already defined, they would be here:
/*
enum VocabularyStatus: String, CaseIterable, Identifiable, Codable {
    case queue = "Queue"
    case drill = "Drill"
    case ready = "Ready"

    var id: String { self.rawValue }

 

    var emoji: String {
        switch self {
        case .queue: return "😫"
        case .drill: return "🔥"
        case .ready: return "💎"
        }
    }
}

struct VocabularyEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var thai: String
    var burmese: String?
    var count: Int
    var status: VocabularyStatus

    init(id: UUID = UUID(), thai: String, burmese: String?, count: Int, status: VocabularyStatus, category: String? = nil) {
        self.id = id
        self.thai = thai
        self.burmese = burmese
        self.count = count
        self.status = status
        self.category = category
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light, dark, system

    var id: String { self.rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil // Uses system setting
        }
    }

    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gearshape.fill"
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let editVocabularyEntry = Notification.Name("editVocabularyEntry")
}
*/

// Fresh: measure the height of the bottom inset (buttons + search) so we can align the list fade precisely
private struct BottomBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


// Assume IntroView and VocabularyListView are separate SwiftUI Views
// (They are external to ContentView in the original code, which is good practice)
/*
struct IntroView: View {
    let totalCount: Int
    let vocabCount: Int
    var body: some View {
        VStack {
            Text("Welcome to Vocab App!")
                .font(.largeTitle)
            Text("Total Vocabulary Entries: \(totalCount)")
            Text("Filtered Entries: \(vocabCount)")
        }
    }
}

struct VocabularyListView: View {
    @Binding var items: [VocabularyEntry]
    @Binding var filteredItems: [VocabularyEntry]
    @Binding var showBurmeseForID: UUID?
    @Binding var selectedStatus: VocabularyStatus?
    let playTapSound: () -> Void
    let saveItems: () -> Void
    let showThaiPrimary: Bool

    var body: some View {
        List {
            ForEach(filteredItems) { item in
                VocabularyRowView(
                    item: Binding(
                        get: { item },
                        set: { newItem in
                            if let index = items.firstIndex(where: { $0.id == newItem.id }) {
                                items[index] = newItem
                                saveItems() // Save whenever an item is updated via the binding
                            }
                        }
                    ),
                    showBurmeseForID: $showBurmeseForID,
                    showThaiPrimary: showThaiPrimary,
                    playTapSound: playTapSound
                )
                .swipeActions(edge: .leading) {
                    Button {
                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                            items[index].status = .drill
                            saveItems()
                            playTapSound()
                        }
                    } label: {
                        Label("Drill", systemImage: "flame.fill")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                            items.remove(at: index)
                            saveItems()
                            playTapSound()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                    Button {
                        NotificationCenter.default.post(name: .editVocabularyEntry, object: item.id)
                        playTapSound()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    let sample = [
        VocabularyEntry(thai: "ขอบคุณ", burmese: "ကျေးဇူးတင်ပါတယ်", count: 0, status: .queue, category: "Polite"),
        VocabularyEntry(thai: "สวัสดี", burmese: "မင်္ဂလာပါ", count: 3, status: .drill, category: "Greeting"),
        VocabularyEntry(thai: "ไปไหน", burmese: "ဘယ်သွားမလဲ", count: 5, status: .ready, category: "Question")
    ]
    VocabularyListView(
        items: .constant(sample),
        filteredItems: .constant(sample),
        showBurmeseForID: .constant(nil),
        selectedStatus: .constant(nil),
        playTapSound: {},
        saveItems: {},
        showThaiPrimary: true
    )
    .previewLayout(.sizeThatFits)
}
#endif

struct VocabularyRowView: View {
    @Binding var item: VocabularyEntry
    @Binding var showBurmeseForID: UUID?
    let showThaiPrimary: Bool
    let playTapSound: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(showThaiPrimary ? item.thai : item.burmese ?? "N/A")
                    .font(showThaiPrimary ? .system(size: 24, weight: .bold) : .headline)
                    .foregroundColor(item.status == .ready ? .green : .primary)
                if showBurmeseForID == item.id {
                    Text(showThaiPrimary ? (item.burmese ?? "N/A") : item.thai)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            }

            Spacer()
            HStack(spacing: 4) {
                Text("\(item.count)")
                    .font(.caption)
                    .foregroundColor(.yellow)
                if let category = item.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
                    Text(category)
                        .font(.caption2)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            Button(action: {
                showBurmeseForID = (showBurmeseForID == item.id) ? nil : item.id
                playTapSound()
            }) {
                Image(systemName: showBurmeseForID == item.id ? "eye.slash.fill" : "eye.fill")
                    .font(.caption)
                    .padding(4)
                    
                    .cornerRadius(5)
            }
            .buttonStyle(PlainButtonStyle()) // To prevent button tint
        }
        .padding(.vertical, 4)
    }
}
*/

// Global func loadCSV (kept outside ContentView so other helpers like
// CategoryViewModel and CategoryWordsView can reuse the same loader).
func loadCSV() -> [VocabularyEntry] {
    let fileManager = FileManager.default
    let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = docsURL.appendingPathComponent("vocab.csv")
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        print("Failed to read vocab.csv from Documents folder")
        return []
    }
    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    guard lines.count > 1 else { return [] } // must have header + at least one row

    let header = lines[0].lowercased()
    let hasIDFirst = header.hasPrefix("id,")

    var entries: [VocabularyEntry] = []
    entries.reserveCapacity(lines.count - 1)
    for line in lines.dropFirst() { // skip header
        let cols = line.components(separatedBy: ",")
        if hasIDFirst {
            guard cols.count >= 6 else { continue }
            let id = UUID(uuidString: cols[0]) ?? UUID()
            let thai = cols[1]
            let burmese = cols[2].isEmpty ? nil : cols[2]
            let count = Int(cols[3]) ?? 0
            let status = VocabularyStatus(rawValue: cols[4].capitalized) ?? .queue
            let category = cols[5].isEmpty ? nil : cols[5]
            entries.append(VocabularyEntry(id: id, thai: thai, burmese: burmese, count: count, status: status, category: category))
        } else {
            guard cols.count >= 4 else { continue }
            let thai = cols[0]
            let burmese = cols.count > 1 && !cols[1].isEmpty ? cols[1] : nil
            let count = cols.count > 2 ? (Int(cols[2]) ?? 0) : 0
            let status = cols.count > 3 ? (VocabularyStatus(rawValue: cols[3].capitalized) ?? .queue) : .queue
            let category = cols.count > 4 ? (cols[4].isEmpty ? nil : cols[4]) : nil
            entries.append(VocabularyEntry(thai: thai, burmese: burmese, count: count, status: status, category: category))
        }
    }
    return entries
}

struct ContentView: View {

    // MARK: - State Variables
    @EnvironmentObject private var vocabStore: VocabStore
    @EnvironmentObject private var router: AppRouter
    private var items: [VocabularyEntry] { vocabStore.items }
    private var itemsBinding: Binding<[VocabularyEntry]> {
        Binding(get: { vocabStore.items }, set: { vocabStore.setItems($0) })
    }
    @State private var filteredItems: [VocabularyEntry] = []
    @State private var showBurmeseForID: UUID? = nil
    @State private var selectedStatus: VocabularyStatus? = nil
    @State private var selectedCategory: String? = nil
    @State private var searchText: String = ""
    // Debounce work item for search to avoid filtering on every keystroke
    @State private var searchDebounceWorkItem: DispatchWorkItem? = nil
    @State private var showAddSheet = false
    @State private var showSettingsSheet = false
    @State private var editingItem: VocabularyEntry? = nil
    @State private var counterItem: VocabularyEntry? = nil
    @State private var showThaiPrimary = true
    @State private var sortByCountAsc = true
    // Show Daily Quiz from bottom cluster
    @State private var showDailyQuiz: Bool = false
    // Global TTS player for this screen
    @StateObject private var ttsPlayer = TTSQueuePlayer()
    @State private var showCategories = false
    // Open a specific category page pushed from CounterView
    @State private var openCategoryFromCounter: Bool = false
    @State private var categoryToOpen: String = ""

    @State private var currentOption: Option = .queue
    @EnvironmentObject var theme: ThemeManager
    @AppStorage("remainingSeconds") private var remainingSeconds: Int = 0
    @AppStorage("remainingTimestamp") private var remainingTimestamp: Double = 0
    @AppStorage("boostType") private var boostTypeRaw: String = BoostType.mins.rawValue
    @AppStorage("lastVocabID") private var storedLastVocabID: String = ""
    @State private var didAutoOpen: Bool = false
    // Trigger to programmatically expand/focus the search box
    @State private var activateSearchNow: Bool = false
    // Reflects whether the search box is expanded/active
    @State private var searchActive: Bool = false
    // Debouncer for search input
    @State private var searchDebounce: DispatchWorkItem? = nil
    // Controls whether the search box is visible at the bottom. Hidden by default until user swipes up the play group
    @State private var showSearchBox: Bool = false
    
    // Fresh: dynamic height of the bottom bar region for aligning the fade
    @State private var bottomBarHeight: CGFloat = 0
    // Fresh: fade thickness
    private let fadeThickness: CGFloat = 72

    // State for New/Edit Word Sheet (can be extracted to a separate ViewModel if more complex logic is needed)
    @State private var newThai = ""
    @State private var newBurmese = ""
    @State private var newCount = "0"
    @State private var newStatus: VocabularyStatus = .queue
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isImporting = false
    // Share sheet state
    @State private var shareURL: URL? = nil
    @State private var showingShare = false


    enum Option: CaseIterable, Identifiable {
        case all, recent, queue, drill, ready

        var id: Self { self }
        
        var label: String {
            switch self {
            case .all: return "🚀 All"
            case .recent: return "🕘 Recent"
            case .queue: return "😫 Queue"
            case .drill: return "🔥 Drill"
            case .ready: return "💎 Ready"
            }
        }

        var status: VocabularyStatus? {
            switch self {
            case .all, .recent: return nil
            case .queue: return .queue
            case .drill: return .drill
            case .ready: return .ready
            }
        }
    }

    var totalCount: Int {
        items.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        NavigationStack {
            
            
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    autoOpenCounterIfNeeded()
                }
                .withNotificationBell()
                .navigationDestination(isPresented: $showCategories) {
                    VocabCategoryView()
                }
                .navigationDestination(isPresented: $openCategoryFromCounter) {
                    CategoryListView(items: itemsBinding, category: categoryToOpen)
                }
                .sheet(isPresented: $showAddSheet, onDismiss: {
                    if case .addWord = router.sheet {
                        router.dismissSheet()
                    }
                }) {
                    AddEditWordSheet(
                        isAdding: true,
                        item: .constant(VocabularyEntry(thai: newThai, burmese: newBurmese.isEmpty ? nil : newBurmese, count: Int(newCount) ?? 0, status: newStatus)), // Pass initial values
                        existingCategories: uniqueCategories,
                         onSave: { newItem in
                            vocabStore.upsert(newItem)
                            resetNewWordFields()
                            showAddSheet = false
                            if case .addWord = router.sheet {
                                router.dismissSheet()
                            }
                            playTapSound()
                        },
                        onCancel: {
                            resetNewWordFields()
                            showAddSheet = false
                            if case .addWord = router.sheet {
                                router.dismissSheet()
                            }
                        }
                    )
                }
                .sheet(isPresented: $showSettingsSheet) {
                    SettingsView()
                }
                .fullScreenCover(isPresented: $showDailyQuiz, onDismiss: {
                    if case .dailyQuiz = router.sheet {
                        router.dismissSheet()
                    }
                }) {
                    DailyQuizView()
                }
                .sheet(item: $counterItem, onDismiss: {
                    counterItem = nil
                    if case .counter = router.sheet {
                        router.dismissSheet()
                    }
                }) { item in
                    if let binding = vocabStore.binding(for: item.id) {
                        CounterView(item: binding, allItems: itemsBinding, totalVocabCount: items.count)
                    } else {
                        Text("Error loading item")
                    }
                }
                .sheet(item: $editingItem) { item in
                    if let binding = vocabStore.binding(for: item.id) {
                        AddEditWordSheet(
                            isAdding: false,
                            item: binding,
                            onSave: { _ in
                                editingItem = nil
                                playTapSound()
                            },
                            onCancel: {
                                editingItem = nil
                            }
                        )
                    } else {
                        Text("Error loading item for editing.")
                            .onAppear { editingItem = nil }
                    }
                }
                .onAppear(perform: setupInitialState)
                
                .onChange(of: vocabStore.items) { _, _ in
                    filterItems()
                    if counterItem == nil && editingItem == nil {
                        applyRouterSheetState(router.sheet)
                    }
                }
                .onChange(of: searchText) {
                    // Debounce to reduce redundant filtering while typing
                    searchDebounce?.cancel()
                    let work = DispatchWorkItem { filterItems() }
                    searchDebounce = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
                }
                .onChange(of: router.shouldActivateSearch) { _, newValue in
                    guard newValue else { return }
                    showSearchBox = true
                    activateSearchNow = true
                    router.shouldActivateSearch = false
                }
                .onChange(of: router.categoryToOpen) { _, newValue in
                    guard let cat = newValue else { return }
                    categoryToOpen = cat
                    openCategoryFromCounter = true
                    router.categoryToOpen = nil
                }
                .onChange(of: router.sheet) { _, newValue in
                    showSettingsSheet = false
                    showAddSheet = false
                    showDailyQuiz = false
                    editingItem = nil
                    counterItem = nil
                    applyRouterSheetState(newValue)
                }
                .alert("Error", isPresented: $showingAlert) {
                    Button("OK") { }
                } message: {
                    Text(alertMessage)
                }
                // Share sheet for exported CSV
                .sheet(isPresented: $showingShare, onDismiss: {
                    showingShare = false
                    shareURL = nil
                }) {
                    if let shareURL {
                        ActivityView(activityItems: [shareURL])
                    }
                }
                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [.commaSeparatedText],
                    allowsMultipleSelection: false
                ) { result in
                    defer { isImporting = false }
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }
                            do {
                                let data = try Data(contentsOf: url)
                                if String(data: data, encoding: .utf8) != nil {
                                    let importedItems: [VocabularyEntry] = [] // CSV import disabled
                                    if !importedItems.isEmpty {
                                        vocabStore.setItems(importedItems)
                                        // alert disabled
                                        showingAlert = true
                                    } else {
                                        // alert disabled
                                        showingAlert = true
                                    }
                                }
                            } catch {
                                // alert disabled
                                showingAlert = true
                            }
                            url.stopAccessingSecurityScopedResource()
                        }
                    case .failure(_):
                        // alert disabled
                        showingAlert = true
                    }
                }
        }
        
    }

    // MARK: - Views 

    private var mainContent: some View {
        VStack(spacing: 0) {
            filterButtons
            VocabularyListView(
                items: itemsBinding,
                filteredItems: $filteredItems,
                showBurmeseForID: $showBurmeseForID,
                selectedStatus: $selectedStatus,
                playTapSound: playTapSound,
                saveItems: { vocabStore.saveNow() },
                showThaiPrimary: showThaiPrimary,
                plusAction: {
                    showAddSheet = true
                    playTapSound()
                },
                homeAction: {
                    @AppStorage("sessionPaused") var sessionPaused: Bool = false
                    sessionPaused = true // prevent auto-resume on IntroView
                    router.openIntro()
                    playTapSound()
                },
                resumeAction: {
                    resumeSession()
                    playTapSound()
                }
            )
            .environmentObject(ttsPlayer)
            .listStyle(PlainListStyle())
            // Fresh: fade-out the list content using a bottom-aligned mask that starts right above the bottom bar
            .mask(listFadeMask)
            // Keep the bottom bar height updated
            .onPreferenceChange(BottomBarHeightKey.self) { h in
                bottomBarHeight = h
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: searchActive ? 0 : 8) {
                    // Floating bottom bar (removed from layout entirely while searching)
                    if !searchActive {
                        BottomTabMock(
                            centerAction: { resumeSession() },
                            plusAction: {
                                showAddSheet = true
                                playTapSound()
                            },
                            categoryAction: {
                                showCategories = true
                                playTapSound()
                            },
                            dailyQuizAction: {
                                showDailyQuiz = true
                                playTapSound()
                            },
                            homeAction: {
                                @AppStorage("sessionPaused") var sessionPaused: Bool = false
                                sessionPaused = true // prevent auto-resume on IntroView
                                router.openIntro()
                                playTapSound()
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Search box placed under the buttons group
                    if showSearchBox {
                        collapsibleSearchBar
                            .padding(.horizontal, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.top, searchActive ? 0 : 6)
                .padding(.horizontal, 8)
                .padding(.bottom, searchActive ? 0 : 6)
                .background(Color.clear) // removed gray block background
                // Fresh: report height of the whole bottom inset (buttons + search)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: BottomBarHeightKey.self, value: geo.size.height)
                    }
                )
                // Animate reveal/hide of the search box
                .animation(.easeInOut(duration: 0.25), value: showSearchBox)
                // Detect swipe-up gesture anywhere on the bottom overlay (play button group area)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            // Reveal search box when user swipes upward
                            if value.translation.height < -20 {
                                withAnimation(.spring()) {
                                    showSearchBox = true
                                }
                                // Programmatically expand and focus the search field after insertion
                                DispatchQueue.main.async {
                                    activateSearchNow = true
                                }
                            }
                        }
                )
            }
        }
    }

    private var collapsibleSearchBar: some View {
        CollapsibleSearchBox(
            searchText: $searchText,
            showThaiPrimary: $showThaiPrimary,
            activateNow: $activateSearchNow,
            isActive: $searchActive,
            onClose: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSearchBox = false
                }
            }
        )
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
    }

    // Fresh: Mask used to create a smooth fade for the list. Disabled entirely when search is active.
    @ViewBuilder
    private var listFadeMask: some View {
        if searchActive {
            // No fade when search field is focused
            Color.white
        } else {
            GeometryReader { proxy in
                let totalH = proxy.size.height
                let fadeStartY = max(0, totalH - bottomBarHeight - fadeThickness)
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: min(1, fadeStartY / max(totalH, 1))),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var filterButtons: some View {
        HStack(spacing: 12) {
            Spacer()
            Button {
                showThaiPrimary.toggle()
                playTapSound()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                    Text(showThaiPrimary ? "Burmese" : "Thai")
                }
                .padding(6)
                
                .cornerRadius(8)
            }

            if selectedCategory == nil {
                Button {
                    cycleOption()
                    selectedStatus = currentOption.status
                    filterItems()
                    playTapSound()
                } label: {
                    Text(currentOption.label)
                        .padding(6)
                }
            } else {
                Text("All")
                    .bold()
                    .padding(6)
            }

            // Category menu removed per request

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Helper Methods

    // Normalize text for search: lowercase and remove diacritics
    private func normalized(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
    }

    // Simple Levenshtein distance for fuzzy search
    private func levenshtein(_ aStr: String, _ bStr: String) -> Int {
        let a = Array(aStr)
        let b = Array(bStr)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var curr = Array(repeating: 0, count: b.count + 1)
        for (i, ca) in a.enumerated() {
            curr[0] = i + 1
            for (j, cb) in b.enumerated() {
                let cost = (ca == cb) ? 0 : 1
                curr[j + 1] = min(
                    prev[j + 1] + 1,      // deletion
                    curr[j] + 1,          // insertion
                    prev[j] + cost        // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }

    // Fuzzy match helper: true if contains or within distance threshold
    private func fuzzyMatch(haystack: String, needle: String) -> Bool {
        let h = normalized(haystack)
        let n = normalized(needle)
        if h.contains(n) { return true }
        // Compare against words to avoid excessive distance on long strings
        let tokens = h.split{ !$0.isLetter && !$0.isNumber }.map(String.init)
        let threshold: Int = {
            switch n.count {
            case 0...4: return 1
            case 5...8: return 2
            default: return 3
            }
        }()
        for t in tokens where !t.isEmpty {
            if levenshtein(t, n) <= threshold { return true }
        }
        return false
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func cycleOption() {
        if let currentIndex = Option.allCases.firstIndex(of: currentOption) {
            let nextIndex = (currentIndex + 1) % Option.allCases.count
            currentOption = Option.allCases[nextIndex]
        }
    }



    private func resumeSession() {
        playTapSound()
        @AppStorage("sessionPaused") var sessionPaused: Bool = false
        if sessionPaused {
            sessionPaused = false
        }
        if let uuid = UUID(uuidString: storedLastVocabID),
           items.contains(where: { $0.id == uuid }) {
            router.openCounter(id: uuid)
            return
        }

        if let next = items.first(where: { $0.status != .ready }) ?? items.first {
            router.openCounter(id: next.id)
        } else {
            router.openContent()
        }
    }

    private func playTapSound() {
        SoundManager.playSound(1104)
        SoundManager.playVibration()
    }

    private func setupInitialState() {
        // Reset transient UI states to avoid unwanted sheets on launch
        isImporting = false
        showingShare = false

        if items.contains(where: { $0.status == .queue }) {
            currentOption = .queue
        } else if items.contains(where: { $0.status == .drill }) {
            currentOption = .drill
        } else if items.contains(where: { $0.status == .ready }) {
            currentOption = .ready
        } else {
            currentOption = .all
        }
        selectedStatus = currentOption.status
        filterItems()

        if router.shouldActivateSearch {
            showSearchBox = true
            activateSearchNow = true
            router.shouldActivateSearch = false
        }

        if case .dailyQuiz = router.sheet {
            showDailyQuiz = true
        }

        applyRouterSheetState(router.sheet)
    }

    private func applyRouterSheetState(_ sheet: AppRouter.Sheet?) {
        switch sheet {
        case .none:
            break
        case .settings:
            showSettingsSheet = true
        case .addWord:
            showAddSheet = true
        case .dailyQuiz:
            showDailyQuiz = true
        case .editWord(let id):
            if let item = items.first(where: { $0.id == id }) {
                editingItem = item
            }
        case .counter(let id):
            if let item = items.first(where: { $0.id == id }) {
                counterItem = item
            }
        }
    }

    private func loadItemsIntoState() { // This function now focuses purely on loading into @State items
        vocabStore.reloadFromDisk()
        filterItems()
    }

    /// Auto-open CounterView if a study session is in progress.
    private func autoOpenCounterIfNeeded() {
        if didAutoOpen { return }
        @AppStorage("sessionPaused") var sessionPaused: Bool = false
        var effective = remainingSeconds
        if boostTypeRaw == BoostType.mins.rawValue {
            let elapsed = Int(Date().timeIntervalSince1970 - remainingTimestamp)
            effective = max(0, remainingSeconds - elapsed)
        }
        if !sessionPaused && effective > 0 {
            // Navigate directly without NotificationCenter.
            if let uuid = UUID(uuidString: storedLastVocabID),
               items.contains(where: { $0.id == uuid }) {
                router.openCounter(id: uuid)
            } else if let next = items.first(where: { $0.status != .ready }) ?? items.first {
                router.openCounter(id: next.id)
            }
        }
        didAutoOpen = true
    }

    // MARK: - Duplicate Cleanup Helper
    private func mergeDuplicateEntries() {
        vocabStore.cleanDuplicates()
    }

    private func saveItems() {
        vocabStore.saveNow()
    }

    private func writeItemsToCSV() {
        // Temporarily disabled heavy file-I/O. Replace with new implementation later.
        vocabStore.saveNow()
    }

    private var uniqueCategories: [String] {
        let cats = items.compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Array(Set(cats)).sorted()
    }

    private var categoryTotalCounts: [String: Int] {
        items.reduce(into: [:]) { dict, entry in
            if let cat = entry.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty {
                dict[cat, default: 0] += 1
            }
        }
    }

    private var categoryReadyCounts: [String: Int] {
        items.filter { $0.status == .ready }.reduce(into: [:]) { dict, entry in
            if let cat = entry.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty {
                dict[cat, default: 0] += 1
            }
        }
    }

    private var categoryNotReadyCounts: [String: Int] {
        Dictionary(uniqueKeysWithValues: categoryTotalCounts.map { key, total in
            (key, total - (categoryReadyCounts[key] ?? 0))
        })
    }

    private var readyTotal: Int {
        items.filter { $0.status == .ready }.count
    }

    private var categoryLabelText: String {
        if let cat = selectedCategory {
            let nr = categoryNotReadyCounts[cat] ?? 0
            let total = categoryTotalCounts[cat] ?? 0
            return "\(cat) \(nr)/\(total)"
        } else {
            return "All \(items.count - readyTotal)/\(items.count)"
        }
    }

    private var categoryCounts: [String: Int] {
        items.reduce(into: [:]) { dict, entry in
            if let cat = entry.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty {
                dict[cat, default: 0] += 1
            }
        }
    }

    private func filterItems() {
        // Simple per-session cache for normalized strings to avoid recomputing per keystroke
        struct SearchCache {
            static var map: [UUID: (thai: String, burmese: String?)] = [:]
        }
        // Capture inputs to avoid data races and allow staleness checks
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let capturedOption = currentOption
        let capturedSelectedStatus = selectedStatus
        let capturedSelectedCategory = selectedCategory
        let capturedSortAsc = sortByCountAsc
        let sourceItems = items // copy the value type array reference
        let recentOrder = RecentCountRecorder.shared.recentIDs()
        let recentRank: [UUID: Int] = Dictionary(uniqueKeysWithValues: recentOrder.enumerated().map { ($0.element, $0.offset) })

        DispatchQueue.global(qos: .userInitiated).async {
            let hasQuery = !q.isEmpty
            var localCache = SearchCache.map

            // Filter
            var result = sourceItems.filter { item in
                if !hasQuery && capturedOption != .recent {
                    if let sel = capturedSelectedStatus, item.status != sel { return false }
                }
                if !hasQuery && capturedOption == .recent {
                    // Recent tab should only show the most recently studied items
                    if recentRank[item.id] == nil { return false }
                }
                if let selCat = capturedSelectedCategory {
                    let cat = item.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if cat != selCat { return false }
                }
                if hasQuery {
                    // Use cached normalized strings
                    let norm = localCache[item.id] ?? {
                        let thai = item.thai.trimmingCharacters(in: .whitespacesAndNewlines)
                        let bur = item.burmese?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let tuple = (thai: thai, burmese: bur)
                        localCache[item.id] = tuple
                        return tuple
                    }()
                    if fuzzyMatch(haystack: norm.thai, needle: q) { return true }
                    if let bur = norm.burmese, fuzzyMatch(haystack: bur, needle: q) { return true }
                    return false
                }
                return true
            }

            // Sort
            if capturedOption == .recent && !hasQuery {
                // Newest first, based on RecentCountRecorder ordering
                result.sort {
                    let r0 = recentRank[$0.id] ?? Int.max
                    let r1 = recentRank[$1.id] ?? Int.max
                    return r0 < r1
                }
            } else if capturedOption == .all || capturedOption == .recent {
                let weight: [VocabularyStatus: Int] = [.drill: 0, .queue: 1, .ready: 2]
                result.sort {
                    let w0 = weight[$0.status] ?? 3
                    let w1 = weight[$1.status] ?? 3
                    if w0 == w1 { return $0.count < $1.count }
                    return w0 < w1
                }
            } else {
                result.sort { capturedSortAsc ? $0.count < $1.count : $0.count > $1.count }
            }

            // Publish back on main if inputs still match
            DispatchQueue.main.async {
                let currentQ = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if currentQ == q &&
                    currentOption == capturedOption &&
                    selectedStatus == capturedSelectedStatus &&
                    selectedCategory == capturedSelectedCategory &&
                    sortByCountAsc == capturedSortAsc {
                    filteredItems = result
                    // Update shared cache
                    SearchCache.map = localCache
                }
            }
        }
    }

    private func importCSVManually() {
        // Legacy manual import temporarily disabled
        CSVManager.importFromDocuments()
    }

    // This function seems to be for clearing the list and CSV, ensure it's intended.
    func deleteAllEntries() {
        vocabStore.setItems([])
        // Legacy CSV file clearing disabled
        // filterItems() and saveItems() are handled automatically by onChange(of: items)
    }

    private func resetNewWordFields() {
        newThai = ""
        newBurmese = ""
        newCount = "0"
        newStatus = .queue
    }
}

// MARK: - Add/Edit Word Sheet (Refactored into a separate View)

struct AddEditWordSheet: View {
    @Environment(\.dismiss) var dismiss // For dismissing the sheet
    @EnvironmentObject private var router: AppRouter
    let isAdding: Bool
    @Binding var item: VocabularyEntry // Binding allows direct modification of the original item
    let onSave: (VocabularyEntry) -> Void
    let onCancel: () -> Void
    let existingCategories: [String]

    // Daily study tracking (shared with CounterView logic)
    @AppStorage("studyHistoryJSON") private var studyHistoryJSON: String = ""
    @AppStorage("todayCount") private var todayCount: Int = 0
    @AppStorage("todayDate") private var todayDate: String = ""

    // Internal state for text fields, allows live editing without updating the source binding until save
    @State private var thaiText: String
    @State private var burmeseText: String
    @State private var countText: String
    @State private var statusSelection: VocabularyStatus
    @State private var categoryText: String

    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var isSaving = false

    private static let countFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    private static func formatCount(_ value: Int) -> String {
        countFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func parseCount(_ text: String) -> Int? {
        let digits = text.filter { $0.isNumber }
        return Int(digits)
    }

    private var categorySuggestions: [String] {
        guard isAdding else { return [] }
        let q = categoryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        let base = existingCategories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let filtered = base.filter { $0.lowercased().hasPrefix(q) }
        let unique = Array(Set(filtered))
        return unique.sorted()
    }

    init(isAdding: Bool,
         item: Binding<VocabularyEntry>,
         existingCategories: [String] = [],
         onSave: @escaping (VocabularyEntry) -> Void,
         onCancel: @escaping () -> Void) {
        self.isAdding = isAdding
        self._item = item
        self.onSave = onSave
        self.onCancel = onCancel
        self.existingCategories = existingCategories

        // Initialize internal @State variables from the binding's wrappedValue
        _thaiText = State(initialValue: item.wrappedValue.thai)
        _burmeseText = State(initialValue: item.wrappedValue.burmese ?? "")
        _countText = State(initialValue: Self.formatCount(item.wrappedValue.count))
        _statusSelection = State(initialValue: item.wrappedValue.status)
        _categoryText = State(initialValue: item.wrappedValue.category ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(isAdding ? "New Word" : "Edit Word") {
                    HStack {
                            TextField("Thai", text: $thaiText)
                                .textInputAutocapitalization(.never)
                            Button(action: {
                                if let clipboardText = UIPasteboard.general.string {
                                    thaiText = clipboardText
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    HStack {
                            TextField("Burmese (optional)", text: $burmeseText)
                                .textInputAutocapitalization(.never)
                            Button(action: {
                                if let clipboardText = UIPasteboard.general.string {
                                    burmeseText = clipboardText
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    TextField("Count", text: $countText)
                        .keyboardType(.numberPad)
                        .onChange(of: countText) { _, newValue in
                            let digits = newValue.filter { $0.isNumber }
                            if let number = Int(digits) {
                                let formatted = Self.formatCount(number)
                                if formatted != newValue {
                                    countText = formatted
                                }
                            } else {
                                countText = ""
                            }
                        }
                    if isAdding {
                        Picker("Status", selection: $statusSelection) {
                            ForEach(VocabularyStatus.allCases) { status in
                                Text("\(status.emoji) \(status.rawValue)").tag(status)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Category (optional)", text: $categoryText)
                        if !categorySuggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categorySuggestions, id: \.self) { cat in
                                        Button {
                                            categoryText = cat
                                        } label: {
                                            Text(cat)
                                                .font(.caption)
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundColor(.primary)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    
                }
            }
            .navigationTitle(isAdding ? "Add Vocab" : "Edit Vocab")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAdding ? "Add" : "Save & Back to Count") {
                        saveAction()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showingSaveAlert) {
                Button("OK") { }
            } message: {
                Text(saveAlertMessage)
            }
        }
    }

    private func saveAction() {
        if isSaving { return }
        guard let count = Self.parseCount(countText),
              !thaiText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            saveAlertMessage = "Thai word is required and Count must be a valid number."
            showingSaveAlert = true
            return
        }
        isSaving = true
        print("🧪 AddEditWordSheet.saveAction isAdding=\(isAdding), id=\(item.id), oldCount=\(item.count)")
        let oldCount = item.count // capture before mutation for delta computation
        var updatedItem = $item.wrappedValue // Start with current item data
        updatedItem.thai = thaiText.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedItem.burmese = burmeseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : burmeseText.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedItem.count = count
        if isAdding {
            updatedItem.status = statusSelection
        }
        updatedItem.category = categoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : categoryText.trimmingCharacters(in: .whitespacesAndNewlines)

        // If adding, create a new ID. If editing, preserve existing ID.
        let finalItem = isAdding ? VocabularyEntry(thai: updatedItem.thai, burmese: updatedItem.burmese, count: updatedItem.count, status: updatedItem.status, category: updatedItem.category) : updatedItem
        print("🧪 AddEditWordSheet.finalItem id=\(finalItem.id), count=\(finalItem.count), isAdding=\(isAdding)")

        // Update the binding to the original item directly (for editing)
        // or pass the new item back (for adding)
        if !isAdding {
            item = finalItem // This updates the original item in ContentView's `items` array
            // Count manual edits toward today's hits using delta
            let delta = count - oldCount
            if delta != 0 { updateTodayCount(by: delta) }
        }
        onSave(finalItem)
        if !isAdding {
            let idToOpen = finalItem.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                router.openCounter(id: idToOpen)
            }
        } // Pass the final item to the ContentView's save closure
        dismiss()
    }

    // MARK: - Daily Study Helpers (mirrors CounterView behavior)
    private func dayKey(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func loadStudyHistory() -> [String: Int] {
        if let data = studyHistoryJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            return decoded
        }
        return [:]
    }

    private func saveStudyHistory(_ history: [String: Int]) {
        // Keep last 400 days
        let now = Date()
        let cal = Calendar.current
        let keys: [String] = (0..<400).compactMap { off in
            guard let d = cal.date(byAdding: .day, value: -off, to: now) else { return nil }
            return dayKey(from: d)
        }
        let trimmed = history.filter { keys.contains($0.key) }
        if let data = try? JSONEncoder().encode(trimmed), let s = String(data: data, encoding: .utf8) {
            studyHistoryJSON = s
        }
    }

    private func appendStudyHistory(date: Date, increment: Int) {
        var history = loadStudyHistory()
        let key = dayKey(from: date)
        let current = history[key] ?? 0
        history[key] = max(0, current + increment)
        saveStudyHistory(history)
    }

    private func updateTodayCount(by increment: Int) {
        let iso = ISO8601DateFormatter()
        let now = Date()
        let storedDate = iso.date(from: todayDate) ?? now
        let cal = Calendar.current
        if !cal.isDate(storedDate, inSameDayAs: now) {
            // New day: reset and set first increment
            todayDate = iso.string(from: now)
            todayCount = max(0, increment)
            appendStudyHistory(date: now, increment: todayCount)
        } else {
            todayCount = max(0, todayCount + increment)
            appendStudyHistory(date: now, increment: increment)
        }
    }
}

// MARK: - Mock Bottom Tab Bar
struct BottomTabMock: View {
    /// Action to perform when the center button is tapped
    var centerAction: () -> Void = {}
    /// Action for the floating '+' button (left of center)
    var plusAction: () -> Void = {}
    /// Action for the 'category' button (between play and home)
    var categoryAction: () -> Void = {}
    /// Action for the 'Daily Quiz' button (between play and home, top)
    var dailyQuizAction: () -> Void = {}
    /// Action for the floating 'home' button (right of center)
    var homeAction: () -> Void = {}
    var body: some View {
        ZStack {
            // Removed background bar to keep only floating circles

            // Remove old inline label row to avoid duplicates

            // Center floating button
            Button(action: {
                centerAction()
            }) {
                Circle()
                    .fill(
                        AngularGradient(gradient: Gradient(colors: [.pink, .purple, .blue, .pink]), center: .center)
                    )
                    .frame(width: 121, height: 121)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 4)
                    )
                    .shadow(radius: 4)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 47)) // 20% larger than previous (39pt)
                            .foregroundColor(.white)
                            .shadow(color: Color.white.opacity(0.7), radius: 4)
                    )
            }
            .offset(y: -38) // move up by 10px
            .buttonStyle(PlainButtonStyle())

            // Floating '+' button (smaller than play), positioned to the left
            Button(action: {
                plusAction()
            }) {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.green,
                                Color.mint,
                                Color.cyan,
                                Color.green
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: 78, height: 78)
                    .overlay(
                        // Subtle glossy rim
                        Circle().stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                    )
                    // Neon glow
                    .shadow(color: Color.cyan.opacity(0.5), radius: 8, x: 0, y: 3)
                    .shadow(color: Color.green.opacity(0.35), radius: 12, x: 0, y: 6)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color.white.opacity(0.6), radius: 2)
                    )
            }
            .offset(x: -110, y: -30)
            .buttonStyle(PlainButtonStyle())

            // Floating 'category' button (between play and home)
            Button(action: {
                categoryAction()
            }) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
                    // Glow effect
                    .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 2)
                    .shadow(color: Color.indigo.opacity(0.3), radius: 12, x: 0, y: 6)
                    .overlay(
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: Color.white.opacity(0.5), radius: 1)
                    )
            }
            .offset(x: 77, y: 10)
            .buttonStyle(PlainButtonStyle())

            // NEW: Floating 'Daily Quiz' button (between play and home, top)
            Button(action: {
                dailyQuizAction()
            }) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: Color.blue.opacity(0.45), radius: 10, x: 0, y: 2)
                    .shadow(color: Color.pink.opacity(0.35), radius: 12, x: 0, y: 6)
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color.white.opacity(0.5), radius: 1)
                    )
            }
            .offset(x: 80, y: -80)
            .buttonStyle(PlainButtonStyle())

            // Floating 'home' button (right of center)
            Button(action: {
                homeAction()
            }) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54) // 20% smaller than 68
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 3)
                    )
                    // Glow effect
                    .shadow(color: Color.orange.opacity(0.55), radius: 10, x: 0, y: 2)
                    .shadow(color: Color.yellow.opacity(0.45), radius: 14, x: 0, y: 6)
                    .overlay(
                        Image(systemName: "house")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: Color.white.opacity(0.5), radius: 1)
                    )
            }
            .offset(x: 110, y: -34)
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


// MARK: - Share Sheet Helper
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct StatView: View {
    let title: String
    let value: String

    @State private var animate = false

    var body: some View {
        VStack {
            Text(value)
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.yellow)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 20)
                .animation(.easeOut(duration: 0.6), value: animate)
                .onAppear {
                    animate = true
                }
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.top, -60) // extra tightening if needed
        }
    }
}

// Duplicate preview removed to avoid redeclaration
// // struct IntroView_Previews: PreviewProvider {
//     static var previews: some View {
//         IntroView(totalCount: 150, vocabCount: 100)
//     }
// }

// Ensure ContentView, VocabularyStatus, and VocabularyEntry are defined
// in their respective files or above this code if they are not yet separated.
