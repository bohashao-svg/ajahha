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
    @State private var isLoggedIn = StorageService.shared.isLoggedIn
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if isLoggedIn {
                HomeView()
                    .environmentObject(appState)
                    .disabled(appConfig.isBanned)
                    .overlay {
                        if appConfig.isBanned { bannedOverlay }
                    }
            } else {
                LoginView()
            }

            if !appConfig.isLoaded {
                Color(hex: "#080C18").ignoresSafeArea()
                ProgressView().tint(.white)
            }

            // App Switcher snapshot mask: prevents white flash, shows branded background
            if scenePhase == .background {
                Color(hex: "#080C18").ignoresSafeArea()
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(Color(hex: "#6C8EFF").opacity(0.4))
                    )
            }
        }
        .onAppear {
            appConfig.load()
            NotificationService.shared.requestPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateChanged)) { _ in
            isLoggedIn = StorageService.shared.isLoggedIn
        }
        .alert("公告", isPresented: $appConfig.showAnnouncement) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(appConfig.announcementText)
        }
    }

    private var bannedOverlay: some View {
        ZStack {
            Color(hex: "#2D1A0E").opacity(0.92).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#C8392B").opacity(0.15))
                        .frame(width: 90, height: 90)
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "#C8392B"))
                }
                Text("软件已被作者禁用")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("请联系作者了解详情")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }
}
