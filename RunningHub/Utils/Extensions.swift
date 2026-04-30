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

// MARK: - Color
extension Color {
    static let rhBackground   = Color(hex: "#0A0E1A")
    static let rhCard         = Color(hex: "#111827")
    static let rhPrimary      = Color(hex: "#F0F4FF")
    static let rhAccent       = Color(hex: "#6C8EFF")
    static let rhGold         = Color(hex: "#FFD166")
    static let rhSecondary    = Color(hex: "#8B9CC8")
    static let rhSuccess      = Color(hex: "#4ECDC4")
    static let rhError        = Color(hex: "#FF6B6B")
    static let rhWarning      = Color(hex: "#FFD166")
    static let rhBorder       = Color(hex: "#2A3550")
    static let rhAccentSoft   = Color(hex: "#1A2340")
    static let rhInk          = Color(hex: "#0A0E1A")
    static let rhPaper        = Color(hex: "#0A0E1A")
    static let rhRedMuted     = Color(hex: "#1F1520")
    static let rhGoldLight    = Color(hex: "#1A1608")
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

typealias SketchRoundedRect = LiquidGlassShape

// MARK: - Glass Background
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
                            .fill(LinearGradient(
                                colors: [
                                    Color.white.opacity(0.09 * intensity),
                                    Color.white.opacity(0.02 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
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
    func glassCard(radius: CGFloat = 18, intensity: Double = 1.0) -> some View {
        self.modifier(GlassBackground(radius: radius, intensity: intensity))
            .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 6)
    }
    func rhCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        self.padding(padding).glassCard(radius: cornerRadius)
    }
    func sketchCard(padding: CGFloat = 16) -> some View {
        self.padding(padding).glassCard(radius: 16)
    }
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Native Input Style
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

// MARK: - Button Style
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

typealias ScaleButtonStyle = LiquidButtonStyle

// MARK: - Glow
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

// MARK: - Animated Spotlight Background
// 两束交替扫描的探照灯，纯 Canvas 渲染，不影响 ScrollView 布局。
struct AnimatedMeshBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Color(hex: "#080C18")
            .ignoresSafeArea()
            .overlay(spotlights.ignoresSafeArea())
    }

    private var spotlights: some View {
        // 用 TimelineView 驱动动画，phase 通过 onAppear 的 withAnimation 更新
        Canvas { ctx, size in
            let t = phase
            let w = size.width
            let h = size.height

            // 光束1：蓝色，从左向右扫
            let b1x = w * (0.15 + 0.55 * (0.5 + 0.5 * sin(t * 0.7)))
            drawBeam(&ctx, tipX: b1x, tipY: 0,
                     spreadAngle: 0.38, length: h * 1.1,
                     color: Color(hex: "#6C8EFF"),
                     opacity: 0.13 + 0.06 * sin(t * 1.1))

            // 光束2：紫色，从右向左扫，相位偏移
            let b2x = w * (0.85 - 0.55 * (0.5 + 0.5 * sin(t * 0.55 + 2.1)))
            drawBeam(&ctx, tipX: b2x, tipY: 0,
                     spreadAngle: 0.32, length: h * 1.05,
                     color: Color(hex: "#A78BFA"),
                     opacity: 0.10 + 0.05 * sin(t * 0.9 + 1.3))

            // 地面环境光晕
            var floorCtx = ctx
            floorCtx.opacity = 0.06
            let floorRect = CGRect(x: 0, y: h * 0.7, width: w, height: h * 0.3)
            floorCtx.fill(
                Path(ellipseIn: floorRect),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: "#6C8EFF").opacity(0.4), .clear]),
                    startPoint: CGPoint(x: w / 2, y: h * 0.7),
                    endPoint:   CGPoint(x: w / 2, y: h)
                )
            )
        }
        .drawingGroup()
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = .pi * 2 * 8   // 8秒一圈，与 duration 匹配
            }
        }
        .allowsHitTesting(false)
    }

    // GraphicsContext 是值类型，用 inout 传递以便修改 opacity
    private func drawBeam(_ ctx: inout GraphicsContext,
                          tipX: CGFloat, tipY: CGFloat,
                          spreadAngle: CGFloat, length: CGFloat,
                          color: Color, opacity: CGFloat) {
        let half   = spreadAngle / 2
        let leftX  = tipX - length * tan(half)
        let rightX = tipX + length * tan(half)
        let baseY  = tipY + length

        var beam = Path()
        beam.move(to: CGPoint(x: tipX,   y: tipY))
        beam.addLine(to: CGPoint(x: leftX,  y: baseY))
        beam.addLine(to: CGPoint(x: rightX, y: baseY))
        beam.closeSubpath()

        var beamCtx = ctx
        beamCtx.opacity = opacity
        beamCtx.fill(beam, with: .linearGradient(
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
// 统一的 SF Symbol 映射，按功能分组，无重复原始值。
enum RHIconName: String {
    // 导航与操作
    case settings       = "gearshape.fill"
    case close          = "xmark"
    case back           = "chevron.left"
    case forward        = "chevron.right"
    case refresh        = "arrow.clockwise"
    case add            = "plus"
    case submit         = "paperplane.fill"
    case search         = "magnifyingglass"
    case clear          = "xmark.circle.fill"       // 清除输入框
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
    case errorIcon      = "xmark.octagon.fill"      // 错误状态（区别于 clear）
    case lock           = "lock.fill"
    case unlock         = "lock.open.fill"          // 解锁/解码入口
    case key            = "key.fill"
    case logout         = "rectangle.portrait.and.arrow.right"
    case clearHistory   = "clock.arrow.circlepath"

    // 内容类型
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

    // 任务状态
    case running        = "bolt.fill"
    case queued         = "hourglass"
    case completed      = "checkmark.seal.fill"
    case failed         = "exclamationmark.circle.fill"
    case cancelled      = "minus.circle.fill"
    case pending        = "clock.badge.fill"

    // 用户与账户
    case profile        = "person.crop.circle.fill"
    case premium        = "star.fill"
    case plus           = "crown.fill"

    // 功能入口
    case grok           = "brain.head.profile"
    case gacha          = "square.stack.fill"
    case decodeAction   = "eye.fill"                // 解码操作按钮（区别于 unlock）
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
