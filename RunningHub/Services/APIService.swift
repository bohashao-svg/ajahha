import Foundation

// MARK: - API Service
final class APIService {

    static let shared = APIService()
    private init() {}

    private let baseURL = "https://www.runninghub.cn"
    private var apiKey: String { StorageService.shared.apiKey ?? "" }

    // MARK: - Generic Request
    private func request<T: Codable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil
    ) async throws -> T {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "RUNNINGHUB-API-KEY")
        req.timeoutInterval = 30

        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard decoded.isSuccess, let result = decoded.data else {
            throw APIError.serverError(decoded.msg ?? "未知错误")
        }
        return result
    }

    // MARK: - Public APIs

    func fetchQuota() async throws -> UserQuota {
        return try await request(path: "/v1/user/quota")
    }

    func fetchWorkflowDetail(workflowId: String) async throws -> WorkflowDetailResponse {
        return try await request(
            path: "/v1/workflow/detail",
            queryItems: [URLQueryItem(name: "workflowId", value: workflowId)]
        )
    }

    func runWorkflow(_ req: RunWorkflowRequest) async throws -> RunWorkflowResponse {
        return try await request(path: "/v1/workflow/run", method: "POST", body: req)
    }

    func fetchTaskBatch(taskIds: [String]) async throws -> [TaskStatusItem] {
        return try await request(
            path: "/v1/task/batch",
            queryItems: [URLQueryItem(name: "taskIds", value: taskIds.joined(separator: ","))]
        )
    }

    func cancelTask(taskId: String) async throws {
        struct Empty: Codable {}
        let _: Empty = try await request(
            path: "/v1/task/\(taskId)/cancel",
            method: "POST"
        )
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "无效的请求地址"
        case .invalidResponse:   return "服务器响应异常"
        case .httpError(let c):  return "HTTP 错误 \(c)"
        case .serverError(let m): return m
        case .noAPIKey:          return "请先配置 API 密钥"
        }
    }
}
