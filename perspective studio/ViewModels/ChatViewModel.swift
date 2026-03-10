import Foundation
import SwiftData
import SwiftUI
import Accessibility

enum ModelLoadingState: Sendable {
    case idle
    case downloading(Double)
    case loading
    case ready(String)
    case error(String)

    var statusText: String {
        statusText(for: OnboardingViewModel.currentExperienceLevel)
    }

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

@Observable
final class ChatViewModel {
    var selectedConversation: Conversation?
    var messageText: String = ""
    var isGenerating: Bool = false
    var isSummarizing: Bool = false
    var modelState: ModelLoadingState = .idle
    var selectedModelID: String?
    var selectedModelIsVideo: Bool = false
    var availableModels: [HFModel] = []
    var newModels: [HFModel] = []
    var isLoadingModels: Bool = false
    var attachedVideoURL: URL?
    var attachedFileURLs: [URL] = []
    var installedModels: [InstalledModel] = []

    private var generationTask: Task<Void, Never>?
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

        // Build display content with file contents
        var parts: [String] = []

        if let url = videoURL {
            parts.append("📹 \(url.lastPathComponent)")
        }

        for fileURL in fileURLs {
            let name = fileURL.lastPathComponent
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
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
                        await MainActor.run { self.isSummarizing = true }
                        let rawSummary = try await LLMService.shared.summarize(prompt: summaryPrompt)
                        let summary = ContextSummarizationService.cleanSummary(rawSummary)
                        conversation.runningSummary = summary
                        conversation.lastSummarizedMessageCount = conversation.messages.count - ContextSummarizationService.recentMessagesToKeep

                        // Insert a system message so the user sees that context was condensed
                        let note = Message(role: .system, content: "Earlier messages have been condensed to preserve context.")
                        note.conversation = conversation
                        conversation.messages.append(note)

                        try? context.save()
                        await MainActor.run { self.isSummarizing = false }
                    }
                }

                let messages = ContextSummarizationService.buildContextualPrompt(
                    conversation: conversation,
                    userMessage: lastUserContent
                )

                let stream = try await LLMService.shared.generate(
                    messages: messages,
                    videoURLs: videoURLs
                )
                var buffer = ""
                var lastFlush = Date()
                for await token in stream {
                    buffer += token
                    let now = Date()
                    if now.timeIntervalSince(lastFlush) >= 0.08 {
                        assistantMessage.content += buffer
                        buffer = ""
                        lastFlush = now
                    }
                }
                if !buffer.isEmpty {
                    assistantMessage.content += buffer
                }

                // Auto-read if setting enabled
                if UserDefaults.standard.bool(forKey: "autoReadAloud") {
                    await MainActor.run {
                        TTSService.shared.speak(text: assistantMessage.content, messageID: assistantMessage.id)
                    }
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
        selectedModelID = model.id
        selectedModelIsVideo = model.category == .video
        modelState = .downloading(0)
        lastAnnouncedMilestone = 0

        Task {
            do {
                let stream = try await LLMService.shared.loadModelByID(
                    model.id,
                    isVideoModel: model.category == .video
                )
                for try await progress in stream {
                    await MainActor.run {
                        self.modelState = .downloading(progress)
                        self.announceProgressMilestone(progress)
                    }
                }
                await MainActor.run {
                    self.modelState = .loading
                }
                try await LLMService.shared.finishLoading()
                await MainActor.run {
                    self.modelState = .ready(model.displayName)
                    AccessibilityNotification.Announcement("Model ready to use").post()
                }
            } catch {
                await MainActor.run {
                    self.modelState = .error(friendlyErrorMessage(for: error, model: model))
                }
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

            found.append(InstalledModel(id: modelId, displayName: modelName, author: author))
        }

        installedModels = found.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func loadInstalledModel(_ model: InstalledModel) {
        let hfModel = HFModel(
            id: model.id,
            name: model.id,
            downloads: 0,
            likes: 0,
            tags: [],
            pipelineTag: nil,
            createdAt: nil
        )
        loadHFModel(hfModel)
    }
}

struct InstalledModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let author: String
}
