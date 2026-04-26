import Foundation
import UIKit

// MARK: - App (WebApp) ViewModel
// 提交逻辑与 HomeViewModel 完全一致：
// 提交成功 → 创建 RHTask → 加入 AppState → TaskPollingService 轮询 → 关闭界面
@MainActor
final class AppViewModel: ObservableObject {

    @Published var webappInput: String = ""
    @Published var currentWebappId: String = ""
    @Published var nodes: [AppNodeInfo] = []
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var didSubmitSuccessfully: Bool = false

    private let appState: AppState

    init(appState: AppState = .shared) {
        self.appState = appState
    }

    // MARK: - Fetch Nodes
    func fetchNodes() async {
        let wid = webappInput.extractWebappId()
        guard !wid.isEmpty else {
            errorMessage = "请输入有效的 AI 应用 ID 或链接"
            return
        }
        currentWebappId = wid
        isLoading = true
        errorMessage = nil
        nodes = []
        defer { isLoading = false }
        do {
            nodes = try await APIService.shared.fetchAppNodes(webappId: wid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Submit Task
    // 与 HomeViewModel.submit() 逻辑一致：上传图片 → 提交 → 创建 RHTask → AppState.addTask → 关闭
    func submit() async {
        guard !nodes.isEmpty else {
            errorMessage = "请先获取节点信息"
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            // 图片节点先上传，拿到 fileName 替换 fieldValue
            var resolvedNodes = nodes
            for i in resolvedNodes.indices {
                let key = resolvedNodes[i].nodeId + resolvedNodes[i].fieldName
                let ft = resolvedNodes[i].fieldType.uppercased()
                if (ft == "IMAGE" || ft == "AUDIO" || ft == "VIDEO"),
                   let img = selectedImages[key] {
                    let fileName = try await APIService.shared.uploadImage(img)
                    resolvedNodes[i].fieldValue = fileName
                }
            }

            let result = try await APIService.shared.runApp(
                webappId: currentWebappId,
                nodeInfoList: resolvedNodes
            )

            // 创建任务，加入 AppState，由 TaskPollingService 统一轮询
            let task = RHTask(
                id: result.taskId,
                workflowId: currentWebappId,
                workflowName: "AI应用",
                isDuckEncoded: false,
                duckPassword: nil,
                isTTEncoded: false,
                isPlusMode: false,
                workflowType: "AI应用"
            )
            appState.addTask(task)

            // 重置表单，通知 View 关闭
            reset()
            didSubmitSuccessfully = true

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reset
    func reset() {
        webappInput = ""
        currentWebappId = ""
        nodes = []
        errorMessage = nil
        selectedImages = [:]
        didSubmitSuccessfully = false
    }
}

// MARK: - String extension for webappId extraction
extension String {
    func extractWebappId() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        // Handle full URL: https://www.runninghub.cn/ai-detail/1234567890
        if let url = URL(string: trimmed),
           let host = url.host, host.contains("runninghub"),
           let last = url.pathComponents.last, !last.isEmpty, last != "/" {
            return last
        }
        return trimmed
    }
}
