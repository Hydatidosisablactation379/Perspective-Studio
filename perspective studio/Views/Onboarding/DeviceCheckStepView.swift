import SwiftUI

struct DeviceCheckStepView: View {
    private let ramGB = RAMService.totalRAMInGB

    private var tier: DeviceTier {
        if ramGB >= 32 { return .great }
        if ramGB >= 16 { return .good }
        if ramGB >= 8 { return .limited }
        return .struggling
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: tier.icon)
                .font(.system(size: 60))
                .foregroundStyle(tier.color)
                .accessibilityHidden(true)

            Text(tier.title)
                .font(.title)
                .bold()
                .accessibilityAddTraits(.isHeader)

            Text("\(Int(ramGB)) GB Unified Memory")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(tier.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Text("Don't worry about picking the perfect model — we'll help you find ones that work great on your Mac.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .padding(.top, 8)
        }
        .padding()
    }

    private enum DeviceTier {
        case great, good, limited, struggling

        var icon: String {
            switch self {
            case .great, .good: "checkmark.circle.fill"
            case .limited: "exclamationmark.triangle.fill"
            case .struggling: "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .great: .green
            case .good: .blue
            case .limited: .orange
            case .struggling: .red
            }
        }

        var title: String {
            switch self {
            case .great: "Your Mac Is Great for AI"
            case .good: "Your Mac Works Well for AI"
            case .limited: "Your Mac Can Run Small Models"
            case .struggling: "Your Mac May Struggle with AI"
            }
        }

        var description: String {
            switch self {
            case .great: "You have plenty of memory to run large, powerful models. Almost everything will work smoothly."
            case .good: "You can run most models comfortably. Some of the largest models may be a tight fit."
            case .limited: "Stick to smaller models for the best experience. Larger models may not fit in memory."
            case .struggling: "Only the smallest models will run on your Mac. Performance may be limited."
            }
        }
    }
}
