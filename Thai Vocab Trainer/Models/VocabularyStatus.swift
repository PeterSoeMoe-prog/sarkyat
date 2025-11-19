import Foundation

public enum VocabularyStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case queue = "Queue"
    case drill = "Drill"
    case ready = "Ready"

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .queue: return "🫠"
        case .drill: return "🔥"
        case .ready: return "💎"
        }
    }
}

