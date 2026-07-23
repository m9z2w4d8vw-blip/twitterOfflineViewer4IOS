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
            if let uiImage = UIImage(dataURLString: src) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 240, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: isMediaOnly ? 18 : 12, style: .continuous))
                    .onTapGesture { onImageTap(uiImage) }
            }
        }
    }

    // MARK: - Search highlighting
    //
    // Matches the same word-boundary rule as `messageMatches` (see
    // SearchMatching.swift), but instead of a yes/no answer, this walks
    // every match and rebuilds the line as concatenated `Text` segments
    // — bold + yellow for the hit, the base bubble color everywhere
    // else. SwiftUI's `Text` has no supported way to attach a
    // *background* color to part of a line (that's a UIKit /
    // NSAttributedString feature that `Text(AttributedString)` doesn't
    // expose), so a literal highlighter-pen box isn't available here
    // without dropping to a UILabel bridge. Bold + color reads clearly
    // as "this is the match" without that complexity, and — because
    // it's built with `Text + Text` rather than separate views — it
    // still wraps as one normal paragraph instead of breaking into an
    // HStack of fixed-width chunks.

    @ViewBuilder
    private func messageText(_ text: String) -> some View {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Text(text).foregroundColor(textColor)
        } else {
            highlighted(text, query: trimmed, baseColor: textColor)
        }
    }

    private func highlighted(_ text: String, query: String, baseColor: Color) -> Text {
        guard let regex = try? NSRegularExpression(
            pattern: "\\b\(NSRegularExpression.escapedPattern(for: query))",
            options: .caseInsensitive
        ) else {
            return Text(text).foregroundColor(baseColor)
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else {
            return Text(text).foregroundColor(baseColor)
        }

        var result = Text("")
        var cursor = 0
        for match in matches {
            guard match.range.location >= cursor else { continue }
            if match.range.location > cursor {
                let before = nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                result = result + Text(before).foregroundColor(baseColor)
            }
            let matched = nsText.substring(with: match.range)
            result = result + Text(matched).bold().foregroundColor(.yellow)
            cursor = match.range.location + match.range.length
        }
        if cursor < nsText.length {
            result = result + Text(nsText.substring(from: cursor)).foregroundColor(baseColor)
        }
        return result
    }
}
