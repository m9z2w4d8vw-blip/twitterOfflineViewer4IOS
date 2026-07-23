import Foundation

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

    // Visible in the Files app under On My iPhone → DM Archive → "Drop
    // JSON Exports Here", once UIFileSharingEnabled is set in Info.plist.
    // A dedicated subfolder rather than the bare Documents root, so it's
    // obvious where to put a new file without it sitting next to this
    // app's own internal bookkeeping (the index, saved conversations,
    // the debug log).
    private var importsFolderURL: URL {
        let url = documentsURL.appendingPathComponent("Drop JSON Exports Here", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private var importedFolderURL: URL {
        let url = importsFolderURL.appendingPathComponent("Imported", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// Looks in the Files-app-visible drop folder for anything new and
    /// imports it automatically — a path that doesn't depend on the
    /// system document picker's import callback at all, since that
    /// callback wasn't reliably firing in a sideloaded install. A
    /// successfully-imported file gets moved into an "Imported"
    /// subfolder (not deleted) so nothing disappears unexpectedly and
    /// nothing gets re-processed on the next scan. A failed one is left
    /// exactly where it was, so it's still there to retry or inspect.
    func scanImportsFolder() async {
        let folder = importsFolderURL
        guard let items = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return
        }
        let jsonFiles = items.filter { $0.pathExtension.lowercased() == "json" }
        guard !jsonFiles.isEmpty else { return }

        DebugLog.shared.log(
            "import",
            "Drop folder scan found \(jsonFiles.count) file(s)",
            detail: jsonFiles.map(\.lastPathComponent).joined(separator: ", ")
        )

        for fileURL in jsonFiles {
            do {
                try await importFile(at: fileURL)
                let destination = importedFolderURL.appendingPathComponent(fileURL.lastPathComponent)
                try? fileManager.removeItem(at: destination)
                try fileManager.moveItem(at: fileURL, to: destination)
                DebugLog.shared.log("import", "Moved processed file into Imported", detail: fileURL.lastPathComponent)
            } catch {
                DebugLog.shared.log(
                    "import",
                    "Auto-import from drop folder failed — left in place",
                    detail: "\(fileURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
        }
    }

    func delete(id: String) {
        try? fileManager.removeItem(at: conversationFileURL(for: id))
        conversations.removeAll { $0.id == id }
        saveIndex()
    }

    nonisolated private static func readAndDecode(url: URL) async throws -> (Data, ArchiveExport) {
        try await ensureDownloaded(url: url)

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.couldNotReadFile(error.localizedDescription)
        }
        let export = try JSONDecoder().decode(ArchiveExport.self, from: data)
        return (data, export)
    }

    nonisolated private static func ensureDownloaded(url: URL) async throws {
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true else {
            return
        }

        if values.ubiquitousItemDownloadingStatus == .current || values.ubiquitousItemDownloadingStatus == .downloaded {
            return
        }

        await DebugLog.shared.log(
            "import",
            "File is in iCloud and not fully downloaded yet — requesting download",
            detail: url.lastPathComponent
        )
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)

        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
            if status == .current || status == .downloaded {
                await DebugLog.shared.log("import", "iCloud download finished", detail: url.lastPathComponent)
                return
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        await DebugLog.shared.log("import", "Gave up waiting for iCloud download after 30s", detail: url.lastPathComponent)
        throw ImportError.icloudTimeout
    }

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
        case icloudTimeout

        var errorDescription: String? {
            switch self {
            case .couldNotReadFile(let reason):
                return "Couldn't read that file: \(reason)"
            case .decodeFailed(let reason):
                return "This doesn't look like a DM Offline Archive export.\n\n\(reason)"
            case .missingConversationId:
                return "This export is missing a conversation id, so it can't be saved."
            case .icloudTimeout:
                return "This file is stored in iCloud and didn't finish downloading in time. Try opening it directly in the Files app first (which forces a download), then import it again — or check your connection and Low Power Mode."
            }
        }
    }
}
