import Foundation
import SwiftUI

struct HFModel: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let downloads: Int
    let likes: Int
    let tags: [String]
    let pipelineTag: String?
    let createdAt: String?

    var displayName: String {
        name.replacingOccurrences(of: "mlx-community/", with: "")
    }

    var beginnerDisplayName: String {
        var clean = displayName
        let suffixes = ["-4bit", "-8bit", "-bf16", "-fp16", "-GGUF", "-gguf",
                        "-4bit-mlx", "-8bit-mlx", "-bf16-mlx",
                        "-Instruct", "-instruct", "-Chat", "-chat"]
        for suffix in suffixes {
            if clean.hasSuffix(suffix) {
                clean = String(clean.dropLast(suffix.count))
            }
        }
        // Strip parameter size suffixes like -7B, -0.5B
        if let range = clean.range(of: #"-\d+\.?\d*[BbMm]$"#, options: .regularExpression) {
            clean = String(clean[clean.startIndex..<range.lowerBound])
        }
        return clean
    }

    var beginnerSizeLabel: String {
        guard let size = parameterSize else { return "Unknown" }
        switch size {
        case ..<1: return "Tiny"
        case 1..<3: return "Small"
        case 3..<13: return "Medium"
        case 13..<40: return "Large"
        default: return "Very Large"
        }
    }

    var quantization: String? {
        let lower = displayName.lowercased()
        if lower.contains("4bit") || lower.contains("4-bit") { return "4-bit" }
        if lower.contains("8bit") || lower.contains("8-bit") { return "8-bit" }
        if lower.contains("bf16") { return "bf16" }
        if lower.contains("fp16") { return "fp16" }
        if lower.contains("fp32") { return "fp32" }
        if tags.contains("4-bit") { return "4-bit" }
        if tags.contains("8-bit") { return "8-bit" }
        return nil
    }

    var parameterSize: Double? {
        let name = displayName
        // Match patterns like "7B", "0.5B", "82M", "1.5B"
        if let match = name.range(of: #"(\d+\.?\d*)[Bb]"#, options: .regularExpression) {
            let numStr = name[match].dropLast()
            return Double(numStr)
        }
        if let match = name.range(of: #"(\d+\.?\d*)[Mm]"#, options: .regularExpression) {
            let numStr = name[match].dropLast()
            if let val = Double(numStr) {
                return val / 1000.0
            }
        }
        return nil
    }

    var estimatedRAMGB: Double? {
        guard let params = parameterSize else { return nil }
        let bitsPerParam: Double = {
            if let q = quantization {
                if q.contains("4") { return 4.5 } // extra 0.5 for quantization metadata
                if q.contains("8") { return 8.5 }
                if q.contains("bf16") || q.contains("fp16") { return 16.0 }
                if q.contains("fp32") { return 32.0 }
            }
            return 4.5 // default to 4-bit quantized (most MLX models)
        }()
        let weightGB = (params * bitsPerParam) / 8.0
        let overhead = max(weightGB * 0.20, 0.5)
        return weightGB + overhead
    }

    var category: ModelCategory {
        let pipeline = (pipelineTag ?? "").lowercased()
        let nameLower = displayName.lowercased()
        let allTags = tags.map { $0.lowercased() }

        // TTS
        if pipeline == "text-to-speech" || pipeline == "text-to-audio" || allTags.contains("tts")
            || nameLower.contains("kokoro") || nameLower.contains("orpheus")
            || nameLower.contains("parler") || nameLower.contains("bark")
            || nameLower.contains("outetts") || nameLower.contains("mars5")
            || nameLower.contains("styletts") || nameLower.contains("f5-tts")
            || nameLower.contains("cosyvoice") || nameLower.contains("chattts") {
            return .tts
        }

        // Transcription / ASR
        if pipeline == "automatic-speech-recognition"
            || nameLower.contains("whisper") || nameLower.contains("parakeet")
            || nameLower.contains("voxtral") || nameLower.contains("canary")
            || nameLower.contains("wav2vec") || nameLower.contains("hubert")
            || nameLower.contains("conformer") || nameLower.contains("mms-")
            || allTags.contains("automatic-speech-recognition")
            || allTags.contains("automatic-speech-translation")
            || allTags.contains("speech-to-text") || allTags.contains("asr")
            || allTags.contains("stt") || allTags.contains("transcription") {
            return .transcription
        }

        // Translation
        if pipeline == "translation" || nameLower.contains("translate") || nameLower.contains("nllb")
            || nameLower.contains("opus-mt") || nameLower.contains("marian")
            || nameLower.contains("seamless") || nameLower.contains("madlad")
            || nameLower.contains("tower") || allTags.contains("translation") {
            return .translation
        }

        // Audio processing
        if pipeline.contains("audio") && !pipeline.contains("text") {
            return .audio
        }
        if pipeline == "audio-classification" || pipeline == "audio-to-audio"
            || nameLower.contains("snac") || nameLower.contains("encodec")
            || nameLower.contains("musicgen") || nameLower.contains("audiogen")
            || nameLower.contains("dac-") {
            return .audio
        }

        // Video — must be checked before Vision to prevent misclassification
        if pipeline == "video-text-to-text"
            || allTags.contains("video-text-to-text")
            || nameLower.contains("video")
            || nameLower.contains("videollama") || nameLower.contains("videochat") {
            return .video
        }

        // Vision — check tags and pipeline
        if pipeline == "image-text-to-text" || pipeline == "visual-question-answering"
            || pipeline == "image-to-text" {
            return .vision
        }
        if allTags.contains("vision-language-model") || allTags.contains("image-text-to-text") {
            return .vision
        }
        if nameLower.contains("vision") || nameLower.contains("llava") || nameLower.contains("pixtral")
            || nameLower.contains("idefics") || nameLower.contains("minicpm-o")
            || nameLower.contains("paligemma") || nameLower.contains("florence")
            || nameLower.contains("molmo") || nameLower.contains("got-ocr")
            || nameLower.contains("moondream") || nameLower.contains("bunny")
            || nameLower.contains("internvl") || nameLower.contains("smolvlm")
            || nameLower.contains("fastvlm") {
            return .vision
        }
        // "VL" but not inside other words like "eval"
        if nameLower.hasSuffix("-vl") || nameLower.contains("-vl-") {
            return .vision
        }

        // Multimodal
        if allTags.contains("multimodal")
            || allTags.contains("audio-text-to-text") {
            return .multimodal
        }

        // Embedding
        if pipeline == "feature-extraction" || pipeline == "sentence-similarity"
            || allTags.contains("embedding") || allTags.contains("sentence-transformers")
            || nameLower.contains("embedding")
            || nameLower.contains("gte-") || nameLower.contains("bge-")
            || nameLower.contains("nomic-embed") || nameLower.contains("e5-")
            || nameLower.contains("jina-embed") {
            return .embedding
        }

        // Code
        if nameLower.contains("codestral") || nameLower.contains("codegemma")
            || nameLower.contains("deepseek-coder") || nameLower.contains("codellama")
            || nameLower.contains("starcoder") || nameLower.contains("devstral")
            || nameLower.contains("qwen2.5-coder") || nameLower.contains("qwen3-coder")
            || nameLower.contains("wizardcoder") || nameLower.contains("opencoder")
            || nameLower.contains("yi-coder") || nameLower.contains("codefuse") {
            return .code
        }
        if nameLower.contains("coder") || (nameLower.contains("code") && !nameLower.contains("unicode")) {
            return .code
        }

        // Reasoning — thinking models, R1, QwQ
        if nameLower.contains("deepseek-r1") || nameLower.contains("qwq")
            || nameLower.contains("reasoning") || nameLower.contains("thinking")
            || nameLower.contains("-r1-") || nameLower.hasSuffix("-r1")
            || nameLower.contains("marco-o1") || nameLower.contains("sky-t1") {
            return .reasoning
        }

        // Writing
        if nameLower.contains("writer") || nameLower.contains("story") || nameLower.contains("novel") {
            return .writing
        }

        // Chat — instruction-tuned, conversational, or known chat families
        let isConversational = allTags.contains("conversational")
        let hasChatTemplate = allTags.contains("chat_template")
        let isInstructTuned = nameLower.contains("instruct") || nameLower.contains("chat")
            || nameLower.hasSuffix("-it") || nameLower.contains("-it-")

        // Model families that are always chat/instruction-tuned
        let chatOnlyFamilies = ["vicuna", "openchat", "zephyr", "hermes",
                                "orca", "neural-chat", "wizardlm", "airoboros",
                                "openhermes", "dolphin", "nous-hermes", "saiga",
                                "tulu", "ultralm", "starling"]
        let isChatFamily = chatOnlyFamilies.contains { nameLower.contains($0) }

        if isConversational || isInstructTuned || isChatFamily || hasChatTemplate {
            return .chat
        }

        // General text generation (base models without instruct tuning)
        if pipeline == "text-generation" || pipeline == "text2text-generation" {
            return .general
        }

        // Models with no pipeline tag — try to infer from name
        if pipeline.isEmpty {
            // If name contains known model families, likely text gen
            let knownFamilies = ["llama", "mistral", "qwen", "gemma", "phi", "deepseek",
                                 "falcon", "yi-", "glm", "olmo", "mpt"]
            for family in knownFamilies {
                if nameLower.contains(family) {
                    return isInstructTuned || isConversational ? .chat : .general
                }
            }
        }

        return .general
    }

    var capabilities: [String] {
        switch category {
        case .chat: ["Answer questions", "Have conversations", "Write content", "Explain topics"]
        case .reasoning: ["Solve math problems", "Think step by step", "Logic puzzles", "Complex analysis"]
        case .code: ["Write code", "Debug errors", "Explain programming concepts", "Generate tests"]
        case .writing: ["Write stories and blog posts", "Edit and improve text", "Creative content"]
        case .vision: ["Describe images", "Answer questions about pictures", "Read text in images"]
        case .video: ["Understand video content", "Describe what happens in clips", "Answer questions about videos"]
        case .tts: ["Read text aloud", "Generate natural speech"]
        case .transcription: ["Turn spoken audio into text", "Transcribe recordings"]
        case .translation: ["Translate between languages", "Multilingual text processing"]
        case .audio: ["Process audio signals", "Separate speakers", "Audio analysis"]
        case .embedding: ["Power search systems", "Find similar content"]
        case .multimodal: ["Process text and images", "Multi-format understanding"]
        case .general: ["General purpose AI tasks", "Answer questions", "Write content"]
        }
    }

    var shortCapabilityText: String {
        switch category {
        case .chat: "Great for conversations and writing"
        case .reasoning: "Thinks step by step through problems"
        case .code: "Built for coding and programming"
        case .writing: "Helps with creative and long-form writing"
        case .vision: "Can understand and describe images"
        case .video: "Watches and understands video content"
        case .tts: "Reads text aloud in a natural voice"
        case .transcription: "Turns spoken audio into written text"
        case .translation: "Translates between languages"
        case .audio: "Processes and transforms audio"
        case .embedding: "Powers search behind the scenes"
        case .multimodal: "Handles text, images, and more"
        case .general: "General purpose AI model"
        }
    }

    var speedLabel: String {
        guard let size = parameterSize else { return "Unknown" }
        switch size {
        case ..<3: return "Fast"
        case 3..<13: return "Medium"
        default: return "Slow"
        }
    }

    var plainLanguageSummary: String {
        let maker = madeBy ?? "an open source project"
        let size = beginnerSizeLabel.lowercased()
        let capability = shortCapabilityText.lowercased()

        var summary = "This is a \(size) AI model from \(maker). It is \(capability)."

        if let params = parameterSize {
            let formatted = params >= 1 ? "\(Int(params)) billion" : "\(Int(params * 1000)) million"
            summary += " It has \(formatted) parameters."
        }

        if category == .chat || category == .general {
            summary += " You can have a conversation with it just like chatting with a friend."
        }

        return summary
    }

    var madeBy: String? {
        let lower = displayName.lowercased()
        if lower.contains("llama") || lower.contains("codellama") { return "Meta" }
        if lower.contains("gemma") { return "Google" }
        if lower.contains("qwen") || lower.contains("qwq") { return "Alibaba" }
        if lower.contains("mistral") || lower.contains("mixtral") || lower.contains("codestral") { return "Mistral" }
        if lower.contains("phi") { return "Microsoft" }
        if lower.contains("openelm") { return "Apple" }
        if lower.contains("deepseek") { return "DeepSeek" }
        if lower.contains("falcon") { return "TII" }
        if lower.contains("yi") && !lower.contains("tiny") { return "01.AI" }
        if lower.contains("command") || lower.contains("aya") { return "Cohere" }
        if lower.contains("starcoder") || lower.contains("starcoderbase") { return "BigCode" }
        if lower.contains("vicuna") { return "LMSYS" }
        if lower.contains("solar") { return "Upstage" }
        if lower.contains("internlm") { return "Shanghai AI Lab" }
        if lower.contains("baichuan") { return "Baichuan" }
        if lower.contains("chatglm") || lower.contains("glm") { return "Zhipu AI" }
        if lower.contains("olmo") { return "AI2" }
        if lower.contains("mpt") { return "MosaicML" }
        if lower.contains("stablelm") { return "Stability AI" }
        if lower.contains("openchat") { return "OpenChat" }
        if lower.contains("zephyr") { return "HuggingFace" }
        if lower.contains("nous") || lower.contains("hermes") { return "Nous Research" }
        if lower.contains("tinyllama") { return "TinyLlama Project" }
        if lower.contains("smollm") { return "HuggingFace" }
        if lower.contains("granite") { return "IBM" }
        if lower.contains("jamba") { return "AI21 Labs" }
        if lower.contains("dbrx") { return "Databricks" }
        if lower.contains("nemotron") { return "NVIDIA" }
        if lower.contains("exaone") { return "LG AI Research" }
        return nil
    }

    var isLikelyLoadable: Bool {
        let pipeline = (pipelineTag ?? "").lowercased()
        return pipeline.isEmpty
            || pipeline.contains("text-generation")
            || pipeline.contains("text2text-generation")
            || pipeline.contains("image-text-to-text")
            || pipeline.contains("video-text-to-text")
    }

    var notLoadableReason: String? {
        guard !isLikelyLoadable else { return nil }
        switch category {
        case .tts:
            return "Text-to-speech models require an audio synthesis engine that is not yet supported."
        case .transcription:
            return "Transcription models require a specialized audio pipeline that is not yet supported."
        case .translation:
            return "Translation models may require a specialized pipeline. Try loading it — some work."
        case .audio:
            return "Audio processing models require a specialized engine that is not yet supported."
        case .embedding:
            return "Embedding models produce vectors for search, not conversational text."
        case .multimodal:
            return "Multimodal models require multi-format input support not yet available."
        default:
            return "This model type is not yet supported for interactive use."
        }
    }

    var makerColor: Color {
        switch madeBy {
        case "Meta": return .blue
        case "Google": return .green
        case "Alibaba": return .orange
        case "Mistral": return .purple
        case "Microsoft": return .teal
        case "DeepSeek": return .indigo
        case "Apple": return .gray
        default: return .secondary
        }
    }

    /// Checks whether this model's weights exist in the HF Hub cache.
    var isDownloaded: Bool {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        let encoded = id.replacingOccurrences(of: "/", with: "--")
        let modelDir = cacheDir.appendingPathComponent("models--\(encoded)")
        let fm = FileManager.default
        return fm.fileExists(atPath: modelDir.appending(path: "blobs").path)
            || fm.fileExists(atPath: modelDir.appending(path: "snapshots").path)
    }
}

enum ModelCategory: String, CaseIterable, Codable, Sendable {
    case chat
    case reasoning
    case code
    case writing
    case vision
    case video
    case tts
    case transcription
    case translation
    case audio
    case embedding
    case multimodal
    case general

    var displayName: String {
        switch self {
        case .chat: "Chat"
        case .reasoning: "Reasoning"
        case .code: "Code"
        case .writing: "Writing"
        case .vision: "Vision"
        case .video: "Video"
        case .tts: "Text to Speech"
        case .transcription: "Transcription"
        case .translation: "Translation"
        case .audio: "Audio"
        case .embedding: "Search & Embedding"
        case .multimodal: "Multimodal"
        case .general: "General"
        }
    }

    var icon: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .reasoning: "brain"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .writing: "pencil.and.outline"
        case .vision: "eye"
        case .video: "film"
        case .tts: "speaker.wave.3"
        case .transcription: "waveform.and.mic"
        case .translation: "globe"
        case .audio: "waveform"
        case .embedding: "magnifyingglass"
        case .multimodal: "square.grid.2x2"
        case .general: "cpu"
        }
    }

    var beginnerDescription: String {
        switch self {
        case .chat: "Great at conversations, writing, and answering questions"
        case .reasoning: "Thinks step by step to solve complex problems"
        case .code: "Built for writing and understanding code"
        case .writing: "Helps with creative writing, editing, and content"
        case .vision: "Can look at images and describe what it sees"
        case .video: "Can watch and understand video content"
        case .tts: "Reads text aloud in a natural sounding voice"
        case .transcription: "Turns spoken audio into written text"
        case .translation: "Translates text from one language to another"
        case .audio: "Processes audio like separating speakers or transforming sound"
        case .embedding: "Powers search and recommendations behind the scenes"
        case .multimodal: "Handles multiple types of content"
        case .general: "A versatile AI model for various tasks"
        }
    }

    var technicalDescription: String {
        switch self {
        case .chat: "Instruction-tuned conversational models"
        case .reasoning: "Chain-of-thought reasoning models"
        case .code: "Code generation and completion models"
        case .writing: "Creative and long-form text generation models"
        case .vision: "Vision-language models (VLMs)"
        case .video: "Video understanding and captioning models"
        case .tts: "Text-to-speech synthesis models"
        case .transcription: "Automatic speech recognition (ASR) models"
        case .translation: "Machine translation models"
        case .audio: "Audio processing and generation models"
        case .embedding: "Text embedding and retrieval models"
        case .multimodal: "Multi-modal input/output models"
        case .general: "General-purpose language models"
        }
    }

    var color: Color {
        switch self {
        case .chat: .blue
        case .reasoning: .purple
        case .code: .green
        case .writing: .mint
        case .vision: .orange
        case .video: .red
        case .tts: .pink
        case .transcription: .cyan
        case .translation: .teal
        case .audio: .red
        case .embedding: .gray
        case .multimodal: .indigo
        case .general: .secondary
        }
    }
}
