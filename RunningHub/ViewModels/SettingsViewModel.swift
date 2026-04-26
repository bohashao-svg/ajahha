import Foundation

// MARK: - Task Center ViewModel
@MainActor
final class TaskCenterViewModel: ObservableObject {

    @Published var selectedTab: TaskStatus = .running
    private let appState: AppState

    init(appState: AppState = .shared) {
        self.appState = appState
    }

    func tasks(for status: TaskStatus) -> [RHTask] {
        appState.tasks(for: status)
    }

    func cancelTask(_ task: RHTask) {
        // 先停止轮询，防止轮询结果覆盖取消状态
        TaskPollingService.shared.stopPolling(taskId: task.id)
        // 立即本地标记已取消，UI 即时响应
        var optimistic = task
        optimistic.status = .cancelled
        optimistic.updatedAt = Date()
        appState.updateTask(optimistic)
        // 异步通知服务端
        Task { try? await APIService.shared.cancelTask(taskId: task.id) }
    }

    func retryDecode(task: RHTask, password: String) {
        guard let url = task.primaryOutputUrl else { return }
        Task {
            do {
                let data = try await DuckDecodeService.shared.decode(imageUrl: url, password: password)
                var updated = task
                updated.decodedImageData = data
                appState.updateTask(updated)
            } catch {}
        }
    }

    func removeTask(_ task: RHTask) {
        appState.removeTask(id: task.id)
    }
}

// MARK: - Settings ViewModel
@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var apiKeyInput: String = ""
    @Published var isPlusDefault: Bool = StorageService.shared.isPlusDefault
    @Published var showSavedAlert = false

    var maskedApiKey: String {
        let key = StorageService.shared.apiKey ?? ""
        guard key.count > 8 else { return key.isEmpty ? "未配置" : "****" }
        return String(key.prefix(4)) + "****" + String(key.suffix(4))
    }

    func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        StorageService.shared.apiKey = trimmed
        apiKeyInput = ""
        showSavedAlert = true
    }

    func savePlusDefault() {
        StorageService.shared.isPlusDefault = isPlusDefault
    }

    func clearHistory() {
        AppState.shared.clearAll()
    }
}
