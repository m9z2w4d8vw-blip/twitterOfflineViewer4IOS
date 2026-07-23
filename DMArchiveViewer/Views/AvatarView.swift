import SwiftUI
import UIKit

// Mirrors the extension viewer's avatar behavior: a real photo when one
// was captured, otherwise a deterministically-colored circle with the
// conversation's first initial, so a given name always lands on the
// same color rather than a random one each time.
struct AvatarView: View {
    let name: String
    let dataUrl: String?
    var size: CGFloat = 40

    private static let palette: [Color] = [
        Color(red: 1.0, green: 0.42, blue: 0.42),
        Color(red: 1.0, green: 0.66, blue: 0.30),
        Color(red: 1.0, green: 0.83, blue: 0.23),
        Color(red: 0.41, green: 0.86, blue: 0.49),
        Color(red: 0.22, green: 0.82, blue: 0.66),
        Color(red: 0.30, green: 0.67, blue: 0.97),
        Color(red: 0.45, green: 0.56, blue: 0.99),
        Color(red: 0.69, green: 0.59, blue: 0.99),
        Color(red: 0.90, green: 0.60, blue: 0.97),
        Color(red: 0.97, green: 0.51, blue: 0.67),
    ]

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    private var backgroundColor: Color {
        guard !name.isEmpty else { return .gray }
        let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Self.palette[hash % Self.palette.count]
    }

    var body: some View {
        Group {
            if let dataUrl, let uiImage = UIImage(dataURLString: dataUrl) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Circle().fill(backgroundColor)
                    Text(initial.isEmpty ? "?" : initial)
                        .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
