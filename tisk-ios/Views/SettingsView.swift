import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DateFilter.startViewKey) private var startView = DateFilter.StartView.doing.rawValue
    @AppStorage(WeekStartsOn.storageKey) private var weekStartsOn = WeekStartsOn.default.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Open the app in", selection: $startView) {
                        ForEach(DateFilter.StartView.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Start view")
                } footer: {
                    Text("Choose whether the list starts on when tasks are due or when you plan to do them. The top-left button still switches at any time, and \"Last used\" remembers it.")
                }

                Section {
                    Picker("Week starts on", selection: $weekStartsOn) {
                        ForEach(WeekStartsOn.allCases) { day in
                            Text(day.label).tag(day.rawValue)
                        }
                    }
                } footer: {
                    Text("Used by the week strip when adding a task and in the task detail screen.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
        }
    }
}
