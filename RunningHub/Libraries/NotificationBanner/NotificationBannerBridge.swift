import UIKit
import SwiftUI

// MARK: - NotificationBanner Bridge
// Mirrors NotificationBanner / FloatingNotificationBanner API.
// Implemented natively with UIKit + liquid glass styling — no SnapKit/MarqueeLabel required.

public enum BannerStyle {
    case success, info, warning, danger, customView
}

// MARK: - Liquid Glass Banner View (UIKit)

public final class LiquidNotificationBanner: UIView {

    public var title: String? { didSet { titleLabel.text = title } }
    public var subtitle: String? { didSet { subtitleLabel.text = subtitle; subtitleLabel.isHidden = subtitle == nil } }
    public var style: BannerStyle = .info { didSet { applyStyle() } }
    public var duration: TimeInterval = 2.8
    public var onTap: (() -> Void)?

    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()
    private let iconView      = UIImageView()
    private let blurView      = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private var dismissTimer: Timer?

    public init(title: String, subtitle: String? = nil, style: BannerStyle = .info) {
        super.init(frame: .zero)
        self.title    = title
        self.subtitle = subtitle
        self.style    = style
        setupViews()
        applyStyle()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        layer.cornerRadius = 18
        layer.cornerCurve  = .continuous
        clipsToBounds = true

        // Blur base
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)

        // Glass overlay
        let glassOverlay = UIView()
        glassOverlay.backgroundColor = UIColor(white: 1, alpha: 0.07)
        glassOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glassOverlay)

        // Border
        let borderLayer = CALayer()
        borderLayer.borderColor = UIColor(white: 1, alpha: 0.15).cgColor
        borderLayer.borderWidth  = 1
        borderLayer.cornerRadius = 18
        borderLayer.cornerCurve  = .continuous
        layer.addSublayer(borderLayer)
        DispatchQueue.main.async { borderLayer.frame = self.bounds }

        // Icon
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor   = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        // Title
        titleLabel.font          = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor     = UIColor(hex: "#F0F4FF")
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Subtitle
        subtitleLabel.font          = .systemFont(ofSize: 12)
        subtitleLabel.textColor     = UIColor(hex: "#8B9CC8")
        subtitleLabel.numberOfLines = 2
        subtitleLabel.isHidden      = subtitle == nil
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            glassOverlay.topAnchor.constraint(equalTo: topAnchor),
            glassOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])

        titleLabel.text    = title
        subtitleLabel.text = subtitle

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func applyStyle() {
        let (iconName, accentColor): (String, UIColor) = {
            switch style {
            case .success: return ("checkmark.circle.fill", UIColor(hex: "#4ECDC4"))
            case .warning: return ("exclamationmark.triangle.fill", UIColor(hex: "#FFD166"))
            case .danger:  return ("xmark.circle.fill", UIColor(hex: "#FF6B6B"))
            case .info:    return ("info.circle.fill", UIColor(hex: "#6C8EFF"))
            case .customView: return ("sparkles", UIColor(hex: "#A78BFA"))
            }
        }()
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = accentColor
        // Subtle accent tint on background
        backgroundColor = accentColor.withAlphaComponent(0.08)
    }

    @objc private func handleTap() {
        onTap?()
        dismiss()
    }

    // MARK: - Show / Dismiss

    public func show(on viewController: UIViewController? = nil,
                     queuePosition: BannerPosition = .top) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }

        translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(self)

        let safeTop = window.safeAreaInsets.top
        let margin: CGFloat = 12

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 16),
            trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -16),
            topAnchor.constraint(equalTo: window.topAnchor, constant: safeTop + margin),
        ])

        // Slide in
        transform = CGAffineTransform(translationX: 0, y: -(safeTop + 100))
        alpha = 0
        UIView.animate(withDuration: 0.42, delay: 0,
                       usingSpringWithDamping: 0.72, initialSpringVelocity: 0.5,
                       options: .curveEaseOut) {
            self.transform = .identity
            self.alpha = 1
        }

        // Shadow
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius  = 16
        layer.shadowOffset  = CGSize(width: 0, height: 6)

        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    public func dismiss() {
        dismissTimer?.invalidate()
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseIn) {
            self.transform = CGAffineTransform(translationX: 0, y: -120)
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}

public enum BannerPosition { case top, bottom }

// MARK: - SwiftUI Banner Modifier

struct BannerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let subtitle: String?
    let style: BannerStyle
    let duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { show in
                if show {
                    let banner = LiquidNotificationBanner(title: title, subtitle: subtitle, style: style)
                    banner.duration = duration
                    banner.show()
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
                        isPresented = false
                    }
                }
            }
    }
}

extension View {
    func liquidBanner(
        isPresented: Binding<Bool>,
        title: String,
        subtitle: String? = nil,
        style: BannerStyle = .info,
        duration: TimeInterval = 2.8
    ) -> some View {
        modifier(BannerModifier(isPresented: isPresented, title: title,
                                subtitle: subtitle, style: style, duration: duration))
    }
}
