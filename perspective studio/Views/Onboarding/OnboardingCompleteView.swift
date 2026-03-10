import SwiftUI

struct OnboardingCompleteView: View {
    let viewModel: OnboardingViewModel

    private var isBeginner: Bool {
        viewModel.selectedExperienceLevel == .beginner || viewModel.selectedExperienceLevel == nil
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("You're All Set!")
                .font(.largeTitle)
                .bold()
                .accessibilityAddTraits(.isHeader)

            if isBeginner {
                beginnerNextSteps
            } else {
                summaryView
            }
        }
        .padding()
    }

    private var beginnerNextSteps: some View {
        VStack(alignment: .leading, spacing: 16) {
            nextStepRow(number: 1, text: "Pick a model from the Discover page")
            nextStepRow(number: 2, text: "Wait for it to download")
            nextStepRow(number: 3, text: "Start chatting!")
        }
        .frame(maxWidth: 350)
    }

    private func nextStepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.blue))
                .accessibilityHidden(true)

            Text(text)
                .font(.body)
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let level = viewModel.selectedExperienceLevel {
                LabeledContent("Experience", value: level.displayName)
            }
            if !viewModel.selectedInterests.isEmpty {
                LabeledContent("Interests", value: viewModel.selectedInterests.map(\.displayName).joined(separator: ", "))
            }
            LabeledContent("Memory", value: "\(Int(RAMService.totalRAMInGB)) GB")
        }
        .frame(maxWidth: 350)
    }
}
