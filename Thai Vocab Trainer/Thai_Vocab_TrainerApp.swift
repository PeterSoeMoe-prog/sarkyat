import SwiftUI

@main
struct Thai_Vocab_TrainerApp: App {
    @State private var items: [VocabularyEntry] = []

    init() {
        copyCSVToDocumentsIfNeeded()
        _items = State(initialValue: loadSavedOrCSV())
    }

    var body: some Scene {
        WindowGroup {
            IntroView(
                totalCount: totalCount(),
                vocabCount: items.count
            )
        }
    }

    private func loadSavedOrCSV() -> [VocabularyEntry] {
        if let savedData = UserDefaults.standard.data(forKey: "vocab_items"),
           let decoded = try? JSONDecoder().decode([VocabularyEntry].self, from: savedData) {
            return decoded
        } else {
            return loadCSV(from: "vocab")
        }
    }

    private func totalCount() -> Int {
        items.reduce(0) { $0 + $1.count }
    }

    private func daysCount() -> Int {
        let calendar = Calendar.current
        let startDateComponents = DateComponents(year: 2023, month: 6, day: 19)
        guard let startDate = calendar.date(from: startDateComponents) else { return 0 }
        let today = Date()
        let daysPassed = calendar.dateComponents([.day], from: startDate, to: today).day ?? 0
        return daysPassed + 1
    }

    private func loadCSV(from filename: String) -> [VocabularyEntry] {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent("\(filename).csv")

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            print("Failed to read CSV from Documents folder")
            return []
        }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        var entries: [VocabularyEntry] = []

        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // skip header
            let cols = line.components(separatedBy: ",")
            if cols.count >= 4 {
                let status = VocabularyStatus(rawValue: cols[3].capitalized) ?? .queue
                let count = Int(cols[2]) ?? 0
                let burmese = cols[1].isEmpty ? nil : cols[1]
                entries.append(VocabularyEntry(thai: cols[0], burmese: burmese, count: count, status: status))
            }
        }
        return entries
    }

    private func copyCSVToDocumentsIfNeeded() {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docsURL.appendingPathComponent("vocab.csv")

        if !fileManager.fileExists(atPath: destURL.path) {
            if let bundleURL = Bundle.main.url(forResource: "vocab", withExtension: "csv") {
                try? fileManager.copyItem(at: bundleURL, to: destURL)
            }
        }
    }

    func saveItemsToCSV(_ items: [VocabularyEntry]) {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent("vocab.csv")

        let header = "thai,burmese,count,status\n"
        let csvLines = items.map { item -> String in
            let burmeseText = item.burmese?.replacingOccurrences(of: ",", with: " ") ?? ""
            return "\(item.thai),\(burmeseText),\(item.count),\(item.status.rawValue)"
        }

        let csvString = header + csvLines.joined(separator: "\n")

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("CSV saved successfully.")
        } catch {
            print("Failed to save CSV: \(error)")
        }
    }
}
