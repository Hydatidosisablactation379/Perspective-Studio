import SwiftUI

struct ModelPickerOverlay: View {
    let models: [HFModel]
    let onSelect: (HFModel) -> Void
    let onDismiss: () -> Void

    private var experienceLevel: ExperienceLevel {
        OnboardingViewModel.currentExperienceLevel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Switch Model")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close model picker")
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(models) { model in
                        Button { onSelect(model) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: model.category.icon)
                                    .foregroundStyle(model.category.color)
                                    .frame(width: 24)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(experienceLevel == .beginner ? model.beginnerDisplayName : model.displayName)
                                        .font(.body)
                                    if let maker = model.madeBy {
                                        Text(maker)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(model.category.displayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(model.category.color.opacity(0.15))
                                    .clipShape(.capsule)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(model.displayName), \(model.madeBy ?? "Unknown maker"), \(model.category.displayName)")
                        .accessibilityHint("Double tap to switch to this model")

                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
        .frame(width: 320, height: 400)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}
