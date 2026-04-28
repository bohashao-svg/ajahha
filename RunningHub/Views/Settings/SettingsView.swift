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
                    VStack(spacing: 16) {
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
                    Text("设置").font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        RHIcon(name: .close, size: 20, color: .rhSecondary)
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

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: .key, title: "API 密钥", accentColor: .rhGold)
            TextField("输入 API Key", text: $vm.apiKeyInput)
                .font(.system(size: 14)).padding(11)
                .background(Color.rhBackground).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhBorder, lineWidth: 1))
                .autocapitalization(.none).disableAutocorrection(true)
            Button { vm.saveAPIKey() } label: {
                Text("保存").font(.system(size: 14, weight: .medium)).foregroundColor(.rhAccent)
                    .frame(maxWidth: .infinity).frame(height: 38)
                    .background(Color.rhAccent.opacity(0.1)).cornerRadius(10)
            }
        }
        .rhCard()
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: .lock, title: "账号状态", accentColor: .rhAccent)
            if vm.isLoggedIn {
                HStack(spacing: 6) {
                    RHIcon(name: .lock, size: 13, color: .rhSuccess)
                    Text("已登录：\(vm.maskedAccessKey)")
                        .font(.system(size: 13)).foregroundColor(.rhSecondary)
                    Spacer()
                    Button { vm.showLogoutConfirm = true } label: {
                        Text("退出登录").font(.system(size: 13, weight: .medium)).foregroundColor(.rhError)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.rhBackground).cornerRadius(10)
            } else {
                Text("未登录").font(.system(size: 13)).foregroundColor(.rhSecondary)
            }
        }
        .rhCard()
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: .settings, title: "偏好设置", accentColor: .rhAccent)
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
        .rhCard()
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: .trash, title: "数据管理", accentColor: .rhError)
            Button { showClearConfirm = true } label: {
                HStack {
                    Text("清除所有任务记录").font(.system(size: 14, weight: .medium)).foregroundColor(.rhError)
                    Spacer()
                    RHIcon(name: .chevron, size: 13, color: .rhError.opacity(0.5))
                }
                .padding(12)
                .background(Color.rhError.opacity(0.05)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhError.opacity(0.15), lineWidth: 1))
            }
        }
        .rhCard()
    }

    private var versionFooter: some View {
        VStack(spacing: 6) {
            Divider()
            Text("人民万岁  v1.0.0").font(.system(size: 12)).foregroundColor(.rhSecondary.opacity(0.7))
        }
        .padding(.top, 4)
    }

    private func sectionHeader(icon: RHIcon.IconName, title: String, accentColor: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(accentColor).frame(width: 3, height: 14)
            RHIcon(name: icon, size: 14, color: accentColor)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.rhPrimary)
        }
    }
}
