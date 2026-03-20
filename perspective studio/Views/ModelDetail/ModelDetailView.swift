import SwiftUI

struct ModelDetailView: View {
    let model: HFModel
    @Bindable var chatViewModel: ChatViewModel
    @State private var modelCard: String?
    @State private var isLoadingCard = false
    @State private var showLoadConfirmation = false
    @State private var showRemoveConfirmation = false
    @State private var downloadCheckID = UUID()

    @AppStorage("experienceLevel") private var experienceLevelRaw: String = ExperienceLevel.beginner.rawValue
    private var experienceLevel: ExperienceLevel {
        ExperienceLevel(rawValue: experienceLevelRaw) ?? .beginner
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
        .onChange(of: chatViewModel.modelState.statusText(for: experienceLevel)) {
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
            } else {
                // Non-loadable models (TTS, etc.) — download only
                downloadOnlyButton
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
            .accessibilityHint("Double tap to load this model and begin a conversation")

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
                .accessibilityHint("Double tap to remove this model from your Mac")
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
            .accessibilityHint("Double tap to download and load this model")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Warning: \(reason)")
        }
    }

    @ViewBuilder
    private var downloadOnlyButton: some View {
        if isThisModelActive {
            switch chatViewModel.modelState {
            case .downloading(let progress):
                VStack(spacing: 8) {
                    ProgressView(value: progress) {
                        Text("Downloading…")
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

            case .error(let message):
                VStack(spacing: 6) {
                    Label("Download Failed", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        chatViewModel.downloadHFModel(model)
                    } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

            default:
                downloadOnlyIdleState
            }
        } else {
            downloadOnlyIdleState
        }
    }

    @ViewBuilder
    private var downloadOnlyIdleState: some View {
        if isModelDownloaded {
            Label(
                "Downloaded",
                systemImage: "checkmark.circle.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.green)

            HStack(spacing: 16) {
                Text("Saved on your Mac for future use")
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
                chatViewModel.downloadHFModel(model)
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
                        Text("\(ram.formatted(.number.precision(.fractionLength(1)))) GB")
                    }
                    .font(.subheadline)

                    HStack {
                        Text("Available for models")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(RAMService.availableRAMForModels.formatted(.number.precision(.fractionLength(1)))) GB")
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

