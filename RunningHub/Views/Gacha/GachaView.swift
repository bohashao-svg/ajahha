import SwiftUI

// MARK: - Gacha View
struct GachaView: View {
    @StateObject private var vm = GachaViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        warningBanner
                        configCard
                        if vm.targetLoaded { extraFieldsCard }
                        promptInputCard
                        if !vm.parsedPrompts.isEmpty { promptPreviewCard }
                        if vm.targetLoaded && !vm.parsedPrompts.isEmpty { submitButton }
                        if !vm.gachaTasks.isEmpty { taskListCard }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.targetLoaded)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.gachaTasks.count)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#FFD166")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        Text("抽卡批量生成")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#F0F4FF"), Color(hex: "#8B9CC8")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        GlassIconButton(icon: .close, size: 18, color: Color(hex: "#8B9CC8"))
                    }
                }
            }
        }
    }

    // MARK: - Warning Banner
    private var warningBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                LiquidGlassShape(radius: 10)
                    .fill(Color(hex: "#FFD166").opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#FFD166"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("注意：批量消耗")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#FFD166"))
                Text("该功能会并发提交多个任务，可能快速消耗余额")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#FFD166").opacity(0.7))
            }
            Spacer()
        }
        .padding(12)
        .background(
            ZStack {
                LiquidGlassShape(radius: 14).fill(Color(hex: "#FFD166").opacity(0.06))
                LiquidGlassShape(radius: 14).fill(
                    LinearGradient(colors: [Color.white.opacity(0.04), Color.clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }
        )
        .overlay(LiquidGlassShape(radius: 14).stroke(Color(hex: "#FFD166").opacity(0.2), lineWidth: 0.8))
    }

    // MARK: - Config Card
    private var configCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            glassLabel("配置", accent: true)

            // API Key
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 14)).foregroundColor(Color(hex: "#FFD166")).frame(width: 20)
                SecureField("抽卡专用 API Key", text: $vm.gachaApiKey)
                    .font(.system(size: 14)).foregroundColor(Color(hex: "#F0F4FF"))
                    .tint(Color(hex: "#6C8EFF")).autocapitalization(.none).disableAutocorrection(true)
                    .onSubmit { vm.saveApiKey() }
                Button { vm.saveApiKey() } label: {
                    Text("保存").font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "#6C8EFF"))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(LiquidGlassShape(radius: 10).fill(Color.white.opacity(0.05)))
            .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.8))

            // Target ID
            HStack(spacing: 10) {
                TextField("工作流 / AI 应用 ID 或链接", text: $vm.targetId)
                    .font(.system(size: 14)).foregroundColor(Color(hex: "#F0F4FF"))
                    .tint(Color(hex: "#6C8EFF")).autocapitalization(.none).disableAutocorrection(true)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(LiquidGlassShape(radius: 10).fill(Color.white.opacity(0.05)))
                    .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                    .onSubmit { Task { await vm.fetchTarget() } }

                Button { Task { await vm.fetchTarget() } } label: {
                    if vm.isLoadingTarget {
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
                            .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 10)
                    }
                }
                .disabled(vm.isLoadingTarget || vm.targetId.isBlank)
                .buttonStyle(LiquidButtonStyle())
            }

            if let err = vm.errorMessage {
                Text(err).font(.system(size: 12)).foregroundColor(Color(hex: "#FF6B6B")).transition(.opacity)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(vm.targetLoaded ? Color(hex: "#4ECDC4") : Color(hex: "#8B9CC8").opacity(0.4))
                    .frame(width: 7, height: 7)
                    .shadow(color: vm.targetLoaded ? Color(hex: "#4ECDC4").opacity(0.6) : .clear, radius: 4)
                Text(vm.targetLoaded
                     ? (vm.isWebApp ? "AI 应用已加载" : "工作流已加载 · \(vm.workflowType.displayName)")
                     : "输入 ID 后点击刷新")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
                Spacer()
            }

            // Concurrency
            HStack {
                Text("并发数").font(.system(size: 13)).foregroundColor(Color(hex: "#8B9CC8"))
                Spacer()
                Stepper("\(vm.concurrency)", value: $vm.concurrency, in: 1...10)
                    .labelsHidden()
                    .tint(Color(hex: "#6C8EFF"))
                Text("\(vm.concurrency)").font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF")).frame(width: 24)
            }
        }
        .sketchCard()
    }

    // MARK: - Extra Fields Card (image/lora)
    @ViewBuilder
    private var extraFieldsCard: some View {
        if !vm.extraFields.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                glassLabel("固定参数（所有任务共用）", accent: false)
                ParameterFormView(fields: $vm.extraFields)
            }
            .sketchCard()
        }
    }

    // MARK: - Prompt Input Card
    private var promptInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                glassLabel("提示词（每行一条）", accent: false)
                Spacer()
                Text("\(vm.promptCount) 条")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
            }

            ZStack(alignment: .topLeading) {
                if vm.promptsText.isEmpty {
                    Text("每行输入一条提示词...")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#8B9CC8").opacity(0.6))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                }
                TextEditor(text: $vm.promptsText)
                    .font(.system(size: 14)).foregroundColor(Color(hex: "#F0F4FF"))
                    .tint(Color(hex: "#6C8EFF"))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(.horizontal, 8).padding(.vertical, 6)
            }
            .background(LiquidGlassShape(radius: 12).fill(Color.white.opacity(0.05)))
            .overlay(LiquidGlassShape(radius: 12).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
        }
        .sketchCard()
    }

    // MARK: - Prompt Preview Card
    private var promptPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            glassLabel("提示词预览", accent: false)
            ForEach(Array(vm.parsedPrompts.prefix(5).enumerated()), id: \.offset) { i, prompt in
                HStack(spacing: 10) {
                    ZStack {
                        LiquidGlassShape(radius: 8).fill(Color(hex: "#6C8EFF").opacity(0.1)).frame(width: 26, height: 26)
                        Text("\(i + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "#6C8EFF"))
                    }
                    Text(prompt).font(.system(size: 13)).foregroundColor(Color(hex: "#F0F4FF")).lineLimit(2)
                    Spacer()
                }
            }
            if vm.parsedPrompts.count > 5 {
                Text("... 还有 \(vm.parsedPrompts.count - 5) 条")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
            }
        }
        .sketchCard()
    }

    // MARK: - Submit Button
    private var submitButton: some View {
        Button { Task { await vm.startBatch() } } label: {
            HStack(spacing: 8) {
                if vm.isRunning {
                    ProgressView().tint(.white)
                    let done = vm.gachaTasks.filter { $0.status == .completed || $0.status == .failed }.count
                    Text("运行中 \(done)/\(vm.gachaTasks.count)...")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                } else {
                    Image(systemName: "rectangle.stack.fill").font(.system(size: 14)).foregroundColor(.white)
                    Text("批量提交 \(vm.promptCount) 个任务")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                LiquidGlassShape(radius: 14)
                    .fill(vm.isRunning
                          ? AnyShapeStyle(Color.white.opacity(0.06))
                          : AnyShapeStyle(LinearGradient(
                              colors: [Color(hex: "#FF6B6B"), Color(hex: "#E05555")],
                              startPoint: .topLeading, endPoint: .bottomTrailing
                          ))
                    )
            )
            .overlay(LiquidGlassShape(radius: 14).stroke(Color.white.opacity(vm.isRunning ? 0.06 : 0.2), lineWidth: 1))
            .shadow(color: vm.isRunning ? .clear : Color(hex: "#FF6B6B").opacity(0.4), radius: 16, x: 0, y: 4)
        }
        .disabled(vm.isRunning || !vm.canStart)
        .buttonStyle(LiquidButtonStyle())
    }

    // MARK: - Task List Card
    private var taskListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                glassLabel("提交结果", accent: true)
                Spacer()
                Text("\(vm.gachaTasks.count) 个").font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
            }

            ForEach(vm.gachaTasks) { task in
                HStack(spacing: 10) {
                    ZStack {
                        LiquidGlassShape(radius: 10)
                            .fill(task.status.color.opacity(0.1))
                            .frame(width: 36, height: 36)
                            .overlay(LiquidGlassShape(radius: 10).stroke(task.status.color.opacity(0.2), lineWidth: 0.6))
                        if task.status == .running {
                            ProgressView().scaleEffect(0.65).tint(task.status.color)
                        } else {
                            Circle().fill(task.status.color).frame(width: 8, height: 8)
                                .shadow(color: task.status.color.opacity(0.6), radius: 4)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.prompt).font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#F0F4FF")).lineLimit(1)
                        Text(task.status.displayName).font(.system(size: 11)).foregroundColor(task.status.color)
                    }
                    Spacer()
                    if let url = task.outputUrls.first {
                        RHRemoteImage(url: url, contentMode: .fill, cornerRadius: 8)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.vertical, 4)
                if task.id != vm.gachaTasks.last?.id {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .sketchCard()
    }

    // MARK: - Helper
    private func glassLabel(_ title: String, accent: Bool) -> some View {
        HStack(spacing: 6) {
            LiquidGlassShape(radius: 2)
                .fill(accent
                      ? AnyShapeStyle(LinearGradient(
                          colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                          startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color(hex: "#8B9CC8").opacity(0.5))
                )
                .frame(width: 3, height: 14)
                .shadow(color: accent ? Color(hex: "#6C8EFF").opacity(0.6) : .clear, radius: 4)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#F0F4FF"))
        }
    }
}
