import Foundation

// MARK: - API Service
final class APIService {

    static let shared = APIService()
    private init() {}

    private let baseURL = "https://www.runninghub.cn"
    private var apiKey: String { (StorageService.shared.apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: - POST (generic Encodable body)
    private func postEncodable<B: Encodable, T: Codable>(path: String, body: B) async throws -> T {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        req.httpBody = try JSONEncoder().encode(body)
        return try await execute(req)
    }

    // MARK: - POST (dict body — for simple key/value requests)
    private func post<T: Codable>(path: String, body: [String: String]) async throws -> T {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(req)
    }

    private func execute<T: Codable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw APIError.httpError(http.statusCode) }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(APIResponse<T>.self, from: data)
        guard decoded.isSuccess, let result = decoded.data else {
            throw APIError.serverError(decoded.msg ?? "未知错误")
        }
        return result
    }

    // MARK: - Public APIs

    /// POST /api/openapi/getJsonApiFormat
    func fetchWorkflowDetail(workflowId: String) async throws -> WorkflowDetailResponse {
        struct Body: Encodable { let apiKey: String; let workflowId: String }
        return try await postEncodable(path: "/api/openapi/getJsonApiFormat",
                                       body: Body(apiKey: apiKey, workflowId: workflowId))
    }

    /// POST /api/openapi/createTask
    func runWorkflow(_ runReq: RunWorkflowRequest) async throws -> RunWorkflowResponse {
        struct Body: Encodable {
            let apiKey: String
            let workflowId: String
            let nodeInfoList: [NodeInput]
            let mode: String?
        }
        return try await postEncodable(
            path: "/api/openapi/createTask",
            body: Body(apiKey: apiKey,
                       workflowId: runReq.workflowId,
                       nodeInfoList: runReq.nodeInfoList,
                       mode: runReq.mode)
        )
    }

    /// POST /api/openapi/getTaskStatus
    func fetchTaskStatus(taskId: String) async throws -> TaskStatusItem {
        struct Body: Encodable { let apiKey: String; let taskId: String }
        return try await postEncodable(path: "/api/openapi/getTaskStatus",
                                       body: Body(apiKey: apiKey, taskId: taskId))
    }

    /// POST /api/openapi/cancelTask
    func cancelTask(taskId: String) async throws {
        struct Body: Encodable { let apiKey: String; let taskId: String }
        struct Res: Codable { let success: Bool? }
        let _: Res = try await postEncodable(path: "/api/openapi/cancelTask",
                                              body: Body(apiKey: apiKey, taskId: taskId))
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
