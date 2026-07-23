import SwiftUI
import UIKit

struct ConversationView: View {
    @ObservedObject var store: ArchiveStore
    let conversationId: String
    let conversationName: String
    let avatarDataUrl: String?

    @State private var messages: [ArchiveMessage] = []
    @State private var wallpaperDataUrl: String?
    @State private var searchText = ""
    @State private var lightboxImage: UIImage?
    @State private var didLoad = false
    @State private var isLoading = false

    private var displayedMessages: [IndexedMessage] {
        let source: [ArchiveMessage]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            source = messages
        } else {
            source = messages.filter { $0.isDivider || messageMatches($0.text, query: searchText) }
        }
        return source.indexed()
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(displayedMessages) { item in
                        MessageRowView(message: item.message) { image in
                            lightboxImage = image
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }

            if isLoading {
                ProgressView("Loading…")
            }
        }
        .background(wallpaperBackground)
        .navigationTitle(conversationName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search in this conversation")
        .task {
            // .onAppear can fire more than once as views re-mount inside
            // a NavigationStack; loading once per screen instance is
            // enough, and avoids re-decoding a potentially large export
            // repeatedly.
            guard !didLoad else { return }
            didLoad = true
            isLoading = true
            if let export = await store.loadFullExport(for: conversationId) {
                messages = export.messages
                wallpaperDataUrl = export.wallpaperDataUrl
            }
            isLoading = false
        }
        .fullScreenCover(isPresented: Binding(
            get: { lightboxImage != nil },
            set: { if !$0 { lightboxImage = nil } }
        )) {
            if let lightboxImage {
                LightboxView(image: lightboxImage)
            }
        }
    }

    @ViewBuilder
    private var wallpaperBackground: some View {
        if let wallpaperDataUrl, let uiImage = UIImage(dataURLString: wallpaperDataUrl) {
            GeometryReader { proxy in
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
        } else {
            Color(.systemBackground)
        }
    }
}
