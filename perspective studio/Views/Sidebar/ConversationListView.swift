import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Binding var selectedConversation: Conversation?
    let onNewChat: () -> Void
    let onDelete: (Conversation) -> Void

    @AppStorage("experienceLevel") private var experienceLevelRaw: String = ExperienceLevel.beginner.rawValue
    private var experienceLevel: ExperienceLevel {
        ExperienceLevel(rawValue: experienceLevelRaw) ?? .beginner
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(conversations) { conversation in
                    Button {
                        selectedConversation = conversation
                    } label: {
                        ConversationRowView(conversation: conversation)
                    }
                    .buttonStyle(.plain)
                    .background(selectedConversation?.id == conversation.id ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(.rect(cornerRadius: 6))
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            onDelete(conversation)
                        }
                    }
                    .accessibilityAddTraits(selectedConversation?.id == conversation.id ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
        }
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem {
                Button("New Chat", systemImage: "plus") {
                    onNewChat()
                }
        
                .accessibilityLabel("Start a new conversation")
                .accessibilityHint("Double tap to create a new chat")
            }
        }
        .overlay {
            if conversations.isEmpty {
                ContentUnavailableView(
                    experienceLevel == .beginner ? "No Chats Yet" : "No Conversations Yet",
                    systemImage: "bubble.left"
                )
            }
        }
    }

}
