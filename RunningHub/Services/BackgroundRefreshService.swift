import BackgroundTasks
import Foundation

// MARK: - Background Refresh Service
// Two entry points for background polling:
//   1. SwiftUI .backgroundTask(.appRefresh) — preferred on iOS 16+
//   2. BGTaskScheduler legacy handler — fallback
//
// iOS controls actual wake-up frequency (typically ≥15 min based on usage).
// This is the standard pattern used by Mail, Weather, etc.

final class BackgroundRefreshService {

    static let shared = BackgroundRefreshService()
    private init() {}

    static let taskIdentifier = "com.runninghub.ios.refresh"

    // MARK: - Register (call before app finishes launching)

    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            refreshTask.expirationHandler = { refreshTask.setTaskCompleted(success: false) }
            Task {
                await self.runOnce()
                refreshTask.setTaskCompleted(success: true)
            }
        }
    }

    // MARK: - Schedule next wake-up (call on foreground appear + every background entry)

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

        // Reschedule for the next cycle
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
                // Only notify on terminal state changes (avoid spammy "running" pings)
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
