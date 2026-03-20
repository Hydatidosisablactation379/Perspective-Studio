import Foundation

#if canImport(MLXLLM)
import MLXLLM
import MLXVLM
import MLXLMCommon

actor LLMService {
    static let shared = LLMService()

    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?
    private var isCancelled = false
    private var isVLM = false
    private var isLoading = false

    func loadModelByID(_ id: String, isVideoModel: Bool = false) throws -> AsyncThrowingStream<Double, Error> {
        // Guard against reentrancy — cancel any in-flight load
        if isLoading {
            isCancelled = true
        }
        isCancelled = false
        isLoading = true
        isVLM = isVideoModel

        // Unload previous model to free memory before loading new one
        modelContainer = nil
        chatSession = nil

        return AsyncThrowingStream { continuation in
            Task {
                let configuration = ModelConfiguration(id: id)

                do {
                    let factory: ModelFactory = isVideoModel
                        ? VLMModelFactory.shared
                        : LLMModelFactory.shared

                    let container = try await factory.loadContainer(
                        configuration: configuration
                    ) { progress in
                        continuation.yield(progress.fractionCompleted)
                    }
                    self.modelContainer = container
                    self.chatSession = ChatSession(container)
                    self.isLoading = false
                    continuation.finish()
                } catch {
                    self.isLoading = false
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func finishLoading() async throws {
        // Model is already loaded after loadModelByID completes
    }

    func resetSession() {
        if let container = modelContainer {
            chatSession = ChatSession(container)
        }
    }

    func generate(
        messages: [(role: String, content: String)],
        videoURLs: [URL] = [],
        systemPrompt: String? = nil,
        temperature: Double? = nil
    ) throws -> AsyncStream<String> {
        guard let container = modelContainer else {
            throw LLMError.modelNotLoaded
        }

        // Ensure we have a session
        if chatSession == nil {
            chatSession = ChatSession(container)
        }
        let session = chatSession!

        isCancelled = false

        // Only send the last user message — ChatSession tracks history internally
        let lastUserMessage = messages.last(where: { $0.role == "user" })?.content ?? ""
        let videos: [UserInput.Video] = videoURLs.map { .url($0) }

        return AsyncStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(to: lastUserMessage, images: [], videos: videos)
                    for try await token in stream {
                        if self.isCancelled { break }
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    func summarize(prompt: String) async throws -> String {
        guard let container = modelContainer else {
            throw LLMError.modelNotLoaded
        }

        // Use a temporary session so we do not pollute the main chat history
        let session = ChatSession(container)
        var result = ""
        let stream = session.streamResponse(to: prompt, images: [], videos: [])
        for try await token in stream {
            result += token
        }
        return result
    }

    func cancel() {
        isCancelled = true
    }

    func unloadModel() {
        modelContainer = nil
        chatSession = nil
        isVLM = false
        isLoading = false
    }
}

#else

actor LLMService {
    static let shared = LLMService()

    private var isCancelled = false

    func loadModelByID(_ id: String, isVideoModel: Bool = false) throws -> AsyncThrowingStream<Double, Error> {
        AsyncThrowingStream { $0.finish(throwing: LLMError.modelNotLoaded) }
    }

    func finishLoading() async throws {}

    func generate(
        messages: [(role: String, content: String)],
        videoURLs: [URL] = [],
        systemPrompt: String? = nil,
        temperature: Double? = nil
    ) throws -> AsyncStream<String> {
        throw LLMError.modelNotLoaded
    }

    func summarize(prompt: String) async throws -> String {
        throw LLMError.modelNotLoaded
    }

    func cancel() { isCancelled = true }
    func resetSession() {}
    func unloadModel() {}
}

#endif

enum LLMError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "No model is loaded. Please download and load a model first."
        }
    }
}
