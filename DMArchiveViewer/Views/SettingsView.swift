import SwiftUI

enum AppearanceMode: String {
    case dark, light
}

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.dark.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        Text("Dark").tag(AppearanceMode.dark.rawValue)
                        Text("Light").tag(AppearanceMode.light.rawValue)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("Build marker: \(ArchiveStore.buildMarker)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } header: {
                    Text("Debug")
                } footer: {
                    Text("Confirms which build is actually running — check this after reinstalling if something doesn't seem to have taken effect.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
