import SwiftUI
import AppKit

// MARK: - Full-width message row (ChatGPT / Copilot style)

struct MessageBubbleView: View {
    let message: Message
    @State private var showingCopyConfirmation = false
    @State private var ttsService = TTSService.shared

    private var isSpeakingThis: Bool { ttsService.speakingMessageID == message.id }

    var body: some View {
        if message.role == .system {
            systemBanner
        } else {
            messageRow
        }
    }

    // MARK: - Message Row

    private var messageRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: avatar + role name + timestamp
            HStack(spacing: 8) {
                avatar
                Text(roleName)
                    .font(.subheadline)
                    .bold()
                Spacer()
                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            // Content
            Text(message.content)
                .font(.body)
                .textSelection(.enabled)

            // Action buttons for assistant messages
            if message.role == .assistant && !message.content.isEmpty {
                actionButtons
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(message.role == .user ? Color.primary.opacity(0.04) : .clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message.role == .user ? "You: \(message.content)" : "Assistant: \(message.content)")
        .accessibilityHint("Swipe up or down for actions")
        .accessibilityAction(named: "Copy message") { copyMessage() }
        .accessibilityAction(named: isSpeakingThis ? "Stop reading aloud" : "Read aloud") { toggleSpeech() }
        .contextMenu {
            Button("Copy Text", systemImage: "doc.on.doc", action: copyMessage)
            Button(isSpeakingThis ? "Stop Reading" : "Read Aloud",
                   systemImage: isSpeakingThis ? "stop.circle" : "speaker.wave.2",
                   action: toggleSpeech)
        }
    }

    // MARK: - System Banner

    private var systemBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System note: \(message.content)")
    }

    // MARK: - Components

    private var roleName: String {
        message.role == .user ? "You" : "Assistant"
    }

    private var avatar: some View {
        Circle()
            .fill(message.role == .user
                  ? LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                  : LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 24, height: 24)
            .overlay(
                Image(systemName: message.role == .user ? "person.fill" : "cpu")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Copy", systemImage: showingCopyConfirmation ? "checkmark" : "doc.on.doc") {
                copyMessage()
            }
            .foregroundStyle(showingCopyConfirmation ? .green : .secondary)
            .accessibilityLabel(showingCopyConfirmation ? "Copied" : "Copy message")

            Button(isSpeakingThis ? "Stop" : "Read Aloud",
                   systemImage: isSpeakingThis ? "stop.circle" : "speaker.wave.2") {
                toggleSpeech()
            }
            .foregroundStyle(isSpeakingThis ? Color.accentColor : .secondary)
            .accessibilityLabel(isSpeakingThis ? "Stop reading aloud" : "Read message aloud")
        }
        .font(.caption)
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)

        withAnimation(.easeInOut(duration: 0.2)) {
            showingCopyConfirmation = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.2)) {
                showingCopyConfirmation = false
            }
        }
    }

    private func toggleSpeech() {
        if TTSService.shared.speakingMessageID == message.id {
            TTSService.shared.stop()
        } else {
            TTSService.shared.speak(text: message.content, messageID: message.id)
        }
    }
}
