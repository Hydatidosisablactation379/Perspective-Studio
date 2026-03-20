import Foundation

enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case experienceLevel
    case interests
    case deviceCheck
    case complete

    var progressFraction: Double {
        guard self != .welcome else { return 0 }
        return Double(rawValue) / Double(Self.allCases.count - 1)
    }
}

@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var selectedExperienceLevel: ExperienceLevel? = nil
    var selectedInterests: Set<AIInterest> = []

    func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func goBack() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    func finishOnboarding() {
        let level = selectedExperienceLevel ?? .beginner
        UserDefaults.standard.set(level.rawValue, forKey: "experienceLevel")

        let interestRaws = selectedInterests.map(\.rawValue)
        UserDefaults.standard.set(interestRaws, forKey: "selectedInterests")

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}
