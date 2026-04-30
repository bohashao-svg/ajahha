import ActivityKit
import Foundation

// MARK: - Live Activity Attributes
// Shared between the main app target and the Widget Extension target.
// Static data (set once at start) + dynamic ContentState (updated during polling).

struct TaskActivityAttributes: ActivityAttributes {

    // Static: never changes after the activity starts
    let taskId: String

    // Dynamic: updated as the task progresses
    struct ContentState: Codable, Hashable {
        var taskName: String
        var statusText: String
        var progressPercent: Int   // 0–100
        var isFinished: Bool
        var isSuccess: Bool        // true = completed, false = failed/cancelled
    }
}
