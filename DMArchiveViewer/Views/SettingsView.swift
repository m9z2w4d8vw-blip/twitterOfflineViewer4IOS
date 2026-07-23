import SwiftUI

enum AppearanceMode: String {
    case dark, light
}

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.dark.rawValue
    // Same key LightboxView reads — UserDefaults keeps them in sync
    // with no extra plumbing.
    @AppStorage("lightboxBackgroundBlur") private var lightboxBackgroundBlur: Double = 0.55
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
                    VStack(alignment: .leading, spacing: 10) {
                        Slider(value: $lightboxBackgroundBlur, in: 0...1)
                        HStack {
                            Text("See-through")
                            Spacer()
                            Text("Opaque")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Photo Viewer")
                } footer: {
                    Text("How much of the conversation shows through the blur behind a photo when you view it full-screen.")
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
