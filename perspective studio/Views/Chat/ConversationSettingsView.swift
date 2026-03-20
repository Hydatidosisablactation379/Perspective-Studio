import SwiftUI
import SwiftData

struct ConversationSettingsView: View {
    @Bindable var conversation: Conversation
    @Environment(\.modelContext) private var modelContext
    @State private var systemPromptText: String = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(conversation.temperature.formatted(.number.precision(.fractionLength(1))))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    Slider(value: $conversation.temperature, in: 0.0...2.0, step: 0.1) {
                        Text("Temperature")
                    }
                    .accessibilityValue(conversation.temperature.formatted(.number.precision(.fractionLength(1))))
                    .onChange(of: conversation.temperature) {
                        try? modelContext.save()
                    }

                    Text(temperatureDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Generation")
                    .accessibilityAddTraits(.isHeader)
            }

            Section {
                TextField("System prompt…", text: $systemPromptText, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityLabel("System prompt")
                    .accessibilityHint("Instructions the model follows for this conversation")
                    .onChange(of: systemPromptText) { _, newValue in
                        conversation.systemPrompt = newValue.isEmpty ? nil : newValue
                        try? modelContext.save()
                    }
            } header: {
                Text("System Prompt")
                    .accessibilityAddTraits(.isHeader)
            } footer: {
                Text("Instructions that guide how the model responds in this conversation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            systemPromptText = conversation.systemPrompt ?? ""
        }
    }

    private var temperatureDescription: String {
        if conversation.temperature < 0.3 {
            return "More focused and predictable"
        } else if conversation.temperature < 0.8 {
            return "Balanced creativity and coherence"
        } else if conversation.temperature < 1.5 {
            return "More creative and varied"
        } else {
            return "Very creative, may be less coherent"
        }
    }
}
