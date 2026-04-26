import Foundation
import Combine

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
        currentWorkflowId = workflowId
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let detail = try await APIService.shared.fetchWorkflowDetail(workflowId: workflowId)
            workflowDetail = detail
            analyzeWorkflow(detail)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func analyzeWorkflow(_ detail: WorkflowDetailResponse) {
        let nodes = detail.allNodes
        workflowType = WorkflowType.detect(from: nodes)
        duckNodeInfo = DuckDecodeService.shared.detectDuckNode(in: nodes)
        formFields = buildFormFields(from: nodes)
    }

    private func buildFormFields(from nodes: [WorkflowNodeRaw]) -> [FormField] {
        var fields: [FormField] = []
        let nodeDict = workflowDetail?.parsedNodes ?? [:]

        // Show ALL nodes that have any inputs — no filtering by class type
        // Only exclude duck steganography nodes (they have no user-editable inputs)
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
                    type: .imageInput
                ))
            } else if inputs.keys.contains("text") {
                // Always show text field even if value is a wired reference (array)
                let defaultText = inputs["text"]?.stringValue ?? ""
                fields.append(FormField(
                    nodeId: nodeId,
                    fieldName: "text",
                    label: title,
                    placeholder: "输入提示词...",
                    value: defaultText,
                    type: .multilineText
                ))
            } else if inputs.keys.contains("prompt") {
                let defaultText = inputs["prompt"]?.stringValue ?? ""
                fields.append(FormField(
                    nodeId: nodeId,
                    fieldName: "prompt",
                    label: title,
                    placeholder: "输入提示词...",
                    value: defaultText,
                    type: .multilineText
                ))
            }
            // Nodes with no text/prompt/image inputs are skipped
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
            // prompt = the raw workflow JSON string returned by API
            let nodeInputs = formFields
                .filter { !$0.value.isBlank && $0.fieldName != "password" }
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
        Task { await fetchWorkflow() }
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
    let type: FieldType

    enum FieldType {
        case text, multilineText, password, imageInput
    }
}
