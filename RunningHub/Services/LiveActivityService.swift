import ActivityKit
import Foundation

// MARK: - Live Activity Service
// Manages a single Live Activity at a time (most-recent-wins policy).
// Requires iOS 16.2+; silently no-ops on older versions.

@MainActor
final class LiveActivityService {

    static let shared = LiveActivityService()
    private init() {}

    // The one active activity we track (only the latest task)
    private var currentActivity: Activity<TaskActivityAttributes>?

    // MARK: - Start

    func start(task: RHTask) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any existing activity immediately (no-animation dismiss)
        endCurrentActivity(animated: false)

        let state = contentState(for: task)
        let attributes = TaskActivityAttributes(taskId: task.id)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            // Live Activities not available or limit reached — fail silently
        }
    }

    // MARK: - Update

    func update(task: RHTask) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity,
              activity.attributes.taskId == task.id else { return }

        let state = contentState(for: task)
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    // MARK: - End

    func end(task: RHTask) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity,
              activity.attributes.taskId == task.id else { return }

        let finalState = contentState(for: task)
        Task {
            // Keep the final state visible for 5 seconds, then dismiss
            await activity.end(
                .init(state: finalState, staleDate: Date().addingTimeInterval(5)),
                dismissalPolicy: .after(Date().addingTimeInterval(5))
            )
            currentActivity = nil
        }
    }

    // MARK: - Private helpers

    private func endCurrentActivity(animated: Bool) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }

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
        return TaskActivityAttributes.ContentState(
            taskName: name,
            statusText: statusText,
            progressPercent: Int((task.progress * 100).rounded()),
            isFinished: task.isFinished,
            isSuccess: task.status == .completed
        )
    }
}
