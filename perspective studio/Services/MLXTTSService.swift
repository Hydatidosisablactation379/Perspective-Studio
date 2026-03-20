import Foundation
import AVFoundation

#if canImport(MLXAudioTTS)
import MLXAudioTTS
import MLXAudioCore

@Observable @MainActor
final class MLXTTSService {
    static let shared = MLXTTSService()

    var isLoading: Bool = false
    var isSpeaking: Bool = false
    var loadedModelID: String?
    var loadingProgress: String = ""
    var lastError: String?

    private var model: SpeechGenerationModel?
    private var playerNode: AVAudioPlayerNode?
    private var engine: AVAudioEngine?
    private var playbackTask: Task<Void, Never>?
    private var lastGeneratedSamples: [Float] = []

    private init() {}

    var canSaveAudio: Bool {
        !lastGeneratedSamples.isEmpty && !isSpeaking
    }

    /// Voices supported by the loaded model (model-dependent).
    var availableVoices: [String] {
        // These are the standard voices supported by Soprano/Orpheus-style models
        ["tara", "leah", "jess", "leo", "dan", "mia", "zac", "zoe"]
    }

    /// Model types recognized by mlx-audio-swift TTS
    static let supportedModelPatterns: [String] = [
        "soprano", "orpheus", "qwen3-tts", "qwen3_tts",
        "marvis", "csm", "sesame", "pocket_tts", "pocket-tts",
        "vyvo", "llama-tts", "llama_tts"
    ]

    /// Check if an installed model name looks like a supported TTS model.
    static func isSupportedTTSModel(_ name: String) -> Bool {
        let lower = name.lowercased()
        return supportedModelPatterns.contains { lower.contains($0) }
    }

    /// The cache directory used by mlx-audio-swift (HubCache.default).
    /// On non-sandboxed macOS: ~/.cache/huggingface/hub/
    /// On sandboxed macOS: ~/Library/Caches/huggingface/hub/
    static var hubCacheModelsDirectory: URL {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        if isSandboxed {
            return URL.cachesDirectory
                .appendingPathComponent("huggingface")
                .appendingPathComponent("hub")
        }
        return home
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
    }

    /// Loads a TTS model by repo ID. If not cached locally, mlx-audio-swift
    /// will download it automatically via HubCache.
    func loadModel(repoID: String) async throws {
        isLoading = true
        loadingProgress = "Loading TTS model…"

        do {
            let loaded = try await TTS.loadModel(modelRepo: repoID)
            model = loaded
            loadedModelID = repoID
            loadingProgress = ""
            isLoading = false
        } catch {
            loadingProgress = ""
            isLoading = false
            throw error
        }
    }

    func speak(text: String, voice: String?) {
        guard let model else { return }
        stop()

        isSpeaking = true
        lastError = nil
        lastGeneratedSamples = []

        // Capture model reference before detaching — model is only read here,
        // and stop() cancels any prior task before a new one starts.
        let capturedModel = model

        playbackTask = Task {
            do {
                let audioEngine = AVAudioEngine()
                let playerNode = AVAudioPlayerNode()
                audioEngine.attach(playerNode)

                let sampleRate = Double(capturedModel.sampleRate)
                guard let format = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: sampleRate,
                    channels: 1,
                    interleaved: false
                ) else {
                    isSpeaking = false
                    return
                }

                audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
                try audioEngine.start()
                playerNode.play()

                engine = audioEngine
                self.playerNode = playerNode

                var accumulatedSamples: [Float] = []

                let stream = capturedModel.generateSamplesStream(
                    text: text,
                    voice: voice,
                    refAudio: nil,
                    refText: nil,
                    language: nil
                )

                for try await samples in stream {
                    if Task.isCancelled { break }

                    accumulatedSamples.append(contentsOf: samples)

                    let frameCount = AVAudioFrameCount(samples.count)
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
                          let channel = buffer.floatChannelData?[0] else { continue }

                    buffer.frameLength = frameCount
                    for i in 0..<samples.count {
                        channel[i] = samples[i]
                    }

                    await playerNode.scheduleBuffer(buffer)
                }

                // Allow remaining buffers to finish playing
                try? await Task.sleep(for: .seconds(0.5))

                if !Task.isCancelled {
                    lastGeneratedSamples = accumulatedSamples
                }
                isSpeaking = false
                audioEngine.stop()
            } catch {
                if !Task.isCancelled {
                    lastError = error.localizedDescription
                }
                isSpeaking = false
            }
        }
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        playerNode?.stop()
        engine?.stop()
        engine = nil
        playerNode = nil
        isSpeaking = false
    }

    func unloadModel() {
        stop()
        model = nil
        loadedModelID = nil
        lastGeneratedSamples = []
    }

    func saveAudioToFile() -> URL? {
        guard !lastGeneratedSamples.isEmpty, let model else { return nil }

        let sampleRate = model.sampleRate
        let bitsPerSample = 16
        let numChannels = 1

        let dataSize = lastGeneratedSamples.count * (bitsPerSample / 8)
        let fileSize = 36 + dataSize

        var wavData = Data()

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        let byteRate = Int(sampleRate) * numChannels * (bitsPerSample / 8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        let blockAlign = numChannels * (bitsPerSample / 8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })

        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        for sample in lastGeneratedSamples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16Value = Int16(clamped * Float(Int16.max))
            wavData.append(contentsOf: withUnsafeBytes(of: int16Value.littleEndian) { Array($0) })
        }

        let timestamp = Date().formatted(.dateTime.year().month().day().hour().minute().second())
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let fileName = "tts_\(timestamp).wav"

        guard let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            lastError = "Could not find Downloads folder"
            return nil
        }
        let fileURL = downloadsDir.appendingPathComponent(fileName)

        do {
            try wavData.write(to: fileURL)
            return fileURL
        } catch {
            lastError = "Failed to save audio: \(error.localizedDescription)"
            return nil
        }
    }
}

#else

// Stub for builds without MLXAudioTTS — no fake behavior, just API surface
@Observable @MainActor
final class MLXTTSService {
    static let shared = MLXTTSService()

    var isLoading = false
    var isSpeaking = false
    var loadedModelID: String?
    var loadingProgress = ""
    var lastError: String?

    var canSaveAudio: Bool { false }
    var availableVoices: [String] { [] }

    static let supportedModelPatterns: [String] = [
        "soprano", "orpheus", "qwen3-tts", "qwen3_tts",
        "marvis", "csm", "sesame", "pocket_tts", "pocket-tts",
        "vyvo", "llama-tts", "llama_tts"
    ]

    static func isSupportedTTSModel(_ name: String) -> Bool {
        let lower = name.lowercased()
        return supportedModelPatterns.contains { lower.contains($0) }
    }

    func loadModel(repoID: String) async throws {
        lastError = "TTS is not available in this build. Link the MLXAudioTTS package."
    }

    func speak(text: String, voice: String?) {
        lastError = "TTS is not available in this build."
    }

    static var hubCacheModelsDirectory: URL {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        if isSandboxed {
            return URL.cachesDirectory
                .appendingPathComponent("huggingface")
                .appendingPathComponent("hub")
        }
        return home
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
    }

    func stop() { isSpeaking = false }
    func unloadModel() { loadedModelID = nil }
    func saveAudioToFile() -> URL? { nil }
}

#endif
