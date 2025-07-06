import SwiftUI
import AudioToolbox // Still needed for AudioServicesPlaySystemSound

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

    init(id: UUID = UUID(), thai: String, burmese: String?, count: Int, status: VocabularyStatus) {
        self.id = id
        self.thai = thai
        self.burmese = burmese
        self.count = count
        self.status = status
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
                    .background(Color.gray.opacity(0.2))
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
            results.append(VocabularyEntry(thai: thai, burmese: burmese, count: count, status: status))
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
    @AppStorage("appTheme") private var appTheme: AppTheme = .dark

    // State for New/Edit Word Sheet (can be extracted to a separate ViewModel if more complex logic is needed)
    @State private var newThai = ""
    @State private var newBurmese = ""
    @State private var newCount = "1000"
    @State private var newStatus: VocabularyStatus = .queue
    @State private var showingAlert = false
    @State private var alertMessage = ""


    enum Option: CaseIterable, Identifiable {
        case all, queue, drill, ready

        var id: Self { self }
        
        var label: String {
            switch self {
            case .all: return "🚀 All"
            case .queue: return "😫 Queue"
            case .drill: return "🔥 Drill"
            case .ready: return "💎 Ready"
            }
        }

        var status: VocabularyStatus? {
            switch self {
            case .all: return nil
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
                .toolbar { toolbarView }
                .navigationDestination(isPresented: $goHome) {
                   
                    
                    IntroView(totalCount: totalCount, vocabCount: items.count) // Pass items.count here
                    
                    
                }
                .sheet(isPresented: $showAddSheet) {
                    AddEditWordSheet(
                        isAdding: true,
                        item: .constant(VocabularyEntry(thai: newThai, burmese: newBurmese.isEmpty ? nil : newBurmese, count: Int(newCount) ?? 1000, status: newStatus)), // Pass initial values
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
        }
        .preferredColorScheme(appTheme.colorScheme)
    }

    // MARK: - Views (keeping as subviews)

    private var mainContent: some View {
        VStack(spacing: 0) {
            searchField
            filterButtons
            VocabularyListView(
                items: $items,
                filteredItems: $filteredItems,
                showBurmeseForID: $showBurmeseForID,
                selectedStatus: $selectedStatus,
                playTapSound: playTapSound,
                saveItems: saveItems,
                showThaiPrimary: showThaiPrimary
            )
            .listStyle(PlainListStyle())
        }
    }

    private var searchField: some View {
        TextField("Search Thai or Burmese...", text: $searchText)
            .textFieldStyle(.roundedBorder) // Modern SwiftUI style
            .padding([.horizontal, .vertical], 8)
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
                .background(Color.orange.opacity(0.1))
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

            Button {
                sortByCountAsc.toggle()
                filterItems()
                playTapSound()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: sortByCountAsc ? "arrow.up.arrow.down" : "arrow.down.arrow.up")
                    Text(sortByCountAsc ? "Count ↑" : "Count ↓")
                }
                .padding(6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private var toolbarView: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: cycleTheme) { // Directly assign method
                    Image(systemName: appTheme.iconName)
                        .imageScale(.large)
                }
            }

            ToolbarItem(placement: .principal) {
                Button {
                    goHome = true
                    playTapSound()
                } label: {
                    Image(systemName: "house")
                        .imageScale(.medium)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { showAddSheet = true; playTapSound() }) {
                        Image(systemName: "plus")
                    }

                    Button(action: importCSVManually) {
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                }
            }
        }
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

    private func cycleTheme() {
        if let currentIndex = AppTheme.allCases.firstIndex(of: appTheme) {
            let nextIndex = (currentIndex + 1) % AppTheme.allCases.count
            appTheme = AppTheme.allCases[nextIndex]
        }
    }

    private func playTapSound() {
        AudioServicesPlaySystemSound(1104) // System sound for tap/click
    }

    private func setupInitialState() {
        loadItemsIntoState() // Renamed for clarity
        selectedStatus = currentOption.status
        filterItems()
    }

    private func loadItemsIntoState() { // This function now focuses purely on loading into @State items
        if let savedData = UserDefaults.standard.data(forKey: "vocab_items"),
           let decoded = try? JSONDecoder().decode([VocabularyEntry].self, from: savedData),
           !decoded.isEmpty {
            self.items = decoded
            print("Loaded items from UserDefaults. Count: \(self.items.count)")
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

    private func saveItems() {
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

        var csvString = "thai,burmese,count,status\n" // Start with the header

        for item in items {
            let thai = item.thai.replacingOccurrences(of: ",", with: "")
            let burmese = (item.burmese ?? "").replacingOccurrences(of: ",", with: "")
            let count = String(item.count)
            let status = item.status.rawValue

            csvString += "\(thai),\(burmese),\(count),\(status)\n"
        }

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Successfully wrote items to vocab.csv in Documents directory.")
        } catch {
            print("❌ Error writing items to vocab.csv: \(error.localizedDescription)")
            alertMessage = "Error writing vocabulary to CSV: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func filterItems() {
        filteredItems = items.filter { item in
            (selectedStatus == nil || item.status == selectedStatus) &&
            (searchText.isEmpty ||
             item.thai.localizedCaseInsensitiveContains(searchText) ||
             (item.burmese?.localizedCaseInsensitiveContains(searchText) ?? false))
        }

        filteredItems.sort {
            sortByCountAsc ? $0.count < $1.count : $0.count > $1.count
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
        newCount = "1000"
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
                    Button(isAdding ? "Add" : "Save") {
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

        // If adding, create a new ID. If editing, preserve existing ID.
        let finalItem = isAdding ? VocabularyEntry(thai: updatedItem.thai, burmese: updatedItem.burmese, count: updatedItem.count, status: updatedItem.status) : updatedItem

        // Update the binding to the original item directly (for editing)
        // or pass the new item back (for adding)
        if !isAdding {
            item = finalItem // This updates the original item in ContentView's `items` array
        }
        onSave(finalItem) // Pass the final item to the ContentView's save closure
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
        }
    }
}

struct IntroView_Previews: PreviewProvider {
    static var previews: some View {
        IntroView(totalCount: 150, vocabCount: 100)
    }
}

// Ensure ContentView, VocabularyStatus, and VocabularyEntry are defined
// in their respective files or above this code if they are not yet separated.
