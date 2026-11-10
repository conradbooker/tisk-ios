import SwiftUI

struct TaskListView: View {
    let selectedTab: UUID?   // nil == all
    let email: String?
    let showComposer: Bool

    @Environment(TaskStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @Environment(DateFilter.self) private var dateFilter
    @Environment(\.openTask) private var openTask

    @State private var filter: StatusFilter = .all
    @State private var collapsed: Set<UUID> = []
    @State private var editingTask: TaskItem?
    @State private var showingSettings = false

    private struct TaskSection: Identifiable {
        let id: UUID?
        let title: String
        let category: TaskCategory?
        let tasks: [TaskItem]

        /// Sections without a category share a fixed key for collapse state.
        var sectionKey: UUID {
            id ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        }
    }

    private var filteredTasks: [TaskItem] {
        store.tasks
            .filter { $0.parentTaskId == nil }   // children live in the detail screen
            .filter { task in
                guard let selectedTab else { return true }
                guard let categoryId = task.categoryId else { return false }
                return store.categoryIdsIncludingDescendants(of: selectedTab).contains(categoryId)
            }
            .filter { filter.matches(store.effectiveStatus(for: $0)) }
            .filter { task in
                dateFilter.mode == .off || relevantDates(for: task).contains { dateFilter.matches($0) }
            }
            .sorted(by: order)
    }

    /// Dates the date filter applies to: the due date, or the planned chip dates.
    private func relevantDates(for task: TaskItem) -> [Date] {
        switch dateFilter.basis {
        case .due: task.dueAt.map { [$0] } ?? []
        case .scheduled: store.chips(for: task).map(\.dueAt)
        }
    }

    /// The date shown and sorted on: in "doing" mode, the planned chip date that
    /// matches the filter (otherwise the next upcoming one).
    private func displayDate(for task: TaskItem) -> Date? {
        let dates = relevantDates(for: task).sorted()
        guard dateFilter.basis == .scheduled else { return dates.first }
        if dateFilter.mode != .off, let match = dates.first(where: { dateFilter.matches($0) }) {
            return match
        }
        return dates.first(where: { $0 >= Calendar.current.startOfDay(for: Date()) }) ?? dates.first
    }

    /// Open tasks first, then by relevant date (soonest first), then newest.
    private func order(_ a: TaskItem, _ b: TaskItem) -> Bool {
        let aDone = a.taskStatus == .done
        let bDone = b.taskStatus == .done
        if aDone != bDone { return !aDone }
        switch (displayDate(for: a), displayDate(for: b)) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.createdAt > b.createdAt
        }
    }

    /// "All" page: tasks grouped by the top-level categories shown in the bottom bar.
    private var groups: [TaskSection] {
        let tasks = filteredTasks
        var claimed: Set<UUID> = []
        var result: [TaskSection] = store.topLevelCategories.compactMap { category in
            let ids = store.categoryIdsIncludingDescendants(of: category.id)
            let items = tasks.filter { $0.categoryId.map(ids.contains) ?? false }
            guard !items.isEmpty else { return nil }
            claimed.formUnion(items.map(\.id))
            return TaskSection(id: category.id, title: category.title, category: category, tasks: items)
        }
        let other = tasks.filter { !claimed.contains($0.id) }
        if !other.isEmpty {
            result.append(TaskSection(id: nil, title: "no category", category: nil, tasks: other))
        }
        return result
    }

    private var title: String {
        "Your Tasks"
    }

    var body: some View {
        List {
            Section {
                Picker("Status", selection: $filter) {
                    ForEach(StatusFilter.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: filter)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            }

            if showComposer {
                Section {
                    TaskComposer(selectedTab: selectedTab)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if store.isLoading && store.tasks.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else if filteredTasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks",
                    systemImage: "checklist",
                    description: Text(
                        filter == .all ? dateFilter.emptyDescription : "Nothing matches this filter."
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if selectedTab == nil {
                ForEach(groups, id: \.sectionKey) { group in
                    Section {
                        if !collapsed.contains(group.sectionKey) {
                            rows(group.tasks)
                        }
                    } header: {
                        header(for: group)
                    }
                }
            } else {
                Section {
                    rows(filteredTasks)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.selection()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        dateFilter.toggleBasis()
                    }
                } label: {
                    // Explicit HStack so the text shows in the toolbar (a plain Label is icon-only there).
                    HStack(spacing: 6) {
                        Image(systemName: dateFilter.basis.symbol)
                        Text(dateFilter.basis.label)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel("Showing when tasks are \(dateFilter.basis == .due ? "due" : "planned"). Tap to switch.")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let email {
                        Text(email)
                    }
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .presentationDetents([.medium])
        }
        .refreshable { await store.load() }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private func rows(_ tasks: [TaskItem]) -> some View {
        ForEach(tasks) { task in
            TaskRow(
                task: task,
                category: store.category(for: task),
                scheduledDate: dateFilter.basis == .scheduled ? displayDate(for: task) : nil,
                isScheduledMode: dateFilter.basis == .scheduled,
                status: store.effectiveStatus(for: task),
                onOpen: { openTask(task.id) },
                onEdit: { editingTask = task },
                onAddChild: { openTask(task.id) }
            )
        }
    }

    private func header(for group: TaskSection) -> some View {
        let isCollapsed = collapsed.contains(group.sectionKey)
        return Button {
            Haptics.light()
            withAnimation(.easeInOut(duration: 0.15)) {
                if isCollapsed {
                    collapsed.remove(group.sectionKey)
                } else {
                    collapsed.insert(group.sectionKey)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let category = group.category {
                    Capsule()
                        .fill(Color(hex: category.backgroundColor) ?? .secondary)
                        .overlay(
                            Capsule().stroke(Color(hex: category.borderColor) ?? .secondary, lineWidth: 1)
                        )
                        .frame(width: 8, height: 18)
                }
                Text(group.title)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                Spacer()
            }
            .foregroundStyle(.primary)
            .textCase(nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

private struct TaskRow: View {
    let task: TaskItem
    let category: TaskCategory?
    var scheduledDate: Date? = nil
    var isScheduledMode = false
    var status: TaskStatus = .todo
    var onOpen: () -> Void = {}
    var onEdit: () -> Void = {}
    var onAddChild: () -> Void = {}

    @Environment(TaskStore.self) private var store

    private var isDone: Bool { task.taskStatus == .done }

    private var displayTitle: String {
        // Nested categories keep "Name: title"; top-level ones already appear
        // in the section / bottom bar, so skip the prefix.
        if let category, category.parentId != nil, !category.title.isEmpty {
            return "\(category.title): \(task.title)"
        }
        return task.title
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            StatusMenu(task: task, status: status, size: 26)
                .sensoryFeedback(.success, trigger: isDone)

            if let category {
                Capsule()
                    .fill(Color(hex: category.backgroundColor) ?? .secondary)
                    .overlay(
                        Capsule().stroke(Color(hex: category.borderColor) ?? .secondary, lineWidth: 1)
                    )
                    .frame(width: 9, height: subtitle == nil ? 26 : 42)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.title3)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task { await store.delete(task) }
            }
        }
        .contextMenu {
            ForEach(TaskStatus.allCases) { status in
                Button(status.menuLabel, systemImage: icon(for: status)) {
                    Task { await store.setStatus(task, to: status) }
                }
            }
            Divider()
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Subtasks", systemImage: "list.bullet.indent", action: onAddChild)
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task { await store.delete(task) }
            }
        }
    }

    private func icon(for status: TaskStatus) -> String {
        switch status {
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        }
    }

    private func relative(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInTomorrow(date) { return "tomorrow" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var subtitle: String? {
        if isScheduledMode {
            let planned: String
            if let date = scheduledDate {
                planned = "doing \(relative(date))"
            } else {
                planned = "not scheduled"
            }
            guard let due = task.dueAt else { return planned }
            return "\(planned), due \(relative(due))"
        }
        guard let due = task.dueAt else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(due) { return "due today" }
        if calendar.isDateInTomorrow(due) { return "due tomorrow" }
        if due < Date(), !isDone { return "overdue, \(due.formatted(.dateTime.month(.abbreviated).day()))" }
        return "due \(due.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
