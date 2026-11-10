import Foundation

/// Which weekday a week strip starts on. Persisted in UserDefaults; default Monday.
enum WeekStartsOn: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    static let storageKey = "weekStartsOn"
    static let `default`: WeekStartsOn = .monday

    var label: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }

    static var current: WeekStartsOn {
        let raw = UserDefaults.standard.object(forKey: storageKey) as? Int
        return raw.flatMap(WeekStartsOn.init(rawValue:)) ?? .default
    }

    /// Calendar whose week starts on the user's preferred day.
    var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = rawValue
        return calendar
    }

    /// The first day of the week that contains `date`.
    func startOfWeek(containing date: Date) -> Date {
        let calendar = self.calendar
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysBack = (weekday - rawValue + 7) % 7
        return calendar.date(byAdding: .day, value: -daysBack, to: day) ?? day
    }
}
