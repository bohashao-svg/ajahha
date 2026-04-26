import Foundation
import Combine
import UIKit

// MARK: - Home ViewModel
@MainActor
final class HomeViewModel: ObservableObject {

    @Published var workflowInput: String = ""
    @Published var isPlusMode: Bool = StorageService.shared.isPlusDefault
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var workflowDetail: WorkflowDetailResponse?
    @Published var workflowType: WorkflowType = .unknown
    @Published var duckNodeInfo: DuckNodeInfo?
    @Published var formFields: [FormField] = []
    @Published var currentWorkflowId: String = ""
    @Published var workflowHistory: [WorkflowHistoryItem] = StorageService.shared.workflowHistory
    @Published var showAllHistory: Bool = false
    @Published var showPromptSelector: Bool = false
    @Published var availablePromptFields: [FormField] = []

    private let appState: AppState

    init(appState: AppState = .shared) {
        self.appState = appState
    }

    // MARK: - Fetch Workflow
    func fetchWorkflow() async {
        guard let workflowId = workflowInput.extractWorkflowId() else {
            errorMessage = "请输入有效的工作流 ID 或链接"
            return
        }
        // 先清空旧数据，避免切换工作流时显示上一个的表单
        workflowDetail = nil
        formFields = []
        duckNodeInfo = nil
        workflowType = .unknown
        currentWorkflowId = workflowId
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var targetId = workflowId
            do {
                let detail = try await APIService.shared.fetchWorkflowDetail(workflowId: workflowId)
                workflowDetail = detail
                analyzeWorkflow(detail)
            } catch APIError.serverError(let msg) where msg.contains("NOT_SAVED") || msg.contains("WORKFLOW_NOT") {
                // Workflow not in user's workspace — auto-fork then retry
                targetId = try await APIService.shared.duplicateWorkflow(workflowId: workflowId)
                currentWorkflowId = targetId
                let detail = try await APIService.shared.fetchWorkflowDetail(workflowId: targetId)
                workflowDetail = detail
                analyzeWorkflow(detail)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func analyzeWorkflow(_ detail: WorkflowDetailResponse) {
        let nodes = detail.allNodes
        workflowType = WorkflowType.detect(from: nodes)
        duckNodeInfo = DuckDecodeService.shared.detectDuckNode(in: nodes)

        let allPromptFields = collectAllPromptFields(from: nodes)

        // If multiple prompt fields detected, show selector
        if allPromptFields.count > 1 {
            availablePromptFields = allPromptFields
            showPromptSelector = true
            formFields = [] // Wait for user selection
        } else {
            formFields = buildFormFields(from: nodes, selectedPrompts: nil)
        }
    }

    func applyPromptSelection(_ selected: [PromptFieldSelection]) {
        guard let detail = workflowDetail else { return }
        formFields = buildFormFields(from: detail.allNodes, selectedPrompts: selected)
        showPromptSelector = false
    }

    private func collectAllPromptFields(from nodes: [WorkflowNodeRaw]) -> [FormField] {
        var fields: [FormField] = []
        let nodeDict = workflowDetail?.parsedNodes ?? [:]

        let inputNodes = nodeDict
            .filter { (_, node) in
                guard let ct = node.classType?.lowercased() else { return false }
                return !ct.contains("duck")
            }
            .sorted { a, b in (Int(a.key) ?? Int.max) < (Int(b.key) ?? Int.max) }

        for (nodeId, node) in inputNodes {
            let title = node.meta?.title ?? node.classType ?? "输入"
            let inputs = node.inputs?.dictValue ?? [:]

            if inputs.keys.contains("text") {
                let defaultText = inputs["text"]?.stringValue ?? ""
                fields.append(FormField(
                    nodeId: nodeId,
                    fieldName: "text",
                    label: title,
                    placeholder: "输入提示词...",
                    value: defaultText,
                    type: .multilineText,
                    promptRole: nil
                ))
            } else if inputs.keys.contains("prompt") {
                let defaultText = inputs["prompt"]?.stringValue ?? ""
                fields.append(FormField(
                    nodeId: nodeId,
                    fieldName: "prompt",
                    label: title,
                    placeholder: "输入提示词...",
                    value: defaultText,
                    type: .multilineText,
                    promptRole: nil
                ))
            }
        }

        return fields
    }

    private func buildFormFields(from nodes: [WorkflowNodeRaw], selectedPrompts: [PromptFieldSelection]?) -> [FormField] {
        var fields: [FormField] = []
        let nodeDict = workflowDetail?.parsedNodes ?? [:]

        let inputNodes = nodeDict
            .filter { (_, node) in
                guard let ct = node.classType?.lowercased() else { return false }
                return !ct.contains("duck")
            }
            .sorted { a, b in (Int(a.key) ?? Int.max) < (Int(b.key) ?? Int.max) }

        for (nodeId, node) in inputNodes {
            let ct = node.classType?.lowercased() ?? ""
            let title = node.meta?.title ?? node.classType ?? "输入"
            let inputs = node.inputs?.dictValue ?? [:]

            if ct.contains("loadimage") {
                fields.append(FormField(
                    nodeId: nodeId,
                    fieldName: "image",
                    label: title,
                    placeholder: "图片 URL",
                    value: "",
                    type: .imageInput,
                    promptRole: nil
                ))
            } else if inputs.keys.contains("text") || inputs.keys.contains("prompt") {
                let fieldName = inputs.keys.contains("text") ? "text" : "prompt"
                let defaultText = inputs[fieldName]?.stringValue ?? ""

                // If selectedPrompts provided, only include selected fields
                if let selections = selectedPrompts {
                    if let selection = selections.first(where: { $0.nodeId == nodeId && $0.fieldName == fieldName }) {
                        fields.append(FormField(
                            nodeId: nodeId,
                            fieldName: fieldName,
                            label: selection.role == .positive ? "正向提示词" : "负向提示词",
                            placeholder: "输入提示词...",
                            value: defaultText,
                            type: .multilineText,
                            promptRole: selection.role
                        ))
                    }
                } else {
                    // No selection dialog shown, include all
                    fields.append(FormField(
                        nodeId: nodeId,
                        fieldName: fieldName,
                        label: title,
                        placeholder: "输入提示词...",
                        value: defaultText,
                        type: .multilineText,
                        promptRole: nil
                    ))
                }
            }
        }

        return fields
    }

    // MARK: - Submit
    func submit() async {
        guard workflowDetail != nil else {
            errorMessage = "请先拉取工作流"
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            // 图片字段先上传，拿到 fileName 替换 value
            var resolvedFields = formFields
            for i in resolvedFields.indices {
                if resolvedFields[i].type == .imageInput,
                   let img = resolvedFields[i].selectedImage {
                    let fileName = try await APIService.shared.uploadImage(img)
                    resolvedFields[i].value = fileName
                }
            }

            let nodeInputs = resolvedFields
                .filter { !$0.value.isBlank && $0.value != "pending_upload" && $0.fieldName != "password" }
                .map { NodeInput(nodeId: $0.nodeId, fieldName: $0.fieldName, fieldValue: $0.value) }

            let req = RunWorkflowRequest(
                workflowId: currentWorkflowId,
                mode: isPlusMode ? "plus" : nil,
                nodeInfoList: nodeInputs
            )

            let response = try await APIService.shared.runWorkflow(req)

            let duckPassword = formFields.first(where: { $0.fieldName == "password" })?.value

            let task = RHTask(
                id: response.taskId,
                workflowId: currentWorkflowId,
                workflowName: currentWorkflowId,
                isDuckEncoded: duckNodeInfo != nil,
                duckPassword: duckPassword?.isEmpty == false ? duckPassword : duckNodeInfo?.password,
                isTTEncoded: TTDecodeService.shared.detectTTNode(in: workflowDetail?.allNodes ?? []),
                isPlusMode: isPlusMode,
                workflowType: workflowType.displayName
            )

            appState.addTask(task)

            // Save to workflow history
            let historyItem = WorkflowHistoryItem(
                workflowId: currentWorkflowId,
                workflowType: workflowType.displayName
            )
            StorageService.shared.addWorkflowHistory(historyItem)
            workflowHistory = StorageService.shared.workflowHistory

            resetForm()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectHistory(_ item: WorkflowHistoryItem) {
        workflowInput = item.workflowId
        showAllHistory = false
        Task { await fetchWorkflow() }
    }

    func removeHistory(_ item: WorkflowHistoryItem) {
        StorageService.shared.removeWorkflowHistory(workflowId: item.workflowId)
        workflowHistory = StorageService.shared.workflowHistory
    }

    private func resetForm() {
        workflowInput = ""
        workflowDetail = nil
        workflowType = .unknown
        duckNodeInfo = nil
        formFields = []
        currentWorkflowId = ""
    }
}

// MARK: - Form Field
struct FormField: Identifiable {
    let id = UUID()
    let nodeId: String
    let fieldName: String
    let label: String
    let placeholder: String
    var value: String
    var selectedImage: UIImage?   // 仅 imageInput 使用
    let type: FieldType
    let promptRole: PromptRole?

    enum FieldType {
        case text, multilineText, password, imageInput
    }
}

// MARK: - Prompt Selection
struct PromptFieldSelection: Identifiable {
    let id = UUID()
    let nodeId: String
    let fieldName: String
    let label: String
    var role: PromptRole
}

enum PromptRole {
    case positive
    case negative
    case none
}
