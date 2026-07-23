import SwiftUI
import UIKit

struct MessageRowView: View {
    let message: ArchiveMessage
    let onImageTap: (UIImage) -> Void

    var body: some View {
        if message.isDivider {
            Text(message.text ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        } else {
            bubbleRow
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
                        Text(message.text ?? "")
                            .foregroundStyle(isMe ? .white : .primary)
                    }
                    mediaViews
                    if let time = message.timeLabel, !time.isEmpty {
                        Text(time)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(isMe ? .white.opacity(0.65) : .secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isMe ? Color.accentColor : Color(.systemFill))
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
}
