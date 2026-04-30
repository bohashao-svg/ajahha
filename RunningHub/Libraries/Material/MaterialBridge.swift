import UIKit
import SwiftUI

// MARK: - Material Pulse Animation Bridge
// Mirrors the PulseAnimation enum and Pulse struct from Material library.
// Implemented natively with CALayer — no external dependency required.

public enum PulseAnimation: Int {
    case none
    case center
    case centerWithBacking
    case centerRadialBeyondBounds
    case radialBeyondBounds
    case backing
    case point
    case pointWithBacking
}

public struct Pulse {
    public static func animate(layer: CALayer,
                               point: CGPoint,
                               width: CGFloat,
                               color: UIColor? = nil,
                               opacity: Float = 0.28,
                               duration: TimeInterval = 0.55) {
        let resolvedColor = color ?? UIColor(red: 0.42, green: 0.56, blue: 1.0, alpha: 1) // #6C8EFF
        let pulseLayer = CAShapeLayer()
        let path = UIBezierPath(ovalIn: CGRect(x: -width / 2, y: -width / 2, width: width, height: width))
        pulseLayer.path = path.cgPath
        pulseLayer.fillColor = resolvedColor.withAlphaComponent(CGFloat(opacity)).cgColor
        pulseLayer.position = point
        pulseLayer.opacity = 0
        layer.addSublayer(pulseLayer)

        CATransaction.begin()
        CATransaction.setCompletionBlock { pulseLayer.removeFromSuperlayer() }

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.1
        scaleAnim.toValue = 1.0
        scaleAnim.duration = duration
        scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values = [opacity, opacity * 0.8, 0]
        opacityAnim.keyTimes = [0, 0.5, 1]
        opacityAnim.duration = duration

        let group = CAAnimationGroup()
        group.animations = [scaleAnim, opacityAnim]
        group.duration = duration
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        pulseLayer.add(group, forKey: "pulse")
        CATransaction.commit()
    }
}

// MARK: - Material Spring Animation Bridge
// Mirrors SpringAnimation from Material library.

public enum SpringDirection: Int {
    case up, down, left, right
}

public class SpringAnimation {
    public var springDirection: SpringDirection = .up
    public var isOpened: Bool = false

    public func animate(view: UIView,
                        open: Bool,
                        distance: CGFloat = 60,
                        duration: TimeInterval = 0.38,
                        completion: (() -> Void)? = nil) {
        isOpened = open
        let translation: CGAffineTransform
        if open {
            switch springDirection {
            case .up:    translation = CGAffineTransform(translationX: 0, y: -distance)
            case .down:  translation = CGAffineTransform(translationX: 0, y: distance)
            case .left:  translation = CGAffineTransform(translationX: -distance, y: 0)
            case .right: translation = CGAffineTransform(translationX: distance, y: 0)
            }
        } else {
            translation = .identity
        }
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut],
            animations: { view.transform = translation },
            completion: { _ in completion?() }
        )
    }
}

// MARK: - SwiftUI Pulse Button Modifier
// Apply Material-style pulse ripple to any SwiftUI button tap

struct PulseButtonStyle: ButtonStyle {
    var pulseColor: Color = Color(hex: "#6C8EFF")

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
            .overlay(
                GeometryReader { geo in
                    if configuration.isPressed {
                        Circle()
                            .fill(pulseColor.opacity(0.18))
                            .frame(width: geo.size.width * 1.6, height: geo.size.width * 1.6)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                            .transition(.opacity.combined(with: .scale(scale: 0.3)))
                    }
                }
                .allowsHitTesting(false)
                .clipped()
            )
    }
}

// MARK: - UIView Pulse Extension
extension UIView {
    func addPulse(at point: CGPoint? = nil,
                  color: UIColor? = nil,
                  opacity: Float = 0.25) {
        let resolvedColor = color ?? UIColor(red: 0.42, green: 0.56, blue: 1.0, alpha: 1)
        let center = point ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let width = max(bounds.width, bounds.height) * 1.4
        Pulse.animate(layer: layer, point: center, width: width, color: resolvedColor, opacity: opacity)
    }
}

// MARK: - Material FAB Button (Floating Action Button)
// Liquid glass variant of Material's FABButton

struct MaterialFABButton: View {
    let icon: String
    var color: Color = Color(hex: "#6C8EFF")
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.45), radius: 14, x: 0, y: 6)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PulseButtonStyle(pulseColor: color))
    }
}
