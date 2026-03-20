import Foundation

/// Manages automatic conversation summarization when context approaches the token limit.
/// Adapted from the Perspective Chat CLI pattern for use with local MLX models.
struct ContextSummarizationService {

    // MARK: - Token Budget Constants

    /// Character-to-token ratio (conservative: 4 chars ≈ 1 token)
    static let charsPerToken: Double = 4.0

    /// Maximum characters for summarization input sent to the model
    static let maxSummarizationInputCharacters = 6000

    /// Maximum characters for the generated summary
    static let maxSummaryCharacters = 800

    /// Safety margin — trigger summarization before hitting the hard limit
    static let safetyMarginRatio = 0.75

    /// Number of recent messages to keep verbatim after summarization
    static let recentMessagesToKeep = 6

    // MARK: - Threshold Check

    /// Determines whether the conversation needs summarization before the next send.
    ///
    /// - First summarization: triggers when the full conversation exceeds the token threshold.
    /// - Re-summarization: triggers when enough new messages have accumulated beyond
    ///   the recent window since the last summary, preventing messages from being silently dropped.
    static func needsSummarization(
        conversation: Conversation,
        pendingUserMessage: String,
        contextLength: Int
    ) -> Bool {
        let messageCount = conversation.messages.count
        guard messageCount > recentMessagesToKeep else { return false }

        let hasSummary = !(conversation.runningSummary ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasSummary {
            // Re-summarize when new messages have accumulated that would be lost—
            // i.e., messages between the last summary boundary and the current recent window.
            let messagesSinceLastSummary = messageCount - conversation.lastSummarizedMessageCount
            return messagesSinceLastSummary > recentMessagesToKeep * 2
        }

        // No summary yet — check token-based threshold against full conversation
        let totalChars = conversation.totalCharacterCount + pendingUserMessage.count
        let totalTokenEstimate = estimateTokens(fromCharCount: totalChars)
        let threshold = Int(Double(contextLength) * safetyMarginRatio)
        return totalTokenEstimate > threshold
    }

    // MARK: - Prompt Building

    /// Builds a summarization prompt from messages that haven't yet been summarized.
    ///
    /// On re-summarization, only includes messages between `lastSummarizedMessageCount`
    /// and the recent window, combined with the existing running summary.
    static func buildSummarizationPrompt(for conversation: Conversation) -> String? {
        let sorted = conversation.sortedMessages
        guard sorted.count > recentMessagesToKeep else { return nil }

        let recentCutoff = sorted.count - recentMessagesToKeep
        let startIndex = max(0, conversation.lastSummarizedMessageCount)
        guard recentCutoff > startIndex else { return nil }

        let messagesToSummarize = Array(sorted[startIndex..<recentCutoff])
        guard !messagesToSummarize.isEmpty else { return nil }

        let existingSummary = conversation.runningSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let conversationText = messagesToSummarize.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            let content = msg.content.count > 500
                ? String(msg.content.prefix(500)) + "..."
                : msg.content
            return "\(role): \(content)"
        }.joined(separator: "\n")

        var input: String
        if !existingSummary.isEmpty {
            input = "Previous summary:\n\(existingSummary)\n\nNew messages:\n\(conversationText)"
        } else {
            input = conversationText
        }

        // Truncate if input is too long
        if input.count > maxSummarizationInputCharacters {
            input = String(input.suffix(maxSummarizationInputCharacters))
        }

        return """
        Summarize this conversation in under 800 characters using bullet points. \
        Output ONLY the summary, no preamble. Preserve: key topics, user preferences, \
        decisions made, and pending questions. Format each point as "• Topic: detail".

        \(input)
        """
    }

    /// Builds the prompt for the model that incorporates a running summary + recent messages.
    static func buildContextualPrompt(
        conversation: Conversation,
        userMessage: String
    ) -> [(role: String, content: String)] {
        let sorted = conversation.sortedMessages
        var prompt: [(role: String, content: String)] = []

        // Include per-conversation system prompt if set
        if let systemPrompt = conversation.systemPrompt,
           !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt.append((role: "system", content: systemPrompt))
        }

        if let summary = conversation.runningSummary,
           !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt.append((
                role: "system",
                content: "Summary of earlier conversation:\n\(summary)"
            ))

            // Only include recent messages after the summary
            let recentCount = min(recentMessagesToKeep, sorted.count)
            let recentMessages = sorted.suffix(recentCount)
            for msg in recentMessages {
                // Skip the current user message — it's appended by the caller
                if msg.role == .user && msg.content == userMessage && msg === sorted.last {
                    continue
                }
                prompt.append((role: msg.role.rawValue, content: msg.content))
            }
        } else {
            // No summary yet — send full history (excluding current user message)
            for msg in sorted {
                if msg.role == .user && msg.content == userMessage && msg === sorted.last {
                    continue
                }
                prompt.append((role: msg.role.rawValue, content: msg.content))
            }
        }

        // Always end with the current user message
        prompt.append((role: "user", content: userMessage))
        return prompt
    }

    /// Cleans and truncates a raw summary string from the model.
    static func cleanSummary(_ raw: String) -> String {
        var summary = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if summary.count > maxSummaryCharacters {
            summary = String(summary.prefix(maxSummaryCharacters))
            if let lastNewline = summary.lastIndex(of: "\n") {
                summary = String(summary[..<lastNewline])
            }
        }
        return summary
    }

    // MARK: - Token Estimation

    static func estimateTokens(from text: String) -> Int {
        max(1, Int(ceil(Double(text.count) / charsPerToken)))
    }

    static func estimateTokens(fromCharCount count: Int) -> Int {
        max(1, Int(ceil(Double(count) / charsPerToken)))
    }
}
