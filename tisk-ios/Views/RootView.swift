import SwiftUI

struct RootView: View {
    let email: String?

    @State private var store = TaskStore()
    @State private var dateFilter = DateFilter()
    @State private var selectedTab: UUID?   // nil == all (every category)
    @State private var showingComposer = false
    @State private var creating: NewEntityKind?
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            TaskListView(
                selectedTab: selectedTab,
                email: email,
                showComposer: showingComposer
            )
            .navigationDestination(for: UUID.self) { id in
                TaskDetailView(taskId: id)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if path.isEmpty {
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 10) {
                    DatePanel()
                    BottomBar(
                        categories: store.topLevelCategories,
                        selection: $selectedTab,
                        isAdding: showingComposer,
                        onAdd: {
                            Haptics.medium()
                            withAnimation(.easeInOut(duration: 0.15)) { showingComposer.toggle() }
                        },
                        onNewCategory: { creating = .category },
                        onNewTaskType: { creating = .taskType }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            // Stay put behind the keyboard so the list can scroll all the way down.
            .ignoresSafeArea(.keyboard)
            }
        }
        .sheet(item: $creating) { kind in
            NewEntitySheet(kind: kind)
        }
        // Applied after safeAreaInset and sheet so the bottom panels and sheets
        // also receive these environment values.
        .environment(store)
        .environment(dateFilter)
        .environment(\.openTask) { id in path.append(id) }
        .task {
            await store.load()
        }
        .onChange(of: store.topLevelCategories) { _, categories in
            // If the selected category disappears, fall back to all.
            if let selectedTab, !categories.contains(where: { $0.id == selectedTab }) {
                self.selectedTab = nil
            }
        }
    }
}
