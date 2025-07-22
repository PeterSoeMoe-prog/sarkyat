import SwiftUI
import AudioToolbox // Still needed for AudioServicesPlaySystemSound
import UIKit

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
    static let editVocabularyEntry = Notification.Name("editVocabularyEntry")
}
*/

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
                    .font(.headline)
                    .foregroundColor(item.status == .ready ? .green : .primary)
                if showBurmeseForID == item.id {
                    Text(showThaiPrimary ? (item.burmese ?? "N/A") : item.thai)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let category = item.category, !category.isEmpty {
                    Text(category)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            if let categoryInline = item.category, !categoryInline.isEmpty {
                Text(categoryInline)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(item.count)")
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

// Global func loadCSV (this remains outside ContentView, as it was in your original setup)
// Refined loadCSV for better clarity and explicit file paths
func loadCSV() -> [VocabularyEntry] {
    let fileManager = FileManager.default
    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let documentsCSVURL = documentsURL.appendingPathComponent("vocab.csv")

    // Attempt to load from Documents Directory
    do {
        let content = try String(contentsOf: documentsCSVURL, encoding: .utf8)
        print("CSV Raw Content from Documents:\n\(content)")  // Add this here

        let entries = parseCSV(content: content)
        print("✅ Successfully loaded CSV from documents directory: \(documentsCSVURL.lastPathComponent). Parsed \(entries.count) items.")
        return entries
    } catch {
        print("❌ Failed to read CSV from documents directory: \(error.localizedDescription). Falling back to app bundle.")
    }

    // Fallback: Attempt to load from App Bundle
    if let bundlePath = Bundle.main.path(forResource: "vocab", ofType: "csv") {
        do {
            let bundleContent = try String(contentsOfFile: bundlePath, encoding: .utf8)
            let entries = parseCSV(content: bundleContent)
            print("✅ Successfully loaded CSV from app bundle. Parsed \(entries.count) items.")
            return entries
        } catch {
            print("❌ Failed to read CSV from bundle: \(error.localizedDescription)")
        }
    }

    // If both fail
    return []
}

// Helper to parse CSV content, extracted for reusability
private func parseCSV(content: String) -> [VocabularyEntry] {
    var results: [VocabularyEntry] = []
    let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

    for (index, line) in lines.enumerated() {
        if index == 0 { continue } // Skip header
        print("Parsing line \(index): '\(line)'")
        let columns = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        print("Columns count: \(columns.count), columns: \(columns)")
        if columns.count >= 4 {
            let thai = columns[0]
            let burmese = columns[1].isEmpty ? nil : columns[1]
            let count = Int(columns[2]) ?? 0
            let statusRaw = columns[3].lowercased()
            print("Status raw value: \(statusRaw)")
            let status = VocabularyStatus(rawValue: statusRaw.capitalized) ?? .queue
            let category = columns.count > 4 ? (columns[4].isEmpty ? nil : columns[4]) : nil
            results.append(VocabularyEntry(thai: thai, burmese: burmese, count: count, status: status, category: category))
        } else {
            print("CSV Parse Warning: Skipping malformed line \(index + 1): '\(line)' (not enough columns)")
        }
    }
    print("Parsed total entries: \(results.count)")

    return results
}


struct ContentView: View {

    // MARK: - State Variables
    @State private var items: [VocabularyEntry] = []
    @State private var filteredItems: [VocabularyEntry] = []
    @State private var showBurmeseForID: UUID? = nil
    @State private var selectedStatus: VocabularyStatus? = nil
    @State private var searchText: String = ""
    @State private var showAddSheet = false
    @State private var isEditing = false
    @State private var editingItem: VocabularyEntry? = nil
    @State private var showThaiPrimary = true
    @State private var sortByCountAsc = true
    @State private var goHome = false

    @State private var currentOption: Option = .queue
    @EnvironmentObject var theme: ThemeManager
    @AppStorage("remainingSeconds") private var remainingSeconds: Int = 0
    @AppStorage("remainingTimestamp") private var remainingTimestamp: Double = 0
    @AppStorage("boostType") private var boostTypeRaw: String = BoostType.mins.rawValue
    @State private var didAutoOpen: Bool = false

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
            items.reduce(0) { $0 + $1.count } // This sums the 'count' of all items
        }

    var body: some View {
        NavigationStack {
            
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                
                .navigationDestination(isPresented: $goHome) {
                   
                    
                    IntroView(totalCount: totalCount,
                              vocabCount: items.count,
                              queueCount: items.filter { $0.status == .queue }.count,
                              drillCount: items.filter { $0.status == .drill }.count,
                              readyCount: items.filter { $0.status == .ready }.count) // Pass items.count here
                    
                    
                }
                .onReceive(NotificationCenter.default.publisher(for: .addWord)) { _ in
                    showAddSheet = true
                    playTapSound()
                }
                .toolbar {
                
            }
            .onReceive(NotificationCenter.default.publisher(for: .homeAction)) { _ in
                    @AppStorage("sessionPaused") var sessionPaused: Bool = false
                    sessionPaused = true // prevent auto-resume on IntroView
                    goHome = true
                    playTapSound()
                }
                .sheet(isPresented: $showAddSheet) {
                    AddEditWordSheet(
                        isAdding: true,
                        item: .constant(VocabularyEntry(thai: newThai, burmese: newBurmese.isEmpty ? nil : newBurmese, count: Int(newCount) ?? 0, status: newStatus)), // Pass initial values
                         onSave: { newItem in
                            items.insert(newItem, at: 0)
                            resetNewWordFields()
                            showAddSheet = false
                            playTapSound()
                        },
                        onCancel: {
                            resetNewWordFields()
                            showAddSheet = false
                        }
                    )
                }
                .sheet(isPresented: $isEditing) {
                    if let item = editingItem,
                       let idx = items.firstIndex(where: { $0.id == item.id }) {
                        AddEditWordSheet(
                            isAdding: false,
                            item: $items[idx], // Pass a binding to the actual item in the array
                            onSave: { _ in
                                isEditing = false
                                playTapSound()
                            },
                            onCancel: {
                                // If cancelled during edit, revert changes if necessary or just dismiss
                                isEditing = false
                            }
                        )
                    } else {
                        Text("Error loading item for editing.")
                            .onAppear { isEditing = false }
                    }
                }
                .onAppear(perform: setupInitialState)
                
                .onChange(of: items) {
                    filterItems()
                    saveItems()
                    writeItemsToCSV()
                }
                .onChange(of: searchText) {
                    filterItems()
                }
                .onReceive(NotificationCenter.default.publisher(for: .editVocabularyEntry)) { notification in
                    if let id = notification.object as? UUID,
                       let item = items.first(where: { $0.id == id }) {
                        editingItem = item
                        isEditing = true
                    }
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
                                if let content = String(data: data, encoding: .utf8) {
                                    let importedItems = parseCSV(content: content)
                                    if !importedItems.isEmpty {
                                        items = importedItems
                                        saveItems()
                                        alertMessage = "Successfully imported \(importedItems.count) items"
                                        showingAlert = true
                                    } else {
                                        alertMessage = "No valid items found in the CSV file"
                                        showingAlert = true
                                    }
                                }
                            } catch {
                                alertMessage = "Error reading file: \(error.localizedDescription)"
                                showingAlert = true
                            }
                            url.stopAccessingSecurityScopedResource()
                        }
                    case .failure(let error):
                        alertMessage = "Error selecting file: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
        }
        
    }

    // MARK: - Views (keeping as subviews)

    private var mainContent: some View {
        VStack(spacing: 0) {
            collapsibleSearchBar
            filterButtons
            VocabularyListView(
                items: $items,
                filteredItems: $filteredItems,
                showBurmeseForID: $showBurmeseForID,
                selectedStatus: $selectedStatus,
                playTapSound: playTapSound,
                saveItems: saveItems,
                showThaiPrimary: showThaiPrimary,
                plusAction: {
                    showAddSheet = true
                    playTapSound()
                },
                homeAction: {
                    @AppStorage("sessionPaused") var sessionPaused: Bool = false
                    sessionPaused = true // prevent auto-resume on IntroView
                    goHome = true
                    playTapSound()
                },
                resumeAction: {
                    resumeSession()
                    playTapSound()
                }
            )
            .listStyle(PlainListStyle())
        }
    }

    private var collapsibleSearchBar: some View {
        CollapsibleSearchBox(searchText: $searchText)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
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

            Button {
                cycleOption()
                selectedStatus = currentOption.status
                filterItems()
                playTapSound()
            } label: {
                Text(currentOption.label)
                    .padding(6)
            }


            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Helper Methods

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
        NotificationCenter.default.post(name: .nextVocabulary, object: nil)
    }

    private func playTapSound() {
        SoundManager.playSound(1104)
        SoundManager.playVibration()
    }

    private func setupInitialState() {
        loadItemsIntoState() // Renamed for clarity
        // Reset transient UI states to avoid unwanted sheets on launch
        isImporting = false
        showingShare = false
        selectedStatus = currentOption.status
        filterItems()
        
        // Set up notification observers
        NotificationCenter.default.addObserver(forName: Notification.Name("showImportPicker"), object: nil, queue: .main) { _ in
            isImporting = true
            // Ensure share sheet doesn't appear after import
            showingShare = false
            shareURL = nil
            playTapSound()
        }
        // Observer for Export CSV action triggered from CollapsibleSearchBox
        NotificationCenter.default.addObserver(forName: Notification.Name("exportCSV"), object: nil, queue: .main) { _ in
            writeItemsToCSV()
            alertMessage = "✅ Exported vocabulary to 'vocab.csv' in your Documents directory."
            showingAlert = true
            playTapSound()
        }
        // Observer for Clean action triggered from CollapsibleSearchBox
        NotificationCenter.default.addObserver(forName: Notification.Name("cleanDuplicates"), object: nil, queue: .main) { _ in
            mergeDuplicateEntries()
            alertMessage = "✅ Cleaned duplicate entries."
            showingAlert = true
            playTapSound()
        }
    }

    private func loadItemsIntoState() { // This function now focuses purely on loading into @State items
        if let savedData = UserDefaults.standard.data(forKey: "vocab_items"),
           let decoded = try? JSONDecoder().decode([VocabularyEntry].self, from: savedData),
           !decoded.isEmpty {
            self.items = decoded
            print("Loaded items from UserDefaults. Count: \(self.items.count)")
            // Run a one-off clean-up to remove any historic duplicates
            saveItems()
            return
        }

        // If no saved data, attempt to load from CSV (documents or bundle)
        let loadedItems = loadCSV() // Calls the global, improved loadCSV
        if !loadedItems.isEmpty {
            self.items = loadedItems
            saveItems() // Save loaded CSV to UserDefaults for persistence
            print("Loaded initial items from CSV (Documents/Bundle).")
        } else {
            print("No initial items found in UserDefaults or CSV.")
        }
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
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .nextVocabulary, object: nil)
            }
        }
        didAutoOpen = true
    }

    // MARK: - Duplicate Cleanup Helper
    private func mergeDuplicateEntries() {
        // Combine entries with same Thai + category (case-insensitive)
        var seen: [String: VocabularyEntry] = [:]
        for entry in items {
            let key = (entry.thai.lowercased() + "|" + (entry.category ?? "").lowercased())
            if var existing = seen[key] {
                // keep higher count and latest status
                existing.count = max(existing.count, entry.count)
                existing.status = existing.status == .ready || entry.status == .ready ? .ready : (existing.status == .drill || entry.status == .drill ? .drill : .queue)
                seen[key] = existing
            } else {
                seen[key] = entry
            }
        }
        items = Array(seen.values).sorted { $0.thai < $1.thai }
        saveItems()        // persist cleaned list
        writeItemsToCSV()  // update CSV file too
    }

    private func saveItems() {
        // Remove any accidental duplicate IDs while preserving first occurrence order
        var seen = Set<UUID>()
        items = items.filter { entry in
            if seen.contains(entry.id) {
                return false
            } else {
                seen.insert(entry.id)
                return true
            }
        }
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "vocab_items")
        } else {
            print("❌ Failed to encode items for saving.")
        }
    }

    private func writeItemsToCSV() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("vocab.csv")

        var csvString = "thai,burmese,count,status,category\n" // Start with the header

        for item in items {
            let thai = item.thai.replacingOccurrences(of: ",", with: "")
            let burmese = (item.burmese ?? "").replacingOccurrences(of: ",", with: "")
            let count = String(item.count)
            let status = item.status.rawValue

            let category = item.category?.replacingOccurrences(of: ",", with: "") ?? ""
            csvString += "\(thai),\(burmese),\(count),\(status),\(category)\n"
        }

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Successfully wrote items to vocab.csv in Documents directory.")
            // Prepare share sheet
            shareURL = fileURL
            showingShare = true
        } catch {
            print("❌ Error writing items to vocab.csv: \(error.localizedDescription)")
            alertMessage = "Error writing vocabulary to CSV: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func filterItems() {
        // Apply filtering differently for .recent
        filteredItems = items.filter { item in
            let statusMatch = (currentOption == .recent) || (selectedStatus == nil || item.status == selectedStatus)
            let searchMatch = searchText.isEmpty ||
                item.thai.localizedCaseInsensitiveContains(searchText) ||
                (item.burmese?.localizedCaseInsensitiveContains(searchText) ?? false)
            return statusMatch && searchMatch
        }

        // Preserve original CSV order for .all and .recent; sort by count only for specific status filters
        if currentOption != .all && currentOption != .recent {
            filteredItems.sort {
                sortByCountAsc ? $0.count < $1.count : $0.count > $1.count
            }
        }
    }

    private func importCSVManually() {
        let loadedItems = loadCSV()
        if !loadedItems.isEmpty {
            items = loadedItems
            // saveItems() and filterItems() are called automatically by onChange(of: items)
            playTapSound()
            print("✅ Manually imported data from vocab.csv.")
        } else {
            print("❌ No items loaded from CSV during manual import. Check CSV file for errors.")
            alertMessage = "No items loaded from CSV. Please check the 'vocab.csv' file in the app's documents directory for errors or ensure it exists."
            showingAlert = true
        }
    }

    // This function seems to be for clearing the list and CSV, ensure it's intended.
    func deleteAllEntries() {
        items.removeAll()
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let csvURL = docURL.appendingPathComponent("vocab.csv")
        let header = "thai,burmese,count,status\n"
        do {
            try header.write(to: csvURL, atomically: true, encoding: .utf8)
            print("✅ vocab.csv cleared in Documents directory.")
        } catch {
            print("❌ Error clearing vocab.csv: \(error.localizedDescription)")
            alertMessage = "Error clearing vocab.csv: \(error.localizedDescription)"
            showingAlert = true
        }
        // filterItems() and saveItems() are called automatically by onChange(of: items)
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
    let isAdding: Bool
    @Binding var item: VocabularyEntry // Binding allows direct modification of the original item
    let onSave: (VocabularyEntry) -> Void
    let onCancel: () -> Void

    // Internal state for text fields, allows live editing without updating the source binding until save
    @State private var thaiText: String
    @State private var burmeseText: String
    @State private var countText: String
    @State private var statusSelection: VocabularyStatus
    @State private var categoryText: String

    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""

    init(isAdding: Bool, item: Binding<VocabularyEntry>, onSave: @escaping (VocabularyEntry) -> Void, onCancel: @escaping () -> Void) {
        self.isAdding = isAdding
        self._item = item
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize internal @State variables from the binding's wrappedValue
        _thaiText = State(initialValue: item.wrappedValue.thai)
        _burmeseText = State(initialValue: item.wrappedValue.burmese ?? "")
        _countText = State(initialValue: String(item.wrappedValue.count))
        _statusSelection = State(initialValue: item.wrappedValue.status)
        _categoryText = State(initialValue: item.wrappedValue.category ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(isAdding ? "New Word" : "Edit Word") {
                    TextField("Thai", text: $thaiText)
                    TextField("Burmese (optional)", text: $burmeseText)
                    TextField("Count", text: $countText)
                        .keyboardType(.numberPad)
                    Picker("Status", selection: $statusSelection) {
                        ForEach(VocabularyStatus.allCases) { status in
                            Text("\(status.emoji) \(status.rawValue)").tag(status)
                        }
                    }
                    TextField("Category (optional)", text: $categoryText)
                    
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
        guard let count = Int(countText.trimmingCharacters(in: .whitespacesAndNewlines)),
              !thaiText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            saveAlertMessage = "Thai word is required and Count must be a valid number."
            showingSaveAlert = true
            return
        }

        var updatedItem = $item.wrappedValue // Start with current item data
        updatedItem.thai = thaiText.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedItem.burmese = burmeseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : burmeseText.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedItem.count = count
        updatedItem.status = statusSelection
        updatedItem.category = categoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : categoryText.trimmingCharacters(in: .whitespacesAndNewlines)

        // If adding, create a new ID. If editing, preserve existing ID.
        let finalItem = isAdding ? VocabularyEntry(thai: updatedItem.thai, burmese: updatedItem.burmese, count: updatedItem.count, status: updatedItem.status, category: updatedItem.category) : updatedItem

        // Update the binding to the original item directly (for editing)
        // or pass the new item back (for adding)
        if !isAdding {
            item = finalItem // This updates the original item in ContentView's `items` array
        }
        onSave(finalItem)
        if !isAdding {
            NotificationCenter.default.post(name: .openCounter, object: finalItem.id)
        } // Pass the final item to the ContentView's save closure
        dismiss()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
import SwiftUI
import AudioToolbox // For tap sound


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
