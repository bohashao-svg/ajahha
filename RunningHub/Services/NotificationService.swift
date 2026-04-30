import UIKit
import UserNotifications

// MARK: - Notification Service
// Sends ONLY system (UNUserNotificationCenter) notifications — the kind that
// appear in the iOS notification centre and lock screen, exactly like WeChat.
// In-app banners have been removed; the system notification fires even when
// the app is in the foreground (UNUserNotificationCenterDelegate handles that).

final class NotificationService: NSObject {

    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    // MARK: - Notify

    func notify(task: RHTask) {
        let name = task.workflowName.isEmpty ? task.workflowType : task.workflowName

        let title: String
        let body: String
        let sound: UNNotificationSound

        switch task.status {
        case .queued:
            title = "任务排队中"
            body  = "「\(name)」已加入队列，等待执行"
            sound = .default
        case .running:
            title = "任务生成中"
            body  = "「\(name)」正在生成，请稍候..."
            sound = .default
        case .completed:
            title = "任务完成 ✓"
            body  = "「\(name)」已生成完毕，点击查看结果"
            sound = .defaultCritical
        case .failed:
            title = "任务失败"
            body  = "「\(name)」执行失败：\(task.errorMsg ?? "未知错误")"
            sound = .defaultCritical
        case .cancelled:
            title = "任务已取消"
            body  = "「\(name)」已被取消"
            sound = .default
        case .pending:
            return
        }

        scheduleNotification(
            title: title,
            body: body,
            sound: sound,
            taskId: task.id,
            status: task.status.rawStringValue
        )
    }

    // MARK: - Schedule

    private func scheduleNotification(title: String, body: String,
                                      sound: UNNotificationSound,
                                      taskId: String, status: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body  = body
            content.sound = sound
            content.userInfo = ["taskId": taskId, "status": status]
            let identifier = "rh_\(taskId)_\(status)"
            // pendingCount 是 @MainActor 属性，在后台线程用 Task 安全读取
            Task { @MainActor in
                content.badge = NSNumber(value: AppState.shared.pendingCount)
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: nil
                )
                UNUserNotificationCenter.current().add(request) { _ in }
            }
        }
    }

    // MARK: - Clear badge

    func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
// Shows system notification banner even when app is in foreground.
extension NotificationService: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + sound + badge even when app is active (foreground)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // User tapped notification — post internal event so app can navigate
        let userInfo = response.notification.request.content.userInfo
        if let taskId = userInfo["taskId"] as? String {
            NotificationCenter.default.post(
                name: .rhNotificationTapped,
                object: nil,
                userInfo: ["taskId": taskId]
            )
        }
        clearBadge()
        completionHandler()
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let rhNotificationTapped = Notification.Name("rhNotificationTapped")
}

// MARK: - TaskStatus raw string helper
extension TaskStatus {
    var rawStringValue: String {
        switch self {
        case .queued:    return "queued"
        case .pending:   return "pending"
        case .running:   return "running"
        case .completed: return "completed"
        case .failed:    return "failed"
        case .cancelled: return "cancelled"
        }
    }
}

// MARK: - RHBanner (kept for API compatibility — now a no-op wrapper)
// All actual notifications go through UNUserNotificationCenter above.
enum RHBanner {
    static func show(title: String, subtitle: String? = nil, style: BannerStyle = .info) {
        let body = subtitle ?? ""
        let isSuccess = style == .success || style == .info
        NotificationService.shared.notify(task: {
            // Build a minimal synthetic task just to reuse the notify path
            var t = RHTask(id: UUID().uuidString, workflowId: "",
                           workflowName: title, isDuckEncoded: false,
                           duckPassword: nil, isTTEncoded: false,
                           isPlusMode: false, workflowType: body)
            t.status = isSuccess ? .completed : .failed
            return t
        }())
    }
    static func success(_ title: String, subtitle: String? = nil) { show(title: title, subtitle: subtitle, style: .success) }
    static func error(_ title: String, subtitle: String? = nil)   { show(title: title, subtitle: subtitle, style: .danger) }
    static func warning(_ title: String, subtitle: String? = nil) { show(title: title, subtitle: subtitle, style: .warning) }
    static func info(_ title: String, subtitle: String? = nil)    { show(title: title, subtitle: subtitle, style: .info) }
}
