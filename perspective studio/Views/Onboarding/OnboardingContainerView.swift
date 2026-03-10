import SwiftUI

struct OnboardingContainerView: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.currentStep != .welcome {
                ProgressView(value: viewModel.currentStep.progressFraction)
                    .padding(.horizontal)
                    .padding(.top)
                    .accessibilityLabel("Step \(viewModel.currentStep.rawValue + 1) of 5")
            }

            Spacer()

            Group {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeStepView()
                case .experienceLevel:
                    ExperienceLevelStepView(selectedLevel: $viewModel.selectedExperienceLevel)
                case .interests:
                    InterestsStepView(selectedInterests: $viewModel.selectedInterests)
                case .deviceCheck:
                    DeviceCheckStepView()
                case .complete:
                    OnboardingCompleteView(viewModel: viewModel)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))

            Spacer()

            HStack {
                if viewModel.currentStep.rawValue > 0 && viewModel.currentStep != .complete {
                    Button("Back") {
                        if reduceMotion {
                            viewModel.goBack()
                        } else {
                            withAnimation { viewModel.goBack() }
                        }
                    }
                    .accessibilityLabel("Go back to previous step")
                }

                Spacer()

                if viewModel.currentStep == .complete {
                    Button("Get Started") {
                        viewModel.finishOnboarding()
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Finish setup and start using Perspective Studio")
                } else if viewModel.currentStep == .welcome {
                    Button("Let's Go") {
                        if reduceMotion {
                            viewModel.advance()
                        } else {
                            withAnimation { viewModel.advance() }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Begin setup")
                } else {
                    Button("Continue") {
                        if reduceMotion {
                            viewModel.advance()
                        } else {
                            withAnimation { viewModel.advance() }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Continue to next step")
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}
