import SwiftUI

struct ModelDiscoveryView: View {
    let models: [HFModel]
    let chatViewModel: ChatViewModel
    @State private var searchText = ""
    @State private var expandedCategories: Set<ModelCategory> = []
    @State private var isNewExpanded = false

    @AppStorage("experienceLevel") private var experienceLevelRaw: String = ExperienceLevel.beginner.rawValue
    private var experienceLevel: ExperienceLevel {
        ExperienceLevel(rawValue: experienceLevelRaw) ?? .beginner
    }

    private var filteredModels: [HFModel] {
        guard !searchText.isEmpty else { return models }
        return models.filter { model in
            model.displayName.localizedStandardContains(searchText)
                || (model.madeBy?.localizedStandardContains(searchText) ?? false)
                || model.category.displayName.localizedStandardContains(searchText)
        }
    }

    private var recommendedModels: [HFModel] {
        models
            .filter { model in
                guard let ram = model.estimatedRAMGB else { return false }
                let compat = RAMService.canRunModel(ramRequired: ram)
                return compat == .comfortable || compat == .tight
            }
            .sorted { $0.downloads > $1.downloads }
            .prefix(6)
            .map { $0 }
    }

    private var newThisWeek: [HFModel] {
        chatViewModel.newModels.sorted { $0.downloads > $1.downloads }
    }

    private var categorizedModels: [(category: ModelCategory, models: [HFModel])] {
        let source = searchText.isEmpty ? models : filteredModels
        var groups: [ModelCategory: [HFModel]] = [:]
        for model in source {
            groups[model.category, default: []].append(model)
        }
        return ModelCategory.allCases.compactMap { cat in
            guard let catModels = groups[cat], !catModels.isEmpty else { return nil }
            return (cat, catModels)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                if searchText.isEmpty && !newThisWeek.isEmpty {
                    newThisWeekSection
                }

                if searchText.isEmpty && experienceLevel != .powerUser && !recommendedModels.isEmpty {
                    recommendedSection
                }

                ForEach(categorizedModels, id: \.category) { group in
                    categorySection(group.category, models: group.models)
                }

                Text("Browsing \(models.count) models from mlx-community")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle(experienceLevel == .beginner ? "Discover Models" : "Model Browser")
        .searchable(text: $searchText, prompt: "Search by name, maker, or category")
        .navigationDestination(for: HFModel.self) { model in
            ModelDetailView(model: model, chatViewModel: chatViewModel)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("Everything runs on your device. Nothing leaves your Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: "memorychip")
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text("Your Mac has \(Int(RAMService.totalRAMInGB)) GB of memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended for You")
                .font(.title2)
                .bold()
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280))], spacing: 16) {
                ForEach(recommendedModels) { model in
                    NavigationLink(value: model) {
                        ModelCardView(model: model)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var newThisWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("New")
                    .font(.title3)
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                Text("\(newThisWeek.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(.capsule)

                Spacer()

                if newThisWeek.count > 6 {
                    Button(isNewExpanded ? "Show Less" : "Show All") {
                        isNewExpanded.toggle()
                    }
                    .font(.subheadline)
                }
            }

            Text(experienceLevel == .beginner
                 ? "Fresh models added to mlx-community in the last 7 days"
                 : "Recently published MLX models from the past 7 days")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let displayModels = isNewExpanded ? newThisWeek : Array(newThisWeek.prefix(6))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280))], spacing: 16) {
                ForEach(displayModels) { model in
                    NavigationLink(value: model) {
                        ModelCardView(model: model)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func categorySection(_ category: ModelCategory, models: [HFModel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                    .accessibilityHidden(true)
                Text(category.displayName)
                    .font(.title3)
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                Text("\(models.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(.capsule)

                Spacer()

                if models.count > 6 {
                    Button(expandedCategories.contains(category) ? "Show Less" : "Show All") {
                        if expandedCategories.contains(category) {
                            expandedCategories.remove(category)
                        } else {
                            expandedCategories.insert(category)
                        }
                    }
                    .font(.subheadline)
                }
            }

            Text(experienceLevel == .beginner ? category.beginnerDescription : category.technicalDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let displayModels = expandedCategories.contains(category) ? models : Array(models.prefix(6))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280))], spacing: 16) {
                ForEach(displayModels) { model in
                    NavigationLink(value: model) {
                        ModelCardView(model: model)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
