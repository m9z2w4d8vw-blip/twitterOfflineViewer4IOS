import SwiftUI
import UIKit

enum AppearanceMode: String {
    case dark, light
}

// One case per icon actually built into the app (see
// Assets.xcassets/AppIcon-Discreet.appiconset, and
// ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES in project.yml, which
// is what registers it with iOS as a real alternate icon). Adding
// another option later means: drop in a new .appiconset, add its name
// to that build setting, and add one case here — the picker UI below
// doesn't need to change.
enum AppIconOption: String, CaseIterable, Identifiable {
    case classic
    case discreet

    var id: String { rawValue }

    /// `nil` is the sentinel `UIApplication.setAlternateIconName`
    /// expects for "switch back to the primary icon" — it's not a
    /// missing case.
    var alternateIconName: String? {
        switch self {
        case .classic: return nil
        case .discreet: return "AppIcon-Discreet"
        }
    }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .discreet: return "Discreet"
        }
    }

    // A plain swatch stands in for a real thumbnail here rather than
    // trying to load the icon art back out of the asset catalog —
    // whether `UIImage(named:)` can reliably read an App-Icon-type
    // catalog entry (as opposed to a normal image set) isn't something
    // worth risking on an unverified assumption for a settings row.
    var swatchColor: Color {
        switch self {
        case .classic: return Color(hex: "#0A84FCFF")
        case .discreet: return Color(hex: "#3A3A3CFF")
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.dark.rawValue
    // Same key LightboxView reads — UserDefaults keeps them in sync
    // with no extra plumbing.
    @AppStorage("lightboxBackgroundBlur") private var lightboxBackgroundBlur: Double = 0.55

    @AppStorage("senderTextColorHex") private var senderTextColorHex: String = BubbleColorDefaults.senderText
    @AppStorage("senderBubbleColorHex") private var senderBubbleColorHex: String = BubbleColorDefaults.senderBubble
    @AppStorage("receiverTextColorHex") private var receiverTextColorHex: String = BubbleColorDefaults.receiverText
    @AppStorage("receiverBubbleColorHex") private var receiverBubbleColorHex: String = BubbleColorDefaults.receiverBubble

    // Same key LibraryView's navigationTitle reads.
    @AppStorage("appDisplayName") private var appDisplayName: String = "DM Offline Archive"

    @State private var currentAlternateIconName: String? = UIApplication.shared.alternateIconName
    @State private var iconSwitchError: String?

    @Environment(\.dismiss) private var dismiss

    private var senderTextColor: Binding<Color> {
        Binding(get: { Color(hex: senderTextColorHex) }, set: { senderTextColorHex = $0.hexString })
    }
    private var senderBubbleColor: Binding<Color> {
        Binding(get: { Color(hex: senderBubbleColorHex) }, set: { senderBubbleColorHex = $0.hexString })
    }
    private var receiverTextColor: Binding<Color> {
        Binding(get: { Color(hex: receiverTextColorHex) }, set: { receiverTextColorHex = $0.hexString })
    }
    private var receiverBubbleColor: Binding<Color> {
        Binding(get: { Color(hex: receiverBubbleColorHex) }, set: { receiverBubbleColorHex = $0.hexString })
    }

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
                    ColorPicker("Your text", selection: senderTextColor, supportsOpacity: false)
                    ColorPicker("Your bubble", selection: senderBubbleColor, supportsOpacity: false)
                    ColorPicker("Their text", selection: receiverTextColor, supportsOpacity: false)
                    ColorPicker("Their bubble", selection: receiverBubbleColor, supportsOpacity: false)
                    Button("Reset to Default Colors", role: .destructive) {
                        senderTextColorHex = BubbleColorDefaults.senderText
                        senderBubbleColorHex = BubbleColorDefaults.senderBubble
                        receiverTextColorHex = BubbleColorDefaults.receiverText
                        receiverBubbleColorHex = BubbleColorDefaults.receiverBubble
                    }
                } header: {
                    Text("Message Colors")
                } footer: {
                    Text("Text and bubble background, set independently for your messages and theirs.")
                }

                Section {
                    TextField("App name", text: $appDisplayName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("App Name")
                } footer: {
                    Text("Changes the title shown inside the app (at the top of the conversation list). iOS doesn't give any app a way to rename its own Home Screen icon label at runtime — that one is fixed at build time in Info.plist and currently reads \"\(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "—")\". Changing that one for real means editing Info.plist and reinstalling.")
                }

                Section {
                    ForEach(AppIconOption.allCases) { option in
                        Button {
                            setIcon(option)
                        } label: {
                            HStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(option.swatchColor)
                                    .frame(width: 40, height: 40)
                                Text(option.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if currentAlternateIconName == option.alternateIconName {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } header: {
                    Text("App Icon")
                } footer: {
                    Text("iOS shows its own confirmation before the Home Screen icon actually changes. This only switches between icons built into the app — no app can use an arbitrary photo as its own icon.")
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
            .alert(
                "Couldn't change the icon",
                isPresented: Binding(
                    get: { iconSwitchError != nil },
                    set: { if !$0 { iconSwitchError = nil } }
                ),
                actions: { Button("OK", role: .cancel) { iconSwitchError = nil } },
                message: { Text(iconSwitchError ?? "") }
            )
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func setIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            iconSwitchError = "This device/build doesn't support alternate icons."
            return
        }
        guard currentAlternateIconName != option.alternateIconName else { return }
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            DispatchQueue.main.async {
                if let error {
                    DebugLog.shared.log("settings", "Could not switch app icon", detail: error.localizedDescription)
                    iconSwitchError = error.localizedDescription
                } else {
                    currentAlternateIconName = option.alternateIconName
                }
            }
        }
    }
}
