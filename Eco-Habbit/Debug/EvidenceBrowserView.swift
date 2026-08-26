import SwiftUI

/// Every photo kept on this device, and which log it belongs to.
///
/// Reads the directory rather than the logs on purpose: a photo whose log has been
/// undone still appears, which is exactly what you want to see when checking that
/// deletion works. The id under each thumbnail is the log's `remoteId` —
/// `{habitId}_{localDate}` — the same string Firestore uses as the document id, so a
/// photo and its log can always be matched by eye.
struct EvidenceBrowserView: View {
    @EnvironmentObject private var app: AppState

    @State private var saved: [EvidenceStore.Saved] = []
    @State private var zoomed: EvidenceStore.Saved?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        ScrollView {
            if saved.isEmpty {
                Text("No photos yet.\nLog an action through the camera — both the automatic match and the picker keep one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .padding(.horizontal, 32)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(saved) { item in
                        cell(item)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Saved photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !saved.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete all", role: .destructive) {
                        app.purgeEvidence()
                        reload()
                    }
                }
            }
        }
        .onAppear(perform: reload)
        .sheet(item: $zoomed) { item in
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        if let image = UIImage(contentsOfFile: item.url.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        }
                        LabeledContent("Log id", value: item.id)
                        LabeledContent("Size", value: format(item.bytes))
                        LabeledContent("Path", value: item.url.lastPathComponent)
                    }
                    .padding()
                }
                .navigationTitle("Evidence")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { zoomed = nil }
                    }
                }
            }
        }
    }

    private func cell(_ item: EvidenceStore.Saved) -> some View {
        VStack(spacing: 4) {
            if let image = UIImage(contentsOfFile: item.url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Text(item.id)
                .font(.system(size: 9, design: .monospaced))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(format(item.bytes))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { zoomed = item }
        .contextMenu {
            Button("Delete", role: .destructive) {
                app.deleteEvidence(id: item.id)
                reload()
            }
        }
    }

    private func reload() { saved = app.savedEvidence }

    private func format(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
