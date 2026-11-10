import SwiftUI

enum StatusIconKind {
    case todo
    case inProgress
    case doneToday
    case notDone
    case pastDue
    case finished

    /// Icon for a planned day (chip) of a task.
    static func chip(_ chip: TaskChip, task: TaskItem, now: Date = Date()) -> StatusIconKind {
        let calendar = Calendar.current
        if chip.isCompleted {
            let doneOn = chip.completedAt ?? chip.dueAt
            return calendar.isDate(doneOn, inSameDayAs: now) ? .doneToday : .finished
        }
        if let due = task.dueAt, due < now, task.taskStatus != .done { return .pastDue }
        if chip.dueAt < calendar.startOfDay(for: now) { return .notDone }
        return .todo
    }

    /// Icon for a whole task.
    static func task(_ task: TaskItem, status: TaskStatus, now: Date = Date()) -> StatusIconKind {
        if status == .done { return .finished }
        if let due = task.dueAt, due < now { return .pastDue }
        if status == .inProgress { return .inProgress }
        return .todo
    }
}

struct StatusIcon: View {
    let kind: StatusIconKind
    var size: CGFloat = 26

    private var line: CGFloat { max(1.5, size * 0.1) }
    private static let darkRed = Color(red: 0.55, green: 0, blue: 0)
    private static let green = Color(red: 0.24, green: 0.69, blue: 0.25)

    var body: some View {
        ZStack {
            switch kind {
            case .todo:
                Circle().strokeBorder(.primary, lineWidth: line)

            case .inProgress:
                Circle().strokeBorder(.primary, lineWidth: line)
                Circle()
                    .trim(from: 0.5, to: 1)
                    .rotation(.degrees(90))
                    .fill(.primary)
                    .padding(line)

            case .doneToday:
                Circle().strokeBorder(.primary, lineWidth: line)
                Circle().fill(.blue).padding(size * 0.14)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)

            case .notDone:
                Circle().strokeBorder(.secondary, lineWidth: line * 0.8)
                Path { path in
                    let inset = size * 0.2
                    path.move(to: CGPoint(x: inset, y: inset))
                    path.addLine(to: CGPoint(x: size - inset, y: size - inset))
                    path.move(to: CGPoint(x: size - inset, y: inset))
                    path.addLine(to: CGPoint(x: inset, y: size - inset))
                }
                .stroke(.secondary, lineWidth: line * 0.8)

            case .pastDue:
                Circle().fill(Self.darkRed)
                Image(systemName: "clock")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: -size * 0.04, y: -size * 0.04)
                Text("?")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.36, height: size * 0.36)
                    .background(Circle().fill(Self.darkRed))
                    .overlay(Circle().stroke(.white, lineWidth: max(1, size * 0.04)))
                    .offset(x: size * 0.22, y: size * 0.22)

            case .finished:
                Circle().fill(Self.green)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        StatusIcon(kind: .todo, size: 40)
        StatusIcon(kind: .inProgress, size: 40)
        StatusIcon(kind: .doneToday, size: 40)
        StatusIcon(kind: .notDone, size: 40)
        StatusIcon(kind: .pastDue, size: 40)
        StatusIcon(kind: .finished, size: 40)
    }
    .padding()
}

extension TaskStatus {
    var symbol: String {
        switch self {
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        }
    }
}

/// The task's status icon; tapping it pops up a menu to move the task to
/// to do, in progress or done.
struct StatusMenu: View {
    let task: TaskItem
    let status: TaskStatus
    var size: CGFloat = 26

    @Environment(TaskStore.self) private var store

    var body: some View {
        Menu {
            Picker("Status", selection: Binding(
                get: { status },
                set: { new in Task { await store.setStatus(task, to: new) } }
            )) {
                ForEach(TaskStatus.allCases) { s in
                    Label(s.menuLabel, systemImage: s.symbol).tag(s)
                }
            }
        } label: {
            StatusIcon(kind: .task(task, status: status), size: size)
                .frame(width: size + 8, height: size + 8)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel("Status: \(status.menuLabel)")
    }
}
