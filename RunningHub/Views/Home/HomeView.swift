import SwiftUI

// MARK: - Home View
struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @StateObject private var appVm = AppViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showTaskCenter = false
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showAPIKeyAlert = false
    @State private var showPremium = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Color.rhBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        premiumEntryCard.padding(.horizontal, 16)

                        VStack(spacing: 16) {
                            aiAppInputCard
                            if appVm.isLoading {
                                NodeFormCardSkeleton().transition(.opacity)
                            } else if !appVm.nodes.isEmpty {
                                aiAppNodeCard.transition(.opacity.combined(with: .move(edge: .top)))
                                aiAppSubmitButton.transition(.opacity).padding(.horizontal, 16)
                            }
                        }
                        .padding(.horizontal, 16)
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: appVm.nodes.isEmpty)

                        VStack(spacing: 16) {
                            workflowInputCard
                            if vm.isLoading {
                                NodeFormCardSkeleton().transition(.opacity)
                            } else if vm.workflowDetail != nil {
                                workflowInfoCard.transition(.opacity.combined(with: .move(edge: .top)))
                                ParameterFormView(fields: $vm.formFields).transition(.opacity.combined(with: .move(edge: .top)))
                                plusToggleCard.transition(.opacity)
                                submitButton.transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 16)
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.workflowDetail == nil)

                        Spacer(minLength: 24)

                        if !vm.workflowHistory.isEmpty && vm.workflowDetail == nil {
                            workflowHistoryCard.padding(.horizontal, 16)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Text("By：iPhone83Plus")
                            .font(.system(size: 11))
                            .foregroundColor(.rhSecondary.opacity(0.4))
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
                        sketchIconButton(icon: .settings)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        Text("人民万岁")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.rhPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button { showProfile = true } label: {
                            sketchIconButton(icon: .image)
                        }
                        taskCenterButton
                    }
                }
            }
            .sheet(isPresented: $showTaskCenter) { TaskCenterView().environmentObject(appState) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showPremium) {
                PremiumWorkflowView { workflowId in
                    vm.workflowInput = workflowId
                    Task { await vm.fetchWorkflow() }
                }
            }
            .sheet(isPresented: $vm.showPromptSelector) {
                PromptSelectorView(fields: vm.availablePromptFields, onConfirm: { vm.applyPromptSelection($0) })
            }
            .alert("请先配置 API 密钥", isPresented: $showAPIKeyAlert) {
                Button("去配置") { showSettings = true }
                Button("取消", role: .cancel) {}
            }
            .onAppear { if !StorageService.shared.hasAPIKey { showAPIKeyAlert = true } }
        }
    }

    // MARK: - Sketch icon button helper
    private func sketchIconButton(icon: RHIcon.IconName) -> some View {
        RHIcon(name: icon, size: 20, color: .rhPrimary)
            .frame(width: 34, height: 34)
            .background(Color.rhCard)
            .clipShape(SketchRoundedRect(radius: 10))
            .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhInk.opacity(0.2), lineWidth: 1.5))
            .shadow(color: Color.rhInk.opacity(0.12), radius: 0, x: 2, y: 2)
            .contentShape(Rectangle())
    }

    // MARK: - Task Center Button
    private var taskCenterButton: some View {
        Button { showTaskCenter = true } label: {
            ZStack(alignment: .topTrailing) {
                RHIcon(name: .tasks, size: 20, color: .rhPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.rhCard)
                    .clipShape(SketchRoundedRect(radius: 10))
                    .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhInk.opacity(0.2), lineWidth: 1.5))
                    .shadow(color: Color.rhInk.opacity(0.12), radius: 0, x: 2, y: 2)
                if appState.pendingCount > 0 {
                    Text("\(appState.pendingCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Color.rhAccent)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.rhCard, lineWidth: 1.5))
                        .offset(x: 6, y: -6)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Premium Entry Card
    private var premiumEntryCard: some View {
        Button { showPremium = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.rhRedMuted)
                        .frame(width: 52, height: 52)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhAccent.opacity(0.4), lineWidth: 1.5))
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Text("✦").font(.system(size: 9)).foregroundColor(.rhGold)
                            Text("★").font(.system(size: 13)).foregroundColor(.rhAccent)
                            Text("✦").font(.system(size: 9)).foregroundColor(.rhGold)
                        }
                        Text("精品").font(.system(size: 9, weight: .bold)).foregroundColor(.rhAccent)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("精品工作流")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.rhPrimary)
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.rhAccent)
                            .clipShape(SketchRoundedRect(radius: 4))
                    }
                    Text("精选优质工作流，一键导入使用")
                        .font(.system(size: 12)).foregroundColor(.rhSecondary)
                }
                Spacer()
                RHIcon(name: .chevron, size: 14, color: .rhAccent.opacity(0.6))
            }
            .padding(14)
            .background(Color.rhCard)
            .clipShape(SketchRoundedRect(radius: 14))
            .overlay(SketchRoundedRect(radius: 14).stroke(Color.rhAccent.opacity(0.25), lineWidth: 1.8))
            .shadow(color: Color.rhInk.opacity(0.12), radius: 0, x: 2, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - AI App Input Card
    private var aiAppInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sketchSectionLabel("AI 应用", star: true)
            HStack(spacing: 10) {
                TextField("输入 AI 应用 ID 或链接", text: $appVm.webappInput)
                    .font(.system(size: 15)).foregroundColor(.rhPrimary)
                    .autocapitalization(.none).disableAutocorrection(true)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.rhBackground)
                    .clipShape(SketchRoundedRect(radius: 10))
                    .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhInk.opacity(0.18), lineWidth: 1.5))
                    .onSubmit { Task { await appVm.fetchNodes() } }
                Button { Task { await appVm.fetchNodes() } } label: {
                    if appVm.isLoading {
                        ProgressView().frame(width: 40, height: 40)
                    } else {
                        RHIcon(name: .refresh, size: 18, color: .white)
                            .frame(width: 40, height: 40)
                            .background(Color.rhAccent)
                            .clipShape(SketchRoundedRect(radius: 10))
                            .shadow(color: Color.rhInk.opacity(0.15), radius: 0, x: 2, y: 2)
                    }
                }
                .disabled(appVm.isLoading || appVm.webappInput.isBlank)
                .buttonStyle(ScaleButtonStyle())
            }
            if let err = appVm.errorMessage {
                Text(err).font(.system(size: 12)).foregroundColor(.rhError).transition(.opacity)
            }
            HStack(spacing: 6) {
                Circle().fill(appVm.nodes.isEmpty ? Color.rhSecondary.opacity(0.4) : Color.rhSuccess).frame(width: 7, height: 7)
                Text(appVm.nodes.isEmpty ? "输入应用 ID 后点击刷新" : "已加载 \(appVm.nodes.count) 个参数节点")
                    .font(.system(size: 12)).foregroundColor(.rhSecondary)
                Spacer()
            }
        }
        .sketchCard()
    }

    // MARK: - AI App Node Card
    private var aiAppNodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sketchSectionLabel("节点参数", star: false)
            ForEach(appVm.nodes.indices, id: \.self) { i in
                AppNodeRow(node: $appVm.nodes[i], selectedImages: $appVm.selectedImages)
                if i < appVm.nodes.count - 1 { Divider().padding(.vertical, 4) }
            }
        }
        .sketchCard()
    }

    // MARK: - AI App Submit Button
    private var aiAppSubmitButton: some View {
        Button { Task { await appVm.submit() } } label: {
            HStack(spacing: 8) {
                if appVm.isSubmitting { ProgressView().tint(.white) }
                else { Text("✦").font(.system(size: 13)).foregroundColor(.white.opacity(0.8)) }
                Text(appVm.isSubmitting ? "提交中..." : "提交任务")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(appVm.isSubmitting ? Color.rhSecondary.opacity(0.35) : Color.rhAccent)
            .clipShape(SketchRoundedRect(radius: 12))
            .overlay(SketchRoundedRect(radius: 12).stroke(Color.rhInk.opacity(appVm.isSubmitting ? 0 : 0.2), lineWidth: 1.5))
            .shadow(color: Color.rhInk.opacity(appVm.isSubmitting ? 0 : 0.18), radius: 0, x: 2, y: 3)
        }
        .disabled(appVm.isSubmitting)
        .buttonStyle(ScaleButtonStyle())
    }

    private var aiAppEntryCard: some View { EmptyView() }

    // MARK: - Workflow Input Card
    private var workflowInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sketchSectionLabel("工作流", star: true)
            HStack(spacing: 10) {
                TextField("输入工作流 ID 或链接", text: $vm.workflowInput)
                    .font(.system(size: 15)).foregroundColor(.rhPrimary)
                    .autocapitalization(.none).disableAutocorrection(true)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color.rhBackground)
                    .clipShape(SketchRoundedRect(radius: 10))
                    .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhInk.opacity(0.18), lineWidth: 1.5))
                    .onSubmit { Task { await vm.fetchWorkflow() } }
                Button { Task { await vm.fetchWorkflow() } } label: {
                    if vm.isLoading {
                        ProgressView().frame(width: 40, height: 40)
                    } else {
                        RHIcon(name: .refresh, size: 18, color: .white)
                            .frame(width: 40, height: 40)
                            .background(Color.rhAccent)
                            .clipShape(SketchRoundedRect(radius: 10))
                            .shadow(color: Color.rhInk.opacity(0.15), radius: 0, x: 2, y: 2)
                    }
                }
                .disabled(vm.isLoading || vm.workflowInput.isBlank)
                .buttonStyle(ScaleButtonStyle())
            }
            if let err = vm.errorMessage {
                Text(err).font(.system(size: 12)).foregroundColor(.rhError).transition(.opacity)
            }
            HStack(spacing: 6) {
                Circle().fill(Color.rhSuccess).frame(width: 7, height: 7)
                Text("就绪").font(.system(size: 12)).foregroundColor(.rhSecondary)
                Spacer()
            }
        }
        .sketchCard()
    }

    // MARK: - Workflow Info Card
    private var workflowInfoCard: some View {
        HStack(spacing: 12) {
            Group {
                switch vm.workflowType {
                case .textToImage: RHIcon(name: .image, size: 20, color: .rhAccent)
                case .textToVideo, .imageToVideo: RHIcon(name: .video, size: 20, color: .rhAccent)
                case .unknown: RHIcon(name: .workflow, size: 20, color: .rhSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.currentWorkflowId).font(.system(size: 14, weight: .medium)).foregroundColor(.rhPrimary).lineLimit(1)
                Text(vm.workflowType.displayName).font(.system(size: 12)).foregroundColor(.rhSecondary)
            }
            Spacer()
            if vm.duckNodeInfo != nil {
                HStack(spacing: 4) {
                    RHIcon(name: .duck, size: 14, color: .rhWarning)
                    Text("鸭鸭图").font(.system(size: 11, weight: .medium)).foregroundColor(.rhWarning)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.rhWarning.opacity(0.12))
                .clipShape(SketchRoundedRect(radius: 8))
            }
        }
        .sketchCard(padding: 12)
    }

    // MARK: - Plus Toggle Card
    private var plusToggleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("✦").font(.system(size: 11)).foregroundColor(.rhGold)
                    Text("Plus 模式").font(.system(size: 14, weight: .medium)).foregroundColor(.rhPrimary)
                }
                Text("开启后以 Plus 优先级提交任务").font(.system(size: 12)).foregroundColor(.rhSecondary)
            }
            Spacer()
            Toggle("", isOn: $vm.isPlusMode).labelsHidden().tint(.rhAccent)
        }
        .sketchCard(padding: 14)
    }

    // MARK: - Submit Button
    private var submitButton: some View {
        Button { Task { await vm.submit() } } label: {
            HStack(spacing: 8) {
                if vm.isSubmitting { ProgressView().tint(.white) }
                else { Text("✦").font(.system(size: 13)).foregroundColor(.white.opacity(0.8)) }
                Text(vm.isSubmitting ? "提交中..." : "提交任务")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(canSubmitNow ? Color.rhAccent : Color.rhSecondary.opacity(0.35))
            .clipShape(SketchRoundedRect(radius: 12))
            .overlay(SketchRoundedRect(radius: 12).stroke(Color.rhInk.opacity(canSubmitNow ? 0.2 : 0), lineWidth: 1.5))
            .shadow(color: Color.rhInk.opacity(canSubmitNow ? 0.18 : 0), radius: 0, x: 2, y: 3)
        }
        .disabled(!canSubmitNow)
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Workflow History Card
    private var workflowHistoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sketchSectionLabel("历史记录", star: false)
                Spacer()
                if vm.workflowHistory.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.showAllHistory.toggle() }
                    } label: {
                        Text(vm.showAllHistory ? "收起" : "更多")
                            .font(.system(size: 12)).foregroundColor(.rhAccent)
                    }
                }
            }
            let displayed = vm.showAllHistory ? vm.workflowHistory : Array(vm.workflowHistory.prefix(3))
            ForEach(displayed) { item in
                Button {
                    if item.itemType == .aiApp {
                        appVm.webappInput = item.workflowId
                        Task { await appVm.fetchNodes() }
                    } else { vm.selectHistory(item) }
                } label: {
                    HStack(spacing: 10) {
                        RHIcon(name: .workflow, size: 14, color: .rhAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.workflowId).font(.system(size: 13, weight: .medium)).foregroundColor(.rhPrimary).lineLimit(1)
                            Text(item.workflowType).font(.system(size: 11)).foregroundColor(.rhSecondary)
                        }
                        Spacer()
                        Text(item.itemType == .aiApp ? "应用" : historyTypeLabel(item.workflowType))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(item.itemType == .aiApp ? .rhAccent : .rhSecondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(item.itemType == .aiApp ? Color.rhAccent.opacity(0.1) : Color.rhBorder.opacity(0.4))
                            .clipShape(SketchRoundedRect(radius: 5))
                        RHIcon(name: .chevron, size: 12, color: .rhBorder)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.removeHistory(item) }
                    } label: { Label("删除", systemImage: "trash") }
                }
                if item.workflowId != displayed.last?.workflowId { Divider() }
            }
        }
        .sketchCard()
    }

    // MARK: - Helpers
    private func sketchSectionLabel(_ title: String, star: Bool) -> some View {
        HStack(spacing: 6) {
            if star { Text("✦").font(.system(size: 11)).foregroundColor(.rhAccent) }
            else { RoundedRectangle(cornerRadius: 2).fill(Color.rhAccent).frame(width: 3, height: 14) }
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.rhPrimary)
        }
    }

    private func historyTypeLabel(_ workflowType: String) -> String {
        switch workflowType {
        case "文生图": return "文生图"
        case "文生视频": return "文生视频"
        case "图生视频": return "图生视频"
        default: return "工作流"
        }
    }

    private var canSubmitNow: Bool { !vm.isSubmitting && appState.canSubmit && vm.workflowDetail != nil }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
