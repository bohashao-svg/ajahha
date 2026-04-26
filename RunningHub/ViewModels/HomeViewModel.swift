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

        // Collect positive prompt fields (one per workflow, skip negative/style variants)
        var addedPositivePrompt = false

        for (nodeId, node) in nodeDict {
            guard let classType = node.classType else { continue }
            let lower = classType.lowercased()

            if lower.contains("duck") { continue }

            // Only positive CLIPTextEncode / CR Text — skip negative variants
            if lower.contains("cliptextencode") || lower.contains("cr text") {
                guard !addedPositivePrompt else { continue }
                if let inputs = node.inputs?.dictValue {
                    for key in ["text", "prompt"] {
                        if let val = inputs[key], val.stringValue != nil {
                            let metaTitle = node.meta?.title?.lowercased() ?? ""
                            let isNeg = lower.contains("negative")
                                || metaTitle.contains("negative")
                                || metaTitle.contains("负向")
                                || metaTitle.contains("neg")
                            if isNeg { continue }
                            fields.append(FormField(
                                nodeId: nodeId,
                                fieldName: key,
                                label: "提示词",
                                placeholder: "输入提示词...",
                                value: val.stringValue ?? "",
                                type: .multilineText
                            ))
                            addedPositivePrompt = true
                            break
                        }
                    }
                }
            }

            // LoadImage — image input (keep all, user may need multiple)
            if lower.contains("loadimage") {
                let metaTitle = node.meta?.title ?? "输入图片"
                fields.append(FormField(
                    nodeId: nodeId,
                    fieldName: "image",
                    label: metaTitle,
                    placeholder: "图片 URL",
                    value: "",
                    type: .imageInput
                ))
            }
        }

        // Duck password field
        if let duck = duckNodeInfo {
            fields.append(FormField(
                nodeId: duck.nodeId,
                fieldName: "password",
                label: "鸭鸭图解码密码",
                placeholder: "输入解码密码",
                value: duck.password ?? "",
                type: .password
            ))
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
            let promptString = workflowDetail?.prompt

            let nodeInputs = formFields
                .filter { !$0.value.isBlank && $0.fieldName != "password" }
                .map { NodeInput(nodeId: $0.nodeId, fieldName: $0.fieldName, fieldValue: $0.value) }

            let req = RunWorkflowRequest(
                workflowId: currentWorkflowId,
                mode: isPlusMode ? "plus" : nil,
                prompt: promptString,
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
