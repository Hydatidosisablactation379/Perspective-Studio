import SwiftUI
import SwiftData
import Accessibility

struct ChatDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let conversation: Conversation
    @Bindable var chatViewModel: ChatViewModel
    @State private var focusInput = false

    @AppStorage("experienceLevel") private var experienceLevelRaw: String = ExperienceLevel.beginner.rawValue
    private var experienceLevel: ExperienceLevel {
        ExperienceLevel(rawValue: experienceLevelRaw) ?? .beginner
    }

    private var sortedMessages: [Message] {
        conversation.sortedMessages
    }

    var body: some View {
        VStack(spacing: 0) {
            // Model picker + status bar
            modelBar
                .accessibilitySortPriority(3)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedMessages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)

                            if message.id != sortedMessages.last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }

                        if chatViewModel.isSummarizing {
                            summarizingIndicator
                        }
                    }
                    .padding(.vertical, 8)
                }
                .accessibilitySortPriority(2)
                .onChange(of: conversation.messages.count) {
                    if let lastID = sortedMessages.last?.id {
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

            Divider()

            // Input
            ChatInputView(
                text: $chatViewModel.messageText,
                attachedVideoURL: $chatViewModel.attachedVideoURL,
                attachedFileURLs: $chatViewModel.attachedFileURLs,
                isGenerating: chatViewModel.isGenerating,
                isVisualModel: chatViewModel.selectedModelIsVisual,
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
            .accessibilitySortPriority(1)
            .onAppear {
                chatViewModel.scanInstalledModels()
            }
        }
        .navigationTitle(conversation.title)
        .onChange(of: conversation.id) {
            focusInput = true
        }
    }

    // MARK: - Model Bar

    /// Status-only bar at the top — model picker is now in the input area.
    private var modelBar: some View {
        HStack(spacing: 12) {
            statusIndicator
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        switch chatViewModel.modelState {
        case .idle:
            Text(experienceLevel == .beginner ? "Pick a model to start" : "No model loaded")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(experienceLevel == .beginner ? "Pick a model to start chatting" : "No model loaded")

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(maxWidth: 120)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Downloading model, \(Int(progress * 100)) percent")

        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(experienceLevel == .beginner ? "Getting ready…" : "Loading model…")
                    .font(.caption)
            }
            .accessibilityElement(children: .combine)

        case .ready(let name):
            if chatViewModel.isGenerating {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(experienceLevel == .beginner ? "Thinking…" : "Generating…")
                        .font(.caption)
                }
                .accessibilityElement(children: .combine)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text(experienceLevel == .beginner ? "Ready" : name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Model \(name) is ready")
            }

        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .accessibilityHidden(true)
                Text(experienceLevel == .beginner ? "Something went wrong" : message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Error: \(message)")
        }
    }

    // MARK: - Summarizing Indicator

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
