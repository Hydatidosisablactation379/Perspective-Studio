import SwiftUI

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .accessibilityHidden(true)

            Text("Welcome to Perspective Studio")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            Text("Your private AI playground")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "lock.shield", title: "Completely Private", subtitle: "Everything runs on your device")
                featureRow(icon: "bolt", title: "Runs Locally", subtitle: "Powered by Apple Silicon")
                featureRow(icon: "hand.raised", title: "You're in Control", subtitle: "Choose your models, your way")
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
