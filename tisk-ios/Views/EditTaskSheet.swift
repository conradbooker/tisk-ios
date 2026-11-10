import SwiftUI

struct EditTaskSheet: View {
    let task: TaskItem

    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var categoryId: UUID?
    @State private var taskTypeId: UUID?
    @State private var priority: TaskPriority?
    @State private var hasDue: Bool
    @State private var dueDate: Date
    @State private var isSaving = false

    init(task: TaskItem) {
        self.task = task
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.description ?? "")
        _categoryId = State(initialValue: task.categoryId)
        _taskTypeId = State(initialValue: task.taskTypeId)
        _priority = State(initialValue: task.priority.flatMap(TaskPriority.init(rawValue:)))
        _hasDue = State(initialValue: task.dueAt != nil)
        _dueDate = State(initialValue: task.dueAt ?? Calendar.current.date(
            bySettingHour: 23, minute: 59, second: 0, of: Date()
        ) ?? Date())
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(1...5)
                }

                Section {
                    Picker("Category", selection: $categoryId) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.visibleCategories) { category in
                            Text(store.path(for: category)).tag(UUID?.some(category.id))
                        }
                    }
                    Picker("Type", selection: $taskTypeId) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.visibleTaskTypes) { type in
                            Text(store.path(for: type)).tag(UUID?.some(type.id))
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        Text("None").tag(TaskPriority?.none)
                        ForEach(TaskPriority.allCases) { p in
                            Text(p.label).tag(TaskPriority?.some(p))
                        }
                    }
                }

                Section {
                    Toggle("Due date", isOn: $hasDue.animation(.easeInOut(duration: 0.15)))
                    if hasDue {
                        DatePicker("Due", selection: $dueDate)
                    }
                } footer: {
                    if !hasDue {
                        Text("No due date specified")
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm, action: save)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        isSaving = true
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let edit = TaskEdit(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: trimmedNotes.isEmpty ? nil : trimmedNotes,
            categoryId: categoryId,
            taskTypeId: taskTypeId,
            dueAt: hasDue ? dueDate : nil,
            priority: priority?.rawValue,
            updatedAt: Date()
        )
        Task {
            let ok = await store.updateTask(task, edit: edit)
            isSaving = false
            if ok { dismiss() }
        }
    }
}
