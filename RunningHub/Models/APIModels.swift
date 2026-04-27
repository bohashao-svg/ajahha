import Foundation

// MARK: - Workflow History Item
struct WorkflowHistoryItem: Codable, Identifiable {
    enum ItemType: String, Codable { case workflow, aiApp }
    var id: String { workflowId }
    let workflowId: String
    let workflowType: String
    let usedAt: Date
    let itemType: ItemType

    init(workflowId: String, workflowType: String, itemType: ItemType = .workflow) {
        self.workflowId = workflowId
        self.workflowType = workflowType
        self.usedAt = Date()
        self.itemType = itemType
    }

    // 兼容旧缓存（没有 itemType 字段）
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        workflowId   = try c.decode(String.self, forKey: .workflowId)
        workflowType = try c.decode(String.self, forKey: .workflowType)
        usedAt       = try c.decode(Date.self,   forKey: .usedAt)
        itemType     = try c.decodeIfPresent(ItemType.self, forKey: .itemType) ?? .workflow
    }
}

// MARK: - Base Response (used by most endpoints)
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let msg: String?
    let data: T?
    var isSuccess: Bool { code == 0 }
}

// MARK: - Workflow Detail
struct WorkflowDetailResponse: Codable {
    let prompt: String

    var parsedNodes: [String: WorkflowNodeRaw] {
        guard let data = prompt.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: WorkflowNodeRaw].self, from: data)
        else { return [:] }
        return dict
    }

    var allNodes: [WorkflowNodeRaw] { Array(parsedNodes.values) }
}

struct WorkflowNodeRaw: Codable {
    let classType: String?
    let inputs: AnyCodable?
    let meta: WorkflowNodeMeta?

    enum CodingKeys: String, CodingKey {
        case classType = "class_type"
        case inputs
        case meta = "_meta"
    }
}

struct WorkflowNodeMeta: Codable {
    let title: String?
}

// MARK: - Workflow Type Detection
enum WorkflowType {
    case textToImage, textToVideo, imageToVideo, unknown

    static func detect(from nodes: [WorkflowNodeRaw]) -> WorkflowType {
        let types = nodes.compactMap { $0.classType?.lowercased() }

        // 图生视频：同时含 video 和 image/i2v 相关节点
        if types.contains(where: { $0.contains("video") && ($0.contains("image") || $0.contains("i2v")) }) {
            return .imageToVideo
        }
        // 视频类：含 video / animate / wan / hunyuan_video / mochi 等
        let videoKeywords = ["video", "animate", "wan", "mochi", "ltx", "cogvideo", "animatediff"]
        if types.contains(where: { t in videoKeywords.contains(where: { t.contains($0) }) }) {
            return .textToVideo
        }
        // 图像类：含采样器或常见图像生成节点
        let imageKeywords = ["ksampler", "sampler", "flux", "unet", "vae", "clip", "checkpoint",
                             "diffusion", "stable", "sdxl", "sd3", "imagen", "controlnet"]
        if types.contains(where: { t in imageKeywords.contains(where: { t.contains($0) }) }) {
            return .textToImage
        }
        return .unknown
    }

    var displayName: String {
        switch self {
        case .textToImage:  return "文生图"
        case .textToVideo:  return "文生视频"
        case .imageToVideo: return "图生视频"
        case .unknown:      return "未知类型"
        }
    }
}

// MARK: - Duck Node Info
struct DuckNodeInfo {
    let nodeId: String
    let password: String?
    let version: String?
}

// MARK: - Upload Image Response
struct UploadImageResponse: Codable {
    let fileName: String
}

// MARK: - Task Submission
struct RunWorkflowRequest: Codable {
    let workflowId: String
    let mode: String?           // maps to instanceType ("plus")
    let nodeInfoList: [NodeInput]
}

struct NodeInput: Codable {
    let nodeId: String
    let fieldName: String
    let fieldValue: String
}

// POST /task/openapi/create response (wrapped in APIResponse)
struct RunWorkflowResponse: Codable {
    let taskId: String
    let taskStatus: String?
}

// MARK: - Task Query (POST /openapi/v2/query)
// Flat response — NOT wrapped in APIResponse
struct TaskQueryResponse: Codable {
    let taskId: String
    let status: String          // QUEUED, RUNNING, SUCCESS, FAILED, CANCELLED
    let errorCode: String?
    let errorMessage: String?
    let results: [TaskQueryResult]?

    var taskStatus: TaskStatus {
        switch status.uppercased() {
        case "SUCCESS":   return .completed
        case "RUNNING":   return .running
        case "FAILED":    return .failed
        case "CANCELLED": return .cancelled
        default:          return .queued   // QUEUED or unknown
        }
    }

    var outputUrls: [String] {
        results?.compactMap { $0.url } ?? []
    }
}

struct TaskQueryResult: Codable {
    let url: String
    let outputType: String?
}

// MARK: - AI App (WebApp) Models

struct AppNodeInfo: Codable, Identifiable {
    var id: String { nodeId + fieldName }
    let nodeId: String
    let nodeName: String?
    let fieldName: String
    var fieldValue: String
    let fieldType: String   // IMAGE, STRING, LIST, AUDIO, VIDEO
    let description: String?
    let fieldData: AnyCodable?  // LIST options
}

struct AppWebappData: Codable {
    let nodeInfoList: [AppNodeInfo]
}

struct AppRunRequest: Codable {
    let webappId: String
    let apiKey: String
    let nodeInfoList: [AppNodeInfo]
}

struct AppRunData: Codable {
    let taskId: String
    let promptTips: String?
}

struct AppOutputItem: Codable {
    let fileUrl: String?
    let fileType: String?
}

// MARK: - Public Resource (LoRA / CHECKPOINT / UNET / GGUF)
struct PublicResourceListRequest: Encodable {
    let resourceType: String
    let resourceName: String
    let current: Int
    let size: Int
}

struct PublicResourcePage: Codable {
    let records: [PublicResource]
    let total: Int
    let pages: Int
    let hasNext: Bool
}

struct PublicResource: Codable, Identifiable {
    let id: String
    let resourceName: String
    let resourceType: String
    let nodeModelName: String?
    let posterUrl: String?
    let thumbnailUrl: String?
    let owner: ResourceOwner?
    let tags: [ResourceTag]?
    let versions: [ResourceVersion]?

    var firstTriggerWords: String? {
        versions?.first(where: { !($0.triggerWords ?? "").isEmpty })?.triggerWords
    }
}

struct ResourceOwner: Codable {
    let name: String?
    let avatar: String?
}

struct ResourceTag: Codable, Identifiable {
    let id: Int
    let name: String
}

struct ResourceVersion: Codable, Identifiable {
    let id: String
    let version: String?
    let versionResourceName: String?
    let baseModel: String?
    let triggerWords: String?
    let posterInfos: [ResourcePosterInfo]?
}

struct ResourcePosterInfo: Codable {
    let posterUrl: String?
    let thumbnailUrl: String?
    let imageWidth: Int?
    let imageHeight: Int?
}

// MARK: - User Task List (个人中心)
struct UserTaskListRequest: Encodable {
    let apiKey: String
    let current: Int
    let size: Int
}

struct UserTaskListPage: Codable {
    let records: [UserTaskRecord]
    let total: Int
    let pages: Int?
    let current: Int?
    let size: Int?
}

struct UserTaskRecord: Codable, Identifiable {
    let taskId: String
    let taskStatus: String?
    let workflowId: String?
    let workflowName: String?
    let createdAt: String?
    let outputList: [UserTaskOutput]?

    var id: String { taskId }

    var isCompleted: Bool {
        (taskStatus ?? "").uppercased() == "SUCCESS"
    }

    var outputUrls: [String] {
        outputList?.compactMap { $0.fileUrl }.filter { !$0.isEmpty } ?? []
    }

    var firstImageUrl: String? {
        outputList?.first(where: { url in
            let ext = (url.fileUrl ?? "").split(separator: ".").last?.lowercased() ?? ""
            return !["mp4", "mov", "webm"].contains(ext)
        })?.fileUrl
    }
}

struct UserTaskOutput: Codable {
    let fileUrl: String?
    let fileType: String?
}

// MARK: - AnyCodable
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self)                      { value = v }
        else if let v = try? c.decode(Int.self)                  { value = v }
        else if let v = try? c.decode(Double.self)               { value = v }
        else if let v = try? c.decode(String.self)               { value = v }
        else if let v = try? c.decode([String: AnyCodable].self) { value = v }
        else if let v = try? c.decode([AnyCodable].self)         { value = v }
        else                                                     { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as Bool:                  try c.encode(v)
        case let v as Int:                   try c.encode(v)
        case let v as Double:                try c.encode(v)
        case let v as String:                try c.encode(v)
        case let v as [String: AnyCodable]:  try c.encode(v)
        case let v as [AnyCodable]:          try c.encode(v)
        default:                             try c.encodeNil()
        }
    }

    var stringValue: String? { value as? String }
    var dictValue: [String: AnyCodable]? { value as? [String: AnyCodable] }
    var arrayValue: [AnyCodable]? { value as? [AnyCodable] }
    var intValue: Int? { value as? Int }
    var doubleValue: Double? { value as? Double }
}
