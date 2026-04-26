import SwiftUI

@main
struct RunningHubApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
        }
    }
}
