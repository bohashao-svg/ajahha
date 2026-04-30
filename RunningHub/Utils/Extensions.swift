import Foundation
import SwiftUI
import CryptoKit

// MARK: - String
extension String {
    var md5: String {
        let digest = Insecure.MD5.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    // Extract workflow ID from a URL or plain ID string
    func extractWorkflowId() -> String? {
        // If it looks like a URL, try to extract the id param or last path component
        if let url = URL(string: self) {
            if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" || $0.name == "workflowId" })?.value {
                return id
            }
            let last = url.lastPathComponent
            if !last.isEmpty && last != "/" { return last }
        }
        // Otherwise treat the whole string as an ID (trimmed)
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
    static let rhBackground   = Color(hex: "#F5EDE4")
    static let rhCard         = Color(hex: "#FFFCF9")
    static let rhPrimary      = Color(hex: "#2D1A0E")
    static let rhAccent       = Color(hex: "#C8392B")
    static let rhGold         = Color(hex: "#C9920A")
    static let rhSecondary    = Color(hex: "#8C7B6E")
    static let rhSuccess      = Color(hex: "#4A8F5F")
    static let rhError        = Color(hex: "#C0392B")
    static let rhWarning      = Color(hex: "#C9920A")
    static let rhBorder       = Color(hex: "#E8D5C4")
    static let rhAccentSoft   = Color(hex: "#F7E4E2")
    // Hand-drawn palette
    static let rhInk          = Color(hex: "#2C1810")   // deep ink for borders/shadows
    static let rhPaper        = Color(hex: "#F5EDE4")   // same as background
    static let rhRedMuted     = Color(hex: "#F2D5D3")   // light red tint
    static let rhGoldLight    = Color(hex: "#FDF3DC")   // light gold tint

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

// MARK: - View
extension View {
    /// Legacy card style (kept for compatibility)
    func rhCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.rhCard)
            .clipShape(SketchRoundedRect(radius: cornerRadius))
            .overlay(SketchRoundedRect(radius: cornerRadius).stroke(Color.rhInk.opacity(0.18), lineWidth: 1.5))
            .shadow(color: Color.rhInk.opacity(0.12), radius: 0, x: 2, y: 3)
    }

    /// Hand-drawn card style
    func sketchCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.rhCard)
            .clipShape(SketchRoundedRect(radius: 14))
            .overlay(SketchRoundedRect(radius: 14).stroke(Color.rhInk.opacity(0.22), lineWidth: 1.8))
            .shadow(color: Color.rhInk.opacity(0.15), radius: 0, x: 2, y: 3)
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Sketch Rounded Rect (slightly irregular corners for hand-drawn feel)
struct SketchRoundedRect: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        // Slightly vary each corner radius for organic feel
        let tl = radius * 0.7
        let tr = radius * 1.1
        let br = radius * 0.85
        let bl = radius * 1.0
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Task Status Color
extension TaskStatus {
    var color: Color {
        switch self {
        case .queued:    return Color(hex: "#C9920A")
        case .pending:   return Color(hex: "#C9920A")
        case .running:   return Color(hex: "#C8392B")
        case .completed: return Color(hex: "#4A8F5F")
        case .failed:    return Color(hex: "#C0392B")
        case .cancelled: return Color(hex: "#8C7B6E")
        }
    }

    var uiColor: UIColor {
        switch self {
        case .queued, .pending: return UIColor(hex: "#C9920A")
        case .running:          return UIColor(hex: "#C8392B")
        case .completed:        return UIColor(hex: "#4A8F5F")
        case .failed:           return UIColor(hex: "#C0392B")
        case .cancelled:        return UIColor(hex: "#8C7B6E")
        }
    }
}
