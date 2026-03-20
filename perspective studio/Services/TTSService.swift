import Foundation
import AVFoundation

@Observable @MainActor
final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSService()

    var isSpeaking: Bool = false
    var speakingMessageID: UUID? = nil

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, messageID: UUID) {
        if isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let plain = stripMarkdown(text)
        guard !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let voiceID = UserDefaults.standard.string(forKey: "ttsVoiceIdentifier")
        let voice = voiceID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)

        let utterance = AVSpeechUtterance(string: plain)
        utterance.voice = voice
        utterance.rate = 0.5

        speakingMessageID = messageID
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        speakingMessageID = nil
    }

    func availableVoices() -> [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let currentLang = Locale.current.language.languageCode?.identifier ?? "en"
        let local = all.filter { $0.language.hasPrefix(currentLang) }.sorted { $0.name < $1.name }
        let others = all.filter { !$0.language.hasPrefix(currentLang) }.sorted { $0.name < $1.name }
        return local + others
    }

    // MARK: - Markdown Stripping

    private func stripMarkdown(_ text: String) -> String {
        var result = text

        // Code blocks (``` ... ```)
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)

        // Inline code
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)

        // Bold+italic ***text***
        result = result.replacingOccurrences(of: "\\*{3}([^*]+)\\*{3}", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_{3}([^_]+)_{3}", with: "$1", options: .regularExpression)

        // Bold **text** or __text__
        result = result.replacingOccurrences(of: "\\*{2}([^*]+)\\*{2}", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_{2}([^_]+)_{2}", with: "$1", options: .regularExpression)

        // Italic *text* or _text_
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)

        // Images ![alt](url) → alt
        result = result.replacingOccurrences(of: "!\\[([^\\]]*)]\\([^)]*\\)", with: "$1", options: .regularExpression)

        // Links [text](url) → text
        result = result.replacingOccurrences(of: "\\[([^\\]]+)]\\([^)]*\\)", with: "$1", options: .regularExpression)

        // Headings (# at start of line)
        result = result.replacingOccurrences(of: "(?m)^#{1,6}\\s+", with: "", options: .regularExpression)

        // Blockquotes
        result = result.replacingOccurrences(of: "(?m)^>\\s*", with: "", options: .regularExpression)

        // Horizontal rules
        result = result.replacingOccurrences(of: "(?m)^[-*_]{3,}$", with: "", options: .regularExpression)

        // List items: leading - or * or +
        result = result.replacingOccurrences(of: "(?m)^[\\-\\*\\+]\\s+", with: "", options: .regularExpression)

        // Numbered list items: "1. "
        result = result.replacingOccurrences(of: "(?m)^\\d+\\.\\s+", with: "", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageID = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingMessageID = nil
        }
    }
}
