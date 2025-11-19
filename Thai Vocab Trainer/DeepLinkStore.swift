import Foundation

enum DeepLinkStore {
    private static let idKey = "deepLinkTargetVocabID"
    private static let thaiKey = "deepLinkTargetThai"

    static func store(_ id: UUID, thai: String?) {
        let d = UserDefaults.standard
        d.set(id.uuidString, forKey: idKey)
        if let thai { d.set(thai, forKey: thaiKey) } else { d.removeObject(forKey: thaiKey) }
    }

    static func consume() -> (UUID, String?)? {
        let d = UserDefaults.standard
        guard let s = d.string(forKey: idKey), let id = UUID(uuidString: s) else { return nil }
        let thai = d.string(forKey: thaiKey)
        d.removeObject(forKey: idKey)
        d.removeObject(forKey: thaiKey)
        return (id, thai)
    }
}
