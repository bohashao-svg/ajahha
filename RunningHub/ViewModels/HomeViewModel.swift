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
        let nodes = detail.workflow?.allNodes ?? []

        // Detect type
        workflowType = WorkflowType.detect(from: nodes)

        // Detect duck node
        duckNodeInfo = DuckDecodeService.shared.detectDuckNode(in: nodes)

        // Build form fields from editable nodes
        formFields = buildFormFields(from: nodes, workflowType: workflowType)
    }

    private func buildFormFields(from nodes: [WorkflowNodeRaw], workflowType: WorkflowType) -> [FormField] {
        var fields: [FormField] = []

        for (index, node) in nodes.enumerated() {
            guard let classType = node.classType else { continue }
            let lower = classType.lowercased()

            // Skip duck encode node — handled separately
            if lower.contains("duck_encode") { continue }

            // Text prompt nodes
            if lower.contains("cliptextencode") || lower.contains("text") {
                if let inputs = node.inputs?.dictValue {
                    for (key, val) in inputs {
                        if key == "text" || key == "prompt" {
                            fields.append(FormField(
                                nodeId: String(index),
                                fieldName: key,
                                label: lower.contains("negative") ? "负向提示词" : "提示词",
                                placeholder: "输入提示词...",
                                value: val.stringValue ?? "",
                                type: .multilineText
                            ))
                        }
                    }
                }
            }

            // Image input nodes
            if lower.contains("loadimage") || lower.contains("image_input") {
                fields.append(FormField(
                    nodeId: String(index),
                    fieldName: "image",
                    label: "输入图片",
                    placeholder: "图片 URL 或 Base64",
                    value: "",
                    type: .imageInput
                ))
            }
        }

        // Duck node password field (if present)
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
        guard let detail = workflowDetail else {
            errorMessage = "请先拉取工作流"
            return
        }
        let workflowId = detail.workflowId

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            // Serialize workflow JSON as prompt string (required by API)
            var promptString: String? = nil
            if let workflow = workflowDetail?.workflow,
               let data = try? JSONEncoder().encode(workflow),
               let str = String(data: data, encoding: .utf8) {
                promptString = str
            }

            // Build node inputs from form fields (only user-filled, non-empty)
            let nodeInputs = formFields
                .filter { !$0.value.isBlank && $0.fieldName != "password" }
                .map { NodeInput(nodeId: $0.nodeId, fieldName: $0.fieldName, fieldValue: $0.value) }

            let req = RunWorkflowRequest(
                workflowId: workflowId,
                mode: isPlusMode ? "plus" : nil,
                prompt: promptString,
                nodeInfoList: nodeInputs
            )

            let response = try await APIService.shared.runWorkflow(req)

            // Get duck password from form
            let duckPassword = formFields.first(where: { $0.fieldName == "password" })?.value

            let task = RHTask(
                id: response.taskId,
                workflowId: workflowId,
                workflowName: detail.name ?? workflowId,
                isDuckEncoded: duckNodeInfo != nil,
                duckPassword: duckPassword?.isEmpty == false ? duckPassword : duckNodeInfo?.password,
                isPlusMode: isPlusMode,
                workflowType: workflowType.displayName
            )

            appState.addTask(task)

            // Reset form for next submission
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
