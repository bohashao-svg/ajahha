import Foundation
import Combine

// MARK: - Task Polling Service
final class TaskPollingService {

    static let shared = TaskPollingService()
    private init() {}

    private var pollingTasks: [String: Task<Void, Never>] = [:]
    private let pollInterval: TimeInterval = 3.0

    // Callback when a task status changes
    var onTaskUpdated: ((RHTask) -> Void)?

    // Start polling for a task
    func startPolling(task: RHTask) {
        guard pollingTasks[task.id] == nil else { return }

        let taskId = task.id
        let pollingTask = Task<Void, Never> { [weak self] in
            guard let self = self else { return }
            await self.pollLoop(taskId: taskId, originalTask: task)
        }
        pollingTasks[taskId] = pollingTask
    }

    // Stop polling for a specific task
    func stopPolling(taskId: String) {
        pollingTasks[taskId]?.cancel()
        pollingTasks.removeValue(forKey: taskId)
    }

    // Stop all polling
    func stopAll() {
        pollingTasks.values.forEach { $0.cancel() }
        pollingTasks.removeAll()
    }

    // Resume polling for all unfinished tasks on app launch
    func resumePolling(for tasks: [RHTask]) {
        tasks.filter { !$0.isFinished }.forEach { startPolling(task: $0) }
    }

    // MARK: - Poll Loop
    private func pollLoop(taskId: String, originalTask: RHTask) async {
        var localTask = originalTask

        while !Task.isCancelled && !localTask.isFinished {
            do {
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }

                let items = try await APIService.shared.fetchTaskBatch(taskIds: [taskId])
                guard let item = items.first(where: { $0.taskId == taskId }) else { continue }

                localTask = applyUpdate(item, to: localTask)
                await MainActor.run { self.onTaskUpdated?(localTask) }

                // If completed and duck-encoded, auto-decode
                if localTask.status == .completed,
                   localTask.isDuckEncoded,
                   let url = localTask.primaryOutputUrl,
                   let password = localTask.duckPassword,
                   localTask.decodedImageData == nil {
                    do {
                        let decoded = try await DuckDecodeService.shared.decode(
                            imageUrl: url, password: password
                        )
                        localTask.decodedImageData = decoded
                        await MainActor.run { self.onTaskUpdated?(localTask) }
                    } catch {
                        // Decode failed — keep duck image, user can retry manually
                    }
                }

            } catch {
                // Network error — retry after interval
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }

        pollingTasks.removeValue(forKey: taskId)
    }

    private func applyUpdate(_ item: TaskStatusItem, to task: RHTask) -> RHTask {
        var updated = task
        updated.status = TaskStatus(rawValue: item.status) ?? task.status
        updated.progress = (item.progress ?? 0) / 100.0
        updated.outputUrls = item.outputs?.compactMap { $0.resolvedUrl } ?? task.outputUrls
        updated.errorMsg = item.errorMsg
        updated.updatedAt = Date()
        return updated
    }
}
