import SwiftUI
import SafariServices
import WebKit

// MARK: - Home View
struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @StateObject private var appVm = AppViewModel()
    @StateObject private var grokWebVm = GrokWebViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showTaskCenter = false
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var showAPIKeyAlert = false
    @State private var showPremium = false
    @State private var showGrok = false
    @State private var showGacha = false
    @State private var unifiedInput: String = ""

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        premiumEntryCard.padding(.horizontal, 16)
                        unifiedInputCard.padding(.horizontal, 16)

                        if appVm.isLoading {
                            NodeFormCardSkeleton().padding(.horizontal, 16).transition(.opacity)
                        } else if !appVm.nodes.isEmpty {
                            VStack(spacing: 16) {
                                aiAppNodeCard.transition(.opacity.combined(with: .move(edge: .top)))
                                aiAppSubmitButton.transition(.opacity).padding(.horizontal, 16)
                            }
                        }

                        if vm.isLoading {
                            NodeFormCardSkeleton().padding(.horizontal, 16).transition(.opacity)
                        } else if vm.workflowDetail != nil {
                            VStack(spacing: 16) {
                                workflowInfoCard.padding(.horizontal, 16).transition(.opacity.combined(with: .move(edge: .top)))
                                ParameterFormView(fields: $vm.formFields).padding(.horizontal, 16).transition(.opacity.combined(with: .move(edge: .top)))
                                plusToggleCard.padding(.horizontal, 16).transition(.opacity)
                                submitButton.padding(.horizontal, 16).transition(.opacity)
                            }
                        }

                        grokButton.padding(.horizontal, 16)
                        gachaEntryCard.padding(.horizontal, 16)
                        Spacer(minLength: 24)

                        if !vm.workflowHistory.isEmpty && vm.workflowDetail == nil && appVm.nodes.isEmpty {
                            workflowHistoryCard.padding(.horizontal, 16)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Text("By：iPhone83Plus")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#8B9CC8").opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 20)
                    }
                    .padding(.top, 12)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: appVm.nodes.isEmpty)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.workflowDetail == nil)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.workflowHistory.isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        GlassIconButton(icon: .settings, size: 18, color: Color(hex: "#8B9CC8"))
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        Text("人民万岁")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#F0F4FF"), Color(hex: "#8B9CC8")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button { showProfile = true } label: {
                            GlassIconButton(icon: .image, size: 18, color: Color(hex: "#8B9CC8"))
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
                    unifiedInput = workflowId
                    fetchUnified()
                }
            }
            .sheet(isPresented: $vm.showPromptSelector) {
                PromptSelectorView(fields: vm.availablePromptFields, onConfirm: { vm.applyPromptSelection($0) })
            }
            .sheet(isPresented: $showGrok) {
                GrokWebView(webView: grokWebVm.webView).ignoresSafeArea()
            }
            .sheet(isPresented: $showGacha) { GachaView() }
            .alert("请先配置 API 密钥", isPresented: $showAPIKeyAlert) {
                Button("去配置") { showSettings = true }
                Button("取消", role: .cancel) {}
            }
            .onAppear { if !StorageService.shared.hasAPIKey { showAPIKeyAlert = true } }
        }
    }

    // MARK: - Premium Entry Card
    private var premiumEntryCard: some View {
        Button { showPremium = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    LiquidGlassShape(radius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#6C8EFF").opacity(0.25), Color(hex: "#A78BFA").opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            LiquidGlassShape(radius: 14)
                                .stroke(Color(hex: "#6C8EFF").opacity(0.4), lineWidth: 1)
                        )
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Text("✦").font(.system(size: 9)).foregroundColor(Color(hex: "#FFD166"))
                            Text("★").font(.system(size: 13)).foregroundColor(Color(hex: "#6C8EFF"))
                            Text("✦").font(.system(size: 9)).foregroundColor(Color(hex: "#FFD166"))
                        }
                        Text("精品").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "#6C8EFF"))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("精品工作流 / AI 应用")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "#F0F4FF"))
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(
                                LiquidGlassShape(radius: 4)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                            )
                    }
                    Text("精选优质工作流，一键导入使用")
                        .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
                }
                Spacer()
                RHIcon(name: .chevron, size: 14, color: Color(hex: "#6C8EFF").opacity(0.7))
            }
            .padding(14)
            .glassCard(radius: 16)
        }
        .buttonStyle(LiquidButtonStyle())
    }

    // MARK: - Unified Input Card
    private var unifiedInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            glassLabel("工作流 / AI 应用", accent: true)
            HStack(spacing: 10) {
                TextField("输入工作流或 AI 应用 ID / 链接", text: $unifiedInput)
                    .font(.system(size: 15)).foregroundColor(Color(hex: "#F0F4FF"))
                    .tint(Color(hex: "#6C8EFF"))
                    .autocapitalization(.none).disableAutocorrection(true)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(LiquidGlassShape(radius: 10).fill(Color.white.opacity(0.05)))
                    .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                    .onSubmit { fetchUnified() }

                Button { fetchUnified() } label: {
                    let isLoading = vm.isLoading || appVm.isLoading
                    if isLoading {
                        ProgressView().frame(width: 40, height: 40)
                    } else {
                        RHIcon(name: .refresh, size: 18, color: .white)
                            .frame(width: 40, height: 40)
                            .background(
                                LiquidGlassShape(radius: 10)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                            )
                            .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                            .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 10, x: 0, y: 0)
                    }
                }
                .disabled(vm.isLoading || appVm.isLoading || unifiedInput.isBlank)
                .buttonStyle(LiquidButtonStyle())
            }

            if let err = vm.errorMessage ?? appVm.errorMessage {
                Text(err).font(.system(size: 12)).foregroundColor(Color(hex: "#FF6B6B")).transition(.opacity)
            }

            HStack(spacing: 6) {
                let hasResult = vm.workflowDetail != nil || !appVm.nodes.isEmpty
                Circle()
                    .fill(hasResult ? Color(hex: "#4ECDC4") : Color(hex: "#8B9CC8").opacity(0.4))
                    .frame(width: 7, height: 7)
                    .shadow(color: hasResult ? Color(hex: "#4ECDC4").opacity(0.6) : .clear, radius: 4)
                Group {
                    if vm.workflowDetail != nil {
                        Text("工作流已加载 · \(vm.workflowType.displayName)")
                    } else if !appVm.nodes.isEmpty {
                        Text("AI 应用已加载 · \(appVm.nodes.count) 个参数节点")
                    } else {
                        Text("输入 ID 后点击刷新")
                    }
                }
                .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
                Spacer()
            }
        }
        .sketchCard()
    }

    // MARK: - AI App Node Card
    private var aiAppNodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            glassLabel("节点参数", accent: false)
            ForEach(appVm.nodes.indices, id: \.self) { i in
                AppNodeRow(node: $appVm.nodes[i], selectedImages: $appVm.selectedImages, selectedVideos: $appVm.selectedVideos)
                if i < appVm.nodes.count - 1 {
                    Divider().background(Color.white.opacity(0.08)).padding(.vertical, 4)
                }
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
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                LiquidGlassShape(radius: 14)
                    .fill(appVm.isSubmitting
                        ? AnyShapeStyle(Color.white.opacity(0.06))
                        : AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    )
            )
            .overlay(LiquidGlassShape(radius: 14).stroke(Color.white.opacity(appVm.isSubmitting ? 0.06 : 0.2), lineWidth: 1))
            .shadow(color: appVm.isSubmitting ? .clear : Color(hex: "#6C8EFF").opacity(0.45), radius: 16, x: 0, y: 4)
        }
        .disabled(appVm.isSubmitting)
        .buttonStyle(LiquidButtonStyle())
    }

    // MARK: - Workflow Info Card
    private var workflowInfoCard: some View {
        HStack(spacing: 12) {
            ZStack {
                LiquidGlassShape(radius: 12)
                    .fill(Color(hex: "#6C8EFF").opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(LiquidGlassShape(radius: 12).stroke(Color(hex: "#6C8EFF").opacity(0.3), lineWidth: 0.8))
                Group {
                    switch vm.workflowType {
                    case .textToImage: RHIcon(name: .image, size: 20, color: Color(hex: "#6C8EFF"))
                    case .textToVideo, .imageToVideo: RHIcon(name: .video, size: 20, color: Color(hex: "#6C8EFF"))
                    case .unknown: RHIcon(name: .workflow, size: 20, color: Color(hex: "#8B9CC8"))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.currentWorkflowId).font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "#F0F4FF")).lineLimit(1)
                Text(vm.workflowType.displayName).font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
            }
            Spacer()
            if vm.duckNodeInfo != nil {
                HStack(spacing: 4) {
                    RHIcon(name: .duck, size: 14, color: Color(hex: "#FFD166"))
                    Text("鸭鸭图").font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "#FFD166"))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(LiquidGlassShape(radius: 8).fill(Color(hex: "#FFD166").opacity(0.1)))
                .overlay(LiquidGlassShape(radius: 8).stroke(Color(hex: "#FFD166").opacity(0.25), lineWidth: 0.8))
            }
        }
        .sketchCard(padding: 12)
    }

    // MARK: - Plus Toggle Card
    private var plusToggleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("✦").font(.system(size: 11)).foregroundColor(Color(hex: "#FFD166"))
                    Text("Plus 模式").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "#F0F4FF"))
                }
                Text("开启后以 Plus 优先级提交任务").font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
            }
            Spacer()
            Toggle("", isOn: $vm.isPlusMode).labelsHidden().tint(Color(hex: "#6C8EFF"))
        }
        .sketchCard(padding: 14)
    }

    // MARK: - Submit Button (workflow)
    private var submitButton: some View {
        Button { Task { await vm.submit() } } label: {
            HStack(spacing: 8) {
                if vm.isSubmitting { ProgressView().tint(.white) }
                else { Text("✦").font(.system(size: 13)).foregroundColor(.white.opacity(0.8)) }
                Text(vm.isSubmitting ? "提交中..." : "提交任务")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                LiquidGlassShape(radius: 14)
                    .fill(canSubmitNow
                        ? LinearGradient(
                            colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)], startPoint: .leading, endPoint: .trailing)
                    )
            )
            .overlay(LiquidGlassShape(radius: 14).stroke(Color.white.opacity(canSubmitNow ? 0.2 : 0.06), lineWidth: 1))
            .shadow(color: canSubmitNow ? Color(hex: "#6C8EFF").opacity(0.45) : .clear, radius: 16, x: 0, y: 4)
        }
        .disabled(!canSubmitNow)
        .buttonStyle(LiquidButtonStyle())
    }

    // MARK: - Grok Button
    private var grokButton: some View {
        Button { showGrok = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    LiquidGlassShape(radius: 14)
                        .fill(Color(hex: "#FFD166").opacity(0.12))
                        .frame(width: 52, height: 52)
                        .overlay(LiquidGlassShape(radius: 14).stroke(Color(hex: "#FFD166").opacity(0.25), lineWidth: 0.8))
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#FFD166"), Color(hex: "#6C8EFF")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("卸甲 AI")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(Color(hex: "#F0F4FF"))
                    Text("点击在应用内打开卸甲 AI 对话")
                        .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
                }
                Spacer()
                RHIcon(name: .chevron, size: 14, color: Color(hex: "#8B9CC8").opacity(0.6))
            }
            .padding(14)
            .glassCard(radius: 16)
        }
        .buttonStyle(LiquidButtonStyle())
    }

    // MARK: - Workflow History Card
    private var workflowHistoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                glassLabel("历史记录", accent: false)
                Spacer()
                if vm.workflowHistory.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.showAllHistory.toggle() }
                    } label: {
                        Text(vm.showAllHistory ? "收起" : "更多")
                            .font(.system(size: 12)).foregroundColor(Color(hex: "#6C8EFF"))
                    }
                }
            }
            let displayed = vm.showAllHistory ? vm.workflowHistory : Array(vm.workflowHistory.prefix(3))
            ForEach(displayed) { item in
                Button {
                    unifiedInput = item.workflowId
                    if item.itemType == .aiApp {
                        appVm.webappInput = item.workflowId
                        Task { await appVm.fetchNodes() }
                    } else {
                        vm.selectHistory(item)
                    }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            LiquidGlassShape(radius: 8)
                                .fill(Color(hex: "#6C8EFF").opacity(0.1))
                                .frame(width: 28, height: 28)
                            RHIcon(name: .workflow, size: 14, color: Color(hex: "#6C8EFF"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.workflowId).font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "#F0F4FF")).lineLimit(1)
                            Text(item.workflowType).font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
                        }
                        Spacer()
                        Text(item.itemType == .aiApp ? "应用" : historyTypeLabel(item.workflowType))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(item.itemType == .aiApp ? Color(hex: "#6C8EFF") : Color(hex: "#8B9CC8"))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(
                                LiquidGlassShape(radius: 5)
                                    .fill(item.itemType == .aiApp ? Color(hex: "#6C8EFF").opacity(0.12) : Color.white.opacity(0.05))
                            )
                        RHIcon(name: .chevron, size: 12, color: Color(hex: "#8B9CC8").opacity(0.4))
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.removeHistory(item) }
                    } label: { Label("删除", systemImage: "trash") }
                }
                if item.workflowId != displayed.last?.workflowId {
                    Divider().background(Color.white.opacity(0.08))
                }
            }
        }
        .sketchCard()
    }

    // MARK: - Gacha Entry Card
    private var gachaEntryCard: some View {
        Button { showGacha = true } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        LiquidGlassShape(radius: 14)
                            .fill(Color(hex: "#FF6B6B").opacity(0.15))
                            .frame(width: 52, height: 52)
                            .overlay(LiquidGlassShape(radius: 14).stroke(Color(hex: "#FF6B6B").opacity(0.25), lineWidth: 0.8))
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#FFD166")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("抽卡批量生成")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(Color(hex: "#F0F4FF"))
                        Text("多提示词并发批量生成，独立运行")
                            .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
                    }
                    Spacer()
                    RHIcon(name: .chevron, size: 14, color: Color(hex: "#8B9CC8").opacity(0.6))
                }
                .padding(14)

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundColor(Color(hex: "#FFD166"))
                    Text("该功能是批量生成，可能会快速消耗你的钱包")
                        .font(.system(size: 11)).foregroundColor(Color(hex: "#FFD166").opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.bottom, 10)
            }
            .glassCard(radius: 16)
        }
        .buttonStyle(LiquidButtonStyle())
    }

    // MARK: - Helpers
    private func fetchUnified() {
        let input = unifiedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        vm.workflowDetail = nil
        vm.formFields = []
        appVm.nodes = []
        appVm.errorMessage = nil
        vm.errorMessage = nil
        let webappId = input.extractWebappId()
        let isWebapp = input.lowercased().contains("webapp") || input.lowercased().contains("app")
        if isWebapp && !webappId.isEmpty {
            appVm.webappInput = input
            Task { await appVm.fetchNodes() }
        } else {
            vm.workflowInput = input
            Task {
                await vm.fetchWorkflow()
                if vm.workflowDetail == nil && vm.errorMessage != nil {
                    vm.errorMessage = nil
                    appVm.webappInput = input
                    await appVm.fetchNodes()
                    if !appVm.nodes.isEmpty { vm.errorMessage = nil }
                }
            }
        }
    }

    private func glassLabel(_ title: String, accent: Bool) -> some View {
        HStack(spacing: 6) {
            if accent {
                LiquidGlassShape(radius: 2)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3, height: 14)
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.6), radius: 4)
            } else {
                LiquidGlassShape(radius: 2)
                    .fill(Color(hex: "#8B9CC8").opacity(0.5))
                    .frame(width: 3, height: 14)
            }
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#F0F4FF"))
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

    // MARK: - Task Center Button
    private var taskCenterButton: some View {
        Button { showTaskCenter = true } label: {
            ZStack(alignment: .topTrailing) {
                GlassIconButton(icon: .tasks, size: 18, color: Color(hex: "#8B9CC8"))
                if appState.pendingCount > 0 {
                    Text("\(appState.pendingCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        )
                        .overlay(Circle().stroke(Color(hex: "#0A0E1A"), lineWidth: 1.5))
                        .offset(x: 6, y: -6)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Persistent WebView
final class GrokWebViewModel: ObservableObject {
    let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.load(URLRequest(url: URL(string: "https://grok.dairoot.cn/")!))
        return wv
    }()
}

struct GrokWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Liquid Button Style (alias kept for compatibility)
// ScaleButtonStyle is already aliased to LiquidButtonStyle in Extensions.swift
