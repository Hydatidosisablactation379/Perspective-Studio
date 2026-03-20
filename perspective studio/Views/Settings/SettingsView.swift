import AVFAudio
import SwiftUI

struct SettingsView: View {
    @AppStorage("experienceLevel") private var experienceLevel: String = ExperienceLevel.beginner.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("defaultContextLength") private var defaultContextLength: Int = 4096
    @AppStorage("autoReadAloud") private var autoReadAloud: Bool = false
    @AppStorage("ttsVoiceIdentifier") private var ttsVoiceIdentifier: String = ""
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    private var selectedLevel: ExperienceLevel {
        ExperienceLevel(rawValue: experienceLevel) ?? .beginner
    }

    var body: some View {
        Form {
                Section {
                    Picker("Experience", selection: $experienceLevel) {
                        ForEach(ExperienceLevel.allCases) { level in
                            Label(level.displayName, systemImage: level.icon)
                                .tag(level.rawValue)
                        }
                    }
                    .pickerStyle(.inline)

                    Text(selectedLevel.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Experience Level")
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    Picker("Context Length", selection: $defaultContextLength) {
                        Text("2,048 tokens").tag(2048)
                        Text("4,096 tokens").tag(4096)
                        Text("8,192 tokens").tag(8192)
                    }

                    if selectedLevel != .beginner {
                        Text("Longer context uses more RAM but allows bigger conversations.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Model Defaults")
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    LabeledContent("Memory") {
                        Text(RAMService.ramDescription)
                    }
                    LabeledContent("Available for Models") {
                        Text("\(RAMService.availableRAMForModels.formatted(.number.precision(.fractionLength(1)))) GB")
                    }
                } header: {
                    Text("Device")
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    Toggle("Read Responses Aloud", isOn: $autoReadAloud)

                    Picker("Voice", selection: $ttsVoiceIdentifier) {
                        Text("Default").tag("")
                        ForEach(availableVoices, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))")
                                .tag(voice.identifier)
                        }
                    }
                } header: {
                    Text("Text-to-Speech")
                        .accessibilityAddTraits(.isHeader)
                } footer: {
                    Text("Uses voices installed on your device. Markdown formatting is stripped before reading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    }
                    LabeledContent("Models") {
                        Text("Powered by mlx-community on Hugging Face")
                    }
                } header: {
                    Text("About")
                        .accessibilityAddTraits(.isHeader)
                }

                Section {
                    Button("Reset Onboarding") {
                        hasCompletedOnboarding = false
                    }
                    .foregroundStyle(.red)
                    .accessibilityHint("Double tap to reset the setup wizard. You will go through onboarding again.")
                }
            }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            availableVoices = TTSService.shared.availableVoices()
        }
    }
}
