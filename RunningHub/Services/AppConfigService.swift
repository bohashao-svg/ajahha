import Foundation

// MARK: - Remote App Config
struct AppConfig: Codable {
    let kg: Bool        // true = normal, false = banned
    let gg: String      // announcement text
}

@MainActor
final class AppConfigService: ObservableObject {

    static let shared = AppConfigService()
    private init() {}

    private let url = URL(string: "https://json.lighttools.net/json/fce0812c918d4ebd")!
    private let lastAnnouncementKey = "rh_last_announcement"

    @Published var isBanned = false
    @Published var showAnnouncement = false
    @Published var announcementText = ""
    @Published var isLoaded = false

    func load() {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let config = try JSONDecoder().decode(AppConfig.self, from: data)
                isBanned = !config.kg
                checkAnnouncement(config.gg)
            } catch {
                // Network failure — allow normal use
            }
            isLoaded = true
        }
    }

    private func checkAnnouncement(_ text: String) {
        guard !text.isEmpty else { return }
        let last = UserDefaults.standard.string(forKey: lastAnnouncementKey) ?? ""
        if text != last {
            announcementText = text
            showAnnouncement = true
            UserDefaults.standard.set(text, forKey: lastAnnouncementKey)
        }
    }
}
