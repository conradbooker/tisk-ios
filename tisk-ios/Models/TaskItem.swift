import Foundation

nonisolated struct TaskItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var categoryId: UUID?
    var taskTypeId: UUID?
    var parentTaskId: UUID?
    var createdAt: Date
    var dueAt: Date?
    var completedAt: Date?
    var title: String
    var description: String?
    var status: String
    var priority: String?
    var userId: UUID
    var source: String
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case taskTypeId = "task_type_id"
        case parentTaskId = "parent_task_id"
        case createdAt = "created_at"
        case dueAt = "due_at"
        case completedAt = "completed_at"
        case title
        case description
        case status
        case priority
        case userId = "user_id"
        case source
        case updatedAt = "updated_at"
    }

    var taskStatus: TaskStatus {
        TaskStatus(databaseValue: status) ?? .todo
    }
}

/// Payload for inserting a task. `category_id` defaults to a random uuid in the
/// database, so nil values are encoded explicitly as null.
nonisolated struct NewTask: Encodable, Sendable {
    var title: String
    var description: String?
    var categoryId: UUID?
    var taskTypeId: UUID?
    var parentTaskId: UUID?
    var dueAt: Date?
    var priority: String?
    var status: String
    var userId: UUID
    var source: String

    enum CodingKeys: String, CodingKey {
        case title, description, status, priority, source
        case parentTaskId = "parent_task_id"
        case categoryId = "category_id"
        case taskTypeId = "task_type_id"
        case dueAt = "due_at"
        case userId = "user_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(categoryId, forKey: .categoryId)
        try c.encode(taskTypeId, forKey: .taskTypeId)
        try c.encode(parentTaskId, forKey: .parentTaskId)
        try c.encode(dueAt, forKey: .dueAt)
        try c.encode(priority, forKey: .priority)
        try c.encode(status, forKey: .status)
        try c.encode(userId, forKey: .userId)
        try c.encode(source, forKey: .source)
    }
}

/// Payload for changing a task's status.
nonisolated struct TaskStatusUpdate: Encodable, Sendable {
    var status: String
    var completedAt: Date?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(status, forKey: .status)
        try c.encode(completedAt, forKey: .completedAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

/// Payload for editing a task. Optional values are encoded as explicit nulls so
/// fields such as the due date can be cleared.
nonisolated struct TaskEdit: Encodable, Sendable {
    var title: String
    var description: String?
    var categoryId: UUID?
    var taskTypeId: UUID?
    var dueAt: Date?
    var priority: String?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case title, description, priority
        case categoryId = "category_id"
        case taskTypeId = "task_type_id"
        case dueAt = "due_at"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(categoryId, forKey: .categoryId)
        try c.encode(taskTypeId, forKey: .taskTypeId)
        try c.encode(dueAt, forKey: .dueAt)
        try c.encode(priority, forKey: .priority)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}
