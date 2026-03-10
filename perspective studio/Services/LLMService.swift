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

    func loadModelByID(_ id: String, isVideoModel: Bool = false) throws -> AsyncThrowingStream<Double, Error> {
        isCancelled = false
        isVLM = isVideoModel
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
                    continuation.finish()
                } catch {
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
        videoURLs: [URL] = []
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
    }
}

#else

actor LLMService {
    static let shared = LLMService()

    private var isCancelled = false

    func loadModelByID(_ id: String, isVideoModel: Bool = false) throws -> AsyncThrowingStream<Double, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                for i in 1...10 {
                    try? await Task.sleep(for: .milliseconds(200))
                    continuation.yield(Double(i) / 10.0)
                }
                continuation.finish()
            }
        }
    }

    func finishLoading() async throws {
        try? await Task.sleep(for: .milliseconds(500))
    }

    func generate(
        messages: [(role: String, content: String)],
        videoURLs: [URL] = []
    ) throws -> AsyncStream<String> {
        isCancelled = false

        return AsyncStream { continuation in
            Task {
                let response = "This is a simulated response from a mock language model. In a real build with MLX linked, you would see actual model output here. The model would process your message and generate a thoughtful response based on its training."
                let words = response.split(separator: " ")

                for word in words {
                    if self.isCancelled { break }
                    try? await Task.sleep(for: .milliseconds(50))
                    continuation.yield(String(word) + " ")
                }
                continuation.finish()
            }
        }
    }

    func summarize(prompt: String) async throws -> String {
        try? await Task.sleep(for: .milliseconds(300))
        return "• User discussed testing the app\n• Key topic: auto-summarization of long conversations"
    }

    func cancel() {
        isCancelled = true
    }

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
