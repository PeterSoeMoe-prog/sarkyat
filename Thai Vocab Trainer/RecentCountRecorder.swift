import Foundation

/// Singleton helper to track the last N vocabulary IDs whose `count` was modified.
/// Uses `UserDefaults` persistence so the list survives app restarts.
@MainActor
final class RecentCountRecorder {
    static let shared = RecentCountRecorder()
    private init() {}

    private let key = "recentCountIDs"
    private let maxCount = 10

    private var ids: [UUID] {
        get {
            if let data = UserDefaults.standard.data(forKey: key),
               let decoded = try? JSONDecoder().decode([UUID].self, from: data) {
                return decoded
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    /// Record an ID as recently updated.
    func record(id: UUID) {
        var list = ids.filter { $0 != id } // remove duplicates
        list.insert(id, at: 0)             // add newest to front
        if list.count > maxCount { list.removeLast(list.count - maxCount) }
        ids = list
    }

    /// Fetch the recent IDs (most recent first).
    func recentIDs() -> [UUID] {
        ids
    }
}
