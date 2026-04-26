import Foundation

// MARK: - Task Status Enum
enum TaskStatus: String, Codable, CaseIterable {
    case queued    = "QUEUED"
    case pending   = "PENDING"
    case running   = "RUNNING"
    case completed = "COMPLETED"
    case failed    = "FAILED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .queued:    return "排队中"
        case .pending:   return "排队中"
        case .running:   return "生成中"
        case .completed: return "已完成"
        case .failed:    return "失败"
        case .cancelled: return "已取消"
        }
    }
}

// MARK: - Local Task Model
struct RHTask: Codable, Identifiable {
    let id: String
    let workflowId: String
    let workflowName: String
    var status: TaskStatus
    var progress: Double       // 0.0 ~ 1.0
    var outputUrls: [String]
    var decodedImageData: Data?
    var isDuckEncoded: Bool
    var duckPassword: String?
    var isTTEncoded: Bool
    var ttDecodedData: Data?
    var isPlusMode: Bool
    var workflowType: String
    var errorMsg: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        workflowId: String,
        workflowName: String,
        isDuckEncoded: Bool,
        duckPassword: String?,
        isTTEncoded: Bool,
        isPlusMode: Bool,
        workflowType: String
    ) {
        self.id = id
        self.workflowId = workflowId
        self.workflowName = workflowName
        self.status = .queued
        self.progress = 0
        self.outputUrls = []
        self.decodedImageData = nil
        self.isDuckEncoded = isDuckEncoded
        self.duckPassword = duckPassword
        self.isTTEncoded = isTTEncoded
        self.ttDecodedData = nil
        self.isPlusMode = isPlusMode
        self.workflowType = workflowType
        self.errorMsg = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isFinished: Bool {
        status == .completed || status == .failed || status == .cancelled
    }

    var primaryOutputUrl: String? { outputUrls.first }
}
