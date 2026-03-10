import SwiftUI

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.body)
                .lineLimit(1)

            Text(conversation.lastMessagePreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(conversation.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Conversation: \(conversation.title). Last message: \(conversation.lastMessagePreview). Updated \(conversation.updatedAt.formatted(.relative(presentation: .named)))")
        .accessibilityHint("Double tap to open")
    }
}
