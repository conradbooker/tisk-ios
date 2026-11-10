import SwiftUI

/// Inline "new task" row shown at the top of the list. Pressing return adds the
/// task and keeps focus so several tasks can be entered in a row.
struct TaskComposer: View {
    let selectedTab: UUID?

    @Environment(TaskStore.self) private var store
    @Environment(DateFilter.self) private var dateFilter

    private enum DueChoice: Equatable {
        case auto            // follows the date filter (today by default)
        case custom(Date)
        case none
    }

    @State private var title = ""
    @State private var categoryId: UUID?
    @State private var taskTypeId: UUID?
    @State private var priority: TaskPriority?
    @State private var due: DueChoice = .auto
    @State private var showingDatePicker = false
    @State private var customDate = Date()
    @State private var weekStart = WeekStartsOn.current.startOfWeek(containing: Date())
    @State private var plannedDays: Set<Date> = []
    @State private var lateDay: Date?
    @FocusState private var focused: Bool

    private var effectiveDue: Date? {
        switch due {
        case .auto: dateFilter.defaultDue
        case .custom(let date): date
        case .none: nil
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                TextField("New task", text: $title)
                    .font(.title3)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(submit)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        categoryMenu
                        typeMenu
                        dueMenu
                        priorityMenu
                    }
                }
            }
            .scrollClipDisabled()

            WeekStrip(
                weekStart: $weekStart,
                dueDate: effectiveDue,
                dueColor: selectedCategoryColor,
                onLongPress: { day in
                    withAnimation(.easeInOut(duration: 0.15)) { _ = plannedDays.remove(day) }
                },
                onSelect: { day in
                    if plannedDays.contains(day) {
                        withAnimation(.easeInOut(duration: 0.15)) { _ = plannedDays.remove(day) }
                    } else if isAfterDue(day, due: effectiveDue) {
                        lateDay = day
                    } else {
                        withAnimation(.easeInOut(duration: 0.15)) { _ = plannedDays.insert(day) }
                    }
                },
                cell: { day in
                if plannedDays.contains(day) {
                    StatusIcon(kind: .todo, size: 22)
                } else {
                    Circle()
                        .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .frame(width: 22, height: 22)
                }
            })
        }
        .padding(.vertical, 4)
        .onAppear { categoryId = selectedTab }
        .onChange(of: selectedTab) { _, new in categoryId = new }
        .task { focused = true }
        .sensoryFeedback(.selection, trigger: categoryId)
        .sensoryFeedback(.selection, trigger: taskTypeId)
        .sensoryFeedback(.selection, trigger: priority)
        .sensoryFeedback(.selection, trigger: due)
        .alert("Planning after the due date", isPresented: Binding(
            get: { lateDay != nil },
            set: { if !$0 { lateDay = nil } }
        )) {
            Button("Plan Anyway") {
                if let lateDay {
                    withAnimation(.easeInOut(duration: 0.15)) { _ = plannedDays.insert(lateDay) }
                }
                lateDay = nil
            }
            Button("Cancel", role: .cancel) { lateDay = nil }
        } message: {
            Text("You're planning to do this after this assignment is due, are you sure?")
        }
    }

    private var selectedCategoryColor: Color {
        store.visibleCategories.first { $0.id == categoryId }
            .flatMap { Color(hex: $0.backgroundColor) } ?? .green
    }

    // MARK: Menus

    private var categoryMenu: some View {
        let category = store.visibleCategories.first { $0.id == categoryId }
        return Menu {
            Picker("Category", selection: $categoryId) {
                Text("No category").tag(UUID?.none)
                ForEach(store.visibleCategories) { c in
                    Text(store.path(for: c)).tag(UUID?.some(c.id))
                }
            }
        } label: {
            pill {
                if let category {
                    CategoryDot(category: category)
                    Text(category.title)
                } else {
                    Text("Category").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var typeMenu: some View {
        let type = store.visibleTaskTypes.first { $0.id == taskTypeId }
        return Menu {
            Picker("Task type", selection: $taskTypeId) {
                Text("No type").tag(UUID?.none)
                ForEach(store.visibleTaskTypes) { t in
                    Text(store.path(for: t)).tag(UUID?.some(t.id))
                }
            }
        } label: {
            pill {
                if let type {
                    Text(type.title)
                } else {
                    Text("Type").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dueMenu: some View {
        Menu {
            Button("Today", systemImage: "calendar") { due = .custom(endOfDay(Date())) }
            Button("Tomorrow", systemImage: "sunrise") {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                due = .custom(endOfDay(tomorrow))
            }
            Button("Pick date…", systemImage: "calendar.badge.clock") {
                customDate = effectiveDue ?? Date()
                showingDatePicker = true
            }
            Button("No due date", systemImage: "calendar.badge.minus") { due = .none }
        } label: {
            pill {
                Image(systemName: "calendar")
                Text(dueLabel)
            }
        }
        .popover(isPresented: $showingDatePicker) {
            DatePicker("Due", selection: $customDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(width: 320)
                .padding(12)
                .presentationCompactAdaptation(.popover)
                .onChange(of: customDate) { _, new in due = .custom(endOfDay(new)) }
        }
    }

    private var priorityMenu: some View {
        Menu {
            Picker("Priority", selection: $priority) {
                Text("No priority").tag(TaskPriority?.none)
                ForEach(TaskPriority.allCases) { p in
                    Text(p.label).tag(TaskPriority?.some(p))
                }
            }
        } label: {
            pill {
                Image(systemName: "flag")
                Text(priority?.label ?? "Priority")
            }
        }
    }

    // MARK: Helpers

    private var dueLabel: String {
        guard let date = effectiveDue else { return "No due date" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func endOfDay(_ date: Date) -> Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: date) ?? date
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 6) {
            content()
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .glassEffect(.regular.interactive(), in: .capsule)
        .fixedSize()
    }

    private func submit() {
        let text = trimmedTitle
        guard !text.isEmpty else { return }
        let payload = (categoryId, taskTypeId, effectiveDue, priority)
        let days = plannedDays.sorted()
        title = ""
        plannedDays = []
        focused = true   // keep the keyboard up for the next task
        Task {
            let created = await store.addTask(
                title: text,
                description: nil,
                categoryId: payload.0,
                taskTypeId: payload.1,
                dueAt: payload.2,
                priority: payload.3
            )
            if let created {
                if !days.isEmpty { await store.addChips(for: created, days: days) }
            } else if title.isEmpty {
                title = text
            }
        }
    }
}

struct CategoryDot: View {
    let category: TaskCategory

    var body: some View {
        Capsule()
            .fill(Color(hex: category.backgroundColor) ?? .secondary)
            .overlay(
                Capsule().stroke(Color(hex: category.borderColor) ?? .secondary, lineWidth: 1)
            )
            .frame(width: 10, height: 18)
    }
}
