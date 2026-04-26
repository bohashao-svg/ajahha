import Foundation
import SwiftUI

// MARK: - String
extension String {
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
    // 奶白底色
    static let rhBackground   = Color(hex: "#FDF6F0")
    // 卡片：暖白带微红
    static let rhCard         = Color(hex: "#FFFAF7")
    // 主文字：深暖棕
    static let rhPrimary      = Color(hex: "#2D1A0E")
    // 主题色：柔雾红
    static let rhAccent       = Color(hex: "#C8392B")
    // 暖金
    static let rhGold         = Color(hex: "#D4A017")
    // 次要文字：暖灰
    static let rhSecondary    = Color(hex: "#8C7B6E")
    // 成功：柔绿
    static let rhSuccess      = Color(hex: "#5A9E6F")
    // 错误：柔红
    static let rhError        = Color(hex: "#C0392B")
    // 警告：暖金
    static let rhWarning      = Color(hex: "#D4A017")
    // 边框：浅暖米
    static let rhBorder       = Color(hex: "#EDE0D4")
    // 浅红背景色（用于按钮、badge底色）
    static let rhAccentSoft   = Color(hex: "#F9E8E6")

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

// MARK: - View
extension View {
    func rhCard(padding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background(Color.rhCard)
            .cornerRadius(cornerRadius)
            .shadow(color: Color(hex: "#C8392B").opacity(0.07), radius: 12, x: 0, y: 4)
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Task Status Color
extension TaskStatus {
    var color: Color {
        switch self {
        case .queued:    return Color(hex: "#D4A017")   // 暖金
        case .pending:   return Color(hex: "#D4A017")
        case .running:   return Color(hex: "#C8392B")   // 柔雾红
        case .completed: return Color(hex: "#5A9E6F")   // 柔绿
        case .failed:    return Color(hex: "#C0392B")   // 深红
        case .cancelled: return Color(hex: "#8C7B6E")   // 暖灰
        }
    }
}
