import SwiftUI

// MARK: - Home View
struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showTaskCenter = false
    @State private var showSettings = false
    @State private var showAPIKeyAlert = false
    @State private var showPremium = false
    @State private var showAIApp = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Color.rhBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Top: Premium workflow entry card
                        premiumEntryCard
                            .padding(.horizontal, 16)

                        // AI App entry card
                        aiAppEntryCard
                            .padding(.horizontal, 16)

                        // Center: Workflow input + detail
                        VStack(spacing: 16) {
                            workflowInputCard

                            if vm.workflowDetail != nil {
                                workflowInfoCard
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                ParameterFormView(fields: $vm.formFields)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                plusToggleCard
                                    .transition(.opacity)
                                submitButton
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 16)
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.workflowDetail == nil)

                        Spacer(minLength: 24)

                        // Bottom: History workflows (centered)
                        if !vm.workflowHistory.isEmpty && vm.workflowDetail == nil {
                            workflowHistoryCard
                                .padding(.horizontal, 16)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // Signature
                        Text("By：iPhone83Plus")
                            .font(.system(size: 11))
                            .foregroundColor(.rhSecondary.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 20)
                    }
                    .padding(.top, 12)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.workflowHistory.isEmpty)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.workflowDetail == nil)
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
                    Text("人民万岁")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.rhPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    taskCenterButton
                }
            }
            .sheet(isPresented: $showTaskCenter) {
                TaskCenterView().environmentObject(appState)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPremium) {
                PremiumWorkflowView { workflowId in
                    vm.workflowInput = workflowId
                    Task { await vm.fetchWorkflow() }
                }
            }
            .sheet(isPresented: $showAIApp) {
                AppView()
            }
            .sheet(isPresented: $vm.showPromptSelector) {
                PromptSelectorView(fields: vm.availablePromptFields, onConfirm: { selections in
                    vm.applyPromptSelection(selections)
                })
            }
            .alert("请先配置 API 密钥", isPresented: $showAPIKeyAlert) {
                Button("去配置") { showSettings = true }
                Button("取消", role: .cancel) {}
            }
            .onAppear {
                if !StorageService.shared.hasAPIKey { showAPIKeyAlert = true }
            }
        }
    }

    // MARK: - Task Center Button
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

    // MARK: - AI App Entry Card
    private var aiAppEntryCard: some View {
        Button { showAIApp = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.rhAccent.opacity(0.12))
                        .frame(width: 52, height: 52)
                    VStack(spacing: 2) {
                        Text("AI").font(.system(size: 14, weight: .bold)).foregroundColor(.rhAccent)
                        Text("应用").font(.system(size: 9, weight: .bold)).foregroundColor(.rhAccent)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 应用")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.rhPrimary)
                    Text("使用 RunningHub WebApp 快速生成")
                        .font(.system(size: 12))
                        .foregroundColor(.rhSecondary)
                }

                Spacer()

                RHIcon(name: .chevron, size: 14, color: .rhAccent.opacity(0.6))
            }
            .padding(14)
            .background(Color.rhCard)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.rhAccent.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color(hex: "#C8392B").opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Premium Entry Card
    private var premiumEntryCard: some View {
        Button { showPremium = true } label: {
            HStack(spacing: 14) {
                // SVG-style decorative icon area
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.rhAccent.opacity(0.12))
                        .frame(width: 52, height: 52)

                    // Star pattern
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text("✦").font(.system(size: 10)).foregroundColor(.rhGold)
                            Text("★").font(.system(size: 14)).foregroundColor(.rhAccent)
                            Text("✦").font(.system(size: 10)).foregroundColor(.rhGold)
                        }
                        Text("精品").font(.system(size: 9, weight: .bold)).foregroundColor(.rhAccent)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("精品工作流")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.rhPrimary)
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.rhAccent)
                            .cornerRadius(4)
                    }
                    Text("精选优质工作流，一键导入使用")
                        .font(.system(size: 12))
                        .foregroundColor(.rhSecondary)
                }

                Spacer()

                RHIcon(name: .chevron, size: 14, color: .rhAccent.opacity(0.6))
            }
            .padding(14)
            .background(Color.rhCard)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.rhAccent.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color(hex: "#C8392B").opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Workflow Input Card
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.rhBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rhBorder, lineWidth: 1))
                    .onSubmit { Task { await vm.fetchWorkflow() } }

                Button {
                    Task { await vm.fetchWorkflow() }
                } label: {
                    if vm.isLoading {
                        ProgressView().frame(width: 40, height: 40)
                    } else {
                        RHIcon(name: .refresh, size: 18, color: .white)
                            .frame(width: 40, height: 40)
                            .background(Color.rhAccent)
                            .cornerRadius(10)
                    }
                }
                .disabled(vm.isLoading || vm.workflowInput.isBlank)
                .buttonStyle(ScaleButtonStyle())
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.rhError)
                    .transition(.opacity)
            }

            HStack(spacing: 6) {
                Circle().fill(Color.rhSuccess).frame(width: 7, height: 7)
                Text("就绪")
                    .font(.system(size: 12))
                    .foregroundColor(.rhSecondary)
                Spacer()
            }
        }
        .rhCard()
    }

    // MARK: - Workflow Info Card
    private var workflowInfoCard: some View {
        HStack(spacing: 12) {
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

    // MARK: - Plus Toggle Card
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

    // MARK: - Submit Button
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
            .background(canSubmitNow ? Color.rhAccent : Color.rhSecondary.opacity(0.35))
            .cornerRadius(14)
        }
        .disabled(!canSubmitNow)
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Workflow History Card
    private var workflowHistoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("历史工作流")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.rhSecondary)
                Spacer()
                if vm.workflowHistory.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.showAllHistory.toggle()
                        }
                    } label: {
                        Text(vm.showAllHistory ? "收起" : "更多")
                            .font(.system(size: 12))
                            .foregroundColor(.rhAccent)
                    }
                }
            }

            let displayed = vm.showAllHistory
                ? vm.workflowHistory
                : Array(vm.workflowHistory.prefix(3))

            ForEach(displayed) { item in
                Button { vm.selectHistory(item) } label: {
                    HStack(spacing: 10) {
                        RHIcon(name: .workflow, size: 14, color: .rhAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.workflowId)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.rhPrimary)
                                .lineLimit(1)
                            Text(item.workflowType)
                                .font(.system(size: 11))
                                .foregroundColor(.rhSecondary)
                        }
                        Spacer()
                        RHIcon(name: .chevron, size: 12, color: .rhBorder)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.removeHistory(item)
                        }
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }

                if item.workflowId != displayed.last?.workflowId {
                    Divider()
                }
            }
        }
        .rhCard()
    }

    private var canSubmitNow: Bool {
        !vm.isSubmitting && appState.canSubmit && vm.workflowDetail != nil
    }
}

// MARK: - Scale Button Style（点击缩放反馈）
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
