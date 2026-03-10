import SwiftUI

struct DownloadsView: View {
    @Bindable var chatViewModel: ChatViewModel
    @State private var downloadedModels: [DownloadedModel] = []
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @State private var showDeleteAllConfirmation = false
    @State private var modelToDelete: DownloadedModel?

    /// HuggingFace Hub cache — where MLXLLM and the Hub Swift package store models.
    private var hubCacheDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
    }

    private var totalSizeFormatted: String {
        let total = downloadedModels.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Scanning downloads...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if downloadedModels.isEmpty {
                    ContentUnavailableView {
                        Label("No Downloads", systemImage: "arrow.down.circle")
                    } description: {
                        Text("Models you download will appear here.")
                    }
                } else {
                    List {
                        ForEach(downloadedModels) { model in
                            DownloadedModelRow(
                                model: model,
                                isLoaded: isModelLoaded(model),
                                onLoad: { loadModel(model) },
                                onDelete: {
                                    modelToDelete = model
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 12) {
                        if !downloadedModels.isEmpty {
                            Text(totalSizeFormatted)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(downloadedModels.count) models")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task { await scanDownloads() }
                        }
                        .labelStyle(.iconOnly)

                        if downloadedModels.count > 1 {
                            Button("Remove All", systemImage: "trash", role: .destructive) {
                                showDeleteAllConfirmation = true
                            }
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
            .task { await scanDownloads() }
            .alert("Delete Model?", isPresented: $showDeleteConfirmation, presenting: modelToDelete) { model in
                Button("Delete", role: .destructive) { deleteModel(model) }
                Button("Cancel", role: .cancel) { }
            } message: { model in
                Text("This will remove \(model.displayName) (\(model.sizeFormatted)) from your Mac. You can re-download it later.")
            }
            .alert("Remove All Models?", isPresented: $showDeleteAllConfirmation) {
                Button("Remove All", role: .destructive) { deleteAllModels() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove all \(downloadedModels.count) downloaded models (\(totalSizeFormatted)) from your Mac. You can re-download them later.")
            }
        }
    }

    private func scanDownloads() async {
        isLoading = true
        let fm = FileManager.default
        let hubDir = hubCacheDirectory

        guard let entries = try? fm.contentsOfDirectory(atPath: hubDir.path()) else {
            downloadedModels = []
            isLoading = false
            return
        }

        var found: [DownloadedModel] = []

        for entry in entries {
            // HF Hub cache format: models--{author}--{modelName}
            guard entry.hasPrefix("models--") else { continue }

            let parts = entry.dropFirst("models--".count).split(separator: "--", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let author = String(parts[0])
            let modelName = String(parts[1])
            let modelId = "\(author)/\(modelName)"

            let modelDir = hubDir.appendingPathComponent(entry)

            // Size is stored in blobs/
            let blobsDir = modelDir.appendingPathComponent("blobs")
            let totalSize = directorySize(at: blobsDir, fileManager: fm)

            found.append(DownloadedModel(
                id: modelId,
                displayName: modelName,
                author: author,
                sizeBytes: totalSize,
                path: modelDir
            ))
        }

        downloadedModels = found.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        isLoading = false
    }

    private func directorySize(at url: URL, fileManager fm: FileManager) -> Int64 {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }

    private func deleteModel(_ model: DownloadedModel) {
        try? FileManager.default.removeItem(at: model.path)
        downloadedModels.removeAll { $0.id == model.id }
    }

    private func deleteAllModels() {
        for model in downloadedModels {
            try? FileManager.default.removeItem(at: model.path)
        }
        downloadedModels.removeAll()
    }

    private func loadModel(_ model: DownloadedModel) {
        let hfModel = HFModel(
            id: model.id,
            name: model.id,
            downloads: 0,
            likes: 0,
            tags: [],
            pipelineTag: nil,
            createdAt: nil
        )
        chatViewModel.loadHFModel(hfModel)
    }

    private func isModelLoaded(_ model: DownloadedModel) -> Bool {
        chatViewModel.selectedModelID == model.id
    }
}

private struct DownloadedModel: Identifiable {
    let id: String
    let displayName: String
    let author: String
    let sizeBytes: Int64
    let path: URL

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

private struct DownloadedModelRow: View {
    let model: DownloadedModel
    let isLoaded: Bool
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.headline)
                    if isLoaded {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(.capsule)
                    }
                }
                Text(model.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(model.sizeFormatted)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !isLoaded {
                Button("Load", systemImage: "play.circle") {
                    onLoad()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)
                .accessibilityLabel("Load \(model.displayName)")
            }

            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(model.displayName)")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
