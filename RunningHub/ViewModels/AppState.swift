import Foundation
import Combine

// MARK: - App State (shared across views)
final class AppState: ObservableObject {

    static let shared = AppState()
    private init() {
        tasks = StorageService.shared.tasks
        setupPolling()
    }

    @Published var tasks: [RHTask] = []
    @Published var quota: UserQuota?
    @Published var isQuotaLoading = false

    var activeTasks: [RHTask] { tasks.filter { !$0.isFinished } }
    var activeCount: Int { activeTasks.count }

    // MARK: - Quota
    func refreshQuota() {
        guard !isQuotaLoading else { return }
        isQuotaLoading = true
        Task { @MainActor in
            defer { isQuotaLoading = false }
            do {
                quota = try await APIService.shared.fetchQuota()
            } catch {}
        }
    }

    var canSubmit: Bool {
        guard let q = quota else { return false }
        return q.hasAvailableSlot
    }

    // MARK: - Task Management
    func addTask(_ task: RHTask) {
        tasks.insert(task, at: 0)
        StorageService.shared.upsertTask(task)
        TaskPollingService.shared.startPolling(task: task)
        refreshQuota()
    }

    func updateTask(_ task: RHTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        }
        StorageService.shared.upsertTask(task)
        if task.isFinished { refreshQuota() }
    }

    func removeTask(id: String) {
        TaskPollingService.shared.stopPolling(taskId: id)
        tasks.removeAll { $0.id == id }
        StorageService.shared.deleteTask(id: id)
    }

    func clearAll() {
        TaskPollingService.shared.stopAll()
        tasks = []
        StorageService.shared.clearAllTasks()
    }

    // MARK: - Polling Setup
    private func setupPolling() {
        TaskPollingService.shared.onTaskUpdated = { [weak self] updated in
            self?.updateTask(updated)
        }
        TaskPollingService.shared.resumePolling(for: tasks)
    }

    // MARK: - Task counts by status
    func tasks(for status: TaskStatus) -> [RHTask] {
        tasks.filter { $0.status == status }
    }

    var pendingCount: Int {
        tasks.filter { $0.status == .queued || $0.status == .running }.count
    }
}
