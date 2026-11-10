import Foundation

nonisolated enum TaskStatus: String, CaseIterable, Identifiable, Sendable {
    case todo
    case inProgress = "in_progress"
    case done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .todo: "to do"
        case .inProgress: "in prog"
        case .done: "done"
        }
    }

    var menuLabel: String {
        switch self {
        case .todo: "To Do"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }

    /// Parses a free-form status string from the database.
    init?(databaseValue: String) {
        let normalized = databaseValue
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        switch normalized {
        case "todo", "to_do", "pending", "open", "not_started": self = .todo
        case "in_progress", "inprogress", "in_prog", "doing", "started": self = .inProgress
        case "done", "complete", "completed", "finished": self = .done
        default: return nil
        }
    }
}

/// Filter options shown in the segmented control.
nonisolated enum StatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case todo
    case inProgress
    case done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "all"
        case .todo: "to do"
        case .inProgress: "in prog"
        case .done: "done"
        }
    }

    func matches(_ status: TaskStatus) -> Bool {
        switch self {
        case .all: true
        case .todo: status == .todo
        case .inProgress: status == .inProgress
        case .done: status == .done
        }
    }
}

nonisolated enum TaskPriority: String, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}
