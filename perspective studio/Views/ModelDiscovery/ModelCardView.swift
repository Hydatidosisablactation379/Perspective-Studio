import SwiftUI

struct ModelCardView: View {
    let model: HFModel
    var isLoaded: Bool = false

    private var experienceLevel: ExperienceLevel {
        OnboardingViewModel.currentExperienceLevel
    }

    private var compatibility: RAMService.ModelCompatibility? {
        guard let ram = model.estimatedRAMGB else { return nil }
        return RAMService.canRunModel(ramRequired: ram)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient header
            HStack {
                Image(systemName: model.category.icon)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityHidden(true)
                Spacer()
                Text(model.category.displayName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(10)
            .background(
                LinearGradient(
                    colors: [model.makerColor, model.makerColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Body
            VStack(alignment: .leading, spacing: 6) {
                Text(experienceLevel == .beginner ? model.beginnerDisplayName : model.displayName)
                    .font(.headline)
                    .lineLimit(2)

                if let maker = model.madeBy {
                    Text(maker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if experienceLevel == .beginner {
                    Text(model.shortCapabilityText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    // Size/speed tag
                    if experienceLevel == .beginner {
                        tagPill(model.beginnerSizeLabel, color: .blue)
                        tagPill(model.speedLabel, color: .purple)
                    } else {
                        if let size = model.parameterSize {
                            tagPill(size >= 1 ? "\(Int(size))B" : "\(Int(size * 1000))M", color: .blue)
                        }
                        if let quant = model.quantization {
                            tagPill(quant, color: .purple)
                        }
                    }
                }

                HStack {
                    if model.isDownloaded {
                        Label("Downloaded", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else if let compat = compatibility {
                        Image(systemName: compat.systemImage)
                            .font(.caption2)
                            .foregroundStyle(compat.color)
                            .accessibilityHidden(true)
                    }

                    Spacer()

                    Text(formattedDownloads)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
        .background(Color(.controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLoaded ? Color.green : .clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private func tagPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(.capsule)
    }

    private var formattedDownloads: String {
        if model.downloads >= 1_000_000 {
            return String(format: "%.1fM", Double(model.downloads) / 1_000_000)
        } else if model.downloads >= 1_000 {
            return String(format: "%.1fK", Double(model.downloads) / 1_000)
        }
        return "\(model.downloads)"
    }

    private var accessibilityDescription: String {
        var parts: [String] = [model.displayName]
        if let maker = model.madeBy { parts.append("by \(maker)") }
        parts.append(model.category.displayName)
        if let size = model.parameterSize {
            parts.append(size >= 1 ? "\(Int(size)) billion parameters" : "\(Int(size * 1000)) million parameters")
        }
        if let compat = compatibility {
            parts.append(compat.beginnerDescription)
        }
        parts.append("\(formattedDownloads) downloads")
        if isLoaded { parts.append("Currently loaded") }
        return parts.joined(separator: ". ")
    }
}
