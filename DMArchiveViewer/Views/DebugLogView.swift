import SwiftUI

struct DebugLogView: View {
    @ObservedObject var debugLog = DebugLog.shared
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if debugLog.entries.isEmpty {
                    ContentUnavailableView(
                        "No log entries yet",
                        systemImage: "text.alignleft",
                        description: Text("Import errors and other diagnostics will show up here.")
                    )
                } else {
                    List(debugLog.entries.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.context.uppercased())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(entry.message)
                                .font(.subheadline)
                            if let detail = entry.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Debug Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", role: .destructive) {
                        showClearConfirm = true
                    }
                    .disabled(debugLog.entries.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: debugLog.exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(debugLog.entries.isEmpty)
                }
            }
            .confirmationDialog(
                "Clear the debug log?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) { debugLog.clear() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
