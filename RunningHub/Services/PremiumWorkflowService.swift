import Foundation

// MARK: - Premium Workflow Item
struct PremiumWorkflowItem: Identifiable {
    let id = UUID()
    let url: String
    var name: String
    var isLoadingName: Bool = false

    var workflowId: String {
        // Try query param: ?workflowId=xxx
        if let urlObj = URL(string: url),
           let components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false),
           let item = components.queryItems?.first(where: { $0.name == "workflowId" }),
           let value = item.value {
            return value
        }
        // Try path-based: /workflow/12345 or last path component
        let parts = url.split(separator: "/").map(String.init)
        return parts.last ?? url
    }
}

// MARK: - Premium Workflow Service
final class PremiumWorkflowService {
    static let shared = PremiumWorkflowService()
    private init() {}

    private let configURL = "https://json.lighttools.net/json/fce0812c918d4ebd"

    func fetchPremiumWorkflows() async throws -> [PremiumWorkflowItem] {
        guard let url = URL(string: configURL) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gzl = json["gzl"] as? [String] else {
            throw URLError(.cannotParseResponse)
        }

        return gzl.map { urlString in
            PremiumWorkflowItem(url: urlString, name: "")
        }
    }
}
