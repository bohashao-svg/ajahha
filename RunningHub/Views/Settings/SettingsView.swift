import SwiftUI

// MARK: - Settings View
// Layout: account card at top → grouped list rows
struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Account card ─────────────────────────────────────
                    accountCard

                    // ── API Key ──────────────────────────────────────────
                    settingsGroup("API 密钥", icon: "key.fill", iconColor: Color(hex: "#FFD166")) {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 14)).foregroundColor(Color(hex: "#FFD166")).frame(width: 20)
                                SecureField("输入 API Key", text: $vm.apiKeyInput)
                                    .font(.system(size: 15)).foregroundColor(.white)
                                    .tint(Color(hex: "#6C8EFF")).autocapitalization(.none).disableAutocorrection(true)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 13)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button { vm.saveAPIKey() } label: {
                                Text("保存密钥")
                                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).frame(height: 46)
                                    .background(LinearGradient(
                                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 10, y: 4)
                            }
                            .buttonStyle(LiquidButtonStyle())
                        }
                    }

                    // ── Preferences ──────────────────────────────────────
                    settingsGroup("偏好设置", icon: "slider.horizontal.3", iconColor: Color(hex: "#4ECDC4")) {
                        VStack(spacing: 0) {
                            toggleRow("Plus 默认模式", icon: "star.fill", iconColor: Color(hex: "#FFD166"),
                                      isOn: $vm.isPlusDefault) { vm.savePlusDefault() }
                        }
                    }

                    // ── Danger zone ──────────────────────────────────────
                    settingsGroup("账户操作", icon: "person.crop.circle", iconColor: Color(hex: "#FF6B6B")) {
                        VStack(spacing: 0) {
                            actionRow("清除任务历史", icon: "trash", iconColor: Color(hex: "#FF6B6B")) {
                                vm.clearHistory()
                            }
                            Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                            actionRow("退出登录", icon: "rectangle.portrait.and.arrow.right",
                                      iconColor: Color(hex: "#FF6B6B")) {
                                showLogoutAlert = true
                            }
                        }
                    }

                    // ── About ────────────────────────────────────────────
                    settingsGroup("关于", icon: "info.circle", iconColor: Color(hex: "#8B9CC8")) {
                        VStack(spacing: 0) {
                            infoRow("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            Divider().background(Color.white.opacity(0.07)).padding(.leading, 52)
                            infoRow("开发者", value: "iPhone83Plus")
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16).padding(.top, 12)
            }
            .background(AnimatedMeshBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("设置").font(.system(size: 17, weight: .black, design: .rounded)).foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundColor(Color.white.opacity(0.6))
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

    // MARK: - Account Card
    private var accountCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 10)
                Image(systemName: "person.fill").font(.system(size: 22)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("已登录").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Text(vm.maskedAccessKey)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            Spacer()
            // Plus badge
            if vm.isPlusDefault {
                Text("✦ Plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#FFD166"))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(hex: "#FFD166").opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Group Container
    private func settingsGroup<Content: View>(_ title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor.opacity(0.8))
                .textCase(.uppercase).tracking(0.5)
            content()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Row Types
    private func toggleRow(_ title: String, icon: String, iconColor: Color, isOn: Binding<Bool>, onChange: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(iconColor)
                .frame(width: 32, height: 32).background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title).font(.system(size: 15)).foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Color(hex: "#6C8EFF"))
                .onChange(of: isOn.wrappedValue) { _ in onChange() }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func actionRow(_ title: String, icon: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(iconColor)
                    .frame(width: 32, height: 32).background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title).font(.system(size: 15)).foregroundColor(iconColor)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Color.white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(LiquidButtonStyle())
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 15)).foregroundColor(Color.white.opacity(0.5))
            Spacer()
            Text(value).font(.system(size: 14)).foregroundColor(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
