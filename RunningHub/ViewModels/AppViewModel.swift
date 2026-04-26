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
    @Published var isPolling: Bool = false
    @Published var errorMessage: String?
    @Published var taskId: String?
    @Published var outputUrls: [String] = []
    @Published var taskFailed: Bool = false
    @Published var failedReason: String?
    @Published var selectedImages: [String: UIImage] = [:]  // nodeId+fieldName → UIImage

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
        outputUrls = []
        taskId = nil
        taskFailed = false
        failedReason = nil
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
        taskFailed = false
        failedReason = nil
        outputUrls = []
        defer { isSubmitting = false }

        do {
            // Upload image nodes first
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
            taskId = result.taskId
            isPolling = true
            await pollOutputs(taskId: result.taskId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Poll Outputs
    private func pollOutputs(taskId: String) async {
        let timeout: TimeInterval = 600
        let start = Date()
        while true {
            do {
                let resp = try await APIService.shared.queryAppOutputs(taskId: taskId)
                let code = resp.code
                if code == 0, let items = resp.data, !items.isEmpty {
                    outputUrls = items.compactMap { $0.fileUrl }
                    isPolling = false
                    return
                } else if code == 805 {
                    taskFailed = true
                    failedReason = resp.msg
                    isPolling = false
                    return
                }
                // 804 = running, 813 = queued — keep polling
            } catch {
                // transient error, keep trying
            }
            if Date().timeIntervalSince(start) > timeout {
                errorMessage = "等待超时（超过10分钟）"
                isPolling = false
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    // MARK: - Reset
    func reset() {
        webappInput = ""
        currentWebappId = ""
        nodes = []
        outputUrls = []
        taskId = nil
        taskFailed = false
        failedReason = nil
        errorMessage = nil
        selectedImages = [:]
    }
}

// MARK: - String extension for webappId extraction
extension String {
    func extractWebappId() -> String {
        // Handle full URL: https://www.runninghub.cn/ai-detail/1234567890
        if let url = URL(string: self),
           let host = url.host, host.contains("runninghub"),
           let last = url.pathComponents.last, !last.isEmpty {
            return last
        }
        // Plain numeric ID
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.allSatisfy({ $0.isNumber }) { return trimmed }
        return trimmed
    }
}
