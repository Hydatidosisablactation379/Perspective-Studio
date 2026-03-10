import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ChatInputView: View {
    @Binding var text: String
    @Binding var attachedVideoURL: URL?
    @Binding var attachedFileURLs: [URL]
    let isGenerating: Bool
    let isVideoModel: Bool
    let installedModels: [InstalledModel]
    let selectedModelID: String?
    let onSelectModel: (InstalledModel) -> Void
    let onSend: () -> Void
    let onStop: () -> Void

    @Binding var shouldFocus: Bool
    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    var body: some View {
        VStack(spacing: 8) {
            // Attached files display
            if !attachedFileURLs.isEmpty || attachedVideoURL != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let videoURL = attachedVideoURL {
                            attachmentChip(
                                name: videoURL.lastPathComponent,
                                icon: "film",
                                color: .purple
                            ) {
                                attachedVideoURL = nil
                            }
                        }
                        ForEach(attachedFileURLs, id: \.self) { url in
                            attachmentChip(
                                name: url.lastPathComponent,
                                icon: iconForFile(url),
                                color: .blue
                            ) {
                                attachedFileURLs.removeAll { $0 == url }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                modelPickerMenu

                if isVideoModel {
                    Button {
                        pickVideo()
                    } label: {
                        Image(systemName: attachedVideoURL != nil ? "film.fill" : "film")
                            .font(.title3)
                            .foregroundStyle(attachedVideoURL != nil ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Attach video")
                    .accessibilityHint("Opens a file picker to select a video")
                }

                Button {
                    pickFiles()
                } label: {
                    Image(systemName: attachedFileURLs.isEmpty ? "paperclip" : "paperclip.circle.fill")
                        .font(.title3)
                        .foregroundColor(attachedFileURLs.isEmpty ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach file")
                .accessibilityHint("Opens a file picker to attach documents")

                TextField("Type a message...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(.rect(cornerRadius: 20))
                    .focused($isFocused)
                    .onSubmit {
                        if canSend { onSend() }
                    }
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type your message here")

                if isGenerating {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityLabel("Stop generating")
                    .accessibilityHint("Double tap to stop the response")
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(canSend ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .accessibilityLabel("Send message")
                    .accessibilityHint(canSend ? "Double tap to send" : "Type a message first")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .onAppear { isFocused = true }
        .onChange(of: shouldFocus) {
            if shouldFocus {
                isFocused = true
                shouldFocus = false
            }
        }
    }

    private func pickVideo() {
        let panel = NSOpenPanel()
        panel.title = "Select a Video"
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            attachedVideoURL = url
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.title = "Attach Files"
        panel.allowedContentTypes = [
            .plainText, .sourceCode, .json, .xml, .yaml, .html, .css,
            .pdf, .rtf, .data
        ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            for url in panel.urls where !attachedFileURLs.contains(url) {
                attachedFileURLs.append(url)
            }
        }
    }

    private func attachmentChip(name: String, icon: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(name)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(.capsule)
    }

    private var selectedModelName: String? {
        guard let id = selectedModelID else { return nil }
        return installedModels.first(where: { $0.id == id })?.displayName
    }

    private var modelPickerMenu: some View {
        Menu {
            if installedModels.isEmpty {
                Text("No models installed")
            } else {
                ForEach(installedModels) { model in
                    Button {
                        onSelectModel(model)
                    } label: {
                        HStack {
                            Text(model.displayName)
                            if model.id == selectedModelID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cube")
                    .font(.title3)
                Text(selectedModelName ?? "Model")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 120)
            }
            .foregroundStyle(selectedModelID != nil ? .blue : .secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(selectedModelName.map { "Current model: \($0)" } ?? "Select a model")
        .accessibilityHint("Opens a menu to switch models")
    }

    private func iconForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift", "py", "js", "ts", "c", "cpp", "h", "rs", "go", "java", "kt", "rb":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "xml", "yaml", "yml", "plist":
            return "curlybraces"
        case "md", "txt", "rtf":
            return "doc.text"
        case "pdf":
            return "doc.richtext"
        case "html", "css":
            return "globe"
        default:
            return "doc"
        }
    }
}
