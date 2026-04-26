import SwiftUI

// MARK: - Settings View
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
                    Text("设置")
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        RHIcon(name: .close, size: 20, color: .rhSecondary)
                    }
                }
            }
            .alert("API 密钥已保存", isPresented: $vm.showSavedAlert) {
                Button("好的", role: .cancel) {}
            }
            .confirmationDialog("确认清除所有任务记录？", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清除", role: .destructive) { vm.clearHistory() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: - API Key Section
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: .key, title: "API 密钥")

            HStack(spacing: 6) {
                RHIcon(name: .lock, size: 14, color: .rhSecondary)
                Text("当前：\(vm.maskedApiKey)")
                    .font(.system(size: 13))
                    .foregroundColor(.rhSecondary)
            }

            HStack(spacing: 10) {
                SecureField("输入新的 API 密钥", text: $vm.apiKeyInput)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Color.rhBackground)
                    .cornerRadius(10)

                Button {
                    vm.saveAPIKey()
                } label: {
                    Text("保存")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(vm.apiKeyInput.isBlank ? Color.rhSecondary.opacity(0.4) : Color.rhAccent)
                        .cornerRadius(10)
                }
                .disabled(vm.apiKeyInput.isBlank)
            }
        }
        .rhCard()
    }

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(icon: .settings, title: "偏好设置")
                .padding(.bottom, 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("默认开启 Plus 模式")
                        .font(.system(size: 14))
                        .foregroundColor(.rhPrimary)
                    Text("新任务默认以 Plus 优先级提交")
                        .font(.system(size: 12))
                        .foregroundColor(.rhSecondary)
                }
                Spacer()
                Toggle("", isOn: $vm.isPlusDefault)
                    .labelsHidden()
                    .tint(.rhAccent)
                    .onChange(of: vm.isPlusDefault) { _ in vm.savePlusDefault() }
            }
        }
        .rhCard()
    }

    // MARK: - Danger Section
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(icon: .trash, title: "数据管理")
                .padding(.bottom, 8)

            Button {
                showClearConfirm = true
            } label: {
                HStack {
                    Text("清除所有任务记录")
                        .font(.system(size: 14))
                        .foregroundColor(.rhError)
                    Spacer()
                    RHIcon(name: .chevron, size: 14, color: .rhError)
                }
            }
        }
        .rhCard()
    }

    // MARK: - Version Footer
    private var versionFooter: some View {
        Text("RunningHub iOS  v1.0.0")
            .font(.system(size: 12))
            .foregroundColor(.rhSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func sectionHeader(icon: RHIcon.IconName, title: String) -> some View {
        HStack(spacing: 6) {
            RHIcon(name: icon, size: 14, color: .rhSecondary)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.rhSecondary)
        }
    }
}
