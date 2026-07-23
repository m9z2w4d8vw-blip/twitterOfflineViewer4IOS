import Foundation

// Mirrors the export format written by the "Export chat" button in the
// DM Offline Archive Chrome extension exactly — see that project's
// viewer.js `exportConversation`. Every field here is optional except
// what's genuinely guaranteed, since this file is trusting data that
// came from a separate project and could in principle evolve.

struct ArchiveExport: Codable {
    let format: String?
    let exportedAt: Double?
    var conversation: ConversationMeta
    var wallpaperDataUrl: String?
    let messages: [ArchiveMessage]
}

struct ConversationMeta: Codable, Equatable {
    let id: String
    var name: String
    let url: String?
    let savedAt: Double?
    var messageCount: Int?
    var avatarDataUrl: String?
    // Not part of the extension's export — set locally on import so the
    // Library can show when a conversation was brought into this app,
    // separately from when it was originally saved from X.
    var importedAt: Double?
}

struct ArchiveMessage: Codable {
    let kind: String? // "message" | "divider" — treat anything else as a message
    let iso: String?
    let timeLabel: String?
    let sender: String? // "me" | "them"
    let text: String?
    let replyToName: String?
    let replyPreview: String?
    let media: [String]?

    var isDivider: Bool { kind == "divider" }
    var isFromMe: Bool { sender == "me" }
}

// SwiftUI's List/ForEach need stable identity to render and animate
// correctly. The export has no per-message id, and a computed
// Identifiable id using UUID() would generate a new value on every
// access — exactly wrong for that purpose. This wraps each message with
// its array position, assigned once when the array is built, which is
// stable for as long as the array itself isn't reordered (it never is).
struct IndexedMessage: Identifiable {
    let id: Int
    let message: ArchiveMessage
}

extension Array where Element == ArchiveMessage {
    func indexed() -> [IndexedMessage] {
        enumerated().map { IndexedMessage(id: $0.offset, message: $0.element) }
    }
}
