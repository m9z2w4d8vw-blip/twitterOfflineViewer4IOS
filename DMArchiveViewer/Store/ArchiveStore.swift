import Foundation

// Persists imported conversations to the app's own Documents directory
// so they survive relaunches without needing to be re-imported every
// time — the whole point of importing rather than just viewing a picked
// file once. A small index file holds just the metadata needed for the
// Library list, so opening the app doesn't require reading every full
// conversation (which can be many megabytes each, given embedded
// photos) just to show names and counts.
@MainActor
final class ArchiveStore: ObservableObject {
    @Published var conversations: [ConversationMeta] = []

    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var indexURL: URL {
        documentsURL.appendingPathComponent("dm_archive_index.json")
    }

    private func conversationFileURL(for id: String) -> URL {
        // Conversation ids look like "1630181465462829057-1896696097785135104"
        // (two numeric ids joined with a hyphen) — already filesystem-safe,
        // but this guards against anything unexpected turning up in a
        // future export format anyway.
        let safe = id.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return documentsURL.appendingPathComponent("conversation_\(safe).json")
    }

    func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        if let decoded = try? JSONDecoder().decode([ConversationMeta].self, from: data) {
            conversations = decoded.sorted { ($0.savedAt ?? 0) > ($1.savedAt ?? 0) }
        }
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    /// Imports one exported .json file. Throws with a message suitable
    /// for showing directly to the person. Runs the actual file read and
    /// JSON decode off the main actor — a large, photo-heavy export
    /// doing that work synchronously on the main thread was a likely
    /// cause of the app appearing to hang (or getting killed by the
    /// watchdog for blocking too long) rather than failing with a clear
    /// error message.
    func importFile(at url: URL) async throws {
        DebugLog.shared.log("import", "Starting import", detail: url.lastPathComponent)

        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        let rawData: Data
        let export: ArchiveExport
        do {
            (rawData, export) = try await Self.readAndDecode(url: url)
        } catch let error as ImportError {
            DebugLog.shared.log("import", "Import failed", detail: error.errorDescription)
            throw error
        } catch {
            let detail = Self.describe(error)
            DebugLog.shared.log("import", "Import failed — could not read/decode the file", detail: detail)
            throw ImportError.decodeFailed(detail)
        }

        guard !export.conversation.id.isEmpty else {
            DebugLog.shared.log("import", "Import failed — export has no conversation id")
            throw ImportError.missingConversationId
        }

        try rawData.write(to: conversationFileURL(for: export.conversation.id), options: .atomic)

        var meta = export.conversation
        meta.importedAt = Date().timeIntervalSince1970 * 1000
        if meta.messageCount == nil {
            meta.messageCount = export.messages.filter { !$0.isDivider }.count
        }

        if let idx = conversations.firstIndex(where: { $0.id == meta.id }) {
            conversations[idx] = meta
        } else {
            conversations.append(meta)
        }
        conversations.sort { ($0.savedAt ?? 0) > ($1.savedAt ?? 0) }
        saveIndex()

        DebugLog.shared.log(
            "import",
            "Import succeeded",
            detail: "\(meta.name) — \(meta.messageCount ?? 0) messages, \(rawData.count) bytes"
        )
    }

    func loadFullExport(for id: String) async -> ArchiveExport? {
        let fileURL = conversationFileURL(for: id)
        do {
            return try await Self.readAndDecodeExisting(url: fileURL)
        } catch {
            DebugLog.shared.log("load", "Could not load stored conversation", detail: Self.describe(error))
            return nil
        }
    }

    nonisolated private static func readAndDecodeExisting(url: URL) async throws -> ArchiveExport {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ArchiveExport.self, from: data)
    }

    func delete(id: String) {
        try? fileManager.removeItem(at: conversationFileURL(for: id))
        conversations.removeAll { $0.id == id }
        saveIndex()
    }

    // Off the main actor deliberately — see importFile's comment above.
    nonisolated private static func readAndDecode(url: URL) async throws -> (Data, ArchiveExport) {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.couldNotReadFile(error.localizedDescription)
        }
        let export = try JSONDecoder().decode(ArchiveExport.self, from: data)
        return (data, export)
    }

    /// Turns a DecodingError into something that actually says what's
    /// wrong and where — "doesn't look like an export" alone isn't
    /// enough to fix a real schema mismatch, and this is the whole
    /// reason the debug log exists.
    nonisolated private static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map(\.stringValue).joined(separator: " → ")
        }
        switch decodingError {
        case .keyNotFound(let key, let context):
            return "Missing field \"\(key.stringValue)\" at [\(path(context))]"
        case .typeMismatch(let type, let context):
            return "Expected \(type) at [\(path(context))]: \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Missing value of type \(type) at [\(path(context))]"
        case .dataCorrupted(let context):
            return "Corrupted JSON at [\(path(context))]: \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    enum ImportError: LocalizedError {
        case couldNotReadFile(String)
        case decodeFailed(String)
        case missingConversationId

        var errorDescription: String? {
            switch self {
            case .couldNotReadFile(let reason):
                return "Couldn't read that file: \(reason)"
            case .decodeFailed(let reason):
                return "This doesn't look like a DM Offline Archive export.\n\n\(reason)"
            case .missingConversationId:
                return "This export is missing a conversation id, so it can't be saved."
            }
        }
    }
}
