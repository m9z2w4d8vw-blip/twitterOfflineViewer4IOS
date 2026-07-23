import UIKit

// Every photo, avatar, and wallpaper in an export arrives as a
// data:image/...;base64,... string rather than a URL to fetch — that's
// deliberate on the extension's side, since the whole point is an
// archive that still works with no network at all. This decodes that
// same format on the iOS side.
extension UIImage {
    convenience init?(dataURLString: String?) {
        guard let dataURLString, let commaIndex = dataURLString.firstIndex(of: ",") else { return nil }
        let base64Part = String(dataURLString[dataURLString.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64Part) else { return nil }
        self.init(data: data)
    }
}
