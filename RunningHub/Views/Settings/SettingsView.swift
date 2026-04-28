import SwiftUI

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirm = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        apiKeySection
                        accountSection
                        preferencesSection
                        dangerSection
                        versionFooter
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("设置").font(.system(size: 17, weight: .bold)).foregroundColor(.rhPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        RHIcon(name: .close, size: 18, color: .rhPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.rhCard)
                            .clipShape(SketchRoundedRect(radius: 8))
                            .overlay(SketchRoundedRect(radius: 8).stroke(Color.rhInk.opacity(0.2), lineWidth: 1.5))
                            .shadow(color: Color.rhInk.opacity(0.1), radius: 0, x: 2, y: 2)
                    }
                }
            }
            .confirmationDialog("确认退出登录？", isPresented: $vm.showLogoutConfirm, titleVisibility: .visible) {
                Button("退出", role: .destructive) { vm.logout() }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("确认清除所有任务记录？", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清除", role: .destructive) { vm.clearHistory() }
                Button("取消", role: .cancel) {}
            }
            .alert("已保存", isPresented: $vm.showSavedAlert) {
                Button("好", role: .cancel) {}
            }
        }
    }

    // MARK: - API Key
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sketchHeader(title: "API 密钥", icon: .key, color: .rhGold)
            TextField("输入 API Key", text: $vm.apiKeyInput)
                .font(.system(size: 14))
                .padding(11)
                .background(Color.rhBackground)
                .clipShape(SketchRoundedRect(radius: 10))
                .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhInk.opacity(0.18), lineWidth: 1.5))
                .autocapitalization(.none).disableAutocorrection(true)
            Button { vm.saveAPIKey() } label: {
                Text("保 存")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rhAccent)
                    .tracking(2)
                    .frame(maxWidth: .infinity).frame(height: 38)
                    .background(Color.rhRedMuted)
                    .clipShape(SketchRoundedRect(radius: 10))
                    .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhAccent.opacity(0.5), lineWidth: 1.5))
                    .shadow(color: Color.rhAccent.opacity(0.15), radius: 0, x: 2, y: 2)
            }
        }
        .sketchCard()
    }

    // MARK: - Account
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sketchHeader(title: "账号状态", icon: .lock, color: .rhAccent)
            if vm.isLoggedIn {
                // 登录状态行
                HStack(spacing: 8) {
                    Circle().fill(Color.rhSuccess).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.rhSuccess.opacity(0.3), lineWidth: 3))
                    Text("已登录：\(vm.maskedAccessKey)")
                        .font(.system(size: 13)).foregroundColor(.rhSecondary)
                    Spacer()
                    Button { vm.showLogoutConfirm = true } label: {
                        Text("退出登录")
                            .font(.system(size: 13, weight: .medium)).foregroundColor(.rhError)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.rhBackground)
                .clipShape(SketchRoundedRect(radius: 10))
                .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhInk.opacity(0.12), lineWidth: 1.2))
            } else {
                Text("未登录").font(.system(size: 13)).foregroundColor(.rhSecondary)
            }

            // 余额区域
            if vm.isLoadingAccount {
                HStack { Spacer(); ProgressView().tint(.rhAccent); Spacer() }.padding(.vertical, 4)
            } else if let status = vm.accountStatus {
                HStack(spacing: 10) {
                    // RH 币
                    VStack(spacing: 4) {
                        Text(status.remainCoins ?? "--")
                            .font(.system(size: 18, weight: .bold)).foregroundColor(.rhAccent)
                        Text("RH 币")
                            .font(.system(size: 11)).foregroundColor(.rhSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.rhAccentSoft)
                    .clipShape(SketchRoundedRect(radius: 10))
                    .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhAccent.opacity(0.2), lineWidth: 1.2))

                    // 钱包余额
                    VStack(spacing: 4) {
                        let money = status.remainMoney ?? "--"
                        let unit = status.currency ?? ""
                        Text("\(money) \(unit)".trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 18, weight: .bold)).foregroundColor(.rhGold)
                        Text("钱包余额")
                            .font(.system(size: 11)).foregroundColor(.rhSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.rhGoldLight)
                    .clipShape(SketchRoundedRect(radius: 10))
                    .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhGold.opacity(0.25), lineWidth: 1.2))
                }
            }

            // 刷新按钮
            Button { Task { await vm.loadAccountStatus() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text("刷新余额")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.rhAccent)
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(Color.rhBackground)
                .clipShape(SketchRoundedRect(radius: 10))
                .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhAccent.opacity(0.3), lineWidth: 1.2))
            }
            .disabled(vm.isLoadingAccount)
        }
        .sketchCard()
        .task { await vm.loadAccountStatus() }
    }

    // MARK: - Preferences
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sketchHeader(title: "偏好设置", icon: .settings, color: .rhAccent)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("✦").font(.system(size: 11)).foregroundColor(.rhGold)
                        Text("默认开启 Plus 模式").font(.system(size: 14, weight: .medium)).foregroundColor(.rhPrimary)
                    }
                    Text("新任务默认以 Plus 优先级提交").font(.system(size: 12)).foregroundColor(.rhSecondary)
                }
                Spacer()
                Toggle("", isOn: $vm.isPlusDefault).labelsHidden().tint(.rhAccent)
                    .onChange(of: vm.isPlusDefault) { _ in vm.savePlusDefault() }
            }
        }
        .sketchCard()
    }

    // MARK: - Danger
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sketchHeader(title: "数据管理", icon: .trash, color: .rhError)
            Button { showClearConfirm = true } label: {
                HStack {
                    Text("清除所有任务记录")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.rhError)
                    Spacer()
                    RHIcon(name: .chevron, size: 13, color: .rhError.opacity(0.5))
                }
                .padding(12)
                .background(Color.rhRedMuted)
                .clipShape(SketchRoundedRect(radius: 10))
                .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhError.opacity(0.3), lineWidth: 1.5))
            }
        }
        .sketchCard()
    }

    // MARK: - Footer
    private var versionFooter: some View {
        Text("人民万岁  v1.0.0")
            .font(.system(size: 12))
            .foregroundColor(.rhSecondary.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private func sketchHeader(title: String, icon: RHIcon.IconName, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3, height: 14)
            RHIcon(name: icon, size: 14, color: color)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.rhPrimary)
        }
    }
}
