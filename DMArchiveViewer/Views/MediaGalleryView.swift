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

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("No photos in this conversation", systemImage: "photo.on.rectangle")
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(items) { item in
                                thumbnail(for: item)
                            }
                        }
                        .padding()
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
    private func thumbnail(for item: MediaGalleryItem) -> some View {
        if let uiImage = UIImage(dataURLString: item.dataUrl) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(minHeight: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(item.messageIndex)
                }
        }
    }
}
