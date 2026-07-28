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

// Not every `media` entry is embedded, though. A message that shares a
// link to someone else's public post (see extractEmbeddedCardLink in
// the extension's content-scraper.js) captures that post's preview
// photo as a plain, permanent pbs.twimg.com URL rather than a data:
// URL — unlike a real DM photo, that image was never behind a
// private, expiring blob: URL, so the scraper never had to download
// and embed it. The extension's own viewer just drops the URL
// straight into an <img src>, which is why it renders there for free.
// This app has no such shortcut and was silently treating any
// non-data: string as "failed to decode" — this loader adds the
// missing second path: fetch the URL itself, once, and keep the
// result in memory for the rest of the session.
actor RemoteMediaCache {
    static let shared = RemoteMediaCache()
    private var images: [String: UIImage] = [:]

    func cached(_ key: String) -> UIImage? { images[key] }
    func store(_ key: String, _ image: UIImage) { images[key] = image }
}

enum ArchiveMediaLoader {
    static func load(_ src: String) async -> UIImage? {
        if let embedded = UIImage(dataURLString: src) { return embedded }

        guard let url = URL(string: src),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }

        if let cached = await RemoteMediaCache.shared.cached(src) { return cached }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            await RemoteMediaCache.shared.store(src, image)
            return image
        } catch {
            await DebugLog.shared.log(
                "media",
                "Could not load a linked (non-embedded) photo — this one needs a connection",
                detail: "\(src): \(error.localizedDescription)"
            )
            return nil
        }
    }
}
