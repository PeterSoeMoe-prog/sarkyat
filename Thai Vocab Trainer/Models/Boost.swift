import Foundation

enum BoostType: String, CaseIterable, Codable {
    case mins, counts, vocabs
}

struct BoostTarget: Codable {
    var type: BoostType
    var value: Int
}
