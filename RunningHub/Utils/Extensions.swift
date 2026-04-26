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
    static let rhBackground   = Color(hex: "#F4F4F6")
    static let rhCard         = Color.white
    static let rhPrimary      = Color(hex: "#1A1A1A")
    static let rhAccent       = Color(hex: "#FF5C35")
    static let rhSecondary    = Color(hex: "#6B7280")
    static let rhSuccess      = Color(hex: "#10B981")
    static let rhError        = Color(hex: "#EF4444")
    static let rhWarning      = Color(hex: "#F59E0B")
    static let rhBorder       = Color(hex: "#E5E7EB")

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
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
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
        case .queued:    return .rhWarning
        case .running:   return .rhAccent
        case .completed: return .rhSuccess
        case .failed:    return .rhError
        case .cancelled: return .rhSecondary
        }
    }
}
