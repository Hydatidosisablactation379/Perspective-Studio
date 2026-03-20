import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct TTSPlaygroundView: View {
    @State private var tts = MLXTTSService.shared
    @State private var vibeVoice = VibeVoiceTTSService.shared
    @State private var inputText: String = ""
    @State private var selectedVoice: String = ""
    @State private var installedTTSModels: [InstalledModel] = []
    @State private var loadError: String?
    @State private var savedFileMessage: String?
    @State private var selectedModelID: String = ""
    var onBrowseModels: (() -> Void)?

    // MARK: - Engine Detection

    /// Only use VibeVoice path when the real package is available AND a VibeVoice model is active.
    private var activeIsVibeVoice: Bool {
        guard VibeVoiceTTSService.isAvailable else { return false }
        return vibeVoice.loadedModelID != nil || vibeVoice.isLoading
    }

    private var isModelLoaded: Bool {
        if activeIsVibeVoice {
            return vibeVoice.loadedModelID != nil && !vibeVoice.isLoading
        }
        return tts.loadedModelID != nil && !tts.isLoading
    }

    private var isLoading: Bool {
        tts.isLoading || (VibeVoiceTTSService.isAvailable && vibeVoice.isLoading)
    }

    private var isSpeaking: Bool {
        tts.isSpeaking || (VibeVoiceTTSService.isAvailable && vibeVoice.isSpeaking)
    }

    private var canSpeak: Bool {
        isModelLoaded && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSaveAudio: Bool {
        if activeIsVibeVoice {
            return vibeVoice.canSaveAudio
        }
        return tts.canSaveAudio
    }

    private var currentVoices: [String] {
        activeIsVibeVoice ? vibeVoice.availableVoices : tts.availableVoices
    }

    private var loadedModelDisplayID: String? {
        if VibeVoiceTTSService.isAvailable, let id = vibeVoice.loadedModelID { return id }
        return tts.loadedModelID
    }

    private var currentLoadingProgress: String {
        if VibeVoiceTTSService.isAvailable && vibeVoice.isLoading { return vibeVoice.loadingProgress }
        return tts.loadingProgress
    }

    var body: some View {
        NavigationStack {
            Form {
                modelSection
                voiceSection
                textSection
                playbackSection
            }
            .formStyle(.grouped)
            .navigationTitle("TTS Playground")
        }
        .onAppear {
            scanTTSModels()
            syncSelectedVoice()
            syncSelectedModelID()
        }
        .onChange(of: activeIsVibeVoice) {
            syncSelectedVoice()
        }
        .onChange(of: vibeVoice.availableVoices) {
            syncSelectedVoice()
        }
        .onChange(of: tts.availableVoices) {
            syncSelectedVoice()
        }
        .onChange(of: selectedModelID) { _, newID in
            guard !newID.isEmpty else { return }
            let currentLoaded = tts.loadedModelID ?? (VibeVoiceTTSService.isAvailable ? vibeVoice.loadedModelID : nil)
            guard newID != currentLoaded else { return }
            loadError = nil
            tts.unloadModel()
            if VibeVoiceTTSService.isAvailable { vibeVoice.unloadModel() }
            if VibeVoiceTTSService.isAvailable && VibeVoiceTTSService.isSupportedModel(newID) {
                Task {
                    do {
                        try await vibeVoice.loadModel(repoID: newID)
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            } else {
                Task {
                    do {
                        try await tts.loadModel(repoID: newID)
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        Section {
            if installedTTSModels.isEmpty && !showVibeVoiceDownloads {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No compatible TTS models found.")
                        .font(.subheadline)

                    Text("Download a supported model from Discover. Try searching for: Soprano, Orpheus, or Qwen3-TTS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let onBrowseModels {
                        Button("Browse Models", systemImage: "magnifyingglass") {
                            onBrowseModels()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                        .accessibilityHint("Opens the Discover tab to find TTS models")
                    }
                }
            } else {
                Picker("Model", selection: $selectedModelID) {
                    Text("Select a model").tag("")
                    ForEach(installedTTSModels) { model in
                        Text(model.displayName).tag(model.id)
                    }
                    if showVibeVoiceDownloads {
                        ForEach(downloadableVibeVoiceModels) { model in
                            Text("\(model.displayName) (download)").tag(model.id)
                        }
                    }
                }
                .accessibilityLabel("TTS Model")
                .accessibilityHint("Choose a downloaded TTS model to use for speech")

                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(currentLoadingProgress.isEmpty ? "Loading model…" : currentLoadingProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                } else if let loadedID = loadedModelDisplayID {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(loadedID.components(separatedBy: "/").last ?? loadedID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Model loaded: \(loadedID.components(separatedBy: "/").last ?? loadedID)")
                }

                if let error = loadError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Error: \(error)")
                }
            }
        } header: {
            Text("Model")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            if VibeVoiceTTSService.isAvailable {
                Text("Supported: Soprano, Orpheus, Qwen3-TTS, Marvis, Pocket TTS, VibeVoice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Supported: Soprano, Orpheus, Qwen3-TTS, Marvis, Pocket TTS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        Section {
            Picker("Voice", selection: $selectedVoice) {
                if !currentVoices.contains(selectedVoice) {
                    Text("Select a voice").tag(selectedVoice)
                }
                ForEach(currentVoices, id: \.self) { voice in
                    Text(displayVoiceName(voice)).tag(voice)
                }
            }
            .accessibilityLabel("Voice")
            .accessibilityHint("Choose a voice for speech generation")

            if activeIsVibeVoice && isModelLoaded && !isSpeaking {
                Button("Preview Voice", systemImage: "waveform") {
                    vibeVoice.previewVoice(selectedVoice)
                }
                .controlSize(.small)
                .accessibilityLabel("Preview \(displayVoiceName(selectedVoice)) voice")
                .accessibilityHint("Generates a short sample of the selected voice")
            }
        } header: {
            Text("Voice")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            if activeIsVibeVoice {
                Text("VibeVoice voices are loaded from voice cache files included with the model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Text Section

    private var textSection: some View {
        Section {
            TextField("Enter text to speak…", text: $inputText, axis: .vertical)
                .lineLimit(3...12)
                .accessibilityLabel("Text to speak")

            Button("Load from File", systemImage: "doc") {
                loadFromFile()
            }
            .accessibilityHint("Opens a file picker to load text from a file")
        } header: {
            Text("Text")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        Section {
            Button(isSpeaking ? "Stop" : "Speak", systemImage: isSpeaking ? "stop.circle.fill" : "play.circle.fill") {
                if isSpeaking {
                    tts.stop()
                    if VibeVoiceTTSService.isAvailable { vibeVoice.stop() }
                } else {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if activeIsVibeVoice {
                        vibeVoice.speak(text: text, voice: selectedVoice)
                    } else {
                        tts.speak(text: text, voice: selectedVoice)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(isSpeaking ? .red : .blue)
            .controlSize(.large)
            .disabled(!canSpeak && !isSpeaking)
            .accessibilityLabel(isSpeaking ? "Stop speaking" : "Speak text")
            .accessibilityHint(isSpeaking ? "Stops playback" : canSpeak ? "Speaks the entered text using the selected model and voice" : "Load a model and enter text first")

            if canSaveAudio {
                Button("Save Audio", systemImage: "square.and.arrow.down") {
                    let url: URL? = if activeIsVibeVoice {
                        vibeVoice.saveAudioToFile()
                    } else {
                        tts.saveAudioToFile()
                    }
                    if let url {
                        savedFileMessage = "Saved to \(url.lastPathComponent)"
                    }
                }
                .controlSize(.small)
                .accessibilityLabel("Save generated audio")
                .accessibilityHint("Saves the last generated audio as a WAV file to Downloads")
            }

            if let message = savedFileMessage {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(message)
            }

            if let speakError = vibeVoiceSpeakError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text(speakError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Speech error: \(speakError)")
            }
        }
    }

    private var vibeVoiceSpeakError: String? {
        VibeVoiceTTSService.isAvailable ? vibeVoice.lastError : nil
    }

    // MARK: - VibeVoice Downloads

    /// Only show VibeVoice download options when the real package is available.
    private var showVibeVoiceDownloads: Bool {
        VibeVoiceTTSService.isAvailable && !downloadableVibeVoiceModels.isEmpty
    }

    private var downloadableVibeVoiceModels: [InstalledModel] {
        let available = [
            InstalledModel(id: "microsoft/VibeVoice-Realtime-0.5B", displayName: "VibeVoice Realtime 0.5B", author: "microsoft", isVisual: false, isLoadable: true),
            InstalledModel(id: "mzbac/VibeVoice-Realtime-0.5B-8bit", displayName: "VibeVoice Realtime 0.5B (8-bit)", author: "mzbac", isVisual: false, isLoadable: true),
        ]
        return available.filter { model in
            !installedTTSModels.contains(where: { $0.id == model.id })
        }
    }

    // MARK: - Actions

    private func syncSelectedModelID() {
        let loaded = tts.loadedModelID ?? (VibeVoiceTTSService.isAvailable ? vibeVoice.loadedModelID : nil)
        selectedModelID = loaded ?? ""
    }

    private func syncSelectedVoice() {
        if !currentVoices.contains(selectedVoice), let first = currentVoices.first {
            selectedVoice = first
        }
    }

    private func isTTSModel(_ name: String) -> Bool {
        MLXTTSService.isSupportedTTSModel(name)
            || (VibeVoiceTTSService.isAvailable && VibeVoiceTTSService.isSupportedModel(name))
    }

    private func displayVoiceName(_ voice: String) -> String {
        if activeIsVibeVoice {
            return voice
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
        return voice.capitalized
    }

    private func scanTTSModels() {
        let fm = FileManager.default
        var found: [InstalledModel] = []

        // Scan MLX LLM cache: ~/Library/Caches/models/{author}/{name}/
        guard let mlxCacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("models") else { return }
        if let authors = try? fm.contentsOfDirectory(atPath: mlxCacheDir.path()) {
            for author in authors {
                let authorDir = mlxCacheDir.appendingPathComponent(author)
                guard let models = try? fm.contentsOfDirectory(atPath: authorDir.path()) else { continue }
                for modelName in models {
                    let modelDir = authorDir.appendingPathComponent(modelName)
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: modelDir.path(), isDirectory: &isDir), isDir.boolValue else { continue }
                    let modelId = "\(author)/\(modelName)"
                    if isTTSModel(modelName) {
                        found.append(InstalledModel(id: modelId, displayName: modelName, author: author, isVisual: false, isLoadable: true))
                    }
                }
            }
        }

        // Scan HubCache directory: ~/.cache/huggingface/hub/ (format: models--author--name)
        let hubCacheDir = MLXTTSService.hubCacheModelsDirectory
        if let entries = try? fm.contentsOfDirectory(atPath: hubCacheDir.path()) {
            for entry in entries {
                guard entry.hasPrefix("models--") else { continue }
                let entryDir = hubCacheDir.appendingPathComponent(entry)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: entryDir.path(), isDirectory: &isDir), isDir.boolValue else { continue }

                let parts = entry.dropFirst("models--".count).split(separator: "--", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let author = String(parts[0])
                let modelName = String(parts[1])
                let modelId = "\(author)/\(modelName)"

                guard !found.contains(where: { $0.id == modelId }) else { continue }

                if isTTSModel(modelName) {
                    found.append(InstalledModel(id: modelId, displayName: modelName, author: author, isVisual: false, isLoadable: true))
                }
            }
        }

        installedTTSModels = found.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func loadFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Load Text File"
        panel.allowedContentTypes = [.plainText, .sourceCode, .json, .xml, .yaml, .html]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                inputText = content.count > 10_000 ? String(content.prefix(10_000)) : content
            }
        }
    }
}
