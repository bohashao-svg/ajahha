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
                    VStack(spacing: 18) {
                        // 顶部装饰横幅
                        heroBanner

                        workflowInputCard

                        if !vm.workflowHistory.isEmpty && vm.workflowDetail == nil {
                            workflowHistoryCard
                        }
                        if vm.workflowDetail != nil {
                            workflowInfoCard
                            ParameterFormView(fields: $vm.formFields)
                            plusToggleCard
                            submitButton
                        }
                        Spacer(minLength: 20)
                        footerView
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color.rhAccentSoft)
                                .frame(width: 34, height: 34)
                            RHIcon(name: .settings, size: 18, color: .rhAccent)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        StarDecoration(size: 14, color: .rhGold)
                        Text("人民万岁")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.rhAccent)
                        StarDecoration(size: 14, color: .rhGold)
                    }
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
            .alert("请先配置 API 密钥", isPresented: $showAPIKeyAlert) {
                Button("去配置") { showSettings = true }
                Button("取消", role: .cancel) {}
            }
            .onAppear {
                if !StorageService.shared.hasAPIKey { showAPIKeyAlert = true }
            }
        }
    }

    // MARK: - Hero Banner
    private var heroBanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#C8392B"), Color(hex: "#A93226")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 88)
                .shadow(color: Color(hex: "#C8392B").opacity(0.35), radius: 14, x: 0, y: 6)

            // 装饰元素
            HStack {
                WheatDecoration()
                    .frame(width: 44, height: 44)
                    .opacity(0.25)
                    .offset(x: -4, y: 8)
                Spacer()
                WheatDecoration()
                    .frame(width: 44, height: 44)
                    .opacity(0.25)
                    .scaleEffect(x: -1)
                    .offset(x: 4, y: 8)
            }
            .padding(.horizontal, 12)

            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    StarDecoration(size: 11, color: .white.opacity(0.7))
                    Text("AI 创作平台")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    StarDecoration(size: 11, color: .white.opacity(0.7))
                }
                Text("人民万岁")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Task Center Button
    private var taskCenterButton: some View {
        Button { showTaskCenter = true } label: {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(Color.rhAccentSoft)
                        .frame(width: 34, height: 34)
                    RHIcon(name: .tasks, size: 18, color: .rhAccent)
                }
                if appState.pendingCount > 0 {
                    Text("\(appState.pendingCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Color.rhGold)
                        .clipShape(Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
    }

    // MARK: - Workflow Input Card
    private var workflowInputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.rhAccent)
                    .frame(width: 3, height: 14)
                Text("工作流")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.rhPrimary)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    RHIcon(name: .workflow, size: 16, color: .rhAccent.opacity(0.7))
                    TextField("输入工作流 ID 或链接", text: $vm.workflowInput)
                        .font(.system(size: 14))
                        .foregroundColor(.rhPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit { Task { await vm.fetchWorkflow() } }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.rhBackground)
                .cornerRadius(14)

                Button {
                    Task { await vm.fetchWorkflow() }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(vm.isLoading || vm.workflowInput.isBlank
                                  ? AnyShapeStyle(Color.rhBorder)
                                  : AnyShapeStyle(LinearGradient(colors: [Color(hex: "#C8392B"), Color(hex: "#A93226")],
                                                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
                            .frame(width: 44, height: 44)
                        if vm.isLoading {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            RHIcon(name: .refresh, size: 18, color: .white)
                        }
                    }
                }
                .disabled(vm.isLoading || vm.workflowInput.isBlank)
            }

            if let err = vm.errorMessage {
                HStack(spacing: 6) {
                    Circle().fill(Color.rhError).frame(width: 6, height: 6)
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.rhError)
                }
            }

            // 状态指示
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
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.rhAccentSoft)
                    .frame(width: 42, height: 42)
                Group {
                    switch vm.workflowType {
                    case .textToImage:  RHIcon(name: .image, size: 20, color: .rhAccent)
                    case .textToVideo, .imageToVideo: RHIcon(name: .video, size: 20, color: .rhAccent)
                    case .unknown: RHIcon(name: .workflow, size: 20, color: .rhSecondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.currentWorkflowId)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.rhPrimary)
                    .lineLimit(1)
                Text(vm.workflowType.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.rhSecondary)
            }

            Spacer()

            if vm.duckNodeInfo != nil {
                HStack(spacing: 4) {
                    RHIcon(name: .duck, size: 13, color: .rhGold)
                    Text("鸭鸭图")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.rhGold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.rhGold.opacity(0.12))
                .cornerRadius(10)
            }
        }
        .rhCard(padding: 14)
    }

    // MARK: - Plus Toggle Card
    private var plusToggleCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.rhGold.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text("✦")
                    .font(.system(size: 16))
                    .foregroundColor(.rhGold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Plus 模式")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.rhPrimary)
                Text("以 Plus 优先级提交任务")
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
            HStack(spacing: 10) {
                if vm.isSubmitting {
                    ProgressView().tint(.white).scaleEffect(0.9)
                } else {
                    StarDecoration(size: 16, color: .white)
                }
                Text(vm.isSubmitting ? "提交中..." : "提交任务")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                canSubmitNow
                    ? LinearGradient(colors: [Color(hex: "#C8392B"), Color(hex: "#A93226")],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.rhBorder, Color.rhBorder],
                                     startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(18)
            .shadow(color: canSubmitNow ? Color(hex: "#C8392B").opacity(0.35) : .clear,
                    radius: 10, x: 0, y: 4)
        }
        .disabled(!canSubmitNow)
    }

    // MARK: - Workflow History Card
    private var workflowHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.rhGold)
                        .frame(width: 3, height: 14)
                    Text("历史工作流")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.rhPrimary)
                }
                Spacer()
                if vm.workflowHistory.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.showAllHistory.toggle()
                        }
                    } label: {
                        Text(vm.showAllHistory ? "收起" : "更多")
                            .font(.system(size: 12, weight: .medium))
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
                        ZStack {
                            Circle()
                                .fill(Color.rhAccentSoft)
                                .frame(width: 32, height: 32)
                            RHIcon(name: .workflow, size: 14, color: .rhAccent)
                        }
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
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if item.workflowId != displayed.last?.workflowId {
                    Divider().background(Color.rhBorder)
                }
            }
        }
        .rhCard()
    }

    // MARK: - Footer
    private var footerView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Rectangle().fill(Color.rhBorder).frame(height: 1)
                StarDecoration(size: 10, color: .rhGold.opacity(0.5))
                Rectangle().fill(Color.rhBorder).frame(height: 1)
            }
            Text("By：iPhone83Plus")
                .font(.system(size: 11))
                .foregroundColor(.rhSecondary.opacity(0.6))
        }
    }

    private var canSubmitNow: Bool {
        !vm.isSubmitting && appState.canSubmit && vm.workflowDetail != nil
    }
}

// MARK: - Star Decoration (五角星)
struct StarDecoration: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Canvas { ctx, sz in
            let s = sz.width
            let cx = s / 2, cy = s / 2
            let r1 = s * 0.5, r2 = s * 0.2
            var path = Path()
            for i in 0..<10 {
                let angle = Double(i) * .pi / 5 - .pi / 2
                let r = i % 2 == 0 ? r1 : r2
                let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
            ctx.fill(path, with: .foreground)
        }
        .foregroundColor(color)
        .frame(width: size, height: size)
    }
}

// MARK: - Wheat Decoration (麦穗)
struct WheatDecoration: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let cx = s * 0.5
            // 茎
            var stem = Path()
            stem.move(to: CGPoint(x: cx, y: s * 0.95))
            stem.addLine(to: CGPoint(x: cx, y: s * 0.1))
            ctx.stroke(stem, with: .foreground, style: StrokeStyle(lineWidth: s * 0.04, lineCap: .round))
            // 麦粒
            let grainPositions: [(CGFloat, CGFloat, Bool)] = [
                (0.35, 0.72, false), (0.65, 0.72, true),
                (0.3, 0.55, false),  (0.7, 0.55, true),
                (0.32, 0.38, false), (0.68, 0.38, true),
                (0.38, 0.22, false), (0.62, 0.22, true),
            ]
            for (x, y, flip) in grainPositions {
                var grain = Path()
                let gx = s * x, gy = s * y
                let w = s * 0.14, h = s * 0.1
                grain.addEllipse(in: CGRect(x: gx - w/2, y: gy - h/2, width: w, height: h))
                ctx.fill(grain, with: .foreground)
                // 连接线
                var line = Path()
                line.move(to: CGPoint(x: cx, y: gy))
                line.addLine(to: CGPoint(x: gx, y: gy))
                ctx.stroke(line, with: .foreground, style: StrokeStyle(lineWidth: s * 0.025, lineCap: .round))
                _ = flip
            }
        }
        .foregroundColor(.white)
    }
}
