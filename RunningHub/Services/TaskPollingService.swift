import Foundation

// MARK: - Task Polling Service
// Flow: poll /task/openapi/outputs every 5s
//   queued  → keep polling
//   running → keep polling (outputs returns dict with netWssUrl)
//   completed → outputs returns [TaskOutputFile], extract URLs, stop
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
            // Poll interval: 3s running, 5s queued
            let interval: TimeInterval = localTask.status == .running ? 3.0 : 5.0
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }

                let result = try await APIService.shared.fetchOutputs(taskId: taskId)

                switch result {
                case .queued:
                    localTask.status = .queued
                    localTask.updatedAt = Date()
                    await MainActor.run { self.onTaskUpdated?(localTask) }

                case .running(_, _):
                    localTask.status = .running
                    localTask.updatedAt = Date()
                    await MainActor.run { self.onTaskUpdated?(localTask) }

                case .completed(let files):
                    localTask.status = .completed
                    localTask.outputUrls = files.map { $0.fileUrl }
                    localTask.updatedAt = Date()
                    await MainActor.run { self.onTaskUpdated?(localTask) }

                    // Auto-decode duck image
                    if localTask.isDuckEncoded,
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
                }

            } catch {
                // Network error — wait then retry
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }

        pollingTasks.removeValue(forKey: taskId)
    }
}
