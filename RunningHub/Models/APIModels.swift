import Foundation

// MARK: - Base Response
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let msg: String?
    let data: T?
    var isSuccess: Bool { code == 0 }
}

// MARK: - User Quota
struct UserQuota: Codable {
    let maxConcurrency: Int
    let usedConcurrency: Int
    var availableConcurrency: Int { maxConcurrency - usedConcurrency }
    var hasAvailableSlot: Bool { availableConcurrency > 0 }
}

// MARK: - Workflow Detail
// API returns: { "prompt": "<JSON string of ComfyUI nodes>" }
struct WorkflowDetailResponse: Codable {
    let prompt: String   // raw JSON string, needs second-pass decode

    // Parsed nodes (ComfyUI dict format: { "nodeId": { class_type, inputs, _meta } })
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
        if types.contains(where: { $0.contains("video") && ($0.contains("image") || $0.contains("i2v")) }) {
            return .imageToVideo
        }
        if types.contains(where: { $0.contains("video") || $0.contains("animate") }) {
            return .textToVideo
        }
        if types.contains(where: { $0.contains("ksampler") || $0.contains("sampler") || $0.contains("image") }) {
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

// MARK: - Duck Node Detection
struct DuckNodeInfo {
    let nodeId: String
    let password: String?
    let version: String?
}

// MARK: - Task Submission
struct RunWorkflowRequest: Codable {
    let workflowId: String
    let mode: String?
    let prompt: String?       // full workflow JSON string (from WorkflowDetailResponse.prompt)
    let nodeInfoList: [NodeInput]
}

struct NodeInput: Codable {
    let nodeId: String
    let fieldName: String
    let fieldValue: String
}

struct RunWorkflowResponse: Codable {
    let taskId: String
}

// MARK: - Task Status
struct TaskStatusItem: Codable {
    let taskId: String
    let status: String
    let progress: Double?
    let outputs: [TaskOutput]?
    let errorMsg: String?
}

struct TaskOutput: Codable {
    let type: String?
    let url: String?
    let fileUrl: String?
    var resolvedUrl: String? { url ?? fileUrl }
}

// MARK: - AnyCodable
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self)                  { value = v }
        else if let v = try? c.decode(Int.self)              { value = v }
        else if let v = try? c.decode(Double.self)           { value = v }
        else if let v = try? c.decode(String.self)           { value = v }
        else if let v = try? c.decode([String: AnyCodable].self) { value = v }
        else if let v = try? c.decode([AnyCodable].self)     { value = v }
        else                                                 { value = NSNull() }
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
}
