import Foundation
import UIKit

// MARK: - Gacha Task (local, not stored in AppState)
struct GachaTask: Identifiable {
    var id: String
    let prompt: String
    var status: TaskStatus
    var outputUrls: [String] = []
    var decodedData: Data?
    var decodedExt: String = "jpg"
    var errorMsg: String?
}

// MARK: - Gacha ViewModel
@MainActor
final class GachaViewModel: ObservableObject {

    // MARK: - Config
    @Published var gachaApiKey: String = UserDefaults.standard.string(forKey: "gacha_api_key") ?? ""
    @Published var targetId: String = ""
    @Published var concurrency: Int = 3
    @Published var promptsText: String = ""

    // MARK: - Target info
    @Published var isLoadingTarget: Bool = false
    @Published var workflowDetail: WorkflowDetailResponse?
    @Published var workflowType: WorkflowType = .unknown
    @Published var duckNodeInfo: DuckNodeInfo?
    @Published var isTTEncoded: Bool = false
    @Published var extraFields: [FormField] = []   // image / lora fields only
    @Published var appNodes: [AppNodeInfo] = []
    @Published var appPromptNodes: [AppNodeInfo] = []  // STRING/TEXT nodes for prompt injection
    @Published var isWebApp: Bool = false
    @Published var targetLoaded: Bool = false

    // MARK: - Batch state
    @Published var isRunning: Bool = false
    @Published var gachaTasks: [GachaTask] = []
    @Published var errorMessage: String?

    private let baseURL = "https://www.runninghub.cn"

    // MARK: - Computed
    var parsedPrompts: [String] {
        promptsText.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var promptCount: Int { parsedPrompts.count }

    var canStart: Bool {
        !gachaApiKey.isBlank && targetLoaded && promptCount > 0 && !isRunning
    }

    // MARK: - Save API Key
    func saveApiKey() {
        UserDefaults.standard.set(gachaApiKey, forKey: "gacha_api_key")
    }

    // MARK: - Fetch Target
    func fetchTarget() async {
        let input = targetId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !gachaApiKey.isBlank else {
            errorMessage = "请先填写 API Key 和目标 ID"
            return
        }
        isLoadingTarget = true
        errorMessage = nil
        targetLoaded = false
        workflowDetail = nil
        extraFields = []
        appNodes = []
        appPromptNodes = []
        isWebApp = false

        defer { isLoadingTarget = false }

        // Try workflow first
        do {
            let detail = try await fetchWorkflowDetail(workflowId: input)
            workflowDetail = detail
            let nodes = detail.allNodes
            workflowType = WorkflowType.detect(from: nodes)
            duckNodeInfo = DuckDecodeService.shared.detectDuckNode(in: nodes)
            isTTEncoded = TTDecodeService.shared.detectTTNode(in: nodes)
            extraFields = buildExtraFields(from: detail)
            isWebApp = false
            targetLoaded = true
            return
        } catch {}

        // Try AI app
        do {
            let nodes = try await fetchAppNodes(webappId: input)
            // STRING/TEXT nodes are prompt targets; others are configurable extra fields
            appPromptNodes = nodes.filter {
                let ft = $0.fieldType.uppercased()
                return ft == "STRING" || ft == "TEXT"
            }
            appNodes = nodes.filter {
                let ft = $0.fieldType.uppercased()
                return ft != "STRING" && ft != "TEXT"
            }
            isWebApp = true
            targetLoaded = true
        } catch {
            errorMessage = "无法识别该 ID，请检查后重试"
        }
    }

    // MARK: - Start Batch
    func startBatch() async {
        let prompts = parsedPrompts
        guard !prompts.isEmpty, targetLoaded else { return }

        isRunning = true
        errorMessage = nil
        gachaTasks = prompts.map {
            GachaTask(id: UUID().uuidString, prompt: $0, status: .queued)
        }

        let batches = prompts.chunked(into: max(1, concurrency))
        for (batchIdx, batch) in batches.enumerated() {
            let startIdx = batchIdx * concurrency
            await withTaskGroup(of: (Int, GachaTask).self) { group in
                for (i, prompt) in batch.enumerated() {
                    let taskIdx = startIdx + i
                    let placeholder = gachaTasks[taskIdx]
                    group.addTask { [weak self] in
                        guard let self else { return (taskIdx, placeholder) }
                        var t = placeholder
                        do {
                            let taskId = try await self.submitSingle(prompt: prompt)
                            t.id = taskId
                            t.status = .queued
                            await MainActor.run { self.gachaTasks[taskIdx] = t }
                            t = try await self.pollUntilDone(task: t, taskIdx: taskIdx)
                        } catch {
                            t.status = .failed
                            t.errorMsg = error.localizedDescription
                        }
                        return (taskIdx, t)
                    }
                }
                for await (idx, result) in group {
                    gachaTasks[idx] = result
                }
            }
        }

        isRunning = false
    }

    // MARK: - Submit Single
    private func submitSingle(prompt: String) async throws -> String {
        if isWebApp {
            return try await runApp(prompt: prompt)
        } else {
            return try await runWorkflow(prompt: prompt)
        }
    }

    private func runWorkflow(prompt: String) async throws -> String {
        guard let url = URL(string: baseURL + "/task/openapi/create") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        // Build node inputs: extra fields + prompt fields from workflowDetail
        var nodeInputs: [[String: String]] = []

        // Extra fields (image/lora)
        for f in extraFields where !f.value.isBlank && f.value != "pending_upload" {
            nodeInputs.append(["nodeId": f.nodeId, "fieldName": f.fieldName, "fieldValue": f.value])
        }

        // Prompt fields from workflow
        if let detail = workflowDetail {
            let nodeDict = detail.parsedNodes
            for (nodeId, node) in nodeDict {
                let ct = node.classType?.lowercased() ?? ""
                guard !ct.contains("duck") else { continue }
                let inputs = node.inputs?.dictValue ?? [:]
                if inputs.keys.contains("text") {
                    nodeInputs.append(["nodeId": nodeId, "fieldName": "text", "fieldValue": prompt])
                } else if inputs.keys.contains("prompt") {
                    nodeInputs.append(["nodeId": nodeId, "fieldName": "prompt", "fieldValue": prompt])
                }
            }
        }

        let body: [String: Any] = [
            "apiKey": gachaApiKey,
            "workflowId": targetId,
            "nodeInfoList": nodeInputs
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        print("[Gacha] runWorkflow response: \(String(data: data, encoding: .utf8)?.prefix(400) ?? "")")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let dataDict = json["data"] as? [String: Any],
              let taskId = dataDict["taskId"] as? String else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: msg ?? "提交失败"])
        }
        return taskId
    }

    private func runApp(prompt: String) async throws -> String {
        guard let url = URL(string: baseURL + "/task/openapi/create") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        var nodeInputs: [[String: String]] = []
        // Extra fields (image, lora, etc.) — user-configured values
        for node in appNodes where !node.fieldValue.isBlank {
            nodeInputs.append(["nodeId": node.nodeId, "fieldName": node.fieldName, "fieldValue": node.fieldValue])
        }
        // Inject prompt into all STRING/TEXT nodes
        for node in appPromptNodes {
            nodeInputs.append(["nodeId": node.nodeId, "fieldName": node.fieldName, "fieldValue": prompt])
        }
        let body: [String: Any] = [
            "apiKey": gachaApiKey,
            "workflowId": targetId,
            "nodeInfoList": nodeInputs
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        print("[Gacha] runApp response: \(String(data: data, encoding: .utf8)?.prefix(400) ?? "")")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? Int, code == 0,
              let dataDict = json["data"] as? [String: Any],
              let taskId = dataDict["taskId"] as? String else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: msg ?? "提交失败"])
        }
        return taskId
    }

    // MARK: - Poll Until Done
    private func pollUntilDone(task: GachaTask, taskIdx: Int) async throws -> GachaTask {
        var t = task
        var attempts = 0
        let maxAttempts = 120  // 10 min max

        while attempts < maxAttempts {
            let interval: UInt64 = t.status == .running ? 3_000_000_000 : 5_000_000_000
            try await Task.sleep(nanoseconds: interval)

            let result = try await pollOutputs(taskId: t.id)
            t.status = result.status
            if !result.outputUrls.isEmpty { t.outputUrls = result.outputUrls }
            if let err = result.errorMessage { t.errorMsg = err }

            await MainActor.run { self.gachaTasks[taskIdx] = t }

            if t.status == .completed {
                if let url = t.outputUrls.first {
                    t = await decodeIfNeeded(task: t, url: url)
                    await MainActor.run { self.gachaTasks[taskIdx] = t }
                }
                return t
            }
            if t.status == .failed || t.status == .cancelled { return t }
            attempts += 1
        }
        t.status = .failed
        t.errorMsg = "超时"
        return t
    }

    // MARK: - Poll Outputs
    private func pollOutputs(taskId: String) async throws -> TaskOutputsPollResult {
        guard let url = URL(string: baseURL + "/task/openapi/outputs") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: ["apiKey": gachaApiKey, "taskId": taskId])

        let (data, _) = try await URLSession.shared.data(for: req)
        print("[Gacha] pollOutputs \(taskId) → \(String(data: data, encoding: .utf8)?.prefix(400) ?? "")")

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        let code = json["code"] as? Int ?? -1

        // code != 0 but task may still be queued — treat as queued instead of throwing
        guard code == 0 else {
            return TaskOutputsPollResult(status: .queued, outputUrls: [], errorMessage: nil)
        }

        let dataField = json["data"]

        // data is array → completed
        if let items = dataField as? [[String: Any]] {
            let urls = items.compactMap { $0["fileUrl"] as? String }
            return TaskOutputsPollResult(status: .completed, outputUrls: urls, errorMessage: nil)
        }

        // data is dict → in progress
        if let dict = dataField as? [String: Any] {
            let rawStatus = (dict["taskStatus"] as? String ?? "").uppercased()
            let status: TaskStatus
            switch rawStatus {
            case "SUCCESS":   status = .completed
            case "RUNNING":   status = .running
            case "FAILED":    status = .failed
            case "CANCELLED": status = .cancelled
            default:          status = .queued
            }
            return TaskOutputsPollResult(status: status, outputUrls: [], errorMessage: dict["errorMessage"] as? String)
        }

        // data is null → still queued
        return TaskOutputsPollResult(status: .queued, outputUrls: [], errorMessage: nil)
    }

    // MARK: - Decode
    private func decodeIfNeeded(task: GachaTask, url: String) async -> GachaTask {
        var t = task
        do {
            if let duck = duckNodeInfo {
                let file = try await DuckDecodeService.shared.decode(imageUrl: url, password: duck.password ?? "")
                t.decodedData = file.data
                t.decodedExt = file.ext
            } else if isTTEncoded {
                let file = try await TTDecodeService.shared.decode(imageUrl: url, password: "")
                t.decodedData = file.data
                t.decodedExt = file.ext
            } else {
                // Download raw
                if let imgUrl = URL(string: url),
                   let (data, _) = try? await URLSession.shared.data(from: imgUrl) {
                    t.decodedData = data
                    t.decodedExt = url.hasSuffix(".mp4") ? "mp4" : "jpg"
                }
            }
        } catch {
            // Decode failed, keep outputUrls for display
        }
        return t
    }

    // MARK: - Upload Image
    func uploadImage(_ image: UIImage, fieldIndex: Int) async {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        guard let url = URL(string: baseURL + "/task/openapi/upload") else { return }

        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"apiKey\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(gachaApiKey)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        if let (respData, _) = try? await URLSession.shared.data(for: req),
           let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
           let d = json["data"] as? [String: Any],
           let fileName = d["fileName"] as? String {
            extraFields[fieldIndex].value = fileName
            extraFields[fieldIndex].selectedImage = image
        }
    }

    // MARK: - Private API helpers (use gachaApiKey)
    private func fetchWorkflowDetail(workflowId: String) async throws -> WorkflowDetailResponse {
        guard let url = URL(string: baseURL + "/api/openapi/getJsonApiFormat") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: ["apiKey": gachaApiKey, "workflowId": workflowId])
        let (data, _) = try await URLSession.shared.data(for: req)
        print("[Gacha] fetchWorkflowDetail → \(String(data: data, encoding: .utf8)?.prefix(300) ?? "")")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let wrapper = try decoder.decode(APIResponse<WorkflowDetailResponse>.self, from: data)
        guard wrapper.isSuccess, let result = wrapper.data else {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: wrapper.msg ?? "获取工作流失败"])
        }
        return result
    }

    private func fetchAppNodes(webappId: String) async throws -> [AppNodeInfo] {
        let urlStr = baseURL + "/api/webapp/apiCallDemo?apiKey=\(gachaApiKey)&webappId=\(webappId)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 30
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(APIResponse<AppWebappData>.self, from: data)
        guard decoded.isSuccess, let result = decoded.data else { throw URLError(.badServerResponse) }
        return result.nodeInfoList
    }

    private func buildExtraFields(from detail: WorkflowDetailResponse) -> [FormField] {
        var fields: [FormField] = []
        let nodeDict = detail.parsedNodes
        let sorted = nodeDict
            .filter { !($0.value.classType?.lowercased().contains("duck") ?? false) }
            .sorted { (Int($0.key) ?? Int.max) < (Int($1.key) ?? Int.max) }

        for (nodeId, node) in sorted {
            let ct = node.classType?.lowercased() ?? ""
            let title = node.meta?.title ?? node.classType ?? "输入"
            let inputs = node.inputs?.dictValue ?? [:]

            if ct.contains("loadimage") {
                fields.append(FormField(nodeId: nodeId, fieldName: "image", label: title,
                    placeholder: "图片 URL", value: "", type: .imageInput, promptRole: nil))
            } else if ct.contains("lora") {
                let loraName = inputs["lora_name"]?.stringValue ?? inputs["lora"]?.stringValue ?? ""
                fields.append(FormField(nodeId: nodeId, fieldName: "lora_name", label: title,
                    placeholder: "选择 LoRA 模型...", value: loraName, type: .loraInput, promptRole: nil))
            }
            // Skip text/prompt fields — those are filled per-prompt
        }
        return fields
    }
}

// MARK: - Array chunked helper
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
