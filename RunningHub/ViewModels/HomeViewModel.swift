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
        // Use parsedNodes dict to get stable nodeId (the ComfyUI node key)
        let nodeDict = workflowDetail?.parsedNodes ?? [:]

        for (nodeId, node) in nodeDict {
            guard let classType = node.classType else { continue }
            let lower = classType.lowercased()

            // Skip duck node — password handled separately below
            if lower.contains("duck") { continue }

            // CR Text / CLIPTextEncode — editable text prompt
            if lower.contains("cr text") || lower.contains("cliptextencode") {
                if let inputs = node.inputs?.dictValue {
                    for key in ["text", "prompt"] {
                        if let val = inputs[key] {
                            let isNeg = lower.contains("negative")
                                || (val.stringValue?.count ?? 0 > 50
                                    && val.stringValue?.contains("低分辨率") == true)
                            fields.append(FormField(
                                nodeId: nodeId,
                                fieldName: key,
                                label: isNeg ? "负向提示词" : "提示词",
                                placeholder: "输入提示词...",
                                value: val.stringValue ?? "",
                                type: .multilineText
                            ))
                        }
                    }
                }
            }

            // LoadImage — image input
            if lower.contains("loadimage") {
                fields.append(FormField(
                    nodeId: nodeId,
                    fieldName: "image",
                    label: "输入图片",
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
            resetForm()

        } catch {
            errorMessage = error.localizedDescription
        }
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
