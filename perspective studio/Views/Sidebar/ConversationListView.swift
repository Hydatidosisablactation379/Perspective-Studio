import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Binding var selectedConversation: Conversation?
    let modelState: ModelLoadingState
    let onNewChat: () -> Void
    let onDelete: (Conversation) -> Void

    private var experienceLevel: ExperienceLevel {
        OnboardingViewModel.currentExperienceLevel
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                modelStatusSection

                ForEach(conversations) { conversation in
                    ConversationRowView(conversation: conversation)
                        .background(selectedConversation?.id == conversation.id ? Color.accentColor.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedConversation = conversation
                        }
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

    @ViewBuilder
    private var modelStatusSection: some View {
        switch modelState {
        case .idle:
            EmptyView()
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(maxWidth: 100)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .monospacedDigit()
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Downloading model, \(Int(progress * 100)) percent")
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(modelState.statusText(for: experienceLevel))
                    .font(.caption)
            }
            .padding(.vertical, 4)
        case .ready(let name):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
            .accessibilityLabel("Model loaded: \(name)")
        case .error(let message):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.caption)
                    .lineLimit(2)
            }
            .padding(.vertical, 4)
        }
    }
}
