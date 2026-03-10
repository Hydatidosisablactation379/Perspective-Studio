import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID = UUID()
    var title: String = "New Conversation"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var modelIdentifier: String?
    var runningSummary: String?
    var lastSummarizedMessageCount: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init(title: String = "New Conversation", modelIdentifier: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.modelIdentifier = modelIdentifier
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    var lastMessagePreview: String {
        guard let last = sortedMessages.last else { return "No messages yet" }
        return String(last.content.prefix(60))
    }

    var totalCharacterCount: Int {
        messages.reduce(0) { $0 + $1.content.count }
    }
}
