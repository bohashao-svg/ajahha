import Foundation

// MARK: - API Service
final class APIService {

    static let shared = APIService()
    private init() {}

    private let baseURL = "https://www.runninghub.cn"
    var apiKey: String {
        (StorageService.shared.apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - POST with Encodable body
    private func postEncodable<B: Encodable, T: Codable>(path: String, body: B) async throws -> T {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30
        req.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: req)
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] \(req.url?.path ?? "") → \(str.prefix(800))")
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

    /// POST /api/openapi/getJsonApiFormat
    func fetchWorkflowDetail(workflowId: String) async throws -> WorkflowDetailResponse {
        struct Body: Encodable { let apiKey: String; let workflowId: String }
        return try await postEncodable(
            path: "/api/openapi/getJsonApiFormat",
            body: Body(apiKey: apiKey, workflowId: workflowId)
        )
    }

    /// POST /task/openapi/create
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

    /// POST /openapi/v2/query — poll task status and results
    /// Response is NOT wrapped in APIResponse, it's a flat object
    func queryTask(taskId: String) async throws -> TaskQueryResponse {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/openapi/v2/query") else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        struct Body: Encodable { let taskId: String }
        req.httpBody = try JSONEncoder().encode(Body(taskId: taskId))

        let (data, _) = try await URLSession.shared.data(for: req)
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] /openapi/v2/query → \(str.prefix(800))")
        }
        #endif

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TaskQueryResponse.self, from: data)
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
