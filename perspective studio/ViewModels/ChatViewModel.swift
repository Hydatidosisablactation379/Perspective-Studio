import Foundation
import SwiftData
import SwiftUI
import AppKit
import Accessibility

enum ModelLoadingState: Sendable {
    case idle
    case downloading(Double)
    case loading
    case ready(String)
    case error(String)

    func statusText(for level: ExperienceLevel) -> String {
        switch self {
        case .idle:
            return level == .beginner ? "No model selected" : "Idle"
        case .downloading(let progress):
            let percent = Int(progress * 100)
            return level == .beginner ? "Downloading... \(percent)%" : "Downloading model... \(percent)%"
        case .loading:
            return level == .beginner ? "Getting the AI ready..." : "Loading model into memory..."
        case .ready(let name):
            return level == .beginner ? "Ready to chat!" : "Model loaded: \(name)"
        case .error(let message):
            return level == .beginner ? "Something went wrong" : "Error: \(message)"
        }
    }
}

@Observable @MainActor
final class ChatViewModel {
    var selectedConversation: Conversation?
    var messageText: String = ""
    var isGenerating: Bool = false
    var isSummarizing: Bool = false
    var modelState: ModelLoadingState = .idle
    var selectedModelID: String?
    var selectedModelIsVisual: Bool = false
    var availableModels: [HFModel] = []
    var newModels: [HFModel] = []
    var isLoadingModels: Bool = false
    var attachedVideoURL: URL?
    var attachedFileURLs: [URL] = []
    var installedModels: [InstalledModel] = []

    private var generationTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var lastAnnouncedMilestone: Int = 0

    func fetchModels() async {
        isLoadingModels = true
        do {
            async let allModels = HuggingFaceService.shared.fetchMLXModels()
            async let recentModels = HuggingFaceService.shared.fetchNewMLXModels()
            availableModels = try await allModels
            newModels = try await recentModels
        } catch {
            print("Failed to fetch models: \(error)")
        }
        isLoadingModels = false
    }

    func sendMessage(in context: ModelContext) {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let conversation = selectedConversation else { return }

        if case .ready = modelState {} else {
            let warning = Message(role: .system, content: "Please select and load a model first using the Model picker.")
            warning.conversation = conversation
            conversation.messages.append(warning)
            try? context.save()
            return
        }

        let videoURL = attachedVideoURL
        let fileURLs = attachedFileURLs
        messageText = ""
        attachedVideoURL = nil
        attachedFileURLs = []

        Task {
            // Read file contents off the main thread
            var parts: [String] = []

            if let url = videoURL {
                parts.append("📹 \(url.lastPathComponent)")
            }

            for fileURL in fileURLs {
                let name = fileURL.lastPathComponent
                let content = await Task.detached(priority: .userInitiated) {
                    try? String(contentsOf: fileURL, encoding: .utf8)
                }.value
                if let content {
                    let trimmed = content.count > 10_000 ? String(content.prefix(10_000)) + "\n…(truncated)" : content
                    parts.append("📎 \(name)\n```\n\(trimmed)\n```")
                } else {
                    parts.append("📎 \(name) (could not read file)")
                }
            }

            parts.append(text)

            let displayContent = parts.joined(separator: "\n\n")

            let userMessage = Message(role: .user, content: displayContent)
            userMessage.conversation = conversation
            conversation.messages.append(userMessage)
            conversation.updatedAt = .now

            if conversation.title == "New Conversation" {
                let maxLen = 40
                if text.count <= maxLen {
                    conversation.title = text
                } else {
                    let truncated = String(text.prefix(maxLen))
                    if let lastSpace = truncated.lastIndex(of: " ") {
                        conversation.title = String(truncated[..<lastSpace]) + "…"
                    } else {
                        conversation.title = truncated + "…"
                    }
                }
            }

            try? context.save()

            generateResponse(for: conversation, in: context, videoURLs: videoURL.map { [$0] } ?? [])
        }
    }

    private func generateResponse(for conversation: Conversation, in context: ModelContext, videoURLs: [URL] = []) {
        let assistantMessage = Message(role: .assistant, content: "")
        assistantMessage.conversation = conversation
        conversation.messages.append(assistantMessage)

        isGenerating = true
        AccessibilityNotification.Announcement("Generating response").post()

        let contextLength = UserDefaults.standard.integer(forKey: "defaultContextLength")
        let effectiveContextLength = contextLength > 0 ? contextLength : 4096

        generationTask = Task {
            do {
                // Auto-summarize if approaching context limit
                let lastUserContent = conversation.sortedMessages.last(where: { $0.role == .user })?.content ?? ""
                if ContextSummarizationService.needsSummarization(
                    conversation: conversation,
                    pendingUserMessage: lastUserContent,
                    contextLength: effectiveContextLength
                ) {
                    if let summaryPrompt = ContextSummarizationService.buildSummarizationPrompt(for: conversation) {
                        isSummarizing = true
                        let rawSummary = try await LLMService.shared.summarize(prompt: summaryPrompt)
                        let summary = ContextSummarizationService.cleanSummary(rawSummary)
                        conversation.runningSummary = summary
                        conversation.lastSummarizedMessageCount = conversation.messages.count - ContextSummarizationService.recentMessagesToKeep

                        // Insert a system message so the user sees that context was condensed
                        let note = Message(role: .system, content: "Earlier messages have been condensed to preserve context.")
                        note.conversation = conversation
                        conversation.messages.append(note)

                        try? context.save()
                        isSummarizing = false
                    }
                }

                let messages = ContextSummarizationService.buildContextualPrompt(
                    conversation: conversation,
                    userMessage: lastUserContent
                )

                let stream = try await LLMService.shared.generate(
                    messages: messages,
                    videoURLs: videoURLs,
                    systemPrompt: conversation.systemPrompt,
                    temperature: conversation.temperature
                )
                var buffer = ""
                var lastFlush = Date.now
                for await token in stream {
                    buffer += token
                    let now = Date.now
                    if now.timeIntervalSince(lastFlush) >= 0.08 {
                        assistantMessage.content += buffer
                        buffer = ""
                        lastFlush = now
                    }
                }
                if !buffer.isEmpty {
                    assistantMessage.content += buffer
                }

                // Auto-read only if the setting is enabled
                if UserDefaults.standard.bool(forKey: "autoReadAloud") {
                    TTSService.shared.speak(text: assistantMessage.content, messageID: assistantMessage.id)
                }

                conversation.updatedAt = .now
                try? context.save()
                AccessibilityNotification.Announcement("Response complete").post()
            } catch {
                if !Task.isCancelled {
                    assistantMessage.content += "\n\n[Error: \(error.localizedDescription)]"
                }
            }

            isGenerating = false
        }
    }

    func stopGenerating() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    @discardableResult
    func createConversation(in context: ModelContext) -> Conversation {
        let conversation = Conversation()
        context.insert(conversation)
        try? context.save()
        selectedConversation = conversation
        Task { await LLMService.shared.resetSession() }
        return conversation
    }

    func deleteConversation(_ conversation: Conversation, in context: ModelContext) {
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        context.delete(conversation)
        try? context.save()
    }

    func loadHFModel(_ model: HFModel) {
        loadTask?.cancel()
        selectedModelID = model.id
        selectedModelIsVisual = model.category == .video || model.category == .vision
        modelState = .downloading(0)
        lastAnnouncedMilestone = 0

        loadTask = Task {
            do {
                let isVisual = model.category == .video || model.category == .vision
                let stream = try await LLMService.shared.loadModelByID(
                    model.id,
                    isVideoModel: isVisual
                )
                for try await progress in stream {
                    modelState = .downloading(progress)
                    announceProgressMilestone(progress)
                }
                modelState = .loading
                try await LLMService.shared.finishLoading()
                modelState = .ready(model.displayName)
                AccessibilityNotification.Announcement("Model ready to use").post()
            } catch {
                modelState = .error(friendlyErrorMessage(for: error, model: model))
            }
        }
    }

    private func announceProgressMilestone(_ progress: Double) {
        let percent = Int(progress * 100)
        let milestones = [25, 50, 75]
        for milestone in milestones {
            if percent >= milestone && lastAnnouncedMilestone < milestone {
                lastAnnouncedMilestone = milestone
                AccessibilityNotification.Announcement("Download \(milestone) percent complete").post()
            }
        }
    }

    func friendlyErrorMessage(for error: Error, model: HFModel) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("memory") || description.contains("ram") {
            return "This model is too large for your Mac's memory. Try a smaller model."
        } else if description.contains("network") || description.contains("internet") || description.contains("connection") {
            return "Could not download the model. Check your internet connection and try again."
        } else if description.contains("disk") || description.contains("space") || description.contains("storage") {
            return "Not enough storage space to download this model. Free up some disk space and try again."
        } else if description.contains("token") || description.contains("vocab") {
            return "This model's format is not supported yet. Try a different model."
        } else {
            return "Something went wrong loading \(model.displayName). Try a different model or restart the app."
        }
    }

    func scanInstalledModels() {
        let fm = FileManager.default
        let hubDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")

        guard let entries = try? fm.contentsOfDirectory(atPath: hubDir.path()) else {
            installedModels = []
            return
        }

        var found: [InstalledModel] = []
        for entry in entries {
            guard entry.hasPrefix("models--") else { continue }
            let parts = entry.dropFirst("models--".count).split(separator: "--", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let author = String(parts[0])
            let modelName = String(parts[1])
            let modelId = "\(author)/\(modelName)"

            let modelDir = hubDir.appendingPathComponent(entry)
            let hasBlobsOrSnapshots = fm.fileExists(atPath: modelDir.appendingPathComponent("blobs").path)
                || fm.fileExists(atPath: modelDir.appendingPathComponent("snapshots").path)
            guard hasBlobsOrSnapshots else { continue }

            // Skip models that cannot be used for chat (TTS, transcription, embedding, etc.)
            guard !Self.looksLikeNonChatModel(modelName) else { continue }

            found.append(InstalledModel(id: modelId, displayName: modelName, author: author, isVisual: Self.looksLikeVisualModel(modelName)))
        }

        installedModels = found.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func loadInstalledModel(_ model: InstalledModel) {
        let pipeline: String? = model.isVisual ? "image-text-to-text" : nil
        let tags: [String] = model.isVisual ? ["image-text-to-text"] : []
        let hfModel = HFModel(
            id: model.id,
            name: model.id,
            downloads: 0,
            likes: 0,
            tags: tags,
            pipelineTag: pipeline,
            createdAt: nil
        )
        loadHFModel(hfModel)
    }

    /// Downloads a model without attempting to load it into memory.
    /// Used for model types that can't be run yet (e.g. TTS).
    func downloadHFModel(_ model: HFModel) {
        loadTask?.cancel()
        selectedModelID = model.id
        selectedModelIsVisual = false
        modelState = .downloading(0)
        lastAnnouncedMilestone = 0

        loadTask = Task {
            do {
                let stream = try await LLMService.shared.loadModelByID(model.id)
                for try await progress in stream {
                    modelState = .downloading(progress)
                    announceProgressMilestone(progress)
                }
                // Loading succeeded (unexpected for TTS, but fine)
                try await LLMService.shared.finishLoading()
                await LLMService.shared.unloadModel()
                modelState = .idle
                AccessibilityNotification.Announcement("Model downloaded successfully").post()
            } catch {
                // Expected for non-loadable models — check if files ended up in cache
                let isNowDownloaded = model.isDownloaded
                if isNowDownloaded {
                    modelState = .idle
                    AccessibilityNotification.Announcement("Model downloaded successfully").post()
                } else {
                    modelState = .error(friendlyErrorMessage(for: error, model: model))
                }
            }
        }
    }

    /// Heuristic to detect models that cannot be used for chat (TTS, transcription, embedding, audio, translation).
    static func looksLikeNonChatModel(_ name: String) -> Bool {
        let lower = name.lowercased()

        // TTS
        if lower.contains("tts") || lower.contains("kokoro") || lower.contains("orpheus")
            || lower.contains("parler") || lower.contains("bark") || lower.contains("outetts")
            || lower.contains("mars5") || lower.contains("styletts") || lower.contains("f5-tts")
            || lower.contains("cosyvoice") || lower.contains("chattts") || lower.contains("soprano")
            || lower.contains("vibevoice") || lower.contains("pocket-tts") || lower.contains("vyvo")
            || lower.contains("marvis") {
            return true
        }

        // Transcription / ASR
        if lower.contains("whisper") || lower.contains("wav2vec") || lower.contains("hubert")
            || lower.contains("conformer") || lower.contains("mms-") || lower.contains("parakeet") {
            return true
        }

        // Embedding
        if lower.contains("embedding") || lower.contains("gte-") || lower.contains("bge-")
            || lower.contains("nomic-embed") || lower.contains("e5-") || lower.contains("jina-embed") {
            return true
        }

        // Translation
        if lower.contains("nllb") || lower.contains("opus-mt") || lower.contains("marian")
            || lower.contains("madlad") {
            return true
        }

        // Audio processing
        if lower.contains("encodec") || lower.contains("musicgen") || lower.contains("audiogen")
            || lower.contains("audiocraft") || lower.contains("dac-") {
            return true
        }

        // Image generation (diffusion models)
        if lower.contains("stable-diffusion") || lower.contains("flux") || lower.contains("diffusion") {
            return true
        }

        return false
    }

    /// Heuristic to detect video or vision models from their name in the HF cache.
    /// Both video and vision models use the VLM pipeline.
    static func looksLikeVisualModel(_ name: String) -> Bool {
        let lower = name.lowercased()
        // Video patterns
        if lower.contains("video") || lower.contains("videollama") || lower.contains("videochat") {
            return true
        }
        // Vision patterns — mirrors HFModel.category detection
        if lower.contains("vision") || lower.contains("llava") || lower.contains("pixtral")
            || lower.contains("idefics") || lower.contains("minicpm-o")
            || lower.contains("paligemma") || lower.contains("florence")
            || lower.contains("molmo") || lower.contains("got-ocr")
            || lower.contains("moondream") || lower.contains("bunny")
            || lower.contains("internvl") || lower.contains("smolvlm")
            || lower.contains("fastvlm") {
            return true
        }
        // "VL" suffix/segment (e.g. Qwen2.5-VL, Phi-3.5-VL)
        if lower.hasSuffix("-vl") || lower.contains("-vl-") {
            return true
        }
        return false
    }
}

struct InstalledModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let author: String
    let isVisual: Bool
    var isLoadable: Bool = true
}
