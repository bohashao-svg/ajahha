import Foundation
import UIKit

// MARK: - API Service
final class APIService {

    static let shared = APIService()
    private init() {}

    private let baseURL = "https://www.runninghub.cn"

    var authToken: String {
        // 优先用 accessKey，fallback 到旧 apiKey
        if let accessKey = StorageService.shared.accessKey, !accessKey.isEmpty {
            return accessKey
        }
        return (StorageService.shared.apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var apiKey: String {
        (StorageService.shared.apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - POST with Encodable body
    private func postEncodable<B: Encodable, T: Codable>(path: String, body: B) async throws -> T {
        guard !authToken.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

    /// 两步登录：
    /// Step 1: POST /uc/pwdLogin (手机号 + MD5密码) → JWT access_token
    /// Step 2: POST /api/instance/access/auth (Bearer JWT) → accessKey
    func login(username: String, password: String) async throws -> LoginResponse {
        // Step 1: pwdLogin
        guard let url1 = URL(string: baseURL + "/uc/pwdLogin") else { throw APIError.invalidURL }
        var req1 = URLRequest(url: url1)
        req1.httpMethod = "POST"
        req1.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req1.timeoutInterval = 30

        struct PwdBody: Encodable {
            let mobile: String; let password: String
            let serviceAgreement: Bool
            let channel: String?; let inviteCode: String?
        }
        req1.httpBody = try JSONEncoder().encode(PwdBody(
            mobile: username, password: password.md5,
            serviceAgreement: true, channel: nil, inviteCode: nil
        ))

        let (data1, _) = try await URLSession.shared.data(for: req1)
        #if DEBUG
        print("[API] /uc/pwdLogin → \(String(data: data1, encoding: .utf8)?.prefix(300) ?? "")")
        #endif

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let step1 = try decoder.decode(APIResponse<PwdLoginResponse>.self, from: data1)
        guard step1.isSuccess, let pwdResp = step1.data else {
            throw APIError.serverError(step1.msg ?? "登录失败")
        }

        // 存 JWT
        StorageService.shared.jwtToken = pwdResp.accessToken

        // Step 2: /api/instance/access/auth
        guard let url2 = URL(string: baseURL + "/api/instance/access/auth") else { throw APIError.invalidURL }
        var req2 = URLRequest(url: url2)
        req2.httpMethod = "POST"
        req2.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req2.setValue("Bearer \(pwdResp.accessToken)", forHTTPHeaderField: "Authorization")
        req2.httpBody = "{}".data(using: .utf8)
        req2.timeoutInterval = 30

        let (data2, _) = try await URLSession.shared.data(for: req2)
        #if DEBUG
        print("[API] /api/instance/access/auth → \(String(data: data2, encoding: .utf8)?.prefix(300) ?? "")")
        #endif

        let step2 = try decoder.decode(APIResponse<LoginResponse>.self, from: data2)
        guard step2.isSuccess, let authResp = step2.data else {
            throw APIError.serverError(step2.msg ?? "获取授权失败")
        }

        // 存 accessKey（expire_in 是绝对时间戳毫秒）
        StorageService.shared.accessKey = authResp.accessKey
        if let expireMs = Double(authResp.expireIn) {
            StorageService.shared.accessKeyExpire = expireMs
        }

        return authResp
    }

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
        guard !authToken.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/openapi/v2/query") else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        struct Body: Encodable { let apiKey: String; let taskId: String }
        req.httpBody = try JSONEncoder().encode(Body(apiKey: authToken, taskId: taskId))

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
        guard !authToken.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/task/openapi/upload") else { throw APIError.invalidURL }
        guard let imageData = image.jpegData(compressionQuality: 0.9) else { throw APIError.invalidResponse }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
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
        guard !authToken.isEmpty else { throw APIError.noAPIKey }
        let urlStr = baseURL + "/api/webapp/apiCallDemo?apiKey=\(authToken)&webappId=\(webappId)"
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

    /// POST /task/webapp/create — submit AI app task via JWT (supports team webapps)
    func runApp(webappId: String, nodeInfoList: [AppNodeInfo]) async throws -> AppRunData {
        guard let jwt = StorageService.shared.jwtToken, !jwt.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/task/webapp/create") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 60
        let inputs = nodeInfoList.map { AppNodeInput(nodeId: $0.nodeId, fieldName: $0.fieldName, fieldValue: $0.fieldValue) }
        req.httpBody = try JSONEncoder().encode(WebAppRunRequest(webappId: webappId, inputs: inputs))
        let (data, _) = try await URLSession.shared.data(for: req)
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] /task/webapp/create → \(str.prefix(800))")
        }
        #endif
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(APIResponse<AppRunData>.self, from: data)
        guard decoded.isSuccess, let result = decoded.data else {
            throw APIError.serverError(decoded.msg ?? "提交失败")
        }
        return result
    }

    /// POST /task/openapi/outputs — query AI app task outputs
    func queryAppOutputs(taskId: String) async throws -> APIResponse<[AppOutputItem]> {
        guard !authToken.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/task/openapi/outputs") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        struct Body: Encodable { let apiKey: String; let taskId: String }
        req.httpBody = try JSONEncoder().encode(Body(apiKey: authToken, taskId: taskId))
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

    /// POST /api/output/history — 获取个人作品历史（用 JWT Bearer）
    func fetchOutputHistory(page: Int, size: Int = 20) async throws -> OutputHistoryPage {
        guard let jwt = StorageService.shared.jwtToken, !jwt.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: baseURL + "/api/output/history") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30

        struct Body: Encodable {
            let size: Int; let current: Int
            let status: [String]; let taskType: [String]
            let hasOutput: Bool; let taskName: String; let reloadData: Bool
        }
        req.httpBody = try JSONEncoder().encode(Body(
            size: size, current: page,
            status: ["SUCCESS"],
            taskType: ["API", "WEBAPP", "WORKFLOW", "ExclAPI", "CORPAPI", "FAST_WEBAPP"],
            hasOutput: true, taskName: "", reloadData: false
        ))

        let (data, _) = try await URLSession.shared.data(for: req)
        #if DEBUG
        if let str = String(data: data, encoding: .utf8) {
            print("[API] /api/output/history → \(str.prefix(800))")
        }
        #endif

        let decoder = JSONDecoder()
        let wrapper = try decoder.decode(APIResponse<OutputHistoryPage>.self, from: data)
        guard wrapper.isSuccess, let result = wrapper.data else {
            throw APIError.serverError(wrapper.msg ?? "获取作品历史失败")
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
