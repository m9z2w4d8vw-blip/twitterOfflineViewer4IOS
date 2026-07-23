import SwiftUI
import UIKit

struct MediaGalleryItem: Identifiable {
    let id = UUID()
    let messageIndex: Int
    let dataUrl: String
}

struct MediaGalleryView: View {
    let items: [MediaGalleryItem]
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    // Fixed 3-column grid, edge-to-edge, perfectly square cells — this
    // is what X's own "Shared media" screen looks like. The previous
    // version used an adaptive grid with `.aspectRatio(1, contentMode:
    // .fill)` and only a `minHeight`, with no matching fixed width —
    // that left the layout system free to size cells inconsistently,
    // which is why thumbnails came out uneven. Computing an exact
    // square side from the available width and using `.fixed(side)`
    // columns removes that ambiguity entirely.
    private let columnCount = 3
    private let spacing: CGFloat = 2

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("No photos in this conversation", systemImage: "photo.on.rectangle")
                } else {
                    GeometryReader { proxy in
                        let totalSpacing = spacing * CGFloat(columnCount - 1)
                        let side = (proxy.size.width - totalSpacing) / CGFloat(columnCount)
                        ScrollView {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.fixed(side), spacing: spacing), count: columnCount),
                                spacing: spacing
                            ) {
                                ForEach(items) { item in
                                    thumbnail(for: item, side: side)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Media in this conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for item: MediaGalleryItem, side: CGFloat) -> some View {
        Group {
            if let uiImage = UIImage(dataURLString: item.dataUrl) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipped()
            } else {
                Color(.systemGray5).frame(width: side, height: side)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(item.messageIndex) }
    }
}
