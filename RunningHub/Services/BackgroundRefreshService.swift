import BackgroundTasks
import Foundation

// MARK: - Background Refresh Service
// SwiftUI .backgroundTask(.appRefresh) in RunningHubApp handles BGTaskScheduler
// registration internally. This service only needs to:
//   1. scheduleNext() — request the next wake-up via BGTaskScheduler.submit
//   2. runOnce()      — poll all unfinished tasks (called by the background task handler)

final class BackgroundRefreshService {

    static let shared = BackgroundRefreshService()
    private init() {}

    static let taskIdentifier = "com.runninghub.ios.refresh"

    // MARK: - Schedule next wake-up

    func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Core: poll all unfinished tasks once

    func runOnce() async {
        let unfinished = await MainActor.run {
            AppState.shared.tasks.filter { !$0.isFinished }
        }
        guard !unfinished.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for task in unfinished {
                group.addTask { await self.pollOnce(task: task) }
            }
        }

        scheduleNext()
    }

    // MARK: - Private: single task poll

    private func pollOnce(task: RHTask) async {
        do {
            let result = try await APIService.shared.pollTaskOutputs(taskId: task.id)
            guard result.status != task.status || !result.outputUrls.isEmpty else { return }

            var updated = task
            updated.status    = result.status
            updated.errorMsg  = result.errorMessage
            updated.updatedAt = Date()
            if !result.outputUrls.isEmpty { updated.outputUrls = result.outputUrls }

            await MainActor.run {
                AppState.shared.updateTask(updated)
                if updated.isFinished {
                    NotificationService.shared.notify(task: updated)
                    LiveActivityService.shared.end(task: updated)
                } else {
                    LiveActivityService.shared.update(task: updated)
                }
            }
        } catch {
            // Silently ignore — will retry on next background wake
        }
    }
}
