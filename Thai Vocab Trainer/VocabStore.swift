import Foundation
import SwiftUI

@MainActor
final class VocabStore: ObservableObject {
    @Published private(set) var items: [VocabularyEntry] = []

    private var saveDebounce: DispatchWorkItem? = nil

    init() {
        reloadFromDisk()
    }

    func reloadFromDisk() {
        items = CSVManager.loadFromDocuments()
    }

    func setItems(_ newItems: [VocabularyEntry], save: Bool = true) {
        items = newItems
        if save { scheduleSave() }
    }

    func upsert(_ entry: VocabularyEntry) {
        if let idx = items.firstIndex(where: { $0.id == entry.id }) {
            items[idx] = entry
        } else {
            items.insert(entry, at: 0)
        }
        scheduleSave()
    }

    func update(_ entry: VocabularyEntry) {
        if let idx = items.firstIndex(where: { $0.id == entry.id }) {
            items[idx] = entry
            scheduleSave()
        }
    }

    func binding(for id: UUID) -> Binding<VocabularyEntry>? {
        guard items.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: {
                self.items.first(where: { $0.id == id }) ?? VocabularyEntry(id: id, thai: "", burmese: nil, count: 0, status: .queue, category: nil)
            },
            set: { updated in
                self.update(updated)
            }
        )
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        scheduleSave()
    }

    func cleanDuplicates() {
        // Combine entries with same Thai + category (case-insensitive)
        var seen: [String: VocabularyEntry] = [:]
        seen.reserveCapacity(items.count)
        for entry in items {
            let key = (entry.thai.lowercased() + "|" + (entry.category ?? "").lowercased())
            if var existing = seen[key] {
                existing.count = max(existing.count, entry.count)
                existing.status = existing.status == .ready || entry.status == .ready
                ? .ready
                : (existing.status == .drill || entry.status == .drill ? .drill : .queue)
                // Prefer first non-empty Burmese
                if (existing.burmese ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let b = entry.burmese,
                   !b.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existing.burmese = b
                }
                seen[key] = existing
            } else {
                seen[key] = entry
            }
        }
        items = Array(seen.values)
        scheduleSave()
    }

    func scheduleSave() {
        saveDebounce?.cancel()
        let snapshot = items
        let work = DispatchWorkItem {
            CSVManager.exportToDocuments(snapshot)
        }
        saveDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func saveNow() {
        saveDebounce?.cancel()
        CSVManager.exportToDocuments(items)
    }
}
