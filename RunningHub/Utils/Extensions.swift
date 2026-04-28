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
    static let rhBackground   = Color(hex: "#F5EDE4")   // 更深的暖米，与卡片拉开对比
    static let rhCard         = Color(hex: "#FFFCF9")   // 卡片近白
    static let rhPrimary      = Color(hex: "#2D1A0E")
    static let rhAccent       = Color(hex: "#C8392B")
    static let rhGold         = Color(hex: "#C9920A")   // 金色加深，更易辨认
    static let rhSecondary    = Color(hex: "#8C7B6E")
    static let rhSuccess      = Color(hex: "#4A8F5F")
    static let rhError        = Color(hex: "#C0392B")
    static let rhWarning      = Color(hex: "#C9920A")
    static let rhBorder       = Color(hex: "#E8D5C4")   // 边框加深一点
    static let rhAccentSoft   = Color(hex: "#F7E4E2")

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
    func rhCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.rhCard)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
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
        case .queued:    return Color(hex: "#C9920A")
        case .pending:   return Color(hex: "#C9920A")
        case .running:   return Color(hex: "#C8392B")
        case .completed: return Color(hex: "#4A8F5F")
        case .failed:    return Color(hex: "#C0392B")
        case .cancelled: return Color(hex: "#8C7B6E")
        }
    }
}
