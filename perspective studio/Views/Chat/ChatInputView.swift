import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ChatInputView: View {
    @Binding var text: String
    @Binding var attachedVideoURL: URL?
    @Binding var attachedFileURLs: [URL]
    let isGenerating: Bool
    let isVisualModel: Bool
    let installedModels: [InstalledModel]
    let selectedModelID: String?
    let onSelectModel: (InstalledModel) -> Void
    let onSend: () -> Void
    let onStop: () -> Void

    @Binding var shouldFocus: Bool
    @FocusState private var isFocused: Bool
    @AccessibilityFocusState private var isTextFieldA11yFocused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    var body: some View {
        VStack(spacing: 8) {
            if !attachedFileURLs.isEmpty || attachedVideoURL != nil {
                attachmentList
            }

            composerView
        }
        .padding(.vertical, 12)
        .onAppear {
            requestTextFieldFocus()
        }
        .onChange(of: shouldFocus) {
            if shouldFocus {
                requestTextFieldFocus()
                shouldFocus = false
            }
        }
    }

    // MARK: - Composer

    private var composerView: some View {
        VStack(spacing: 0) {
            messageTextField
            modelPickerRow
            inputToolbar
        }
        .background(Color(.controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private var messageTextField: some View {
        TextField("Message…", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...8)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .focused($isFocused)
            .defaultFocus($isFocused, true)
            .onSubmit {
                if canSend { onSend() }
            }
            .accessibilityLabel("Message input")
            .accessibilityHint(canSend ? "Press Return to send" : "Type your message here")
            .accessibilityFocused($isTextFieldA11yFocused)
    }

    private var modelPickerRow: some View {
        HStack(spacing: 6) {
            modelPickerMenu
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var modelPickerMenu: some View {
        Menu {
            if installedModels.isEmpty {
                Text("No models installed")
            } else {
                ForEach(installedModels) { model in
                    Button {
                        onSelectModel(model)
                        requestTextFieldFocus()
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
                Image(systemName: "cpu")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text(modelPickerTitle)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(selectedModelID != nil ? .primary : .secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(selectedModelName.map { "Current model: \($0)" } ?? "Select a model")
        .accessibilityHint("Opens a menu to choose an AI model")
    }

    private var modelPickerTitle: String {
        if let selectedModelName {
            return selectedModelName
        }
        if installedModels.isEmpty {
            return "No Models"
        }
        return "Select Model"
    }

    private var selectedModelName: String? {
        guard let id = selectedModelID else { return nil }
        return installedModels.first(where: { $0.id == id })?.displayName
    }

    private var inputToolbar: some View {
        HStack(spacing: 6) {
            attachButton

            Spacer(minLength: 0)

            sendOrStopButton
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .padding(.top, 4)
    }

    private var attachButton: some View {
        Button("Attach", systemImage: hasAttachments ? "paperclip.circle.fill" : "paperclip") {
            pickAttachments()
        }
        .font(.body)
        .labelStyle(.iconOnly)
        .frame(width: 32, height: 32)
        .background(hasAttachments ? Color.accentColor.opacity(0.14) : Color(.controlBackgroundColor))
        .foregroundStyle(hasAttachments ? Color.blue : Color.secondary)
        .clipShape(.circle)
        .buttonStyle(.plain)
        .accessibilityLabel(attachmentAccessibilityLabel)
        .accessibilityHint("Opens a file picker")
    }

    private var hasAttachments: Bool {
        !attachedFileURLs.isEmpty || attachedVideoURL != nil
    }

    private var attachmentAccessibilityLabel: String {
        let count = attachedFileURLs.count + (attachedVideoURL != nil ? 1 : 0)
        if count == 0 {
            return "Attach"
        }
        return "\(count) \(count == 1 ? "file" : "files") attached. Attach more"
    }

    @ViewBuilder
    private var sendOrStopButton: some View {
        if isGenerating {
            Button("Stop generating", systemImage: "stop.circle.fill") {
                onStop()
            }
            .font(.title2)
            .labelStyle(.iconOnly)
            .foregroundStyle(.red)
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityHint("Double tap to stop the response")
        } else {
            Button("Send message", systemImage: "arrow.up.circle.fill") {
                onSend()
            }
            .font(.title2)
            .labelStyle(.iconOnly)
            .foregroundStyle(canSend ? Color.blue : Color.secondary)
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityHint(canSend ? "Double tap to send" : "Type a message first")
        }
    }

    // MARK: - Attachment List

    private var attachmentList: some View {
        ScrollView(.horizontal) {
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
        .scrollIndicators(.hidden)
    }

    // MARK: - File Picker

    private var videoTypes: [UTType] {
        [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
    }

    private var imageTypes: [UTType] {
        [.image, .jpeg, .png, .heic, .gif, .tiff, .bmp, .webP]
    }

    private var documentTypes: [UTType] {
        [.plainText, .sourceCode, .json, .xml, .yaml, .html, .css, .pdf, .rtf, .data]
    }

    private func pickAttachments() {
        let panel = NSOpenPanel()
        panel.title = "Attach Files"
        panel.allowedContentTypes = isVisualModel ? documentTypes + imageTypes + videoTypes : documentTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            for url in panel.urls {
                if isVideoType(url) {
                    attachedVideoURL = url
                } else if !attachedFileURLs.contains(url) {
                    attachedFileURLs.append(url)
                }
            }
        }

        requestTextFieldFocus()
    }

    private func isVideoType(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(ext)
    }

    // MARK: - Helpers

    private func attachmentChip(name: String, icon: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Button("Remove \(name)", systemImage: "xmark.circle.fill") {
                onRemove()
            }
            .labelStyle(.iconOnly)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(.capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Attached: \(name)")
        .accessibilityHint("Contains a remove button")
    }

    private func requestTextFieldFocus() {
        isFocused = false
        Task { @MainActor in
            await Task.yield()
            isFocused = true
            isTextFieldA11yFocused = true
        }
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
