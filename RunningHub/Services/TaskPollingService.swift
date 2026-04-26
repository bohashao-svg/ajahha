import Foundation

// MARK: - Task Polling Service
final class TaskPollingService {

    static let shared = TaskPollingService()
    private init() {}

    private var pollingTasks: [String: Task<Void, Never>] = [:]

    var onTaskUpdated: ((RHTask) -> Void)?

    func startPolling(task: RHTask) {
        guard pollingTasks[task.id] == nil else { return }
        let taskId = task.id
        let pollingTask = Task<Void, Never> { [weak self] in
            guard let self = self else { return }
            await self.pollLoop(taskId: taskId, originalTask: task)
        }
        pollingTasks[taskId] = pollingTask
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
    // Per docs: PENDING → poll every 5s, RUNNING → poll every 2s
    private func pollLoop(taskId: String, originalTask: RHTask) async {
        var localTask = originalTask

        while !Task.isCancelled && !localTask.isFinished {
            let interval: TimeInterval = localTask.status == .running ? 2.0 : 5.0
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }

                let item = try await APIService.shared.fetchTaskStatus(taskId: taskId)
                localTask = applyUpdate(item, to: localTask)
                await MainActor.run { self.onTaskUpdated?(localTask) }

                // Auto-decode duck image on completion
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
                        // Decode failed — user can retry manually
                    }
                }

            } catch {
                // Network error — wait then retry
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }

        pollingTasks.removeValue(forKey: taskId)
    }

    private func applyUpdate(_ item: TaskStatusItem, to task: RHTask) -> RHTask {
        var updated = task
        updated.status = TaskStatus(rawValue: item.status) ?? task.status
        // progress is already 0-1 per docs
        if let p = item.progress { updated.progress = p }
        let urls = item.allOutputUrls
        if !urls.isEmpty { updated.outputUrls = urls }
        updated.errorMsg = item.errorMsg
        updated.updatedAt = Date()
        return updated
    }
}
