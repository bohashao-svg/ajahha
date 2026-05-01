import ActivityKit
import Foundation

// MARK: - Live Activity Attributes
// Shared between the main app target and the Widget Extension target.

struct TaskActivityAttributes: ActivityAttributes {

    let taskId: String

    struct ContentState: Codable, Hashable {
        var taskName: String
        var statusText: String
        /// -1 = indeterminate (running, no progress data from API)
        ///  0 = not started / queued
        /// 1–100 = known percentage
        var progressPercent: Int
        var isFinished: Bool
        var isSuccess: Bool
    }
}
