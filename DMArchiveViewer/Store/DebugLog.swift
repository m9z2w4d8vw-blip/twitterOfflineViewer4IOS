import Foundation

// Without Xcode's console attached (this app is meant to be sideloaded,
// not run from a debugger), there's otherwise no way to see what
// actually went wrong when something like an import fails — the same
// gap the Chrome extension's debug log was originally built to close.
// This mirrors that: an in-memory + persisted log, viewable and
// shareable from inside the app itself.
@MainActor
final class DebugLog: ObservableObject {
    static let shared = DebugLog()

    struct Entry: Identifiable, Codable {
        let id: UUID
        let timestamp: Double
        let context: String
        let message: String
        let detail: String?

        init(context: String, message: String, detail: String? = nil) {
            self.id = UUID()
            self.timestamp = Date().timeIntervalSince1970 * 1000
            self.context = context
            self.message = message
            self.detail = detail
        }
    }

    @Published private(set) var entries: [Entry] = []

    private let maxEntries = 2000
    private let fileManager = FileManager.default

    private var logFileURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dm_archive_debug_log.json")
    }

    private init() {
        load()
    }

    func log(_ context: String, _ message: String, detail: String? = nil) {
        let entry = Entry(context: context, message: message, detail: detail)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    /// Formatted for sharing (e.g. via ShareLink) — a single text blob
    /// rather than a JSON dump, since the point is for a person to read
    /// it or paste it, not re-import it anywhere.
    var exportText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return entries.map { entry in
            let date = Date(timeIntervalSince1970: entry.timestamp / 1000)
            var line = "[\(formatter.string(from: date))] [\(entry.context)] \(entry.message)"
            if let detail = entry.detail, !detail.isEmpty {
                line += "\n    \(detail)"
            }
            return line
        }.joined(separator: "\n")
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: logFileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: logFileURL),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = decoded
    }
}
