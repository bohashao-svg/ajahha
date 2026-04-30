import Foundation

// MARK: - Task Polling Service
// Uses POST /openapi/v2/query — wrapped in APIResponse<TaskQueryResponse>
// taskStatus field: QUEUED / RUNNING / SUCCESS / FAILED / CANCELLED
final class TaskPollingService {

    static let shared = TaskPollingService()
    private init() {}

    private var pollingTasks: [String: Task<Void, Never>] = [:]

    var onTaskUpdated: ((RHTask) -> Void)?

    func startPolling(task: RHTask) {
        guard pollingTasks[task.id] == nil else { return }
        let taskId = task.id
        let t = Task<Void, Never> { [weak self] in
            await self?.pollLoop(taskId: taskId, originalTask: task)
        }
        pollingTasks[taskId] = t
    }

    func stopPolling(taskId: String) {
        pollingTasks[taskId]?.cancel()
        pollingTasks.removeValue(forKey: taskId)
    }

    func stopAll() {
        pollingTasks.values.forEach { $0.cancel() }
        pollingTasks.removeAll()
    }

    func resumePolling(for tasks: [RHTask]) {
        tasks.filter { !$0.isFinished }.forEach { startPolling(task: $0) }
    }

    // MARK: - Poll Loop
    private func pollLoop(taskId: String, originalTask: RHTask) async {
        var localTask = originalTask

        while !Task.isCancelled && !localTask.isFinished {
            let interval: TimeInterval = localTask.status == .running ? 3.0 : 5.0
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }

                let result = try await APIService.shared.pollTaskOutputs(taskId: taskId)

                localTask.status = result.status
                localTask.errorMsg = result.errorMessage
                localTask.updatedAt = Date()
                if !result.outputUrls.isEmpty { localTask.outputUrls = result.outputUrls }

                let snapshot = localTask
                await MainActor.run { self.onTaskUpdated?(snapshot) }

            } catch {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }

        pollingTasks.removeValue(forKey: taskId)
    }
}
