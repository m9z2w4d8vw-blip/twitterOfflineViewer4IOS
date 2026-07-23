import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var store = ArchiveStore()
    @State private var showImporter = false
    @State private var showDebugLog = false
    @State private var showSettings = false
    @State private var importErrorMessage: String?
    @State private var isImporting = false
    @State private var searchText = ""
    @Environment(\.scenePhase) private var scenePhase

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
                    HStack(spacing: 16) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")

                        Button {
                            showDebugLog = true
                        } label: {
                            Image(systemName: "ladybug")
                        }
                        .accessibilityLabel("Debug log")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isImporting {
                        ProgressView()
                    } else {
                        HStack(spacing: 16) {
                            Button {
                                Task { await store.scanImportsFolder() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("Check the drop folder for new files")

                            Button {
                                showImporter = true
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                            }
                            .accessibilityLabel("Import export file")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search")
        }
        .onAppear {
            store.logLaunchDiagnostics()
            store.loadIndex()
            Task { await store.scanImportsFolder() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await store.scanImportsFolder() }
            }
        }
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
            VStack(spacing: 10) {
                Text("Open the Files app → On My iPhone → DM Archive → \"Drop JSON Exports Here\", and copy an export .json file in. It's picked up automatically.")
                Text("If Files doesn't show that folder, this is the exact path (usable directly in Filza or a similar tool):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(store.importsFolderPath)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        } actions: {
            HStack(spacing: 16) {
                Button("Check now") { Task { await store.scanImportsFolder() } }
                Button("Use file picker instead") { showImporter = true }
            }
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
        .refreshable {
            await store.scanImportsFolder()
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
            DebugLog.shared.log(
                "import",
                "File picker returned successfully",
                detail: "\(urls.count) file(s): \(urls.map(\.lastPathComponent).joined(separator: ", "))"
            )
            guard !urls.isEmpty else {
                DebugLog.shared.log("import", "Picker returned zero URLs — nothing to import, and nothing else will happen")
                return
            }
            isImporting = true
            Task {
                for url in urls {
                    do {
                        try await store.importFile(at: url)
                    } catch {
                        DebugLog.shared.log("import", "importFile threw", detail: error.localizedDescription)
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
