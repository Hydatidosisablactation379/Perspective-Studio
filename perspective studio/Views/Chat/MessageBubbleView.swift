import SwiftUI
import AppKit
import AVFoundation

struct MessageBubbleView: View {
    let message: Message
    @State private var showingCopyConfirmation = false
    @State private var ttsService = TTSService.shared
    private let maxBubbleWidth: CGFloat = 520

    private var isSpeakingThis: Bool { ttsService.speakingMessageID == message.id }

    private var isUser: Bool { message.role == .user }
    private var isSystem: Bool { message.role == .system }

    var body: some View {
        if isSystem {
            systemBanner
        } else {
            HStack(alignment: isUser ? .bottom : .top, spacing: 8) {
                if isUser {
                    Spacer(minLength: 50)
                    userBubble
                    userAvatar
                } else {
                    assistantAvatar
                    assistantBubble
                    Spacer(minLength: 50)
                }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isUser ? "You said: \(message.content)" : "Assistant said: \(message.content)")
            .accessibilityAction(named: "Copy") { copyMessage() }
            .accessibilityAction(named: isSpeakingThis ? "Stop reading" : "Read aloud") { toggleSpeech() }
            .contextMenu {
                Button(action: copyMessage) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
            }
        }
    }

    // MARK: - System Banner

    private var systemBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System note: \(message.content)")
    }

    private var userBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(.white)
            .textSelection(.enabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.0, green: 0.48, blue: 1.0),
                             Color(red: 0.0, green: 0.42, blue: 0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedBubbleShape(isFromUser: true))
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.content)
                .font(.body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray).opacity(0.15))
                .clipShape(RoundedBubbleShape(isFromUser: false))

            HStack(spacing: 6) {
                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: copyMessage) {
                    Image(systemName: showingCopyConfirmation ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(showingCopyConfirmation ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
                Button(action: toggleSpeech) {
                    Image(systemName: isSpeakingThis ? "stop.circle" : "speaker.wave.2")
                        .font(.system(size: 11))
                        .foregroundStyle(isSpeakingThis ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSpeakingThis ? "Stop reading" : "Read aloud")
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: maxBubbleWidth, alignment: .leading)
    }

    private var userAvatar: some View {
        Circle()
            .fill(LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            )
            .accessibilityHidden(true)
    }

    private var assistantAvatar: some View {
        Circle()
            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "cpu")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            )
            .accessibilityHidden(true)
    }

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

struct RoundedBubbleShape: Shape {
    var isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 20
        let tailRadius: CGFloat = 4

        let topLeft = radius
        let topRight = radius
        let bottomLeft = isFromUser ? radius : tailRadius
        let bottomRight = isFromUser ? tailRadius : radius

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                    radius: topRight, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                    radius: bottomRight, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                    radius: bottomLeft, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                    radius: topLeft, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}
