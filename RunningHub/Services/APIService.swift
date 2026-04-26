import Foundation

// MARK: - API Service
final class APIService {

    static let shared = APIService()
    private init() {}

    private let baseURL = "https://www.runninghub.cn"
    private var apiKey: String { StorageService.shared.apiKey ?? "" }

    // MARK: - Generic Request
    // RunningHub API: apiKey is passed in the request body for POST,
    // and as a query parameter for GET requests.
    private func request<T: Codable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: [String: Any]? = nil
    ) async throws -> T {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }

        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        // For GET: append apiKey as query param
        var allQueryItems = queryItems ?? []
        if method == "GET" {
            allQueryItems.append(URLQueryItem(name: "apiKey", value: apiKey))
        }
        if !allQueryItems.isEmpty {
            components.queryItems = allQueryItems
        }

        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        // For POST: include apiKey in body
        if method == "POST" {
            var bodyDict = body ?? [:]
            bodyDict["apiKey"] = apiKey
            req.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
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
        return try await request(path: "/task/openapi/account/info")
    }

    func fetchWorkflowDetail(workflowId: String) async throws -> WorkflowDetailResponse {
        return try await request(
            path: "/task/openapi/workflow/detail",
            queryItems: [URLQueryItem(name: "workflowId", value: workflowId)]
        )
    }

    func runWorkflow(_ runReq: RunWorkflowRequest) async throws -> RunWorkflowResponse {
        var body: [String: Any] = [
            "workflowId": runReq.workflowId,
            "nodeInfoList": runReq.nodeInfoList.map {
                ["nodeId": $0.nodeId, "fieldName": $0.fieldName, "fieldValue": $0.fieldValue]
            }
        ]
        if let mode = runReq.mode {
            body["mode"] = mode
        }
        return try await request(path: "/task/openapi/create", method: "POST", body: body)
    }

    func fetchTaskStatus(taskId: String) async throws -> TaskStatusItem {
        return try await request(
            path: "/task/openapi/status",
            method: "POST",
            body: ["taskId": taskId]
        )
    }

    func cancelTask(taskId: String) async throws {
        struct Empty: Codable {}
        let _: Empty = try await request(
            path: "/task/openapi/cancel",
            method: "POST",
            body: ["taskId": taskId]
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
        case .invalidURL:         return "无效的请求地址"
        case .invalidResponse:    return "服务器响应异常"
        case .httpError(let c):   return "HTTP 错误 \(c)"
        case .serverError(let m): return m
        case .noAPIKey:           return "请先在设置中配置 API 密钥"
        }
    }
}
