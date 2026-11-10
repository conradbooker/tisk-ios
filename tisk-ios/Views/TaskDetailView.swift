import SwiftUI

struct TaskDetailView: View {
    let taskId: UUID

    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openTask) private var openTask

    @State private var weekStart = WeekStartsOn.current.startOfWeek(containing: Date())
    @State private var lateDay: Date?
    @State private var editingTask: TaskItem?

    private var task: TaskItem? {
        store.tasks.first { $0.id == taskId }
    }

    var body: some View {
        Group {
            if let task {
                content(for: task)
            } else {
                ContentUnavailableView("Task not found", systemImage: "questionmark.circle")
                    .task { dismiss() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskId) { await store.loadChildren(of: taskId) }
        .toolbar {
            if let task {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editingTask = task }
                }
            }
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
    }

    private func content(for task: TaskItem) -> some View {
        let status = store.effectiveStatus(for: task)
        let chips = store.chips(for: task)
        let category = store.categoryTitle(for: task)

        return List {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    StatusMenu(task: task, status: status, size: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        if let category {
                            Text(category)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(task.title)
                            .font(.title2.weight(.semibold))
                        if let notes = task.description, !notes.isEmpty {
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Subtasks") {
                ForEach(store.children(of: task.id)) { child in
                    SubtaskRow(child: child) { openTask(child.id) }
                }
                SubtaskComposer(parent: task)
            }

            Section {
                WeekStrip(
                    weekStart: $weekStart,
                    allowsPast: true,
                    showsGrid: true,
                    dueDate: task.dueAt,
                    dueColor: store.categoryColor(for: task) ?? .green,
                    onLongPress: { day in
                        if let chip = store.chip(for: task, on: day) {
                            Task { await store.deleteChip(chip) }
                        }
                    },
                    onSelect: { day in
                        if let chip = store.chip(for: task, on: day) {
                            Task { await store.toggleChip(chip) }
                        } else if isAfterDue(day, due: task.dueAt) {
                            lateDay = day
                        } else {
                            Task { await store.addChips(for: task, days: [day]) }
                        }
                    },
                    cell: { day in
                    if let chip = store.chip(for: task, on: day) {
                        StatusIcon(kind: .chip(chip, task: task), size: 22)
                    } else {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                })
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            } header: {
                Text("Next 7 days")
            } footer: {
                Text("Tap a day to plan it, tap again to mark it done, long press to remove it.")
            }

            Section("Details") {
                LabeledContent("Status", value: status.menuLabel)
                LabeledContent(
                    "Due",
                    value: task.dueAt.map {
                        $0.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    } ?? "No due date specified"
                )
                if let type = store.taskType(id: task.taskTypeId) {
                    LabeledContent("Type", value: store.path(for: type))
                }
                if let priority = task.priority, !priority.isEmpty {
                    LabeledContent("Priority", value: priority.capitalized)
                }
            }

            if !chips.isEmpty {
                Section("Planned days") {
                    ForEach(chips) { chip in
                        HStack(spacing: 12) {
                            StatusIcon(kind: .chip(chip, task: task), size: 22)
                            Text(chip.dueAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { Task { await store.toggleChip(chip) } }
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                Task { await store.deleteChip(chip) }
                            }
                        }
                    }
                }
            }
        }
        .contentMargins(.bottom, 24, for: .scrollContent)
        .alert("Planning after the due date", isPresented: Binding(
            get: { lateDay != nil },
            set: { if !$0 { lateDay = nil } }
        )) {
            Button("Plan Anyway") {
                if let day = lateDay {
                    Task { await store.addChips(for: task, days: [day]) }
                }
                lateDay = nil
            }
            Button("Cancel", role: .cancel) { lateDay = nil }
        } message: {
            Text("You're planning to do this after this assignment is due, are you sure?")
        }
    }
}

private struct SubtaskRow: View {
    let child: TaskItem
    let onOpen: () -> Void

    @Environment(TaskStore.self) private var store

    var body: some View {
        let status = store.effectiveStatus(for: child)
        HStack(spacing: 12) {
            StatusMenu(task: child, status: status, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(child.title)
                    .strikethrough(status == .done)
                    .foregroundStyle(status == .done ? .secondary : .primary)
                if let due = child.dueAt {
                    Text("due \(due.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task { await store.delete(child) }
            }
        }
    }
}
