import Foundation

/// A scheduled work session for a task. `dueAt` is when the chip is planned
/// (when the user will do the work); `taskDueAt` mirrors the task's own due date.
nonisolated struct TaskChip: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var userId: UUID
    var taskId: UUID
    var taskChipCategoryId: UUID?
    var status: String
    var createdAt: Date
    var updatedAt: Date?
    var dueAt: Date
    var taskDueAt: Date
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case taskId = "task_id"
        case taskChipCategoryId = "task_chip_category_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case dueAt = "due_at"
        case taskDueAt = "task_due_at"
        case completedAt = "completed_at"
    }

    static let todoStatus = "to_do"
    static let completedStatus = "completed"

    var isCompleted: Bool {
        status == Self.completedStatus || completedAt != nil
    }
}

nonisolated struct NewChip: Encodable, Sendable {
    var userId: UUID
    var taskId: UUID
    var status: String = TaskChip.todoStatus
    var createdAt: Date
    var dueAt: Date
    var taskDueAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case taskId = "task_id"
        case status
        case createdAt = "created_at"
        case dueAt = "due_at"
        case taskDueAt = "task_due_at"
    }
}

nonisolated struct ChipUpdate: Encodable, Sendable {
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
