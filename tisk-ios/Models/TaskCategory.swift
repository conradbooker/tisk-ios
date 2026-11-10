import Foundation

nonisolated struct TaskCategory: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var userId: UUID
    var parentId: UUID?
    var title: String
    var description: String?
    var backgroundColor: String
    var borderColor: String
    var isHidden: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case parentId = "parent_id"
        case title
        case description
        case backgroundColor = "background_color"
        case borderColor = "border_color"
        case isHidden = "is_hidden"
    }
}

nonisolated struct NewCategory: Encodable, Sendable {
    var title: String
    var backgroundColor: String
    var borderColor: String
    var parentId: UUID?
    var isHidden = false
    var userId: UUID

    enum CodingKeys: String, CodingKey {
        case title
        case backgroundColor = "background_color"
        case borderColor = "border_color"
        case parentId = "parent_id"
        case isHidden = "is_hidden"
        case userId = "user_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(backgroundColor, forKey: .backgroundColor)
        try c.encode(borderColor, forKey: .borderColor)
        try c.encode(parentId, forKey: .parentId)
        try c.encode(isHidden, forKey: .isHidden)
        try c.encode(userId, forKey: .userId)
    }
}

nonisolated struct NewTaskType: Encodable, Sendable {
    var title: String
    var parentId: UUID?
    var isHidden = false
    var userId: UUID

    enum CodingKeys: String, CodingKey {
        case title
        case parentId = "parent_id"
        case isHidden = "is_hidden"
        case userId = "user_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(parentId, forKey: .parentId)
        try c.encode(isHidden, forKey: .isHidden)
        try c.encode(userId, forKey: .userId)
    }
}
