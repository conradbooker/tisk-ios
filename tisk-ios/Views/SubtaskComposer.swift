import SwiftUI

private struct OpenTaskKey: EnvironmentKey {
    static let defaultValue: (UUID) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Pushes a task's detail screen onto the navigation stack.
    var openTask: (UUID) -> Void {
        get { self[OpenTaskKey.self] }
        set { self[OpenTaskKey.self] = newValue }
    }
}

/// "Add subtask" field shown in a task's detail screen. Return adds the child
/// (inheriting category, type, due date and priority) and keeps focus.
struct SubtaskComposer: View {
    let parent: TaskItem

    @Environment(TaskStore.self) private var store
    @State private var title = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
                .frame(width: 26)
            TextField("Add subtask", text: $title)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(submit)
        }
    }

    private func submit() {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        title = ""
        focused = true
        Task {
            _ = await store.addTask(
                title: text,
                description: nil,
                categoryId: parent.categoryId,
                taskTypeId: parent.taskTypeId,
                parentTaskId: parent.id,
                dueAt: parent.dueAt,
                priority: parent.priority.flatMap(TaskPriority.init(rawValue:))
            )
        }
    }
}
