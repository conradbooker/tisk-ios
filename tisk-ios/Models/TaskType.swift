import Foundation

nonisolated struct TaskType: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var userId: UUID
    var parentId: UUID?
    var createdAt: Date
    var title: String
    var description: String?
    var isHidden: Bool
    var categoryId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case parentId = "parent_id"
        case createdAt = "created_at"
        case title
        case description
        case isHidden = "is_hidden"
        case categoryId = "category_id"
    }
}
