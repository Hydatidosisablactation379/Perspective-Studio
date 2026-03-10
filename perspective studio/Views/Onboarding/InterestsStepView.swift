import SwiftUI

struct InterestsStepView: View {
    @Binding var selectedInterests: Set<AIInterest>

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("What would you like to use AI for?")
                .font(.title)
                .bold()
                .accessibilityAddTraits(.isHeader)

            Text("\(selectedInterests.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AIInterest.allCases) { interest in
                    InterestCard(
                        interest: interest,
                        isSelected: selectedInterests.contains(interest)
                    ) {
                        if selectedInterests.contains(interest) {
                            selectedInterests.remove(interest)
                        } else {
                            selectedInterests.insert(interest)
                        }
                    }
                }
            }
            .frame(maxWidth: 450)
        }
        .padding()
    }
}

private struct InterestCard: View {
    let interest: AIInterest
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                Image(systemName: interest.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .accessibilityHidden(true)

                Text(interest.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(interest.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.controlBackgroundColor))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(interest.displayName). \(interest.description)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to toggle")
        .accessibilityAddTraits(.isButton)
    }
}
