import Foundation
import SwiftUI
import Observation
import Supabase

@Observable
final class TaskStore {
    private(set) var tasks: [TaskItem] = []
    private(set) var categories: [TaskCategory] = []
    private(set) var taskTypes: [TaskType] = []
    private(set) var chips: [TaskChip] = []
    private(set) var isLoading = false
    var errorMessage: String? {
        didSet { if errorMessage != nil { Haptics.error() } }
    }

    private var client: SupabaseClient { SupabaseService.client }

    // MARK: Derived data

    var visibleTaskTypes: [TaskType] {
        taskTypes
            .filter { !$0.isHidden }
            .sorted { path(for: $0).localizedCaseInsensitiveCompare(path(for: $1)) == .orderedAscending }
    }

    /// "Parent / Child" name for a task type (walks up the parent chain).
    func path(for type: TaskType) -> String {
        var names = [type.title]
        var current = type
        var seen: Set<UUID> = [type.id]
        while let parentId = current.parentId,
              !seen.contains(parentId),
              let parent = taskTypes.first(where: { $0.id == parentId }) {
            names.insert(parent.title, at: 0)
            seen.insert(parentId)
            current = parent
        }
        return names.joined(separator: " / ")
    }

    var visibleCategories: [TaskCategory] {
        categories
            .filter { !$0.isHidden }
            .sorted { path(for: $0).localizedCaseInsensitiveCompare(path(for: $1)) == .orderedAscending }
    }

    /// Categories with no parent, used for the bottom bar tabs.
    var topLevelCategories: [TaskCategory] {
        categories
            .filter { !$0.isHidden && $0.parentId == nil }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// The category's id plus the ids of all its descendants.
    func categoryIdsIncludingDescendants(of id: UUID) -> Set<UUID> {
        var result: Set<UUID> = [id]
        var frontier: [UUID] = [id]
        while let current = frontier.popLast() {
            for child in categories where child.parentId == current && !result.contains(child.id) {
                result.insert(child.id)
                frontier.append(child.id)
            }
        }
        return result
    }

    /// "Parent / Child" name for a category (walks up the parent chain).
    func path(for category: TaskCategory) -> String {
        var names = [category.title]
        var current = category
        var seen: Set<UUID> = [category.id]
        while let parentId = current.parentId,
              !seen.contains(parentId),
              let parent = categories.first(where: { $0.id == parentId }) {
            names.insert(parent.title, at: 0)
            seen.insert(parentId)
            current = parent
        }
        return names.joined(separator: " / ")
    }

    func category(for task: TaskItem) -> TaskCategory? {
        guard let id = task.categoryId else { return nil }
        return categories.first { $0.id == id }
    }

    func categoryTitle(for task: TaskItem) -> String? {
        guard let id = task.categoryId,
              let category = categories.first(where: { $0.id == id }) else { return nil }
        return path(for: category)
    }

    func chips(for task: TaskItem) -> [TaskChip] {
        chips.filter { $0.taskId == task.id }.sorted { $0.dueAt < $1.dueAt }
    }

    /// Direct children of a task (already loaded via `loadChildren`).
    func children(of id: UUID) -> [TaskItem] {
        tasks
            .filter { $0.parentTaskId == id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// The top-level ancestor of a category (or the category itself).
    func topLevelCategory(of category: TaskCategory) -> TaskCategory {
        var current = category
        var seen: Set<UUID> = [category.id]
        while let parentId = current.parentId,
              !seen.contains(parentId),
              let parent = categories.first(where: { $0.id == parentId }) {
            seen.insert(parentId)
            current = parent
        }
        return current
    }

    func chip(for task: TaskItem, on day: Date) -> TaskChip? {
        chips.first { $0.taskId == task.id && Calendar.current.isDate($0.dueAt, inSameDayAs: day) }
    }

    /// A task counts as in progress once any of its planned days is done.
    func effectiveStatus(for task: TaskItem) -> TaskStatus {
        let status = task.taskStatus
        if status == .todo, chips.contains(where: { $0.taskId == task.id && $0.isCompleted }) {
            return .inProgress
        }
        return status
    }

    func categoryColor(for task: TaskItem) -> Color? {
        guard let id = task.categoryId,
              let category = categories.first(where: { $0.id == id }) else { return nil }
        return Color(hex: category.backgroundColor)
    }

    func taskType(id: UUID?) -> TaskType? {
        guard let id else { return nil }
        return taskTypes.first { $0.id == id }
    }

    // MARK: Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let fetchedTasks: [TaskItem] = client
                .from("tasks")
                .select()
                .is("parent_task_id", value: nil)   // top-level only; children load on demand
                .order("created_at", ascending: false)
                .execute()
                .value
            async let fetchedCategories: [TaskCategory] = client
                .from("categories")
                .select()
                .execute()
                .value
            async let fetchedTypes: [TaskType] = client
                .from("task_types")
                .select()
                .execute()
                .value
            async let fetchedChips: [TaskChip] = client
                .from("task_chips")
                .select()
                .order("due_at", ascending: true)
                .execute()
                .value
            let (t, c, ty) = try await (fetchedTasks, fetchedCategories, fetchedTypes)
            // Chips are optional for the app to work; don't fail the whole load.
            chips = (try? await fetchedChips) ?? []
            // Keep any children already loaded for open detail screens.
            tasks = t + tasks.filter { $0.parentTaskId != nil }
            categories = c
            taskTypes = ty
            errorMessage = nil
        } catch is CancellationError {
            // Pull-to-refresh was cancelled; keep current data.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// `select * from tasks where parent_task_id = :id`, merged into local state.
    func loadChildren(of parentId: UUID) async {
        do {
            let kids: [TaskItem] = try await client
                .from("tasks")
                .select()
                .eq("parent_task_id", value: parentId)
                .order("created_at", ascending: true)
                .execute()
                .value
            let ids = Set(kids.map(\.id))
            tasks.removeAll { $0.parentTaskId == parentId && !ids.contains($0.id) }
            for kid in kids {
                if let i = tasks.firstIndex(where: { $0.id == kid.id }) {
                    tasks[i] = kid
                } else {
                    tasks.append(kid)
                }
            }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Mutations

    func addTask(
        title: String,
        description: String?,
        categoryId: UUID?,
        taskTypeId: UUID?,
        parentTaskId: UUID? = nil,
        dueAt: Date?,
        priority: TaskPriority?
    ) async -> TaskItem? {
        do {
            let userId = try await client.auth.session.user.id
            let payload = NewTask(
                title: title,
                description: description,
                categoryId: categoryId,
                taskTypeId: taskTypeId,
                parentTaskId: parentTaskId,
                dueAt: dueAt,
                priority: priority?.rawValue,
                status: TaskStatus.todo.rawValue,
                userId: userId,
                source: "ios"
            )
            let created: TaskItem = try await client
                .from("tasks")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            tasks.insert(created, at: 0)
            Haptics.success()
            return created
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: Chips (planned days)

    private func noon(_ day: Date) -> Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    func addChips(for task: TaskItem, days: [Date]) async {
        let unique = Dictionary(grouping: days.map { Calendar.current.startOfDay(for: $0) }, by: { $0 })
            .keys.sorted()
            .filter { chip(for: task, on: $0) == nil }
        guard !unique.isEmpty else { return }
        do {
            let userId = try await client.auth.session.user.id
            let now = Date()
            let fallbackDue = noon(unique.last ?? now)
            let payloads = unique.map {
                NewChip(
                    userId: userId,
                    taskId: task.id,
                    createdAt: now,
                    dueAt: noon($0),
                    taskDueAt: task.dueAt ?? fallbackDue
                )
            }
            let created: [TaskChip] = try await client
                .from("task_chips")
                .insert(payloads)
                .select()
                .execute()
                .value
            chips.append(contentsOf: created)
            Haptics.light()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleChip(_ chip: TaskChip) async {
        guard let index = chips.firstIndex(where: { $0.id == chip.id }) else { return }
        let previous = chips[index]
        let now = Date()
        let completing = !chip.isCompleted
        if completing { Haptics.success() } else { Haptics.light() }

        chips[index].status = completing ? TaskChip.completedStatus : TaskChip.todoStatus
        chips[index].completedAt = completing ? now : nil
        chips[index].updatedAt = now

        do {
            try await client
                .from("task_chips")
                .update(ChipUpdate(
                    status: chips[index].status,
                    completedAt: chips[index].completedAt,
                    updatedAt: now
                ))
                .eq("id", value: chip.id)
                .execute()
        } catch {
            if let i = chips.firstIndex(where: { $0.id == chip.id }) { chips[i] = previous }
            errorMessage = error.localizedDescription
            return
        }

        // The task is in progress once any planned day is done.
        if let task = tasks.first(where: { $0.id == chip.taskId }), task.taskStatus != .done {
            let anyDone = chips.contains { $0.taskId == task.id && $0.isCompleted }
            let desired: TaskStatus = anyDone ? .inProgress : .todo
            if task.taskStatus != desired {
                await setStatus(task, to: desired)
            }
        }
    }

    func deleteChip(_ chip: TaskChip) async {
        guard let index = chips.firstIndex(where: { $0.id == chip.id }) else { return }
        Haptics.warning()
        let removed = chips.remove(at: index)
        do {
            try await client
                .from("task_chips")
                .delete()
                .eq("id", value: chip.id)
                .execute()
        } catch {
            chips.insert(removed, at: min(index, chips.count))
            errorMessage = error.localizedDescription
        }
    }

    func addCategory(
        title: String,
        backgroundHex: String,
        borderHex: String,
        parentId: UUID?
    ) async -> TaskCategory? {
        do {
            let userId = try await client.auth.session.user.id
            let created: TaskCategory = try await client
                .from("categories")
                .insert(NewCategory(
                    title: title,
                    backgroundColor: backgroundHex,
                    borderColor: borderHex,
                    parentId: parentId,
                    userId: userId
                ))
                .select()
                .single()
                .execute()
                .value
            categories.append(created)
            Haptics.success()
            return created
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func addTaskType(title: String, parentId: UUID? = nil) async -> TaskType? {
        do {
            let userId = try await client.auth.session.user.id
            let created: TaskType = try await client
                .from("task_types")
                .insert(NewTaskType(title: title, parentId: parentId, userId: userId))
                .select()
                .single()
                .execute()
                .value
            taskTypes.append(created)
            Haptics.success()
            return created
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func updateTask(_ task: TaskItem, edit: TaskEdit) async -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return false }
        let previous = tasks[index]

        tasks[index].title = edit.title
        tasks[index].description = edit.description
        tasks[index].categoryId = edit.categoryId
        tasks[index].taskTypeId = edit.taskTypeId
        tasks[index].dueAt = edit.dueAt
        tasks[index].priority = edit.priority
        tasks[index].updatedAt = edit.updatedAt

        do {
            try await client
                .from("tasks")
                .update(edit)
                .eq("id", value: task.id)
                .execute()
            return true
        } catch {
            if let i = tasks.firstIndex(where: { $0.id == task.id }) { tasks[i] = previous }
            errorMessage = error.localizedDescription
            return false
        }
    }

    func toggleComplete(_ task: TaskItem) async {
        await setStatus(task, to: task.taskStatus == .done ? .todo : .done)
    }

    func setStatus(_ task: TaskItem, to newStatus: TaskStatus) async {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let previous = tasks[index]
        let now = Date()

        if newStatus == .done { Haptics.success() } else { Haptics.light() }

        // Optimistic update.
        tasks[index].status = newStatus.rawValue
        tasks[index].completedAt = newStatus == .done ? now : nil
        tasks[index].updatedAt = now

        do {
            let update = TaskStatusUpdate(
                status: newStatus.rawValue,
                completedAt: newStatus == .done ? now : nil,
                updatedAt: now
            )
            try await client
                .from("tasks")
                .update(update)
                .eq("id", value: task.id)
                .execute()
        } catch {
            if let i = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[i] = previous
            }
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ task: TaskItem) async {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        Haptics.warning()
        let removed = tasks.remove(at: index)
        let removedChips = chips.filter { $0.taskId == task.id }
        chips.removeAll { $0.taskId == task.id }
        do {
            // Delete the task's planned days first so no orphan chips remain.
            try await client
                .from("task_chips")
                .delete()
                .eq("task_id", value: task.id)
                .execute()
            try await client
                .from("tasks")
                .delete()
                .eq("id", value: task.id)
                .execute()
        } catch {
            tasks.insert(removed, at: min(index, tasks.count))
            chips.append(contentsOf: removedChips)
            errorMessage = error.localizedDescription
        }
    }
}
