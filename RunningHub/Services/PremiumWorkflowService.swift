import Foundation

// MARK: - Premium Workflow Item
struct PremiumWorkflowItem: Identifiable {
    let id = UUID()
    let url: String
    var name: String

    var workflowId: String {
        // Parse URL properly to avoid including query string in the path component
        guard let urlObj = URL(string: url),
              let components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false) else {
            return url
        }
        // Try query param: ?workflowId=xxx
        if let item = components.queryItems?.first(where: { $0.name == "workflowId" }),
           let value = item.value, !value.isEmpty {
            return value
        }
        // Path-based: /workflow/12345  — take last non-empty path component (no query string)
        let pathComponents = components.path.split(separator: "/").map(String.init)
        return pathComponents.last ?? url
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

        var seen = Set<String>()
        var items: [PremiumWorkflowItem] = []
        for entry in gzl {
            guard let urlString = entry["url"] as? String else { continue }
            let name = entry["name"] as? String ?? ""
            let item = PremiumWorkflowItem(url: urlString, name: name)
            let wid = item.workflowId
            guard wid != urlString, wid.count > 3, !seen.contains(wid) else { continue }
            seen.insert(wid)
            items.append(item)
        }
        return items
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
