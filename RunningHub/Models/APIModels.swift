import Foundation

// MARK: - Workflow History Item
struct WorkflowHistoryItem: Codable, Identifiable {
    var id: String { workflowId }
    let workflowId: String
    let workflowType: String
    let usedAt: Date

    init(workflowId: String, workflowType: String) {
        self.workflowId = workflowId
        self.workflowType = workflowType
        self.usedAt = Date()
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
        if types.contains(where: { $0.contains("video") && ($0.contains("image") || $0.contains("i2v")) }) {
            return .imageToVideo
        }
        if types.contains(where: { $0.contains("video") || $0.contains("animate") }) {
            return .textToVideo
        }
        if types.contains(where: { $0.contains("ksampler") || $0.contains("sampler") }) {
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
