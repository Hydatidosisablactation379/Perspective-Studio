import SwiftUI

struct ModelDetailView: View {
    let model: HFModel
    @Bindable var chatViewModel: ChatViewModel
    @State private var modelCard: String?
    @State private var isLoadingCard = false
    @State private var showLoadConfirmation = false
    @State private var showRemoveConfirmation = false
    @State private var downloadCheckID = UUID()

    private var experienceLevel: ExperienceLevel {
        OnboardingViewModel.currentExperienceLevel
    }

    private var compatibility: RAMService.ModelCompatibility? {
        guard let ram = model.estimatedRAMGB else { return nil }
        return RAMService.canRunModel(ramRequired: ram)
    }

    /// Re-evaluated when `downloadCheckID` changes to reflect filesystem state.
    private var isModelDownloaded: Bool {
        _ = downloadCheckID
        return model.isDownloaded
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()

                if !model.isLikelyLoadable {
                    notLoadableWarning
                }

                loadSection

                if experienceLevel == .beginner {
                    capabilitiesSection
                }

                aboutSection

                ramSection

                if experienceLevel != .beginner {
                    technicalSection
                }

                if let card = modelCard {
                    modelCardSection(card)
                }
            }
            .padding()
        }
        .navigationTitle(model.displayName)
        .task { await loadModelCard() }
        .alert("Load Model?", isPresented: $showLoadConfirmation) {
            Button("Load", role: .none) { chatViewModel.loadHFModel(model) }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let compat = compatibility, compat == .tight {
                Text("This model may be a tight fit for your Mac's memory. It might run slowly.")
            } else {
                Text("This will download and load \(model.displayName) for chat.")
            }
        }
        .alert("Remove Model?", isPresented: $showRemoveConfirmation) {
            Button("Remove", role: .destructive) { removeDownloadedModel() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete \(model.displayName) from your Mac. You can re-download it later.")
        }
        .onChange(of: chatViewModel.modelState.statusText) {
            downloadCheckID = UUID()
        }
    }

    private func removeDownloadedModel() {
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        let encoded = model.id.replacingOccurrences(of: "/", with: "--")
        let modelDir = cacheDir.appendingPathComponent("models--\(encoded)")
        try? FileManager.default.removeItem(at: modelDir)
        downloadCheckID = UUID()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(experienceLevel == .beginner ? model.beginnerDisplayName : model.displayName)
                .font(.largeTitle)
                .bold()

            HStack(spacing: 12) {
                if let maker = model.madeBy {
                    Text(maker)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(model.category.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(model.category.color.opacity(0.15))
                    .clipShape(.capsule)
            }
        }
    }

    /// Whether this model is currently being downloaded/loaded by the view model.
    private var isThisModelActive: Bool {
        chatViewModel.selectedModelID == model.id
    }

    private var loadSection: some View {
        VStack(spacing: 12) {
            if model.isLikelyLoadable {
                // Active download / load progress for THIS model
                if isThisModelActive {
                    switch chatViewModel.modelState {
                    case .downloading(let progress):
                        VStack(spacing: 8) {
                            ProgressView(value: progress) {
                                Text(experienceLevel == .beginner ? "Downloading…" : "Downloading model…")
                                    .font(.subheadline)
                            } currentValueLabel: {
                                Text("\(Int(progress * 100))%")
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            .tint(.blue)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 12))

                    case .loading:
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text(experienceLevel == .beginner ? "Getting the AI ready…" : "Loading into memory…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 12))

                    case .ready:
                        Label(
                            experienceLevel == .beginner ? "Ready to chat!" : "Model loaded",
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.green)

                    case .error(let message):
                        VStack(spacing: 6) {
                            Label("Failed", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                chatViewModel.loadHFModel(model)
                            } label: {
                                Label("Try Again", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                    case .idle:
                        downloadOrLoadButton
                    }
                } else {
                    downloadOrLoadButton
                }
            }
        }
    }

    @ViewBuilder
    private var downloadOrLoadButton: some View {
        if isModelDownloaded {
            Button {
                chatViewModel.loadHFModel(model)
            } label: {
                Label(
                    experienceLevel == .beginner ? "Start Chatting" : "Load Model",
                    systemImage: "play.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)

            HStack(spacing: 16) {
                Text("Already downloaded on your Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    showRemoveConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        } else {
            Button {
                if compatibility == .tight {
                    showLoadConfirmation = true
                } else {
                    chatViewModel.loadHFModel(model)
                }
            } label: {
                Label(
                    experienceLevel == .beginner ? "Download & Chat" : "Download & Load",
                    systemImage: "arrow.down.circle"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(compatibility == .incompatible)
        }
    }

    @ViewBuilder
    private var notLoadableWarning: some View {
        if let reason = model.notLoadableReason {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(reason)
                    .font(.subheadline)
            }
            .padding()
            .background(.orange.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What This Model Can Do")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(model.capabilities, id: \.self) { capability in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text(capability)
                        .font(.subheadline)
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About This Model")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text(model.plainLanguageSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var ramSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(experienceLevel == .beginner ? "Will It Work on My Mac?" : "Will It Run on My Mac?")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let compat = compatibility {
                        CompatibilityBadgeView(compatibility: compat)
                    }
                    Spacer()
                    Text(RAMService.ramDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let ram = model.estimatedRAMGB {
                    HStack {
                        Text("Estimated RAM needed")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f GB", ram))
                    }
                    .font(.subheadline)

                    HStack {
                        Text("Available for models")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f GB", RAMService.availableRAMForModels))
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 12))
        }
        .accessibilityElement(children: .combine)
    }

    private var technicalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Technical Details")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                if let params = model.parameterSize {
                    LabeledContent("Parameters", value: params >= 1 ? "\(Int(params))B" : "\(Int(params * 1000))M")
                }
                if let quant = model.quantization {
                    LabeledContent("Precision", value: quant)
                }
                LabeledContent("Downloads", value: "\(model.downloads.formatted())")
                LabeledContent("Likes", value: "\(model.likes.formatted())")
            }
        }
    }

    private func modelCardSection(_ card: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From the Model Page")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text(card)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func loadModelCard() async {
        isLoadingCard = true
        do {
            modelCard = try await HuggingFaceService.shared.fetchModelCard(for: model.id)
        } catch {
            modelCard = nil
        }
        isLoadingCard = false
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
