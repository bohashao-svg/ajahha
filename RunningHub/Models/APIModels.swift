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

// MARK: - Workflow
struct WorkflowDetailResponse: Codable {
    let workflowId: String
    let name: String?
    let workflow: WorkflowGraph?
}

struct WorkflowGraph: Codable {
    var nodes: [WorkflowNode]?
    private var _nodeDict: [String: WorkflowNodeRaw]?

    var allNodes: [WorkflowNodeRaw] {
        return _nodeDict?.values.map { $0 } ?? []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: WorkflowNodeRaw].self) {
            _nodeDict = dict
            nodes = nil
        } else {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            nodes = try keyed.decodeIfPresent([WorkflowNode].self, forKey: .nodes)
            _nodeDict = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        if let dict = _nodeDict {
            var container = encoder.singleValueContainer()
            try container.encode(dict)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(nodes, forKey: .nodes)
        }
    }

    enum CodingKeys: String, CodingKey { case nodes }
}

struct WorkflowNode: Codable {
    let id: String?
    let type: String?
    let inputs: AnyCodable?
}

struct WorkflowNodeRaw: Codable {
    let classType: String?
    let inputs: AnyCodable?
    enum CodingKeys: String, CodingKey {
        case classType = "class_type"
        case inputs
    }
}

// MARK: - Workflow Type Detection
enum WorkflowType {
    case textToImage, textToVideo, imageToVideo, unknown

    static func detect(from nodes: [WorkflowNodeRaw]) -> WorkflowType {
        let types = nodes.compactMap { $0.classType?.lowercased() }
        if types.contains(where: { $0.contains("video") && $0.contains("image") }) {
            return .imageToVideo
        }
        if types.contains(where: { $0.contains("video") }) {
            return .textToVideo
        }
        if types.contains(where: { $0.contains("image") || $0.contains("ksampler") || $0.contains("sampler") }) {
            return .textToImage
        }
        return .unknown
    }

    var displayName: String {
        switch self {
        case .textToImage: return "文生图"
        case .textToVideo: return "文生视频"
        case .imageToVideo: return "图生视频"
        case .unknown: return "未知类型"
        }
    }
}

// MARK: - Duck Encode Node Detection
struct DuckNodeInfo {
    let nodeId: String
    let password: String?
    let version: String?
}

// MARK: - Task Submission
struct RunWorkflowRequest: Codable {
    let workflowId: String
    let mode: String?
    let prompt: String?       // full workflow JSON string
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
    let type: String?   // "image" | "video"
    let url: String?
    let fileUrl: String?

    var resolvedUrl: String? { url ?? fileUrl }
}

// MARK: - AnyCodable helper
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        default: try container.encodeNil()
        }
    }

    var stringValue: String? { value as? String }
    var dictValue: [String: AnyCodable]? { value as? [String: AnyCodable] }
}
