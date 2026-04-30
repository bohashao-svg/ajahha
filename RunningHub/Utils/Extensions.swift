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
// Two alternating spotlight beams sweeping across a dark plane.
// Uses Canvas + opacity-only animation — zero layout side-effects on ScrollView.
struct AnimatedMeshBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Color(hex: "#080C18")
            .ignoresSafeArea()
            .overlay(spotlights.ignoresSafeArea())
    }

    private var spotlights: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { tl in
            Canvas { ctx, size in
                let t = phase
                let w = size.width
                let h = size.height

                // ── Beam 1: blue, sweeps left→right ──────────────────────
                // Beam origin at top-left area, tip sweeps horizontally
                let b1x = w * (0.15 + 0.55 * (0.5 + 0.5 * sin(t * 0.7)))
                let b1y: CGFloat = 0
                drawBeam(ctx: ctx, size: size,
                         originX: b1x, originY: b1y,
                         spreadAngle: 0.38,
                         length: h * 1.1,
                         color: Color(hex: "#6C8EFF"),
                         opacity: 0.13 + 0.06 * sin(t * 1.1))

                // ── Beam 2: purple, sweeps right→left, offset phase ──────
                let b2x = w * (0.85 - 0.55 * (0.5 + 0.5 * sin(t * 0.55 + 2.1)))
                let b2y: CGFloat = 0
                drawBeam(ctx: ctx, size: size,
                         originX: b2x, originY: b2y,
                         spreadAngle: 0.32,
                         length: h * 1.05,
                         color: Color(hex: "#A78BFA"),
                         opacity: 0.10 + 0.05 * sin(t * 0.9 + 1.3))

                // ── Ambient floor glow ────────────────────────────────────
                let floorRect = CGRect(x: 0, y: h * 0.7, width: w, height: h * 0.3)
                ctx.opacity = 0.06
                ctx.fill(Path(ellipseIn: floorRect),
                         with: .linearGradient(
                            Gradient(colors: [Color(hex: "#6C8EFF").opacity(0.4), .clear]),
                            startPoint: CGPoint(x: w / 2, y: h * 0.7),
                            endPoint:   CGPoint(x: w / 2, y: h)
                         ))
            }
        }
        .drawingGroup()
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
        .allowsHitTesting(false)
    }

    private func drawBeam(ctx: GraphicsContext, size: CGSize,
                          originX: CGFloat, originY: CGFloat,
                          spreadAngle: CGFloat, length: CGFloat,
                          color: Color, opacity: CGFloat) {
        let halfSpread = spreadAngle / 2
        let tipX = originX
        let tipY = originY
        let leftX  = tipX - length * tan(halfSpread)
        let rightX = tipX + length * tan(halfSpread)
        let baseY  = tipY + length

        var beam = Path()
        beam.move(to: CGPoint(x: tipX, y: tipY))
        beam.addLine(to: CGPoint(x: leftX, y: baseY))
        beam.addLine(to: CGPoint(x: rightX, y: baseY))
        beam.closeSubpath()

        ctx.opacity = opacity
        ctx.fill(beam, with: .linearGradient(
            Gradient(stops: [
                .init(color: color.opacity(0.9), location: 0),
                .init(color: color.opacity(0.3), location: 0.5),
                .init(color: color.opacity(0),   location: 1)
            ]),
            startPoint: CGPoint(x: tipX, y: tipY),
            endPoint:   CGPoint(x: tipX, y: baseY)
        ))
    }
}
                            endPoint:   CGPoint(x: r.midX, y: r.maxY)
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

// MARK: - App Icon System
// Centralised SF Symbol names matching the app's AI/creative theme.
// No emoji anywhere — all icons are SF Symbols.
enum RHIconName: String {
    // Navigation & actions
    case settings       = "gearshape.fill"
    case close          = "xmark"
    case back           = "chevron.left"
    case forward        = "chevron.right"
    case refresh        = "arrow.clockwise"
    case add            = "plus"
    case submit         = "paperplane.fill"
    case search         = "magnifyingglass"
    case clear          = "xmark.circle.fill"
    case delete         = "trash.fill"
    case save           = "square.and.arrow.down.fill"
    case share          = "square.and.arrow.up"
    case copy           = "doc.on.doc"
    case edit           = "pencil"
    case filter         = "line.3.horizontal.decrease.circle"
    case sort           = "arrow.up.arrow.down"
    case expand         = "arrow.up.left.and.arrow.down.right"
    case collapse       = "arrow.down.right.and.arrow.up.left"
    case info           = "info.circle"
    case warning        = "exclamationmark.triangle.fill"
    case success        = "checkmark.circle.fill"
    case error          = "xmark.circle.fill"
    case lock           = "lock.fill"
    case unlock         = "lock.open.fill"
    case key            = "key.fill"
    case logout         = "rectangle.portrait.and.arrow.right"
    case clearHistory   = "clock.arrow.circlepath"

    // Content types
    case image          = "photo.fill"
    case video          = "video.fill"
    case audio          = "waveform"
    case document       = "doc.fill"
    case workflow       = "arrow.triangle.branch"
    case aiApp          = "cpu.fill"
    case lora           = "wand.and.stars"
    case prompt         = "text.bubble.fill"
    case node           = "slider.horizontal.3"
    case batch          = "square.stack.3d.up.fill"
    case history        = "clock.fill"
    case gallery        = "photo.stack.fill"

    // Status
    case running        = "bolt.fill"
    case queued         = "hourglass"
    case completed      = "checkmark.seal.fill"
    case failed         = "exclamationmark.circle.fill"
    case cancelled      = "minus.circle.fill"
    case pending        = "clock.badge.fill"

    // User & account
    case profile        = "person.crop.circle.fill"
    case premium        = "star.fill"
    case plus           = "crown.fill"

    // Features
    case grok           = "brain.head.profile"
    case gacha          = "square.stack.fill"
    case decode         = "lock.open.fill"
    case taskCenter     = "list.bullet.clipboard.fill"
    case notification   = "bell.fill"
    case sparkle        = "sparkles"
}

extension View {
    func rhIcon(_ name: RHIconName, size: CGFloat = 16, color: Color = .white) -> some View {
        Image(systemName: name.rawValue)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(color)
    }
}

// MARK: - Typewriter Text
struct TypewriterText: View {
    let fullText: String
    var font: Font = .system(size: 11)
    var color: Color = Color.white.opacity(0.25)
    var delay: Double = 0.5
    var charInterval: Double = 0.06

    @State private var displayed: String = ""
    @State private var charIndex: Int = 0

    var body: some View {
        Text(displayed)
            .font(font)
            .foregroundColor(color)
            .onAppear { startTyping() }
    }

    private func startTyping() {
        displayed = ""
        charIndex = 0
        typeNext()
    }

    private func typeNext() {
        guard charIndex < fullText.count else { return }
        let idx = fullText.index(fullText.startIndex, offsetBy: charIndex)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(charIndex) * charInterval) {
            displayed.append(fullText[idx])
            charIndex += 1
            typeNext()
        }
    }
}
