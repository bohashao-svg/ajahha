import SwiftUI
import SafariServices
import WebKit

// MARK: - Home View
// Layout: sticky header bar → scrollable content → floating action bar at bottom
struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @StateObject private var appVm = AppViewModel()
    @StateObject private var grokWebVm = GrokWebViewModel()
    @EnvironmentObject private var appState: AppState

    @State private var showTaskCenter = false
    @State private var showSettings   = false
    @State private var showProfile    = false
    @State private var showPremium    = false
    @State private var showGrok       = false
    @State private var showGacha      = false
    @State private var showAPIKeyAlert = false
    @State private var unifiedInput: String = ""

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // ── Scrollable content ───────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Top spacer for nav bar
                        Color.clear.frame(height: 8)

                        // Hero status card
                        heroCard

                        // Input section
                        inputSection

                        // Dynamic form (workflow or AI app)
                        if appVm.isLoading || vm.isLoading {
                            loadingSection
                        } else if !appVm.nodes.isEmpty {
                            aiAppSection
                        } else if vm.workflowDetail != nil {
                            workflowSection
                        }

                        // Quick-access row
                        quickAccessRow

                        // History
                        if !vm.workflowHistory.isEmpty && vm.workflowDetail == nil && appVm.nodes.isEmpty {
                            historySection
                        }

                        // Footer
                        Text("By：iPhone83Plus")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.2))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 100)
                    }
                    .padding(.horizontal, 16)
                }
                .background(AnimatedMeshBackground().ignoresSafeArea())

                // ── Floating bottom bar ──────────────────────────────────
                floatingBottomBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showTaskCenter) {
                TaskCenterView().environmentObject(appState)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showProfile)  { ProfileView() }
            .sheet(isPresented: $showPremium) {
                PremiumWorkflowView { id in
                    unifiedInput = id; fetchUnified()
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

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
            }
        }
        ToolbarItem(placement: .principal) {
            Text("人民万岁")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [.white, Color(hex: "#8B9CC8")],
                    startPoint: .leading, endPoint: .trailing
                ))
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showProfile = true } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 30, height: 30)
                    Image(systemName: "person.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI 创作工作台")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.pendingCount > 0 ? Color(hex: "#FFD166") : Color(hex: "#4ECDC4"))
                        .frame(width: 7, height: 7)
                        .shadow(color: (appState.pendingCount > 0 ? Color(hex: "#FFD166") : Color(hex: "#4ECDC4")).opacity(0.8), radius: 4)
                    Text(appState.pendingCount > 0 ? "\(appState.pendingCount) 个任务进行中" : "就绪")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
            Spacer()
            // Task center badge button
            Button { showTaskCenter = true } label: {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                    if appState.pendingCount > 0 {
                        Text("\(min(appState.pendingCount, 99))")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color(hex: "#FF6B6B"))
                            .clipShape(Capsule())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(LiquidButtonStyle())
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("工作流 / AI 应用", systemImage: "link")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.45))
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.35))
                    TextField("输入 ID 或链接", text: $unifiedInput)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .tint(Color(hex: "#6C8EFF"))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit { fetchUnified() }
                    if !unifiedInput.isEmpty {
                        Button { unifiedInput = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))

                // Fetch button
                Button { fetchUnified() } label: {
                    Group {
                        if vm.isLoading || appVm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .background(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 10, y: 4)
                }
                .disabled(vm.isLoading || appVm.isLoading || unifiedInput.isBlank)
                .buttonStyle(LiquidButtonStyle())
            }

            // Status pill
            if let err = vm.errorMessage ?? appVm.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FF6B6B"))
            } else {
                let loaded = vm.workflowDetail != nil || !appVm.nodes.isEmpty
                if loaded {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#4ECDC4"))
                        Text(vm.workflowDetail != nil
                             ? "工作流已加载 · \(vm.workflowType.displayName)"
                             : "AI 应用已加载 · \(appVm.nodes.count) 个节点")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#4ECDC4"))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Loading Section
    private var loadingSection: some View {
        VStack(spacing: 12) {
            NodeFormCardSkeleton()
        }
        .transition(.opacity)
    }

    // MARK: - AI App Section
    private var aiAppSection: some View {
        VStack(spacing: 12) {
            sectionHeader("节点参数", icon: "slider.horizontal.3")
            VStack(spacing: 0) {
                ForEach(appVm.nodes.indices, id: \.self) { i in
                    AppNodeRow(node: $appVm.nodes[i],
                               selectedImages: $appVm.selectedImages,
                               selectedVideos: $appVm.selectedVideos)
                    if i < appVm.nodes.count - 1 {
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 16)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))

            submitButton(
                label: appVm.isSubmitting ? "提交中..." : "提交任务",
                isLoading: appVm.isSubmitting,
                disabled: appVm.isSubmitting
            ) { Task { await appVm.submit() } }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Workflow Section
    private var workflowSection: some View {
        VStack(spacing: 12) {
            // Workflow info pill
            HStack(spacing: 10) {
                Image(systemName: workflowIcon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#6C8EFF"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "#6C8EFF").opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.currentWorkflowId).font(.system(size: 13, weight: .medium)).foregroundColor(.white).lineLimit(1)
                    Text(vm.workflowType.displayName).font(.system(size: 11)).foregroundColor(Color.white.opacity(0.45))
                }
                Spacer()
                if vm.duckNodeInfo != nil {
                    Label("鸭鸭图", systemImage: "tortoise.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#FFD166"))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(hex: "#FFD166").opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))

            // Form
            sectionHeader("参数配置", icon: "slider.horizontal.3")
            ParameterFormView(fields: $vm.formFields)

            // Plus toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plus 模式").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    Text("优先队列，更快出图").font(.system(size: 12)).foregroundColor(Color.white.opacity(0.4))
                }
                Spacer()
                Toggle("", isOn: $vm.isPlusMode).labelsHidden().tint(Color(hex: "#6C8EFF"))
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))

            submitButton(
                label: vm.isSubmitting ? "提交中..." : "提交任务",
                isLoading: vm.isSubmitting,
                disabled: !canSubmitNow
            ) { Task { await vm.submit() } }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Quick Access Row
    private var quickAccessRow: some View {
        HStack(spacing: 10) {
            quickTile(icon: "brain.head.profile", label: "卸甲 AI",
                      color: Color(hex: "#FFD166")) { showGrok = true }
            quickTile(icon: "rectangle.stack.fill", label: "批量抽卡",
                      color: Color(hex: "#FF6B6B")) { showGacha = true }
            quickTile(icon: "star.fill", label: "精品工作流",
                      color: Color(hex: "#A78BFA")) { showPremium = true }
        }
    }

    private func quickTile(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(LiquidButtonStyle())
    }

    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("最近使用", icon: "clock")
                Spacer()
                if vm.workflowHistory.count > 3 {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            vm.showAllHistory.toggle()
                        }
                    } label: {
                        Text(vm.showAllHistory ? "收起" : "全部")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#6C8EFF"))
                    }
                }
            }

            let items = vm.showAllHistory ? vm.workflowHistory : Array(vm.workflowHistory.prefix(3))
            VStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        unifiedInput = item.workflowId
                        if item.itemType == .aiApp {
                            appVm.webappInput = item.workflowId
                            Task { await appVm.fetchNodes() }
                        } else {
                            vm.selectHistory(item)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.itemType == .aiApp ? "app.badge" : "arrow.triangle.branch")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#6C8EFF"))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: "#6C8EFF").opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.workflowId)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white).lineLimit(1)
                                Text(item.workflowType)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.2))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .buttonStyle(LiquidButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation { vm.removeHistory(item) }
                        } label: { Label("删除", systemImage: "trash") }
                    }
                    if item.workflowId != items.last?.workflowId {
                        Divider().background(Color.white.opacity(0.07)).padding(.leading, 58)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    // MARK: - Floating Bottom Bar
    private var floatingBottomBar: some View {
        // Only show when a form is loaded and ready to submit
        EmptyView()
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.white.opacity(0.45))
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func submitButton(label: String, isLoading: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading { ProgressView().tint(.white).scaleEffect(0.85) }
                Text(label)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(
                disabled
                ? AnyShapeStyle(Color.white.opacity(0.08))
                : AnyShapeStyle(LinearGradient(
                    colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                    startPoint: .leading, endPoint: .trailing
                ))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: disabled ? .clear : Color(hex: "#6C8EFF").opacity(0.4), radius: 14, y: 6)
        }
        .disabled(disabled)
        .buttonStyle(LiquidButtonStyle())
    }

    private var workflowIcon: String {
        switch vm.workflowType {
        case .textToImage: return "photo"
        case .textToVideo, .imageToVideo: return "video"
        case .unknown: return "arrow.triangle.branch"
        }
    }

    private var canSubmitNow: Bool {
        !vm.isSubmitting && appState.canSubmit && vm.workflowDetail != nil
    }

    private func fetchUnified() {
        let input = unifiedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        vm.workflowDetail = nil; vm.formFields = []
        appVm.nodes = []; appVm.errorMessage = nil; vm.errorMessage = nil
        let isWebapp = input.lowercased().contains("webapp") || input.lowercased().contains("app")
        if isWebapp {
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
