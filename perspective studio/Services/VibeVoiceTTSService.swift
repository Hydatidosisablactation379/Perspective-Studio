import Foundation
import AVFoundation

#if canImport(VibeVoice)
import VibeVoice
import MLX

@Observable @MainActor
final class VibeVoiceTTSService {
    static let shared = VibeVoiceTTSService()
    static let isAvailable = true

    var isLoading: Bool = false
    var isSpeaking: Bool = false
    var loadedModelID: String?
    var loadingProgress: String = ""
    var availableVoices: [String] = []
    var lastError: String?
    var isGeneratingPreview: Bool = false

    private var tts: VibeVoiceTextToSpeech?
    private var modelDirectory: URL?
    private var player: RealtimeAudioPlayer?
    private var speakTask: Task<Void, Never>?
    private var lastGeneratedAudio: MLXArray?

    private init() {}

    static func isSupportedModel(_ name: String) -> Bool {
        name.lowercased().contains("vibevoice")
    }

    var canSaveAudio: Bool {
        lastGeneratedAudio != nil && !isSpeaking
    }

    func loadModel(repoID: String) async throws {
        isLoading = true
        lastError = nil

        do {
            let modelDir = try await resolveWithProgress(repoID: repoID)
            modelDirectory = modelDir

            loadingProgress = "Loading model weights…"
            let (inference, voices) = try await loadModelWeightsOffMain(modelDir: modelDir)

            loadingProgress = "Loading tokenizer…"
            let tokenizer = try await VibeVoiceTextToSpeech.loadTokenizer()

            availableVoices = voices
            tts = VibeVoiceTextToSpeech(inference: inference, tokenizer: tokenizer)
            loadedModelID = repoID
            loadingProgress = ""
            isLoading = false
        } catch {
            loadingProgress = ""
            isLoading = false
            throw error
        }
    }

    /// Loads model weights and voice caches off the main thread.
    private nonisolated func loadModelWeightsOffMain(modelDir: URL) async throws -> (VibeVoiceStreamInference, [String]) {
        let model = try loadVibeVoiceStreamModel(from: modelDir)
        let inference = VibeVoiceStreamInference(
            model: model,
            numInferenceSteps: 20,
            cfgScale: 1.3
        )

        copySharedVoicesIfNeeded(to: modelDir)
        let voices = scanVoiceCachesResult(in: modelDir)

        if let firstVoice = voices.first, firstVoice != "Default" {
            let path = voiceCachePath(for: firstVoice, in: modelDir)
            try inference.loadVoiceCache(from: path)
        }

        return (inference, voices)
    }

    func speak(text: String, voice: String?) {
        guard let tts, let modelDirectory else { return }
        stop()

        isSpeaking = true
        lastError = nil

        let voicePath: String? = if let voice, voice != "Default" {
            voiceCachePath(for: voice, in: modelDirectory)
        } else {
            nil
        }

        speakTask = Task {
            do {
                let audio = try await generateAudio(tts: tts, text: text, voicePath: voicePath)

                if Task.isCancelled {
                    isSpeaking = false
                    return
                }

                lastGeneratedAudio = audio
                try playAudio(audio)
            } catch {
                isSpeaking = false
                if !Task.isCancelled {
                    lastError = error.localizedDescription
                }
            }
        }
    }

    private nonisolated func generateAudio(tts: VibeVoiceTextToSpeech, text: String, voicePath: String?) async throws -> MLXArray {
        if let voicePath {
            try? tts.loadVoiceCache(from: voicePath)
        }
        return try tts.generate(text: text, maxSpeechTokens: 500)
    }

    private func playAudio(_ audio: MLXArray) throws {
        let newPlayer = try RealtimeAudioPlayer()
        player = newPlayer

        newPlayer.onPlaybackComplete = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = false
                self?.player = nil
            }
        }

        try newPlayer.start()
        newPlayer.scheduleAudio(chunk: audio)
        newPlayer.audioStreamerDidFinish(AudioStreamer())
    }

    func previewVoice(_ voice: String) {
        guard tts != nil, modelDirectory != nil else { return }
        isGeneratingPreview = true
        speak(text: "Hello, this is a preview of this voice.", voice: voice)
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        player?.stop()
        player = nil
        isSpeaking = false
        isGeneratingPreview = false
    }

    func unloadModel() {
        stop()
        tts = nil
        modelDirectory = nil
        loadedModelID = nil
        availableVoices = []
        lastError = nil
        lastGeneratedAudio = nil
    }

    func saveAudioToFile() -> URL? {
        guard let audio = lastGeneratedAudio else { return nil }

        let flattened = audio.reshaped([-1])
        eval(flattened)
        let samples = flattened.asArray(Float.self)

        let sampleRate: Int = 24000
        let bitsPerSample: Int = 16
        let numChannels: Int = 1

        let dataSize = samples.count * (bitsPerSample / 8)
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
        let byteRate = sampleRate * numChannels * (bitsPerSample / 8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        let blockAlign = numChannels * (bitsPerSample / 8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })

        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16Value = Int16(clamped * Float(Int16.max))
            wavData.append(contentsOf: withUnsafeBytes(of: int16Value.littleEndian) { Array($0) })
        }

        let timestamp = Date().formatted(.dateTime.year().month().day().hour().minute().second())
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let fileName = "vibevoice_\(timestamp).wav"

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

    // MARK: - Private

    private func resolveWithProgress(repoID: String) async throws -> URL {
        if ModelResolution.findCachedModel(modelId: repoID) != nil {
            loadingProgress = "Getting ready…"
        } else {
            loadingProgress = "Downloading model (first time may take a while)…"
        }
        return try await ModelResolution.resolve(modelSpec: repoID)
    }

    private nonisolated func copySharedVoicesIfNeeded(to modelDir: URL) {
        if resolveVoiceDirectory(in: modelDir) != nil { return }

        let fm = FileManager.default
        let mlxCacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("models")
        let hfCacheDir = ModelResolution.getHuggingFaceCacheDirectory()

        if let authors = try? fm.contentsOfDirectory(at: mlxCacheDir, includingPropertiesForKeys: nil) {
            for authorDir in authors {
                guard let models = try? fm.contentsOfDirectory(at: authorDir, includingPropertiesForKeys: nil) else { continue }
                for modelDir2 in models {
                    if findAndCopyVoices(from: modelDir2, to: modelDir) != nil {
                        return
                    }
                }
            }
        }

        if let entries = try? fm.contentsOfDirectory(at: hfCacheDir, includingPropertiesForKeys: nil) {
            for entry in entries {
                guard entry.lastPathComponent.hasPrefix("models--") else { continue }
                let snapshotsDir = entry.appendingPathComponent("snapshots")
                guard let snapshots = try? fm.contentsOfDirectory(at: snapshotsDir, includingPropertiesForKeys: nil) else { continue }
                for snapshot in snapshots {
                    if findAndCopyVoices(from: snapshot, to: modelDir) != nil {
                        return
                    }
                }
            }
        }
    }

    @discardableResult
    private nonisolated func findAndCopyVoices(from sourceDir: URL, to destDir: URL) -> URL? {
        let fm = FileManager.default
        for dirName in ["voices", "voice_cache"] {
            let sourceVoiceDir = sourceDir.appendingPathComponent(dirName)
            guard let voiceFiles = try? fm.contentsOfDirectory(atPath: sourceVoiceDir.path()),
                  voiceFiles.contains(where: { $0.hasSuffix(".safetensors") }) else { continue }

            let destVoiceDir = destDir.appendingPathComponent("voices")
            try? fm.createDirectory(at: destVoiceDir, withIntermediateDirectories: true)
            for file in voiceFiles where file.hasSuffix(".safetensors") {
                let src = sourceVoiceDir.appendingPathComponent(file)
                let dst = destVoiceDir.appendingPathComponent(file)
                if !fm.fileExists(atPath: dst.path()) {
                    try? fm.copyItem(at: src, to: dst)
                }
            }
            return destVoiceDir
        }
        return nil
    }

    private nonisolated func scanVoiceCachesResult(in modelDir: URL) -> [String] {
        let fm = FileManager.default
        guard let dir = resolveVoiceDirectory(in: modelDir),
              let files = try? fm.contentsOfDirectory(atPath: dir.path()) else {
            return ["Default"]
        }

        let voices = files
            .filter { $0.hasSuffix(".safetensors") }
            .map { $0.replacingOccurrences(of: ".safetensors", with: "") }
            .sorted()

        return voices.isEmpty ? ["Default"] : voices
    }

    private nonisolated func resolveVoiceDirectory(in modelDir: URL) -> URL? {
        let fm = FileManager.default
        for dirName in ["voices", "voice_cache"] {
            let dir = modelDir.appendingPathComponent(dirName)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dir.path(), isDirectory: &isDir), isDir.boolValue {
                return dir
            }
        }
        return nil
    }

    private nonisolated func voiceCachePath(for voice: String, in modelDir: URL) -> String {
        let voiceDir = resolveVoiceDirectory(in: modelDir) ?? modelDir.appendingPathComponent("voices")
        return voiceDir.appendingPathComponent("\(voice).safetensors").path()
    }
}

#else

/// Stub when VibeVoice package is not available.
@Observable @MainActor
final class VibeVoiceTTSService {
    static let shared = VibeVoiceTTSService()
    static let isAvailable = false

    var isLoading = false
    var isSpeaking = false
    var loadedModelID: String?
    var loadingProgress = ""
    var availableVoices: [String] = []
    var lastError: String?
    var isGeneratingPreview = false
    var canSaveAudio: Bool { false }

    private init() {}

    static func isSupportedModel(_ name: String) -> Bool { false }
    func loadModel(repoID: String) async throws {}
    func speak(text: String, voice: String?) {}
    func previewVoice(_ voice: String) {}
    func stop() {}
    func unloadModel() {}
    func saveAudioToFile() -> URL? { nil }
}

#endif
