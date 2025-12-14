import Foundation
import SwiftUI

/// ViewModel that loads `vocab.csv` from the app's Documents directory and aggregates stats per category.
@MainActor
final class CategoryViewModel: ObservableObject {
    struct Stat: Identifiable, Equatable {
        let name: String
        var completed: Int
        var total: Int
        var percent: Int { total == 0 ? 0 : Int(Double(completed) / Double(total) * 100) }
        var id: String { name } // stable identity by name
    }

    @Published var stats: [Stat] = []

    private func loadCategoryRows() -> [(category: String, isReady: Bool)] {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent("vocab.csv")
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        let header = lines[0].lowercased()
        let hasIDFirst = header.hasPrefix("id,")

        var rows: [(category: String, isReady: Bool)] = []
        rows.reserveCapacity(lines.count - 1)
        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ",")
            if hasIDFirst {
                guard cols.count >= 6 else { continue }
                let statusRaw = cols[4].trimmingCharacters(in: .whitespacesAndNewlines)
                let categoryRaw = cols[5].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !categoryRaw.isEmpty else { continue }
                let isReady = statusRaw.caseInsensitiveCompare("ready") == .orderedSame
                rows.append((category: categoryRaw, isReady: isReady))
            } else {
                guard cols.count >= 4 else { continue }
                let statusRaw = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let categoryRaw = (cols.count > 4 ? cols[4] : "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !categoryRaw.isEmpty else { continue }
                let isReady = statusRaw.caseInsensitiveCompare("ready") == .orderedSame
                rows.append((category: categoryRaw, isReady: isReady))
            }
        }
        return rows
    }

    func load() {
        let rows = loadCategoryRows()
        guard !rows.isEmpty else {
            self.stats = []
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var buckets: [String: (completed: Int, total: Int)] = [:]
            buckets.reserveCapacity(128)
            for row in rows {
                let rawCat = row.category
                var record = buckets[rawCat] ?? (0, 0)
                record.total &+= 1
                if row.isReady { record.completed &+= 1 }
                buckets[rawCat] = record
            }
            let computed = buckets.map { Stat(name: $0.key, completed: $0.value.completed, total: $0.value.total) }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            DispatchQueue.main.async {
                self.stats = computed
            }
        }
    }
}
