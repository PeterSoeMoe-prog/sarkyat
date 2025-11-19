import Foundation
import SwiftUI

/// Temporary stub to disable old CSV import/export code without breaking build.
/// All former CSV-related functions should delegate to these no-op helpers.
/// Later we will replace the bodies with a clean implementation.
enum CSVManager {
    /// Replace previous `loadCSV()` or manual import.
    static func importFromDocuments() {
        // no-op for now
    }

    /// Write the supplied entries to `Documents/vocab.csv` so the file is always
    /// in sync with the in-memory vocabulary list. If the write fails we simply
    /// log the error – the app will continue to function using UserDefaults.
    static func exportToDocuments(_ items: [VocabularyEntry]) {
        let header = "thai,burmese,count,status,category\n"
        let csvLines = items.map { item -> String in
            // Ensure we do not break the CSV structure with stray commas or line-breaks.
            let sanitize: (String) -> String = { $0.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ") }
            let thai = sanitize(item.thai)
            let burmese = sanitize(item.burmese ?? "")
            let category = sanitize(item.category ?? "")
            return "\(thai),\(burmese),\(item.count),\(item.status.rawValue.lowercased()),\(category)"
        }
        let csvString = header + csvLines.joined(separator: "\n")

        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent("vocab.csv")
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Failed to write vocab.csv: \(error.localizedDescription)")
        }
    }

    /// Replace previous duplicate-clean logic in CSV file (can still call in-memory cleanup elsewhere).
    static func cleanDuplicates(on items: inout [VocabularyEntry]) {
        // no-op for now
    }

    /// Build a temporary CSV file containing the supplied entries and return its URL.
    /// The file is placed in the system temporary directory and overwritten each time.
    ///
    /// - Throws: Propagates any file-system write errors.
    static func makeTempCSV(from items: [VocabularyEntry]) throws -> URL {
        let header = "thai,burmese,count,status,category\n"
        let csvLines = items.map { item -> String in
            let burmeseText = item.burmese?.replacingOccurrences(of: ",", with: " ") ?? ""
            let categoryText = item.category?.replacingOccurrences(of: ",", with: " ") ?? ""
            return "\(item.thai),\(burmeseText),\(item.count),\(item.status.rawValue.lowercased()),\(categoryText)"
        }
        let csvString = header + csvLines.joined(separator: "\n")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("vocab.csv")
        try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}
