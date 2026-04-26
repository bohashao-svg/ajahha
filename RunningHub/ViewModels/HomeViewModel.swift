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

    private func isNegativeNode(_ node: WorkflowNodeRaw) -> Bool {
        let classLower = node.classType?.lowercased() ?? ""
        let titleLower = node.meta?.title?.lowercased() ?? ""
        // Use word-boundary-like checks to avoid false positives (e.g. "positive" contains "pos")
        let negPatterns = ["negative", "负向", "反向", "neg prompt", "neg_prompt"]
        return negPatterns.contains(where: { classLower.contains($0) || titleLower.contains($0) })
    }

    private func buildFormFields(from nodes: [WorkflowNodeRaw]) -> [FormField] {
        var fields: [FormField] = []
        let nodeDict = workflowDetail?.parsedNodes ?? [:]

        // Collect all text-type nodes that are not negative
        let textClassTypes = ["cliptextencode", "cr text", "text multiline", "string", "note"]
        let textNodes = nodeDict
            .filter { (_, node) in
                guard let ct = node.classType?.lowercased() else { return false }
                return textClassTypes.contains(where: { ct.contains($0) }) && !isNegativeNode(node)
            }
            // Sort by node ID numerically so lower-numbered (earlier) nodes come first
            .sorted { a, b in
                let ai = Int(a.key) ?? Int.max
                let bi = Int(b.key) ?? Int.max
                return ai < bi
            }

        // Prefer node whose title explicitly says positive/正向
        let positivePatterns = ["positive", "正向", "提示词", "prompt"]
        let chosen = textNodes.first(where: { (_, node) in
            let title = node.meta?.title?.lowercased() ?? ""
            return positivePatterns.contains(where: { title.contains($0) })
        }) ?? textNodes.first  // fallback: lowest-ID non-negative text node

        if let (nodeId, node) = chosen {
            let inputs = node.inputs?.dictValue ?? [:]
            let defaultText = inputs["text"]?.stringValue ?? inputs["prompt"]?.stringValue ?? ""
            let fieldName = (inputs["text"] != nil) ? "text" : "prompt"
            fields.append(FormField(
                nodeId: nodeId,
                fieldName: fieldName,
                label: "提示词",
                placeholder: "输入提示词...",
                value: defaultText,
                type: .multilineText
            ))
        }

        // Image input nodes — sorted by node ID
        let imageNodes = nodeDict
            .filter { (_, node) in node.classType?.lowercased().contains("loadimage") == true }
            .sorted { a, b in (Int(a.key) ?? Int.max) < (Int(b.key) ?? Int.max) }

        for (nodeId, node) in imageNodes {
            fields.append(FormField(
                nodeId: nodeId,
                fieldName: "image",
                label: node.meta?.title ?? "输入图片",
                placeholder: "图片 URL",
                value: "",
                type: .imageInput
            ))
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
