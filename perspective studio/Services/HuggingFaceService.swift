import Foundation

actor HuggingFaceService {
    static let shared = HuggingFaceService()

    private var cachedModels: [HFModel] = []
    private var lastFetchDate: Date?
    private var cachedNewModels: [HFModel] = []
    private var lastNewFetchDate: Date?
    private let cacheExpiry: TimeInterval = 300

    func fetchMLXModels(forceRefresh: Bool = false) async throws -> [HFModel] {
        if !forceRefresh, let lastFetch = lastFetchDate,
           Date.now.timeIntervalSince(lastFetch) < cacheExpiry,
           !cachedModels.isEmpty {
            return cachedModels
        }

        var allModels: [HFModel] = []
        var nextPageURL: URL? = buildInitialURL()

        while let url = nextPageURL {
            let (data, response) = try await URLSession.shared.data(from: url)
            let responses = try JSONDecoder().decode([HFModelResponse].self, from: data)

            let models = responses.map { r in
                HFModel(
                    id: r.id,
                    name: r.id,
                    downloads: r.downloads ?? 0,
                    likes: r.likes ?? 0,
                    tags: r.tags ?? [],
                    pipelineTag: r.pipelineTag,
                    createdAt: r.createdAt
                )
            }

            allModels.append(contentsOf: models)
            nextPageURL = extractNextPageURL(from: response)

            if allModels.count > 10_000 { break }
        }

        cachedModels = allModels
        lastFetchDate = .now
        return allModels
    }

    func fetchNewMLXModels(forceRefresh: Bool = false) async throws -> [HFModel] {
        if !forceRefresh, let lastFetch = lastNewFetchDate,
           Date.now.timeIntervalSince(lastFetch) < cacheExpiry,
           !cachedNewModels.isEmpty {
            return cachedNewModels
        }

        guard let url = buildNewModelsURL() else { throw HFError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let responses = try JSONDecoder().decode([HFModelResponse].self, from: data)

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let models = responses.compactMap { r -> HFModel? in
            guard let dateStr = r.createdAt,
                  let date = formatter.date(from: dateStr),
                  date >= sevenDaysAgo else { return nil }
            return HFModel(
                id: r.id,
                name: r.id,
                downloads: r.downloads ?? 0,
                likes: r.likes ?? 0,
                tags: r.tags ?? [],
                pipelineTag: r.pipelineTag,
                createdAt: r.createdAt
            )
        }

        cachedNewModels = models
        lastNewFetchDate = .now
        return models
    }

    func fetchModelCard(for modelId: String) async throws -> String {
        let urlString = "https://huggingface.co/\(modelId)/raw/main/README.md"
        guard let url = URL(string: urlString) else {
            throw HFError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard var content = String(data: data, encoding: .utf8) else {
            throw HFError.invalidResponse
        }

        // Skip YAML frontmatter
        if content.hasPrefix("---") {
            if let endRange = content.range(of: "---", range: content.index(content.startIndex, offsetBy: 3)..<content.endIndex) {
                content = String(content[endRange.upperBound...])
            }
        }

        // Filter out images and HTML lines, take first 3 paragraphs
        let lines = content.components(separatedBy: "\n")
        var paragraphs: [String] = []
        var currentParagraph = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("![") || trimmed.hasPrefix("<") || trimmed.hasPrefix("```") {
                continue
            }
            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespaces))
                    currentParagraph = ""
                    if paragraphs.count >= 3 { break }
                }
            } else {
                currentParagraph += (currentParagraph.isEmpty ? "" : " ") + trimmed
            }
        }
        if !currentParagraph.isEmpty && paragraphs.count < 3 {
            paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespaces))
        }

        let result = paragraphs.joined(separator: "\n\n")
        return String(result.prefix(1500))
    }

    private func buildInitialURL() -> URL? {
        var components = URLComponents(string: "https://huggingface.co/api/models")
        components?.queryItems = [
            URLQueryItem(name: "author", value: "mlx-community"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "1000"),
        ]
        return components?.url
    }

    private func buildNewModelsURL() -> URL? {
        var components = URLComponents(string: "https://huggingface.co/api/models")
        components?.queryItems = [
            URLQueryItem(name: "author", value: "mlx-community"),
            URLQueryItem(name: "sort", value: "createdAt"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "200"),
        ]
        return components?.url
    }

    private nonisolated func extractNextPageURL(from response: URLResponse) -> URL? {
        guard let httpResponse = response as? HTTPURLResponse,
              let linkHeader = httpResponse.value(forHTTPHeaderField: "Link") else {
            return nil
        }

        let links = linkHeader.components(separatedBy: ",")
        for link in links {
            let parts = link.components(separatedBy: ";")
            guard parts.count == 2 else { continue }
            let rel = parts[1].trimmingCharacters(in: .whitespaces)
            if rel == "rel=\"next\"" {
                let urlString = parts[0]
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                return URL(string: urlString)
            }
        }
        return nil
    }
}

enum HFError: LocalizedError {
    case invalidURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid Hugging Face URL"
        case .invalidResponse: "Could not read model information"
        }
    }
}

private struct HFModelResponse: Decodable, Sendable {
    let id: String
    let downloads: Int?
    let likes: Int?
    let tags: [String]?
    let pipelineTag: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "modelId"
        case downloads
        case likes
        case tags
        case pipelineTag = "pipeline_tag"
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try "modelId" first, fall back to "id"
        if let modelId = try? container.decode(String.self, forKey: .id) {
            self.id = modelId
        } else {
            let fallbackContainer = try decoder.container(keyedBy: FallbackKeys.self)
            self.id = try fallbackContainer.decode(String.self, forKey: .id)
        }
        self.downloads = try container.decodeIfPresent(Int.self, forKey: .downloads)
        self.likes = try container.decodeIfPresent(Int.self, forKey: .likes)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.pipelineTag = try container.decodeIfPresent(String.self, forKey: .pipelineTag)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    private enum FallbackKeys: String, CodingKey {
        case id
    }
}
