import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var store = ArchiveStore()
    @State private var showImporter = false
    @State private var showDebugLog = false
    @State private var importErrorMessage: String?
    @State private var isImporting = false
    @State private var searchText = ""

    // .json alone was too strict in practice — a file that arrived via
    // AirDrop or as an email/Files attachment doesn't always end up
    // tagged with a clean "public.json" type, which could make it not
    // even show up as selectable in the picker (looking exactly like
    // "the file won't import" from the outside, with no error at all
    // to explain why). Falling back through plainText/data/item covers
    // that regardless of how the file's type metadata ended up tagged.
    private let importTypes: [UTType] = [.json, .plainText, .data, .item]

    private var filtered: [ConversationMeta] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return store.conversations }
        return store.conversations.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.conversations.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("DM Offline Archive")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDebugLog = true
                    } label: {
                        Image(systemName: "ladybug")
                    }
                    .accessibilityLabel("Debug log")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isImporting {
                        ProgressView()
                    } else {
                        Button {
                            showImporter = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .accessibilityLabel("Import export file")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search")
        }
        .onAppear { store.loadIndex() }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: importTypes,
            allowsMultipleSelection: true
        ) { result in
            handleImportResult(result)
        }
        .sheet(isPresented: $showDebugLog) {
            DebugLogView()
        }
        .alert(
            "Couldn't import that file",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) { importErrorMessage = nil }
                Button("View debug log") {
                    importErrorMessage = nil
                    showDebugLog = true
                }
            },
            message: { Text(importErrorMessage ?? "") }
        )
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No conversations yet", systemImage: "tray")
        } description: {
            Text("Import a .json file exported from the DM Offline Archive browser extension using the button above.")
        } actions: {
            Button("Import a file") { showImporter = true }
        }
    }

    private var list: some View {
        List {
            ForEach(filtered, id: \.id) { convo in
                NavigationLink {
                    ConversationView(
                        store: store,
                        conversationId: convo.id,
                        conversationName: convo.name,
                        avatarDataUrl: convo.avatarDataUrl
                    )
                } label: {
                    row(for: convo)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    store.delete(id: filtered[index].id)
                }
            }
        }
    }

    private func row(for convo: ConversationMeta) -> some View {
        HStack(spacing: 12) {
            AvatarView(name: convo.name, dataUrl: convo.avatarDataUrl, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(convo.name)
                    .font(.headline)
                Text("\(convo.messageCount ?? 0) messages")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            isImporting = true
            Task {
                for url in urls {
                    do {
                        try await store.importFile(at: url)
                    } catch {
                        importErrorMessage = error.localizedDescription
                    }
                }
                isImporting = false
            }
        case .failure(let error):
            DebugLog.shared.log("import", "File picker returned an error", detail: error.localizedDescription)
            importErrorMessage = error.localizedDescription
        }
    }
}
