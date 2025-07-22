import Foundation

struct VocabularyEntry: Identifiable, Equatable, Codable {
    var id: UUID
    var thai: String
    var burmese: String?
    var count: Int
    var status: VocabularyStatus
    var category: String?

    init(id: UUID = UUID(), thai: String, burmese: String?, count: Int, status: VocabularyStatus, category: String? = nil) {
        self.id = id
        self.thai = thai
        self.burmese = burmese
        self.count = count
        self.status = status
        self.category = category
    }
}
