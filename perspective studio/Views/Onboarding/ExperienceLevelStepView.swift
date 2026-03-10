import SwiftUI

struct ExperienceLevelStepView: View {
    @Binding var selectedLevel: ExperienceLevel?

    var body: some View {
        VStack(spacing: 24) {
            Text("How familiar are you with AI?")
                .font(.title)
                .bold()
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                ForEach(ExperienceLevel.allCases) { level in
                    ExperienceLevelCard(
                        level: level,
                        isSelected: selectedLevel == level
                    ) {
                        selectedLevel = level
                    }
                }
            }
            .frame(maxWidth: 400)
        }
        .padding()
    }
}

private struct ExperienceLevelCard: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: level.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 36)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                    Text(level.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.displayName). \(level.description)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to select")
        .accessibilityAddTraits(.isButton)
    }
}
