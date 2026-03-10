import Foundation
import SwiftData

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

@Model
final class Message {
    var id: UUID = UUID()
    var role: MessageRole = MessageRole.user
    var content: String = ""
    var timestamp: Date = Date.now
    var conversation: Conversation?

    init(role: MessageRole, content: String, conversation: Conversation? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = .now
        self.conversation = conversation
    }
}
