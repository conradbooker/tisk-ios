import SwiftUI

enum NewEntityKind: String, Identifiable {
    case category
    case taskType

    var id: String { rawValue }

    var heading: String {
        switch self {
        case .category: "New Category"
        case .taskType: "New Task Type"
        }
    }

    var placeholder: String {
        switch self {
        case .category: "Category name"
        case .taskType: "Task type name"
        }
    }
}

struct NewEntitySheet: View {
    let kind: NewEntityKind

    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var parentId: UUID?
    @State private var backgroundHex = CategorySwatch.all[0].background
    @State private var borderHex = CategorySwatch.all[0].border
    @State private var customColor: Color = .blue
    @State private var isSaving = false
    @FocusState private var focused: Bool

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    private var isCustomColor: Bool {
        !CategorySwatch.all.contains { $0.background == backgroundHex }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(kind.placeholder, text: $title)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(save)
                }

                Section {
                    Picker("Parent", selection: $parentId) {
                        Text("None").tag(UUID?.none)
                        switch kind {
                        case .category:
                            ForEach(store.visibleCategories) { category in
                                Text(store.path(for: category)).tag(UUID?.some(category.id))
                            }
                        case .taskType:
                            ForEach(store.visibleTaskTypes) { type in
                                Text(store.path(for: type)).tag(UUID?.some(type.id))
                            }
                        }
                    }
                }

                if kind == .category {
                    Section("Color") {
                        colorRow
                    }
                }
            }
            .navigationTitle(kind.heading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", role: .confirm, action: save)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.height(kind == .category ? 380 : 270)])
        .onAppear { focused = true }
    }

    // MARK: Color row

    private var colorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CategorySwatch.all) { swatch in
                    swatchButton(
                        background: swatch.background,
                        border: swatch.border,
                        selected: swatch.background == backgroundHex
                    ) {
                        backgroundHex = swatch.background
                        borderHex = swatch.border
                    }
                    .accessibilityLabel(swatch.name)
                }

                if isCustomColor {
                    swatchButton(background: backgroundHex, border: borderHex, selected: true) {}
                        .accessibilityLabel("Custom color")
                }

                plusColorPicker
            }
            .padding(.vertical, 4)
        }
    }

    private func swatchButton(
        background: String,
        border: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: background) ?? .secondary)
                .overlay(Circle().stroke(Color(hex: border) ?? .secondary, lineWidth: 1.5))
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    /// A "+" button that opens the system color picker. The picker's own well is
    /// kept almost invisible on top of the plus so taps reach it.
    private var plusColorPicker: some View {
        ZStack {
            Circle()
                .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [3]))
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ColorPicker("Custom color", selection: $customColor, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.3)
                .opacity(0.02)
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .accessibilityLabel("Pick a custom color")
        .onChange(of: customColor) { _, color in
            backgroundHex = color.hexString
            borderHex = color.darkenedHexString
        }
    }

    // MARK: Save

    private func save() {
        guard canSave else { return }
        isSaving = true
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let ok: Bool
            switch kind {
            case .category:
                ok = await store.addCategory(
                    title: name,
                    backgroundHex: backgroundHex,
                    borderHex: borderHex,
                    parentId: parentId
                ) != nil
            case .taskType:
                ok = await store.addTaskType(title: name, parentId: parentId) != nil
            }
            isSaving = false
            if ok { dismiss() }
        }
    }
}
