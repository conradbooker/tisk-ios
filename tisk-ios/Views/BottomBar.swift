import SwiftUI

/// Floating Liquid Glass bar: a capsule of text tabs ("home" plus one per task
/// type) and a separate blue glass + button.
struct BottomBar: View {
    let categories: [TaskCategory]
    @Binding var selection: UUID?   // nil == all
    let isAdding: Bool
    let onAdd: () -> Void
    let onNewCategory: () -> Void
    let onNewTaskType: () -> Void

    @Namespace private var namespace

    private let height: CGFloat = 56

    /// Should be placed inside a `GlassEffectContainer` by the parent.
    var body: some View {
        HStack(spacing: 12) {
            tabs
                .frame(height: height)
                .glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID("tabs", in: namespace)

            // Tap focuses the inline composer; long press shows the create menu.
            Menu {
                Button("New Task Type", systemImage: "tag", action: onNewTaskType)
                Button("New Category", systemImage: "folder.badge.plus", action: onNewCategory)
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isAdding ? 45 : 0))
                    .animation(.easeInOut(duration: 0.15), value: isAdding)
                    .frame(width: height, height: height)
            } primaryAction: {
                onAdd()
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .glassEffect(.regular.tint(isAdding ? .red : .blue).interactive(), in: .circle)
            .glassEffectID("add", in: namespace)
            .accessibilityLabel(isAdding ? "Close new task" : "Add task")
        }
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                tab(title: "all", id: nil)
                ForEach(categories) { category in
                    tab(title: category.title, id: category.id)
                }
            }
            .padding(.horizontal, 6)
        }
        .scrollBounceBehavior(.basedOnSize)
        .contentMargins(.vertical, 6, for: .scrollContent)
    }

    private func tab(title: String, id: UUID?) -> some View {
        let isSelected = selection == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selection = id }
        } label: {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .frame(height: height - 12)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.primary.opacity(0.1))
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview {
    @Previewable @State var selection: UUID?
    GlassEffectContainer(spacing: 12) {
        BottomBar(
            categories: [], selection: $selection,
            isAdding: false, onAdd: {}, onNewCategory: {}, onNewTaskType: {}
        )
    }
    .padding()
}
