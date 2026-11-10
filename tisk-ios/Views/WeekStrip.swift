import SwiftUI

/// Seven day columns (letter over date, then a small cell underneath) with an
/// arrow on each side that pages by a week. Weeks begin on the day chosen in Settings.
struct WeekStrip<Cell: View>: View {
    @Binding var weekStart: Date
    var allowsPast = false
    var showsGrid = false
    /// Draws a vertical bar at the end of the due day (colored like the category chip).
    var dueDate: Date? = nil
    var dueColor: Color = .green
    var onLongPress: ((Date) -> Void)? = nil
    let onSelect: (Date) -> Void
    @ViewBuilder let cell: (Date) -> Cell

    @AppStorage(WeekStartsOn.storageKey) private var weekStartsOnRaw = WeekStartsOn.default.rawValue

    private var weekStartsOn: WeekStartsOn {
        WeekStartsOn(rawValue: weekStartsOnRaw) ?? .default
    }

    private var calendar: Calendar { weekStartsOn.calendar }
    private var today: Date { calendar.startOfDay(for: Date()) }

    private var days: [Date] {
        let start = weekStartsOn.startOfWeek(containing: weekStart)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var canGoBack: Bool {
        allowsPast || weekStartsOn.startOfWeek(containing: weekStart) > weekStartsOn.startOfWeek(containing: today)
    }

    var body: some View {
        HStack(spacing: 0) {
            arrow("chevron.left", enabled: canGoBack) { shift(-7) }

            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    column(day, isLast: index == 6)
                }
            }

            arrow("chevron.right", enabled: true) { shift(7) }
        }
        .onAppear { snapWeekStart() }
        .onChange(of: weekStartsOnRaw) { _, _ in snapWeekStart() }
    }

    private func column(_ day: Date, isLast: Bool) -> some View {
        let isPast = day < today
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isDisabled = isPast && !allowsPast
        return VStack(spacing: 4) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(day.formatted(.dateTime.day()))
                .font(.caption.weight(isToday ? .bold : .regular))
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    if isToday {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor.opacity(0.2))
                    }
                }
                .overlay(alignment: .bottom) {
                    if isToday {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.accentColor)
                            .frame(width: 16, height: 3)
                            .offset(y: 3)
                    }
                }

            Rectangle()
                .fill(showsGrid ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
                .frame(height: 1)

            cell(day)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .overlay(alignment: .trailing) {
                    if let dueDate, calendar.isDate(day, inSameDayAs: dueDate) {
                        Capsule()
                            .fill(dueColor)
                            .frame(width: 4, height: 36)
                            .offset(x: 2)
                            .accessibilityLabel("Due")
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            if showsGrid && !isLast {
                Rectangle().fill(.quaternary).frame(width: 1)
            }
        }
        .opacity(isDisabled ? 0.4 : 1)
        .onTapGesture {
            if !isDisabled {
                Haptics.selection()
                onSelect(day)
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            guard !isDisabled, let onLongPress else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPress(day)
        }
        .accessibilityAddTraits(.isButton)
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(enabled ? .primary : .tertiary)
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "chevron.left" ? "Previous week" : "Next week")
    }

    private func shift(_ days: Int) {
        withAnimation(.easeInOut(duration: 0.15)) {
            let start = weekStartsOn.startOfWeek(containing: weekStart)
            weekStart = calendar.date(byAdding: .day, value: days, to: start) ?? weekStart
        }
    }

    private func snapWeekStart() {
        let snapped = weekStartsOn.startOfWeek(containing: weekStart)
        if !calendar.isDate(snapped, inSameDayAs: weekStart) {
            weekStart = snapped
        }
    }
}

/// True when `day` is a later calendar day than the due date.
func isAfterDue(_ day: Date, due: Date?) -> Bool {
    guard let due else { return false }
    let calendar = Calendar.current
    return calendar.startOfDay(for: day) > calendar.startOfDay(for: due)
}
