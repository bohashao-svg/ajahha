import Foundation

// MARK: - Task Polling Service
// Uses POST /task/openapi/outputs to poll task status and results
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
    // Uses POST /task/openapi/outputs — code 0=success, 804=running, 813=queued, 805=failed
    private func pollLoop(taskId: String, originalTask: RHTask) async {
        var localTask = originalTask

        while !Task.isCancelled && !localTask.isFinished {
            let interval: TimeInterval = localTask.status == .running ? 3.0 : 5.0
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }

                let response = try await APIService.shared.queryAppOutputs(taskId: taskId)

                switch response.code {
                case 0:
                    // Success — data contains output items
                    localTask.status = .completed
                    let urls = response.data?.compactMap { $0.fileUrl } ?? []
                    if !urls.isEmpty { localTask.outputUrls = urls }
                case 804:
                    localTask.status = .running
                case 813:
                    localTask.status = .queued
                case 805:
                    localTask.status = .failed
                    localTask.errorMsg = response.msg
                default:
                    // Unknown code — keep current status, retry
                    break
                }
                localTask.updatedAt = Date()

                let snapshot = localTask
                await MainActor.run { self.onTaskUpdated?(snapshot) }

            } catch {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }

        pollingTasks.removeValue(forKey: taskId)
    }
}
