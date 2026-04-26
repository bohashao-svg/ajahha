import Foundation

// MARK: - API Service
final class APIService {

    static let shared = APIService()
    private init() {}

    private let baseURL = "https://www.runninghub.cn"
    private var apiKey: String { StorageService.shared.apiKey ?? "" }

    // MARK: - POST
    private func post<T: Codable>(path: String, body: [String: Any]) async throws -> T {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        var fullBody = body
        fullBody["apiKey"] = apiKey
        req.httpBody = try JSONSerialization.data(withJSONObject: fullBody)

        return try await execute(req)
    }

    // MARK: - GET
    private func get<T: Codable>(path: String) async throws -> T {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        return try await execute(req)
    }

    private func execute<T: Codable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw APIError.httpError(http.statusCode) }

        let decoded = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard decoded.isSuccess, let result = decoded.data else {
            throw APIError.serverError(decoded.msg ?? "未知错误")
        }
        return result
    }

    // MARK: - Public APIs

    /// POST /api/openapi/accountStatus
    func fetchQuota() async throws -> UserQuota {
        return try await post(path: "/api/openapi/accountStatus", body: [:])
    }

    /// POST /api/openapi/getJsonApiFormat
    func fetchWorkflowDetail(workflowId: String) async throws -> WorkflowDetailResponse {
        return try await post(
            path: "/api/openapi/getJsonApiFormat",
            body: ["workflowId": workflowId]
        )
    }

    /// POST /api/openapi/createTask
    func runWorkflow(_ runReq: RunWorkflowRequest) async throws -> RunWorkflowResponse {
        var body: [String: Any] = [
            "workflowId": runReq.workflowId,
            "prompt": runReq.prompt ?? ""
        ]
        if let mode = runReq.mode { body["mode"] = mode }
        return try await post(path: "/api/openapi/createTask", body: body)
    }

    /// POST /api/openapi/getTaskStatus
    func fetchTaskStatus(taskId: String) async throws -> TaskStatusItem {
        return try await post(
            path: "/api/openapi/getTaskStatus",
            body: ["taskId": taskId]
        )
    }

    /// POST /api/openapi/cancelTask
    func cancelTask(taskId: String) async throws {
        struct CancelResult: Codable { let success: Bool? }
        let _: CancelResult = try await post(
            path: "/api/openapi/cancelTask",
            body: ["taskId": taskId]
        )
    }
}

// MARK: - Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:         return "无效的请求地址"
        case .invalidResponse:    return "服务器响应异常"
        case .httpError(let c):   return "HTTP 错误 \(c)"
        case .serverError(let m): return m
        case .noAPIKey:           return "请先在设置中配置 API 密钥"
        }
    }
}
