import SwiftUI
import SwiftData
import Accessibility

struct ChatDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let conversation: Conversation
    @Bindable var chatViewModel: ChatViewModel
    @State private var focusInput = false

    private var experienceLevel: ExperienceLevel {
        OnboardingViewModel.currentExperienceLevel
    }

    var body: some View {
        VStack(spacing: 0) {
            modelStatusBar

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(conversation.sortedMessages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }

                        if chatViewModel.isSummarizing {
                            summarizingIndicator
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: conversation.messages.count) {
                    Task { @MainActor in
                        if let lastID = conversation.sortedMessages.last?.id {
                            if reduceMotion {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            } else {
                                withAnimation {
                                    proxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            ChatInputView(
                text: $chatViewModel.messageText,
                attachedVideoURL: $chatViewModel.attachedVideoURL,
                attachedFileURLs: $chatViewModel.attachedFileURLs,
                isGenerating: chatViewModel.isGenerating,
                isVideoModel: chatViewModel.selectedModelIsVideo,
                installedModels: chatViewModel.installedModels,
                selectedModelID: chatViewModel.selectedModelID,
                onSelectModel: { model in
                    chatViewModel.loadInstalledModel(model)
                },
                onSend: {
                    chatViewModel.sendMessage(in: modelContext)
                },
                onStop: {
                    chatViewModel.stopGenerating()
                },
                shouldFocus: $focusInput
            )
            .onAppear {
                chatViewModel.scanInstalledModels()
            }
        }
        .navigationTitle(conversation.title)
        .navigationSubtitle(chatViewModel.modelState.statusText)
        .onChange(of: conversation.id) {
            focusInput = true
        }
    }

    private var modelStatusBar: some View {
        HStack(spacing: 8) {
            switch chatViewModel.modelState {
            case .idle:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(experienceLevel == .beginner ? "Pick a model to start chatting" : "No model loaded")
                    .font(.caption)

            case .downloading(let progress):
                ProgressView(value: progress)
                    .frame(maxWidth: 150)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .monospacedDigit()

            case .loading:
                ProgressView()
                    .controlSize(.small)
                Text(chatViewModel.modelState.statusText(for: experienceLevel))
                    .font(.caption)

            case .ready(let name):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text(name)
                    .font(.caption)
                    .lineLimit(1)

            case .error(let message):
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.caption)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
    }

    private var summarizingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Condensing conversation history…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Condensing conversation history")
    }
}
