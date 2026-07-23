import SwiftUI
import UIKit

// @AppStorage only knows how to persist simple types (String, Bool,
// Double, Int...) — there's no built-in AppStorage<Color>. Hex string
// is the interchange format between storage and both the ColorPickers
// in Settings and the actual bubble rendering in MessageRowView, both
// of which read/write the same UserDefaults keys independently.
extension Color {
    /// Parses an "#RRGGBBAA" (or "RRGGBBAA") string. Falls back to a
    /// neutral gray on anything malformed rather than crashing — a
    /// stray bad value in UserDefaults shouldn't take the whole
    /// conversation view down with it.
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned.removeAll { $0 == "#" }
        guard cleaned.count == 8, let value = UInt64(cleaned, radix: 16) else {
            self = .gray
            return
        }
        let r = Double((value & 0xFF00_0000) >> 24) / 255
        let g = Double((value & 0x00FF_0000) >> 16) / 255
        let b = Double((value & 0x0000_FF00) >> 8) / 255
        let a = Double(value & 0x0000_00FF) / 255
        self = Color(red: r, green: g, blue: b, opacity: a)
    }

    /// `UIColor.getRed(_:green:blue:alpha:)` converts through whatever
    /// color space the picker handed back, which is more reliable here
    /// than reading `cgColor.components` directly — that array's count
    /// and order isn't guaranteed the same across every color space.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X%02X",
            Int((r * 255).rounded()),
            Int((g * 255).rounded()),
            Int((b * 255).rounded()),
            Int((a * 255).rounded())
        )
    }
}

// Defaults chosen to roughly match how bubbles already looked before
// this was configurable (the app's default theme is dark — see
// AppearanceMode.dark in SettingsView — so these target that, not a
// light background).
enum BubbleColorDefaults {
    static let senderText = "#FFFFFFFF"
    static let senderBubble = "#0A84FCFF"
    static let receiverText = "#FFFFFFFF"
    static let receiverBubble = "#3A3A3CFF"
}
