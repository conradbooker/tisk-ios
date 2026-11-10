import Foundation
import Observation

/// Shared state for the floating date panel and the task list filter.
@Observable
final class DateFilter {
    enum Mode: String, CaseIterable, Identifiable {
        case day
        case month
        case off

        var id: String { rawValue }

        var menuLabel: String {
            switch self {
            case .day: "Day"
            case .month: "Month"
            case .off: "All dates (no filter)"
            }
        }
    }

    /// What the date filter and subtitles refer to.
    enum Basis: String, CaseIterable, Identifiable {
        case due        // when a task is due
        case scheduled  // when the user plans to do it (task chips)

        var id: String { rawValue }

        var label: String {
            switch self {
            case .due: "due"
            case .scheduled: "doing"
            }
        }

        var symbol: String {
            switch self {
            case .due: "flag"
            case .scheduled: "calendar.badge.clock"
            }
        }

        var toggled: Basis { self == .due ? .scheduled : .due }
    }

    /// Which view the app starts in (Settings).
    enum StartView: String, CaseIterable, Identifiable {
        case doing
        case due
        case last

        var id: String { rawValue }

        var label: String {
            switch self {
            case .doing: "Doing (when I'll do it)"
            case .due: "Due (when it's due)"
            case .last: "Last used"
            }
        }
    }

    static let startViewKey = "startView"
    static let lastBasisKey = "lastBasis"

    var basis: Basis
    var mode: Mode = .day

    init() {
        let defaults = UserDefaults.standard
        let start = defaults.string(forKey: Self.startViewKey).flatMap(StartView.init(rawValue:)) ?? .doing
        switch start {
        case .doing: basis = .scheduled
        case .due: basis = .due
        case .last:
            basis = defaults.string(forKey: Self.lastBasisKey).flatMap(Basis.init(rawValue:)) ?? .scheduled
        }
    }

    /// Switches between due and doing, remembering the choice across launches.
    func toggleBasis() {
        basis = basis.toggled
        UserDefaults.standard.set(basis.rawValue, forKey: Self.lastBasisKey)
    }
    var anchor: Date = Date()

    private var calendar: Calendar { .current }

    var label: String {
        switch mode {
        case .day:
            anchor.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .month:
            anchor.formatted(.dateTime.month(.wide).year())
        case .off:
            "All dates"
        }
    }

    func matches(_ date: Date?) -> Bool {
        switch mode {
        case .off:
            return true
        case .day:
            guard let date else { return false }
            return calendar.isDate(date, inSameDayAs: anchor)
        case .month:
            guard let date else { return false }
            return calendar.isDate(date, equalTo: anchor, toGranularity: .month)
        }
    }

    func step(_ delta: Int) {
        switch mode {
        case .off:
            mode = .day
            anchor = Date()
        case .day:
            anchor = calendar.date(byAdding: .day, value: delta, to: anchor) ?? anchor
        case .month:
            anchor = calendar.date(byAdding: .month, value: delta, to: anchor) ?? anchor
        }
    }

    func pick(_ date: Date) {
        mode = .day
        anchor = date
    }

    /// Default due date for new tasks: the selected day, otherwise today, at 23:59.
    var defaultDue: Date {
        let base = mode == .day ? anchor : Date()
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: base) ?? base
    }

    var emptyDescription: String {
        switch mode {
        case .off: "Add one above."
        case .day:
            basis == .due
                ? "Nothing is due on this day. Use the arrows or long press the date to change the filter."
                : "Nothing is scheduled on this day. Use the arrows or long press the date to change the filter."
        case .month:
            basis == .due ? "Nothing is due this month." : "Nothing is scheduled this month."
        }
    }
}
