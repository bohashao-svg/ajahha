import Foundation

// MARK: - Task Polling Service
// Uses POST /openapi/v2/query to poll task status and results
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
            // RUNNING: poll every 3s; QUEUED: poll every 5s
            let interval: TimeInterval = localTask.status == .running ? 3.0 : 5.0
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }

                let response = try await APIService.shared.queryTask(taskId: taskId)

                localTask.status = response.taskStatus
                localTask.errorMsg = response.errorMessage
                localTask.updatedAt = Date()

                if !response.outputUrls.isEmpty {
                    localTask.outputUrls = response.outputUrls
                }

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
                    } catch {}
                }

            } catch {
                // Network error — wait then retry
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }

        pollingTasks.removeValue(forKey: taskId)
    }
}
