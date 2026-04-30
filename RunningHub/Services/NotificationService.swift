import UIKit
import UserNotifications

// MARK: - In-App Notification Banner (pure UIKit, no external deps)

final class RHBannerView: UIView {

    // MARK: - UI
    private let iconView   = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel  = UILabel()
    private let pill       = UIView()

    // MARK: - State
    private var dismissTimer: Timer?
    private var panStart: CGFloat = 0
    private var topConstraint: NSLayoutConstraint!

    // MARK: - Init
    init(title: String, body: String, isSuccess: Bool) {
        super.init(frame: .zero)
        setupAppearance(isSuccess: isSuccess)
        titleLabel.text = title
        bodyLabel.text  = body
        let sfName = isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
        iconView.image = UIImage(systemName: sfName)
        iconView.tintColor = isSuccess ? UIColor(named: "rhSuccess") ?? .systemGreen
                                       : UIColor(named: "rhError")  ?? .systemRed
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout
    private func setupAppearance(isSuccess: Bool) {
        backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 0.12, alpha: 0.97)
                : UIColor(white: 0.98, alpha: 0.97)
        }
        layer.cornerRadius  = 18
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius  = 12
        layer.shadowOffset  = CGSize(width: 0, height: 4)
        clipsToBounds       = false

        // Pill indicator
        pill.backgroundColor = isSuccess
            ? (UIColor(named: "rhSuccess") ?? .systemGreen)
            : (UIColor(named: "rhError")   ?? .systemRed)
        pill.layer.cornerRadius = 2
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)

        // Icon
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Title
        titleLabel.font          = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor     = UIColor { tc in
            tc.userInterfaceStyle == .dark ? .white : UIColor(white: 0.1, alpha: 1)
        }
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Body
        bodyLabel.font          = .systemFont(ofSize: 12, weight: .regular)
        bodyLabel.textColor     = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(white: 0.7, alpha: 1)
                : UIColor(white: 0.45, alpha: 1)
        }
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.widthAnchor.constraint(equalToConstant: 4),
            pill.heightAnchor.constraint(equalToConstant: 36),

            iconView.leadingAnchor.constraint(equalTo: pill.trailingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),

            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            bodyLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    // MARK: - Show / Dismiss
    func show(in window: UIWindow, duration: TimeInterval = 4.0) {
        translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(self)

        let safeTop = window.safeAreaInsets.top
        let topOffset = safeTop + 12

        topConstraint = topAnchor.constraint(equalTo: window.topAnchor, constant: -120)
        NSLayoutConstraint.activate([
            topConstraint,
            leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 16),
            trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -16),
        ])
        window.layoutIfNeeded()

        // Slide in
        topConstraint.constant = topOffset
        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            window.layoutIfNeeded()
        }

        // Haptic
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Auto-dismiss
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let window = superview as? UIWindow ?? window else {
            removeFromSuperview(); return
        }
        topConstraint.constant = -120
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            options: .curveEaseIn
        ) {
            window.layoutIfNeeded()
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    // MARK: - Gestures
    @objc private func handleTap() { dismiss() }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let ty = gr.translation(in: superview).y
        switch gr.state {
        case .began:
            dismissTimer?.invalidate()
            panStart = topConstraint.constant
        case .changed:
            topConstraint.constant = min(panStart + ty, panStart)
            superview?.layoutIfNeeded()
        case .ended, .cancelled:
            let vy = gr.velocity(in: superview).y
            if ty < -30 || vy < -400 {
                dismiss()
            } else {
                topConstraint.constant = panStart
                UIView.animate(withDuration: 0.3) { self.superview?.layoutIfNeeded() }
                dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    self?.dismiss()
                }
            }
        default: break
        }
    }
}

// MARK: - Notification Service

final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // Queue so banners don't overlap
    private var queue: [RHBannerView] = []
    private var isShowing = false

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Notify (called when task status changes to completed/failed)

    func notify(task: RHTask) {
        let isSuccess = task.status == .completed
        let title = isSuccess ? "任务完成 ✓" : "任务失败"
        let name  = task.workflowName.isEmpty ? task.workflowType : task.workflowName
        let body  = isSuccess
            ? "\(name) 已生成完毕，点击查看结果"
            : "\(name) 执行失败：\(task.errorMsg ?? "未知错误")"

        // In-app banner (must be on main thread)
        DispatchQueue.main.async { [weak self] in
            self?.showBanner(title: title, body: body, isSuccess: isSuccess)
        }

        // System push (fires even when app is backgrounded)
        scheduleSystemNotification(title: title, body: body, taskId: task.id, isSuccess: isSuccess)
    }

    // MARK: - In-App Banner

    private func showBanner(title: String, body: String, isSuccess: Bool) {
        guard let window = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }

        let banner = RHBannerView(title: title, body: body, isSuccess: isSuccess)
        queue.append(banner)
        if !isShowing { showNext(in: window) }
    }

    private func showNext(in window: UIWindow) {
        guard !queue.isEmpty else { isShowing = false; return }
        isShowing = true
        let banner = queue.removeFirst()
        banner.show(in: window, duration: 4.5)

        // Chain next banner after current one finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.showNext(in: window)
        }
    }

    // MARK: - System Push Notification

    private func scheduleSystemNotification(title: String, body: String, taskId: String, isSuccess: Bool) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body  = body
            content.sound = isSuccess ? .default : UNNotificationSound(named: UNNotificationSoundName("error.caf"))
            content.userInfo = ["taskId": taskId]

            // Fire immediately (trigger = nil fires right away)
            let request = UNNotificationRequest(
                identifier: "task_\(taskId)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }
}
