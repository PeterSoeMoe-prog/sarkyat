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

    func load() {
        // Load source synchronously (fast), heavy aggregation off-main
        let entries: [VocabularyEntry]
        if let customLoader = Optional<(()->[VocabularyEntry])>(loadCSV) {
            entries = customLoader()
        } else {
            entries = []
        }
        guard !entries.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            var buckets: [String: (completed: Int, total: Int)] = [:]
            buckets.reserveCapacity(128)
            for entry in entries {
                guard let rawCat = entry.category?.trimmingCharacters(in: .whitespacesAndNewlines), !rawCat.isEmpty else { continue }
                var record = buckets[rawCat] ?? (0, 0)
                record.total &+= 1
                if entry.status == .ready { record.completed &+= 1 }
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
