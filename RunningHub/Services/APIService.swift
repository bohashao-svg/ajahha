import Foundation

// MARK: - API Service
final class APIService {

    static let shared = APIService()
    private init() {}

    private let baseURL = "https://www.runninghub.cn"
    private var apiKey: String {
        (StorageService.shared.apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - POST
    private func postEncodable<B: Encodable, T: Codable>(path: String, body: B) async throws -> T {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30
        req.httpBody = try JSONEncoder().encode(body)
        return try await execute(req)
    }

    private func execute<T: Codable>(_ req: URLRequest) async throws -> T {
        let (data, _) = try await URLSession.shared.data(for: req)

        // Debug: log raw response
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] \(req.url?.path ?? "") → \(str.prefix(500))")
        }
        #endif

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(APIResponse<T>.self, from: data)
        guard decoded.isSuccess, let result = decoded.data else {
            throw APIError.serverError(decoded.msg ?? "未知错误")
        }
        return result
    }

    // MARK: - Public APIs

    /// POST /api/openapi/getJsonApiFormat — fetch workflow detail
    func fetchWorkflowDetail(workflowId: String) async throws -> WorkflowDetailResponse {
        struct Body: Encodable { let apiKey: String; let workflowId: String }
        return try await postEncodable(
            path: "/api/openapi/getJsonApiFormat",
            body: Body(apiKey: apiKey, workflowId: workflowId)
        )
    }

    /// POST /task/openapi/create — run workflow
    func runWorkflow(_ req: RunWorkflowRequest) async throws -> RunWorkflowResponse {
        struct Body: Encodable {
            let apiKey: String
            let workflowId: String
            let nodeInfoList: [NodeInput]
            let instanceType: String?
        }
        return try await postEncodable(
            path: "/task/openapi/create",
            body: Body(
                apiKey: apiKey,
                workflowId: req.workflowId,
                nodeInfoList: req.nodeInfoList,
                instanceType: req.mode
            )
        )
    }

    /// POST /task/openapi/outputs — get task outputs
    func fetchTaskStatus(taskId: String) async throws -> TaskStatusItem {
        struct Body: Encodable { let apiKey: String; let taskId: String }
        return try await postEncodable(
            path: "/task/openapi/outputs",
            body: Body(apiKey: apiKey, taskId: taskId)
        )
    }

    /// POST /task/openapi/cancel
    func cancelTask(taskId: String) async throws {
        struct Body: Encodable { let apiKey: String; let taskId: String }
        struct Res: Codable { let success: Bool? }
        let _: Res = try await postEncodable(
            path: "/task/openapi/cancel",
            body: Body(apiKey: apiKey, taskId: taskId)
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
