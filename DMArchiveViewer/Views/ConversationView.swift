import SwiftUI
import PhotosUI
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
    @State private var showGallery = false
    @State private var scrollTarget: Int?
    @State private var showWallpaperPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var displayedMessages: [IndexedMessage] {
        let source: [ArchiveMessage]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            source = messages
        } else {
            source = messages.filter { $0.isDivider || messageMatches($0.text, query: searchText) }
        }
        return source.indexed()
    }

    private var mediaItems: [MediaGalleryItem] {
        var items: [MediaGalleryItem] = []
        for (index, message) in messages.enumerated() {
            for src in message.media ?? [] {
                items.append(MediaGalleryItem(messageIndex: index, dataUrl: src))
            }
        }
        return items
    }

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(displayedMessages) { item in
                            MessageRowView(message: item.message) { image in
                                lightboxImage = image
                            }
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation {
                        proxy.scrollTo(target, anchor: .center)
                    }
                    scrollTarget = nil
                }
            }

            if isLoading {
                ProgressView("Loading…")
            }
        }
        .background(wallpaperBackground)
        .navigationTitle(conversationName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search in this conversation")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showGallery = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .accessibilityLabel("View all media")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showWallpaperPicker = true
                    } label: {
                        Label("Choose from Photos", systemImage: "photo")
                    }
                    if wallpaperDataUrl != nil {
                        Button(role: .destructive) {
                            wallpaperDataUrl = nil
                            Task { await store.setWallpaper(for: conversationId, dataUrl: nil) }
                        } label: {
                            Label("Remove Wallpaper", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: wallpaperDataUrl != nil ? "photo.fill" : "photo")
                }
                .accessibilityLabel("Set a wallpaper for this conversation")
            }
        }
        .photosPicker(isPresented: $showWallpaperPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data),
                      let encoded = Self.resizedDataURL(from: uiImage) else {
                    DebugLog.shared.log("wallpaper", "Could not load the picked photo")
                    return
                }
                wallpaperDataUrl = encoded
                await store.setWallpaper(for: conversationId, dataUrl: encoded)
                selectedPhotoItem = nil
            }
        }
        .sheet(isPresented: $showGallery) {
            MediaGalleryView(items: mediaItems) { messageIndex in
                showGallery = false
                searchText = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    scrollTarget = messageIndex
                }
            }
        }
        .task {
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

    private static func resizedDataURL(from image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.85) -> String? {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        guard let jpegData = resized.jpegData(compressionQuality: quality) else { return nil }
        return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }
}
