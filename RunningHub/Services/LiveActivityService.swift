import ActivityKit
import Foundation

// MARK: - Live Activity Service
// Manages a single Live Activity at a time (most-recent-wins policy).
// Requires iOS 16.2+; silently no-ops on older versions.

@MainActor
final class LiveActivityService {

    static let shared = LiveActivityService()
    private init() {}

    private var currentActivity: Activity<TaskActivityAttributes>?

    // MARK: - Start

    func start(task: RHTask) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Synchronously clear the old reference BEFORE requesting a new activity.
        // Never delegate this to an async Task — any `await` between clearing and
        // assigning would let the async closure overwrite the NEW reference with nil.
        let old = currentActivity
        currentActivity = nil
        if let old {
            Task { [old] in await old.end(nil, dismissalPolicy: .immediate) }
        }

        let attributes = TaskActivityAttributes(taskId: task.id)
        let state = contentState(for: task)
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Live Activities disabled, device unsupported, or limit reached
        }
    }

    // MARK: - Update

    func update(task: RHTask) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity,
              activity.attributes.taskId == task.id else { return }

        let state = contentState(for: task)
        Task { [activity] in
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    // MARK: - End

    func end(task: RHTask) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity,
              activity.attributes.taskId == task.id else { return }

        // Clear synchronously so a concurrent start() won't be overwritten
        currentActivity = nil
        let finalState = contentState(for: task)
        Task { [activity] in
            await activity.end(
                .init(state: finalState, staleDate: Date().addingTimeInterval(8)),
                dismissalPolicy: .after(Date().addingTimeInterval(8))
            )
        }
    }

    // MARK: - Content State

    private func contentState(for task: RHTask) -> TaskActivityAttributes.ContentState {
        let name = task.workflowName.isEmpty ? task.workflowType : task.workflowName
        let statusText: String
        switch task.status {
        case .queued, .pending: statusText = "排队中，等待执行…"
        case .running:          statusText = "生成中，请稍候…"
        case .completed:        statusText = "已完成，点击查看结果"
        case .failed:           statusText = "执行失败：\(task.errorMsg ?? "未知错误")"
        case .cancelled:        statusText = "已取消"
        }
        // API doesn't return progress — use -1 as sentinel for "indeterminate"
        let progress = task.progress > 0
            ? Int((task.progress * 100).rounded())
            : (task.status == .running ? -1 : 0)
        return TaskActivityAttributes.ContentState(
            taskName: name,
            statusText: statusText,
            progressPercent: progress,
            isFinished: task.isFinished,
            isSuccess: task.status == .completed
        )
    }
}
