import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    apiKeySection
                    accountSection
                    aboutSection
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(AnimatedMeshBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("设置")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#F0F4FF"), Color(hex: "#8B9CC8")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        GlassIconButton(icon: .close, size: 18, color: Color(hex: "#8B9CC8"))
                    }
                }
            }
            .alert("确认退出登录？", isPresented: $showLogoutAlert) {
                Button("退出", role: .destructive) { vm.logout() }
                Button("取消", role: .cancel) {}
            }
            .alert("已保存", isPresented: $vm.showSavedAlert) {
                Button("好", role: .cancel) {}
            }
        }
    }

    // MARK: - API Key Section
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("API 密钥", icon: "key.fill", color: Color(hex: "#FFD166"))

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14)).foregroundColor(Color(hex: "#FFD166")).frame(width: 20)
                    SecureField("输入 API Key", text: $vm.apiKeyInput)
                        .font(.system(size: 14))
                        .tint(Color(hex: "#6C8EFF")).autocapitalization(.none).disableAutocorrection(true)
                }
                .nativeInput()

                Button { vm.saveAPIKey() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
                        Text("保存密钥").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(
                        LiquidGlassShape(radius: 12)
                            .fill(LinearGradient(
                                colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    )
                    .overlay(LiquidGlassShape(radius: 12).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 10)
                }
                .buttonStyle(LiquidButtonStyle())
            }
        }
        .sketchCard()
    }

    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("账户", icon: "person.circle.fill", color: Color(hex: "#4ECDC4"))

            settingsRow(
                icon: "key.horizontal.fill",
                iconColor: Color(hex: "#4ECDC4"),
                title: "Access Key",
                trailing: AnyView(
                    Text(vm.maskedAccessKey)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "#8B9CC8"))
                )
            )

            glassDivider

            settingsRow(
                icon: "star.fill",
                iconColor: Color(hex: "#FFD166"),
                title: "Plus 默认模式",
                trailing: AnyView(
                    Toggle("", isOn: $vm.isPlusDefault)
                        .labelsHidden()
                        .tint(Color(hex: "#6C8EFF"))
                        .onChange(of: vm.isPlusDefault) { _ in vm.savePlusDefault() }
                )
            )

            glassDivider

            Button { showLogoutAlert = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        LiquidGlassShape(radius: 8).fill(Color(hex: "#FF6B6B").opacity(0.12)).frame(width: 32, height: 32)
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14)).foregroundColor(Color(hex: "#FF6B6B"))
                    }
                    Text("退出登录")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "#FF6B6B"))
                    Spacer()
                    RHIcon(name: .chevron, size: 12, color: Color(hex: "#FF6B6B").opacity(0.5))
                }
            }
            .buttonStyle(LiquidButtonStyle())
        }
        .sketchCard()
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("关于", icon: "info.circle.fill", color: Color(hex: "#8B9CC8"))

            settingsRow(
                icon: "app.badge",
                iconColor: Color(hex: "#6C8EFF"),
                title: "版本",
                trailing: AnyView(
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.system(size: 13)).foregroundColor(Color(hex: "#8B9CC8"))
                )
            )

            glassDivider

            settingsRow(
                icon: "person.2.fill",
                iconColor: Color(hex: "#8B9CC8"),
                title: "开发者",
                trailing: AnyView(
                    Text("iPhone83Plus")
                        .font(.system(size: 13)).foregroundColor(Color(hex: "#8B9CC8"))
                )
            )
        }
        .sketchCard()
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                LiquidGlassShape(radius: 8).fill(color.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(color)
            }
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#F0F4FF"))
        }
    }

    private func settingsRow(icon: String, iconColor: Color, title: String, trailing: AnyView) -> some View {
        HStack(spacing: 10) {
            ZStack {
                LiquidGlassShape(radius: 8).fill(iconColor.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(iconColor)
            }
            Text(title).font(.system(size: 14)).foregroundColor(Color(hex: "#F0F4FF"))
            Spacer()
            trailing
        }
    }

    private var glassDivider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5).padding(.leading, 42)
    }
}
