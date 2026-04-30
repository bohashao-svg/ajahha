import Foundation
import SwiftUI
import CryptoKit

// MARK: - String
extension String {
    var md5: String {
        let digest = Insecure.MD5.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    func extractWorkflowId() -> String? {
        if let url = URL(string: self) {
            if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" || $0.name == "workflowId" })?.value {
                return id
            }
            let last = url.lastPathComponent
            if !last.isEmpty && last != "/" { return last }
        }
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Date
extension Date {
    func relativeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }
}

// MARK: - Liquid Glass Color System
extension Color {
    // Core semantic colors — deep space palette
    static let rhBackground   = Color(hex: "#0A0E1A")   // deep space navy
    static let rhCard         = Color(hex: "#111827")   // glass card base
    static let rhPrimary      = Color(hex: "#F0F4FF")   // near-white text
    static let rhAccent       = Color(hex: "#6C8EFF")   // electric blue
    static let rhGold         = Color(hex: "#FFD166")   // warm gold
    static let rhSecondary    = Color(hex: "#8B9CC8")   // muted blue-grey
    static let rhSuccess      = Color(hex: "#4ECDC4")   // teal
    static let rhError        = Color(hex: "#FF6B6B")   // coral red
    static let rhWarning      = Color(hex: "#FFD166")   // gold
    static let rhBorder       = Color(hex: "#2A3550")   // subtle border
    static let rhAccentSoft   = Color(hex: "#1A2340")   // accent tint bg
    // Glass-specific
    static let rhInk          = Color(hex: "#0A0E1A")
    static let rhPaper        = Color(hex: "#0A0E1A")
    static let rhRedMuted     = Color(hex: "#1F1520")
    static let rhGoldLight    = Color(hex: "#1A1608")
    // Glass surface tints
    static let glassWhite     = Color.white.opacity(0.06)
    static let glassBorder    = Color.white.opacity(0.12)
    static let glassHighlight = Color.white.opacity(0.18)
    static let glassDeep      = Color(hex: "#0D1220").opacity(0.85)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - UIColor
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8)  & 0xFF) / 255
        let b = CGFloat(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Liquid Glass Shape
struct LiquidGlassShape: Shape {
    var radius: CGFloat
    var smoothness: CGFloat = 0.55

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        let k = r * smoothness
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                   control1: CGPoint(x: rect.maxX - r + k, y: rect.minY),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + r - k))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.maxY - r + k),
                   control2: CGPoint(x: rect.maxX - r + k, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                   control1: CGPoint(x: rect.minX + r - k, y: rect.maxY),
                   control2: CGPoint(x: rect.minX, y: rect.maxY - r + k))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                   control1: CGPoint(x: rect.minX, y: rect.minY + r - k),
                   control2: CGPoint(x: rect.minX + r - k, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// Legacy alias — keeps all existing call sites compiling
typealias SketchRoundedRect = LiquidGlassShape

// MARK: - Glass Background ViewModifier
struct GlassBackground: ViewModifier {
    var radius: CGFloat = 16
    var intensity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .background(
                LiquidGlassShape(radius: radius)
                    .fill(Color(hex: "#111827").opacity(0.72 * intensity))
                    .overlay(
                        LiquidGlassShape(radius: radius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.09 * intensity),
                                        Color.white.opacity(0.02 * intensity)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                LiquidGlassShape(radius: radius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22 * intensity),
                                Color.white.opacity(0.05 * intensity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - View Extensions
extension View {
    /// Primary liquid glass card — single shadow only to avoid offscreen render
    func glassCard(radius: CGFloat = 18, intensity: Double = 1.0) -> some View {
        self.modifier(GlassBackground(radius: radius, intensity: intensity))
            .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 6)
    }

    /// Legacy card style — now renders as glass
    func rhCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .glassCard(radius: cornerRadius)
    }

    /// Sketch card — now renders as glass
    func sketchCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .glassCard(radius: 16)
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Native Input Field Style
// Plain system appearance — no glass background on text inputs per design requirement.
struct NativeInputStyle: ViewModifier {
    var focused: Bool = false
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        focused ? Color(hex: "#6C8EFF").opacity(0.7) : Color(UIColor.separator).opacity(0.5),
                        lineWidth: focused ? 1.5 : 0.8
                    )
            )
    }
}

extension View {
    func nativeInput(focused: Bool = false) -> some View {
        modifier(NativeInputStyle(focused: focused))
    }
}
struct LiquidButtonStyle: ButtonStyle {
    var color: Color = .rhAccent
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Legacy alias
typealias ScaleButtonStyle = LiquidButtonStyle

// MARK: - Glow Modifier
struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius / 2, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 12) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Animated Mesh Background
// Single static background — no per-frame layout changes, no blur on animated layers.
// Blur is applied once at snapshot time via drawingGroup(); animation only drives opacity.
struct AnimatedMeshBackground: View {
    @State private var phase: Bool = false

    var body: some View {
        // Fixed dark base — never changes size or position
        Color(hex: "#0A0E1A")
            .ignoresSafeArea()
            .overlay(orbs.ignoresSafeArea())
    }

    private var orbs: some View {
        // All orbs are pre-blurred static shapes; only opacity animates.
        // opacity animation does NOT affect layout, so ScrollView stays still.
        Canvas { ctx, size in
            // Orb 1 — blue, top-left
            ctx.opacity = phase ? 0.22 : 0.14
            ctx.drawLayer { inner in
                let r = CGRect(x: size.width * 0.05, y: size.height * 0.02,
                               width: size.width * 0.65, height: size.height * 0.45)
                inner.fill(Path(ellipseIn: r),
                           with: .linearGradient(
                            Gradient(colors: [Color(hex: "#6C8EFF").opacity(0.55), .clear]),
                            startPoint: CGPoint(x: r.midX, y: r.minY),
                            endPoint:   CGPoint(x: r.midX, y: r.maxY)
                           ))
            }
            // Orb 2 — purple, bottom-right
            ctx.opacity = phase ? 0.18 : 0.10
            ctx.drawLayer { inner in
                let r = CGRect(x: size.width * 0.45, y: size.height * 0.5,
                               width: size.width * 0.6, height: size.height * 0.45)
                inner.fill(Path(ellipseIn: r),
                           with: .linearGradient(
                            Gradient(colors: [Color(hex: "#A78BFA").opacity(0.5), .clear]),
                            startPoint: CGPoint(x: r.midX, y: r.minY),
                            endPoint:   CGPoint(x: r.midX, y: r.maxY)
                           ))
            }
            // Orb 3 — teal, center
            ctx.opacity = phase ? 0.14 : 0.08
            ctx.drawLayer { inner in
                let r = CGRect(x: size.width * 0.25, y: size.height * 0.25,
                               width: size.width * 0.5, height: size.height * 0.35)
                inner.fill(Path(ellipseIn: r),
                           with: .linearGradient(
                            Gradient(colors: [Color(hex: "#4ECDC4").opacity(0.4), .clear]),
                            startPoint: CGPoint(x: r.midX, y: r.minY),
                            endPoint:   CGPoint(x: r.midX, y: r.maxY)
                           ))
            }
        }
        // drawingGroup() rasterises to a single Metal texture — zero per-frame CPU layout
        .drawingGroup()
        .blur(radius: 60)   // single blur pass on the already-rasterised texture
        .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: phase)
        .onAppear { phase = true }
        .allowsHitTesting(false)
    }
}

// MARK: - Task Status Color
extension TaskStatus {
    var color: Color {
        switch self {
        case .queued:    return Color(hex: "#FFD166")
        case .pending:   return Color(hex: "#FFD166")
        case .running:   return Color(hex: "#6C8EFF")
        case .completed: return Color(hex: "#4ECDC4")
        case .failed:    return Color(hex: "#FF6B6B")
        case .cancelled: return Color(hex: "#8B9CC8")
        }
    }

    var uiColor: UIColor {
        switch self {
        case .queued, .pending: return UIColor(hex: "#FFD166")
        case .running:          return UIColor(hex: "#6C8EFF")
        case .completed:        return UIColor(hex: "#4ECDC4")
        case .failed:           return UIColor(hex: "#FF6B6B")
        case .cancelled:        return UIColor(hex: "#8B9CC8")
        }
    }
}
