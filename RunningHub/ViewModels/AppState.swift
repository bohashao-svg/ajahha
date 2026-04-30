import Foundation
import Combine

// MARK: - App State (shared across views)
@MainActor
final class AppState: ObservableObject {

    static let shared = AppState()
    private init() {
        tasks = StorageService.shared.tasks
        setupPolling()
    }

    @Published var tasks: [RHTask] = []

    var activeTasks: [RHTask] { tasks.filter { !$0.isFinished } }
    var canSubmit: Bool { true }

    // MARK: - Task Management
    func addTask(_ task: RHTask) {
        tasks.insert(task, at: 0)
        StorageService.shared.upsertTask(task)
        TaskPollingService.shared.startPolling(task: task)
        LiveActivityService.shared.start(task: task)
    }

    func updateTask(_ task: RHTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
            // Notification is handled exclusively by TaskPollingService
            // to avoid double-firing. Do NOT call notify() here.
        } else {
            tasks.insert(task, at: 0)
        }
        StorageService.shared.upsertTask(task)
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
            Task { @MainActor [weak self] in
                self?.updateTask(updated)
            }
        }
        TaskPollingService.shared.resumePolling(for: tasks)
    }

    func tasks(for status: TaskStatus) -> [RHTask] {
        if status == .queued {
            return tasks.filter { $0.status == .queued || $0.status == .pending }
        }
        return tasks.filter { $0.status == status }
    }

    var pendingCount: Int {
        tasks.filter { $0.status == .queued || $0.status == .pending || $0.status == .running }.count
    }
}
