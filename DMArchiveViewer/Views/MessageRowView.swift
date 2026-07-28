import SwiftUI
import UIKit

struct MessageRowView: View {
    let message: ArchiveMessage
    var searchQuery: String = ""
    let onImageTap: (UIImage) -> Void
    var onDoubleTap: (() -> Void)? = nil

    // Same keys the ColorPickers in Settings write to — UserDefaults
    // keeps everything in sync with no extra plumbing.
    @AppStorage("senderTextColorHex") private var senderTextColorHex: String = BubbleColorDefaults.senderText
    @AppStorage("senderBubbleColorHex") private var senderBubbleColorHex: String = BubbleColorDefaults.senderBubble
    @AppStorage("receiverTextColorHex") private var receiverTextColorHex: String = BubbleColorDefaults.receiverText
    @AppStorage("receiverBubbleColorHex") private var receiverBubbleColorHex: String = BubbleColorDefaults.receiverBubble

    var body: some View {
        if message.isDivider {
            Text(message.text ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        } else {
            bubbleRow
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { onDoubleTap?() }
        }
    }

    private var isMe: Bool { message.isFromMe }
    private var mediaList: [String] { message.media ?? [] }
    private var hasText: Bool { !(message.text ?? "").isEmpty }
    // A caption-less photo gets its own bubble with no padding or
    // background, the same way the extension's viewer treats it — a
    // colored frame around a bare photo doesn't read as a real chat
    // bubble the way a padded background behind text does.
    private var isMediaOnly: Bool { !hasText && !mediaList.isEmpty }

    private var textColor: Color { Color(hex: isMe ? senderTextColorHex : receiverTextColorHex) }
    private var bubbleColor: Color { Color(hex: isMe ? senderBubbleColorHex : receiverBubbleColorHex) }

    @ViewBuilder
    private var bubbleRow: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
            if let replyPreview = message.replyPreview, !replyPreview.isEmpty {
                Text(replyLabel(replyPreview))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            if isMediaOnly {
                mediaViews
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if hasText {
                        messageText(message.text ?? "")
                    }
                    mediaViews
                    if let time = message.timeLabel, !time.isEmpty {
                        Text(time)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(textColor.opacity(0.65))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
    }

    private func replyLabel(_ quoted: String) -> String {
        if let name = message.replyToName, !name.isEmpty {
            return "↩ \(name): \(quoted)"
        }
        return "↩ \(quoted)"
    }

    @ViewBuilder
    private var mediaViews: some View {
        ForEach(mediaList, id: \.self) { src in
            BubbleMediaThumbnail(src: src, cornerRadius: isMediaOnly ? 18 : 12, onTap: onImageTap)
        }
    }

    // MARK: - Text styling: search highlighting + tappable links
    //
    // Both are just attribute ranges laid over the same
    // AttributedString, so they compose in one pass instead of two
    // separate rendering paths. A word-boundary search hit gets bold +
    // yellow, the same rule as SearchMatching.swift. A plain http(s)
    // URL — the same shape the extension's appendLinkifiedText (in
    // viewer.js) turns into a real <a class="msg-link">, same text
    // color + underline, no color swap — gets AttributedString's
    // `.link` attribute, which SwiftUI's Text renders as a genuinely
    // tappable link with no extra gesture plumbing needed.

    @ViewBuilder
    private func messageText(_ text: String) -> some View {
        Text(styledAttributedString(text))
    }

    private func styledAttributedString(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = textColor
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        if let urlRegex = try? NSRegularExpression(pattern: "https?://[^\\s]+") {
            for match in urlRegex.matches(in: text, range: fullRange) {
                guard let attrRange = Range(match.range, in: attributed) else { continue }
                if let url = URL(string: nsText.substring(with: match.range)) {
                    attributed[attrRange].link = url
                    attributed[attrRange].underlineStyle = .single
                }
            }
        }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespaces)
        if !trimmedQuery.isEmpty,
           let queryRegex = try? NSRegularExpression(
               pattern: "\\b\(NSRegularExpression.escapedPattern(for: trimmedQuery))",
               options: .caseInsensitive
           ) {
            for match in queryRegex.matches(in: text, range: fullRange) {
                guard let attrRange = Range(match.range, in: attributed) else { continue }
                attributed[attrRange].foregroundColor = .yellow
                attributed[attrRange].font = .body.bold()
            }
        }

        return attributed
    }
}

// A `media` entry is either embedded (a data: URL, decodes instantly,
// no network needed) or linked (a plain pbs.twimg.com URL from a
// shared post's preview photo, needs a fetch — see ArchiveMediaLoader
// in DataURLImage.swift). This view covers both: it renders the same
// way once loaded either way, and only shows a spinner/placeholder
// during the brief window a linked photo is still being fetched.
private struct BubbleMediaThumbnail: View {
    let src: String
    let cornerRadius: CGFloat
    let onTap: (UIImage) -> Void

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 240, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .onTapGesture { onTap(image) }
            } else if failed {
                placeholder(systemImage: "photo.badge.exclamationmark")
            } else {
                placeholder(systemImage: nil)
                    .overlay { ProgressView() }
            }
        }
        .task(id: src) {
            guard image == nil, !failed else { return }
            if let loaded = await ArchiveMediaLoader.load(src) {
                image = loaded
            } else {
                failed = true
            }
        }
    }

    @ViewBuilder
    private func placeholder(systemImage: String?) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.systemGray5))
            .frame(width: 160, height: 160)
            .overlay {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(.secondary)
                }
            }
    }
}
