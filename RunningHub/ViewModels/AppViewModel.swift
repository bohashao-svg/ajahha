import Foundation
import UIKit

// MARK: - App (WebApp) ViewModel
@MainActor
final class AppViewModel: ObservableObject {

    @Published var webappInput: String = ""
    @Published var currentWebappId: String = ""
    @Published var nodes: [AppNodeInfo] = []
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var didSubmitSuccessfully: Bool = false
    @Published var selectedImages: [String: UIImage] = [:]  // nodeId+fieldName → UIImage
    @Published var selectedVideos: [String: URL] = [:]      // nodeId+fieldName → video file URL

    private let appState: AppState

    init(appState: AppState = .shared) {
        self.appState = appState
        NotificationCenter.default.addObserver(
            forName: .loraDidSelect, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  (note.userInfo?["source"] as? String) == "app",
                  let tw = note.userInfo?["triggerWords"] as? String,
                  !tw.isEmpty else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                for i in self.nodes.indices {
                    let ft = self.nodes[i].fieldType.uppercased()
                    if ft == "STRING" || ft == "TEXT" {
                        let current = self.nodes[i].fieldValue
                        self.nodes[i].fieldValue = current.isEmpty ? tw : "\(tw), \(current)"
                        break
                    }
                }
            }
        }
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
    func submit() async {
        guard !nodes.isEmpty else {
            errorMessage = "请先获取节点信息"
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            var resolvedNodes = nodes
            for i in resolvedNodes.indices {
                let key = resolvedNodes[i].nodeId + resolvedNodes[i].fieldName
                let ft = resolvedNodes[i].fieldType.uppercased()
                if ft == "IMAGE" || ft == "AUDIO",
                   let img = selectedImages[key] {
                    let fileName = try await APIService.shared.uploadImage(img)
                    resolvedNodes[i].fieldValue = fileName
                } else if ft == "VIDEO",
                          let videoURL = selectedVideos[key] {
                    let fileName = try await APIService.shared.uploadVideo(videoURL)
                    resolvedNodes[i].fieldValue = fileName
                }
            }

            let result = try await APIService.shared.runApp(
                webappId: currentWebappId,
                nodeInfoList: resolvedNodes
            )

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

            // 写入历史记录
            let historyItem = WorkflowHistoryItem(
                workflowId: currentWebappId,
                workflowType: "AI应用",
                itemType: .aiApp
            )
            StorageService.shared.addWorkflowHistory(historyItem)
            NotificationCenter.default.post(name: .workflowHistoryDidChange, object: nil)

            reset()
            didSubmitSuccessfully = true
            // 内嵌模式：提交成功后直接重置（无需 dismiss）
            didSubmitSuccessfully = false

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
        // 不重置 didSubmitSuccessfully，由 View 的 onChange 消费后自行处理
    }
}

// MARK: - String extension for webappId extraction
extension String {
    func extractWebappId() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed),
           let host = url.host, host.contains("runninghub"),
           let last = url.pathComponents.last, !last.isEmpty, last != "/" {
            return last
        }
        return trimmed
    }
}
