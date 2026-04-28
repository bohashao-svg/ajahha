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
                let duckFile = try await DuckDecodeService.shared.decode(imageUrl: url, password: password)
                var updated = task
                updated.decodedImageData = duckFile.data
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

    @Published var apiKeyInput: String = StorageService.shared.apiKey ?? ""
    @Published var isPlusDefault: Bool = StorageService.shared.isPlusDefault
    @Published var showSavedAlert: Bool = false
    @Published var showLogoutConfirm: Bool = false
    @Published var accountStatus: AccountStatusData?
    @Published var isLoadingAccount: Bool = false

    var isLoggedIn: Bool { StorageService.shared.isLoggedIn }

    var maskedAccessKey: String {
        guard let key = StorageService.shared.accessKey, key.count > 8 else { return "未登录" }
        return String(key.prefix(4)) + "****" + String(key.suffix(4))
    }

    func saveAPIKey() {
        StorageService.shared.apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        showSavedAlert = true
    }

    func logout() {
        StorageService.shared.accessKey = nil
        StorageService.shared.accessKeyExpire = 0
    }

    func savePlusDefault() {
        StorageService.shared.isPlusDefault = isPlusDefault
    }

    func clearHistory() {
        AppState.shared.clearAll()
    }

    func loadAccountStatus() async {
        isLoadingAccount = true
        accountStatus = try? await APIService.shared.fetchAccountStatus()
        isLoadingAccount = false
    }
}
