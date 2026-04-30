import SwiftUI

// MARK: - Gacha View
// Layout: dashboard-style — config panel left, live task feed right (on iPad);
// on iPhone: vertical stack with sticky submit bar at bottom
struct GachaView: View {
    @StateObject private var vm = GachaViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Warning banner
                        warningBanner

                        // Config card
                        configCard

                        // Extra fields
                        if vm.targetLoaded && !vm.extraFields.isEmpty {
                            extraFieldsCard
                        }

                        // Prompt editor
                        promptCard

                        // Preview
                        if !vm.parsedPrompts.isEmpty {
                            promptPreview
                        }

                        // Task feed
                        if !vm.gachaTasks.isEmpty {
                            taskFeed
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.targetLoaded)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.gachaTasks.count)
                }
                .background(AnimatedMeshBackground().ignoresSafeArea())

                // Sticky submit bar
                if vm.targetLoaded && !vm.parsedPrompts.isEmpty {
                    submitBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: RHIconName.gacha.rawValue)
                            .font(.system(size: 14))
                            .foregroundStyle(LinearGradient(
                                colors: [Color(hex: "#FF6B6B"), Color(hex: "#FFD166")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                        Text("批量抽卡")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: RHIconName.close.rawValue).font(.system(size: 15, weight: .semibold)).foregroundColor(Color.white.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - Warning Banner
    private var warningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: RHIconName.warning.rawValue)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#FFD166"))
            VStack(alignment: .leading, spacing: 2) {
                Text("注意：批量消耗").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "#FFD166"))
                Text("并发提交多个任务，可能快速消耗余额")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#FFD166").opacity(0.65))
            }
            Spacer()
        }
        .padding(14)
        .background(Color(hex: "#FFD166").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "#FFD166").opacity(0.2), lineWidth: 1))
    }

    // MARK: - Config Card
    private var configCard: some View {
        VStack(spacing: 14) {
            sectionLabel("配置", icon: "gearshape")

            // API Key
            HStack(spacing: 10) {
                Image(systemName: RHIconName.key.rawValue).font(.system(size: 14)).foregroundColor(Color(hex: "#FFD166")).frame(width: 20)
                SecureField("抽卡专用 API Key", text: $vm.gachaApiKey)
                    .font(.system(size: 14)).foregroundColor(.white)
                    .tint(Color(hex: "#6C8EFF")).autocapitalization(.none).disableAutocorrection(true)
                    .onSubmit { vm.saveApiKey() }
                Button { vm.saveApiKey() } label: {
                    Text("保存").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: "#6C8EFF"))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Target ID + fetch
            HStack(spacing: 10) {
                TextField("工作流 / AI 应用 ID 或链接", text: $vm.targetId)
                    .font(.system(size: 14)).foregroundColor(.white)
                    .tint(Color(hex: "#6C8EFF")).autocapitalization(.none).disableAutocorrection(true)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit { Task { await vm.fetchTarget() } }

                Button { Task { await vm.fetchTarget() } } label: {
                    Group {
                        if vm.isLoadingTarget { ProgressView().tint(.white) }
                        else { Image(systemName: RHIconName.submit.rawValue).font(.system(size: 15, weight: .semibold)).foregroundColor(.white) }
                    }
                    .frame(width: 44, height: 44)
                    .background(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 8, y: 3)
                }
                .disabled(vm.isLoadingTarget || vm.targetId.isBlank)
                .buttonStyle(LiquidButtonStyle())
            }

            // Status
            if let err = vm.errorMessage {
                Text(err).font(.system(size: 12)).foregroundColor(Color(hex: "#FF6B6B"))
            } else if vm.targetLoaded {
                HStack(spacing: 6) {
                    Image(systemName: RHIconName.success.rawValue).font(.system(size: 12)).foregroundColor(Color(hex: "#4ECDC4"))
                    Text(vm.isWebApp ? "AI 应用已加载" : "工作流已加载 · \(vm.workflowType.displayName)")
                        .font(.system(size: 12)).foregroundColor(Color(hex: "#4ECDC4"))
                }
                .transition(.opacity)
            }

            // Concurrency stepper
            HStack {
                Text("并发数").font(.system(size: 14)).foregroundColor(Color.white.opacity(0.6))
                Spacer()
                HStack(spacing: 0) {
                    Button { if vm.concurrency > 1 { vm.concurrency -= 1 } } label: {
                        Image(systemName: RHIconName.cancelled.rawValue).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color.white.opacity(0.08))
                    }
                    Text("\(vm.concurrency)")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(width: 36)
                    Button { if vm.concurrency < 10 { vm.concurrency += 1 } } label: {
                        Image(systemName: RHIconName.add.rawValue).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color.white.opacity(0.08))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Extra Fields
    private var extraFieldsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("固定参数（所有任务共用）", icon: "slider.horizontal.3")
            ParameterFormView(fields: $vm.extraFields)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Prompt Card
    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("提示词列表", icon: "text.alignleft")
                Spacer()
                if vm.promptCount > 0 {
                    Text("\(vm.promptCount) 条")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#6C8EFF"))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: "#6C8EFF").opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            ZStack(alignment: .topLeading) {
                if vm.promptsText.isEmpty {
                    Text("每行输入一条提示词，支持批量粘贴...")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.25))
                        .padding(.horizontal, 14).padding(.vertical, 13)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $vm.promptsText)
                    .font(.system(size: 14)).foregroundColor(.white)
                    .tint(Color(hex: "#6C8EFF"))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(.horizontal, 10).padding(.vertical, 8)
            }
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Prompt Preview
    private var promptPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("预览（前 5 条）", icon: "eye")
            ForEach(Array(vm.parsedPrompts.prefix(5).enumerated()), id: \.offset) { i, p in
                HStack(spacing: 10) {
                    Text("\(i+1)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Color(hex: "#6C8EFF"))
                        .frame(width: 22, height: 22)
                        .background(Color(hex: "#6C8EFF").opacity(0.12))
                        .clipShape(Circle())
                    Text(p).font(.system(size: 13)).foregroundColor(Color.white.opacity(0.7)).lineLimit(2)
                    Spacer()
                }
            }
            if vm.parsedPrompts.count > 5 {
                Text("... 还有 \(vm.parsedPrompts.count - 5) 条")
                    .font(.system(size: 12)).foregroundColor(Color.white.opacity(0.3))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Task Feed
    private var taskFeed: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("提交结果", icon: "chart.bar")
                Spacer()
                let done = vm.gachaTasks.filter { $0.status == .completed || $0.status == .failed }.count
                Text("\(done)/\(vm.gachaTasks.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.4))
            }

            // Progress overview bar
            GeometryReader { geo in
                let total = CGFloat(vm.gachaTasks.count)
                let done = CGFloat(vm.gachaTasks.filter { $0.status == .completed }.count)
                let failed = CGFloat(vm.gachaTasks.filter { $0.status == .failed }.count)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07)).frame(height: 6)
                    HStack(spacing: 0) {
                        Capsule().fill(Color(hex: "#4ECDC4")).frame(width: total > 0 ? geo.size.width * done/total : 0, height: 6)
                        Capsule().fill(Color(hex: "#FF6B6B")).frame(width: total > 0 ? geo.size.width * failed/total : 0, height: 6)
                    }
                }
            }
            .frame(height: 6)

            ForEach(vm.gachaTasks) { task in
                HStack(spacing: 10) {
                    Circle().fill(task.status.color).frame(width: 8, height: 8)
                        .shadow(color: task.status.color.opacity(0.6), radius: 3)
                    Text(task.prompt).font(.system(size: 13)).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    if let url = task.outputUrls.first {
                        RHRemoteImage(url: url, contentMode: .fill, cornerRadius: 6)
                            .frame(width: 36, height: 36)
                    } else if task.status == .running {
                        ProgressView().scaleEffect(0.6).tint(task.status.color)
                    }
                }
                .padding(.vertical, 4)
                if task.id != vm.gachaTasks.last?.id {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Sticky Submit Bar
    private var submitBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.08))
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.promptCount) 个任务").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Text("并发 \(vm.concurrency) 个").font(.system(size: 12)).foregroundColor(Color.white.opacity(0.4))
                }
                Spacer()
                Button { Task { await vm.startBatch() } } label: {
                    HStack(spacing: 8) {
                        if vm.isRunning {
                            ProgressView().tint(.white).scaleEffect(0.8)
                            let done = vm.gachaTasks.filter { $0.status == .completed || $0.status == .failed }.count
                            Text("\(done)/\(vm.gachaTasks.count)").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        } else {
                            Image(systemName: RHIconName.running.rawValue).font(.system(size: 14)).foregroundColor(.white)
                            Text("开始批量").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 22).frame(height: 46)
                    .background(vm.isRunning
                        ? AnyShapeStyle(Color.white.opacity(0.1))
                        : AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "#FF6B6B"), Color(hex: "#E05555")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                    )
                    .clipShape(Capsule())
                    .shadow(color: vm.isRunning ? .clear : Color(hex: "#FF6B6B").opacity(0.4), radius: 10, y: 4)
                }
                .disabled(vm.isRunning || !vm.canStart)
                .buttonStyle(LiquidButtonStyle())
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Helper
    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.white.opacity(0.4))
            .textCase(.uppercase).tracking(0.5)
    }
}
