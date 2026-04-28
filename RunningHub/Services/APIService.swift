import Foundation
import UIKit

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

    /// POST /api/openapi/workflow/duplicate — fork a public workflow into user's workspace
    /// Returns the new workflowId that belongs to the user
    @discardableResult
    func duplicateWorkflow(workflowId: String) async throws -> String {
        struct Body: Encodable { let apiKey: String; let workflowId: String }
        struct Res: Codable { let workflowId: String? }
        let res: Res = try await postEncodable(
            path: "/api/openapi/workflow/duplicate",
            body: Body(apiKey: apiKey, workflowId: workflowId)
        )
        return res.workflowId ?? workflowId
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

    /// POST /task/openapi/upload — multipart/form-data 上传图片，返回文件名
    func uploadImage(_ image: UIImage) async throws -> String {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/task/openapi/upload") else { throw APIError.invalidURL }
        guard let imageData = image.jpegData(compressionQuality: 0.9) else { throw APIError.invalidResponse }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 60

        var body = Data()
        // apiKey field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"apiKey\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(apiKey)\r\n".data(using: .utf8)!)
        // file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: req)
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] /task/openapi/upload → \(str.prefix(400))")
        }
        #endif
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(APIResponse<UploadImageResponse>.self, from: data)
        guard decoded.isSuccess, let result = decoded.data else {
            throw APIError.serverError(decoded.msg ?? "上传失败")
        }
        return result.fileName
    }

    // MARK: - AI App (WebApp) APIs

    /// GET /api/webapp/apiCallDemo — fetch node list for a WebApp
    func fetchAppNodes(webappId: String) async throws -> [AppNodeInfo] {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        let urlStr = baseURL + "/api/webapp/apiCallDemo?apiKey=\(apiKey)&webappId=\(webappId)"
        guard let url = URL(string: urlStr) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 30
        let (data, _) = try await URLSession.shared.data(for: req)
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] /api/webapp/apiCallDemo → \(str.prefix(800))")
        }
        #endif
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(APIResponse<AppWebappData>.self, from: data)
        guard decoded.isSuccess, let result = decoded.data else {
            throw APIError.serverError(decoded.msg ?? "获取节点失败")
        }
        return result.nodeInfoList
    }

    /// POST /task/openapi/ai-app/run — submit AI app task
    func runApp(webappId: String, nodeInfoList: [AppNodeInfo]) async throws -> AppRunData {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/task/openapi/ai-app/run") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 60
        let inputs = nodeInfoList.map { AppNodeInput(nodeId: $0.nodeId, fieldName: $0.fieldName, fieldValue: $0.fieldValue) }
        let body = AppRunRequest(webappId: webappId, apiKey: apiKey, nodeInfoList: inputs)
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] /task/openapi/ai-app/run → \(str.prefix(800))")
        }
        #endif
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(APIResponse<AppRunData>.self, from: data)
        guard decoded.isSuccess, let result = decoded.data else {
            throw APIError.serverError(decoded.msg ?? "提交失败")
        }
        return result
    }

    /// POST /task/openapi/outputs — query AI app task outputs
    func queryAppOutputs(taskId: String) async throws -> APIResponse<[AppOutputItem]> {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/task/openapi/outputs") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30
        struct Body: Encodable { let apiKey: String; let taskId: String }
        req.httpBody = try JSONEncoder().encode(Body(apiKey: apiKey, taskId: taskId))
        let (data, _) = try await URLSession.shared.data(for: req)
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] /task/openapi/outputs → \(str.prefix(800))")
        }
        #endif
        let decoder = JSONDecoder()
        return try decoder.decode(APIResponse<[AppOutputItem]>.self, from: data)
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

    /// POST /openapi/v2/resource/list — 获取公共模型列表（LoRA / CHECKPOINT / UNET / GGUF）
    func fetchPublicResources(type: String, keyword: String, page: Int, size: Int = 20) async throws -> PublicResourcePage {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/openapi/v2/resource/list") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30
        req.httpBody = try JSONEncoder().encode(PublicResourceListRequest(
            resourceType: type, resourceName: keyword.isEmpty ? nil : keyword, current: page, size: size
        ))
        let (data, _) = try await URLSession.shared.data(for: req)
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] /openapi/v2/resource/list → \(str.prefix(1000))")
        }
        #endif
        // API 返回驼峰字段名，不使用 convertFromSnakeCase
        let decoder = JSONDecoder()
        let wrapper = try decoder.decode(APIResponse<PublicResourcePage>.self, from: data)
        guard wrapper.isSuccess, let result = wrapper.data else {
            throw APIError.serverError(wrapper.msg ?? "获取模型列表失败")
        }
        return result
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
