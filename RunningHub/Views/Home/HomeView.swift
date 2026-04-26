import SwiftUI

// MARK: - Home View
struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showTaskCenter = false
    @State private var showSettings = false
    @State private var showAPIKeyAlert = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Color.rhBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        workflowInputCard
                        if vm.workflowDetail != nil {
                            workflowInfoCard
                            ParameterFormView(fields: $vm.formFields)
                            plusToggleCard
                            submitButton
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        RHIcon(name: .settings, size: 22, color: .rhSecondary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("RunningHub")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.rhPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    taskCenterButton
                }
            }
            .sheet(isPresented: $showTaskCenter) {
                TaskCenterView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("请先配置 API 密钥", isPresented: $showAPIKeyAlert) {
                Button("去配置") { showSettings = true }
                Button("取消", role: .cancel) {}
            }
            .onAppear {
                if !StorageService.shared.hasAPIKey { showAPIKeyAlert = true }
                appState.refreshQuota()
            }
        }
    }

    // MARK: - Subviews

    private var taskCenterButton: some View {
        Button { showTaskCenter = true } label: {
            ZStack(alignment: .topTrailing) {
                RHIcon(name: .tasks, size: 22, color: .rhPrimary)
                if appState.pendingCount > 0 {
                    Text("\(appState.pendingCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Color.rhAccent)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
    }

    private var workflowInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("工作流")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.rhSecondary)

            HStack(spacing: 10) {
                TextField("输入工作流 ID 或链接", text: $vm.workflowInput)
                    .font(.system(size: 15))
                    .foregroundColor(.rhPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit { Task { await vm.fetchWorkflow() } }

                Button {
                    Task { await vm.fetchWorkflow() }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        RHIcon(name: .refresh, size: 18, color: .white)
                            .frame(width: 36, height: 36)
                            .background(Color.rhAccent)
                            .cornerRadius(10)
                    }
                }
                .disabled(vm.isLoading || vm.workflowInput.isBlank)
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.rhError)
            }

            // Quota status
            quotaStatusView
        }
        .rhCard()
    }

    private var quotaStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.canSubmit ? Color.rhSuccess : Color.rhError)
                .frame(width: 7, height: 7)
            if let q = appState.quota {
                Text("并发 \(q.usedConcurrency)/\(q.maxConcurrency)  ·  剩余 \(q.remainConcurrency) 个")
                    .font(.system(size: 12))
                    .foregroundColor(.rhSecondary)
            } else {
                Text("正在检查并发配额...")
                    .font(.system(size: 12))
                    .foregroundColor(.rhSecondary)
            }
            Spacer()
        }
    }

    private var workflowInfoCard: some View {
        HStack(spacing: 12) {
            // Type icon
            Group {
                switch vm.workflowType {
                case .textToImage:  RHIcon(name: .image, size: 20, color: .rhAccent)
                case .textToVideo, .imageToVideo: RHIcon(name: .video, size: 20, color: .rhAccent)
                case .unknown: RHIcon(name: .workflow, size: 20, color: .rhSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.currentWorkflowId)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rhPrimary)
                    .lineLimit(1)
                Text(vm.workflowType.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.rhSecondary)
            }

            Spacer()

            if vm.duckNodeInfo != nil {
                HStack(spacing: 4) {
                    RHIcon(name: .duck, size: 14, color: .rhWarning)
                    Text("鸭鸭图")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.rhWarning)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.rhWarning.opacity(0.12))
                .cornerRadius(8)
            }
        }
        .rhCard(padding: 12)
    }

    private var plusToggleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Plus 模式")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rhPrimary)
                Text("开启后以 Plus 优先级提交任务")
                    .font(.system(size: 12))
                    .foregroundColor(.rhSecondary)
            }
            Spacer()
            Toggle("", isOn: $vm.isPlusMode)
                .labelsHidden()
                .tint(.rhAccent)
        }
        .rhCard(padding: 14)
    }

    private var submitButton: some View {
        Button {
            Task { await vm.submit() }
        } label: {
            HStack(spacing: 8) {
                if vm.isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    RHIcon(name: .plus, size: 16, color: .white)
                }
                Text(vm.isSubmitting ? "提交中..." : "提交任务")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canSubmitNow ? Color.rhAccent : Color.rhSecondary.opacity(0.4))
            .cornerRadius(14)
        }
        .disabled(!canSubmitNow)
    }

    private var canSubmitNow: Bool {
        !vm.isSubmitting && appState.canSubmit && vm.workflowDetail != nil
    }
}
