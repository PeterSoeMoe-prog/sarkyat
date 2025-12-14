import Foundation
import SwiftUI

/// Temporary stub to disable old CSV import/export code without breaking build.
/// All former CSV-related functions should delegate to these no-op helpers.
/// Later we will replace the bodies with a clean implementation.
enum CSVManager {
    static func loadFromDocuments() -> [VocabularyEntry] {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent("vocab.csv")

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        // Supports both legacy format:
        // thai,burmese,count,status,category
        // and new format:
        // id,thai,burmese,count,status,category
        let header = lines[0].lowercased()
        let hasIDFirst = header.hasPrefix("id,")

        var entries: [VocabularyEntry] = []
        entries.reserveCapacity(lines.count - 1)
        for line in lines.dropFirst() {
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

    /// Replace previous `loadCSV()` or manual import.
    static func importFromDocuments() {
        // no-op for now
    }

    /// Write the supplied entries to `Documents/vocab.csv` so the file is always
    /// in sync with the in-memory vocabulary list. If the write fails we simply
    /// log the error – the app will continue to function using UserDefaults.
    static func exportToDocuments(_ items: [VocabularyEntry]) {
        let header = "id,thai,burmese,count,status,category\n"
        let csvLines = items.map { item -> String in
            // Ensure we do not break the CSV structure with stray commas or line-breaks.
            let sanitize: (String) -> String = { $0.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ") }
            let id = item.id.uuidString
            let thai = sanitize(item.thai)
            let burmese = sanitize(item.burmese ?? "")
            let category = sanitize(item.category ?? "")
            return "\(id),\(thai),\(burmese),\(item.count),\(item.status.rawValue.lowercased()),\(category)"
        }
        let csvString = header + csvLines.joined(separator: "\n")

        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent("vocab.csv")
        do {
            // Write atomically via a temporary file, then replace.
            let tmpURL = docsURL.appendingPathComponent("vocab.csv.tmp")
            try csvString.write(to: tmpURL, atomically: true, encoding: .utf8)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            }
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
        let header = "id,thai,burmese,count,status,category\n"
        let sanitize: (String) -> String = { $0.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ") }
        let csvLines = items.map { item -> String in
            let id = item.id.uuidString
            let thai = sanitize(item.thai)
            let burmese = sanitize(item.burmese ?? "")
            let category = sanitize(item.category ?? "")
            return "\(id),\(thai),\(burmese),\(item.count),\(item.status.rawValue.lowercased()),\(category)"
        }
        let csvString = header + csvLines.joined(separator: "\n")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("vocab.csv")
        try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
}
