import SwiftUI

@main
struct RunningHubApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var appConfig = AppConfigService.shared

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environmentObject(appState)
                .environmentObject(appConfig)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Root View (handles config loading + banned overlay)
struct ContentRootView: View {
    @EnvironmentObject private var appConfig: AppConfigService
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            HomeView()
                .environmentObject(appState)
                .disabled(appConfig.isBanned)
                .overlay {
                    if appConfig.isBanned {
                        bannedOverlay
                    }
                }

            if !appConfig.isLoaded {
                Color.white.ignoresSafeArea()
                ProgressView()
            }
        }
        .onAppear { appConfig.load() }
        .alert("公告", isPresented: $appConfig.showAnnouncement) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(appConfig.announcementText)
        }
    }

    private var bannedOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "xmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                Text("软件已被作者禁用")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("请联系作者了解详情")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}
