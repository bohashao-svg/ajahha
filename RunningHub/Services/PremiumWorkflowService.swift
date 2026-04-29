import Foundation

// MARK: - Premium Workflow Item
struct PremiumWorkflowItem: Identifiable {
    let id = UUID()
    let url: String
    var name: String

    var workflowId: String {
        guard let urlObj = URL(string: url),
              let components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false) else {
            return url
        }
        // Query param: ?workflowId=xxx or ?id=xxx
        let queryNames = ["workflowId", "id"]
        for name in queryNames {
            if let item = components.queryItems?.first(where: { $0.name == name }),
               let value = item.value, !value.isEmpty {
                return value
            }
        }
        // Path-based: /workflow/12345 or /ai-detail-mobile/12345
        let pathComponents = components.path.split(separator: "/").map(String.init)
        if let last = pathComponents.last, !last.isEmpty {
            return last
        }
        return url
    }
}

// MARK: - Premium Workflow Service
final class PremiumWorkflowService {
    static let shared = PremiumWorkflowService()
    private init() {}

    private let configURL = "https://json.lighttools.net/json/fce0812c918d4ebd"

    func fetchPremiumWorkflows() async throws -> [PremiumWorkflowItem] {
        guard let url = URL(string: configURL) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gzl = json["gzl"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        // No deduplication — show all entries as configured in JSON
        return gzl.compactMap { entry -> PremiumWorkflowItem? in
            guard let urlString = entry["url"] as? String else { return nil }
            let name = entry["name"] as? String ?? ""
            return PremiumWorkflowItem(url: urlString, name: name)
        }
    }

    /// Fetch workflow name by calling getJsonApiFormat and extracting a title from node meta
    func fetchWorkflowName(workflowId: String) async throws -> String {
        let detail = try await APIService.shared.fetchWorkflowDetail(workflowId: workflowId)
        let nodes = detail.parsedNodes

        // Prefer nodes with a meaningful meta title (not just class type names)
        let candidates = nodes.values
            .compactMap { $0.meta?.title }
            .filter { !$0.isEmpty }
            .sorted()

        if let first = candidates.first {
            return first
        }
        // Fallback: use first classType
        if let ct = nodes.values.first?.classType {
            return ct
        }
        return "工作流 \(workflowId)"
    }
}
