import SwiftUI

/// Floating Liquid Glass capsule showing the active date filter with arrows on
/// each side. Tap the date for a calendar; long press for Day / Month / All.
struct DatePanel: View {
    @Environment(DateFilter.self) private var filter
    @State private var showingCalendar = false

    private let height: CGFloat = 48

    var body: some View {
        @Bindable var filter = filter

        HStack(spacing: 0) {
            arrow("chevron.left", label: "Previous") { filter.step(-1) }

            Menu {
                Picker("Filter by", selection: $filter.mode.animation(.easeInOut(duration: 0.15))) {
                    ForEach(DateFilter.Mode.allCases) { mode in
                        Text(mode.menuLabel).tag(mode)
                    }
                }
            } label: {
                Text(filter.label)
                    .font(.headline)
                    .foregroundStyle(filter.mode == .off ? .secondary : .primary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .frame(minWidth: 140)
                    .frame(height: height)
                    .contentShape(Rectangle())
            } primaryAction: {
                Haptics.light()
                showingCalendar = true
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .popover(isPresented: $showingCalendar) {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { filter.anchor },
                        set: { filter.pick($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(width: 320)
                .padding(12)
                .presentationCompactAdaptation(.popover)
            }

            arrow("chevron.right", label: "Next") { filter.step(1) }
        }
        .padding(.horizontal, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(.easeInOut(duration: 0.15), value: filter.label)
        .sensoryFeedback(.selection, trigger: filter.label)
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: height, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
