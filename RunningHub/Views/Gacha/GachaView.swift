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
                        workflowInputCard
                        if !vm.prompts.isEmpty { promptListCard }
                        addPromptCard
                        if !vm.prompts.isEmpty { submitButton }
                        if !vm.tasks.isEmpty { taskListCard }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.prompts.count)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.tasks.count)
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
                LiquidGlassShape(radius: 14)
                    .fill(Color(hex: "#FFD166").opacity(0.06))
                LiquidGlassShape(radius: 14)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
        )
        .overlay(LiquidGlassShape(radius: 14).stroke(Color(hex: "#FFD166").opacity(0.2), lineWidth: 0.8))
    }

    // MARK: - Workflow Input Card
    private var workflowInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                LiquidGlassShape(radius: 2)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3, height: 14)
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.6), radius: 4)
                Text("工作流配置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
            }

            HStack(spacing: 10) {
                TextField("工作流 ID", text: $vm.workflowId)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                    .tint(Color(hex: "#6C8EFF"))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(LiquidGlassShape(radius: 10).fill(Color.white.opacity(0.05)))
                    .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.8))

                Button { Task { await vm.fetchWorkflow() } } label: {
                    if vm.isLoadingWorkflow {
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
                .disabled(vm.isLoadingWorkflow || vm.workflowId.isBlank)
                .buttonStyle(LiquidButtonStyle())
            }

            if let err = vm.workflowError {
                Text(err).font(.system(size: 12)).foregroundColor(Color(hex: "#FF6B6B")).transition(.opacity)
            }

            if vm.workflowLoaded {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "#4ECDC4")).frame(width: 7, height: 7)
                        .shadow(color: Color(hex: "#4ECDC4").opacity(0.6), radius: 4)
                    Text("工作流已加载 · \(vm.workflowType)")
                        .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
                    Spacer()
                }
                .transition(.opacity)
            }

            if vm.workflowLoaded {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    Text("固定参数（所有任务共用）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#8B9CC8"))
                    ParameterFormView(fields: $vm.sharedFields)
                }
            }
        }
        .sketchCard()
    }

    // MARK: - Prompt List Card
    private var promptListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                LiquidGlassShape(radius: 2)
                    .fill(Color(hex: "#8B9CC8").opacity(0.5))
                    .frame(width: 3, height: 14)
                Text("提示词列表")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                Spacer()
                Text("\(vm.prompts.count) 条")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
            }

            ForEach(vm.prompts.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    ZStack {
                        LiquidGlassShape(radius: 8)
                            .fill(Color(hex: "#6C8EFF").opacity(0.1))
                            .frame(width: 28, height: 28)
                        Text("\(i + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#6C8EFF"))
                    }

                    Text(vm.prompts[i])
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#F0F4FF"))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            vm.prompts.remove(at: i)
                        }
                    } label: {
                        RHIcon(name: .close, size: 12, color: Color(hex: "#FF6B6B").opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(LiquidGlassShape(radius: 7).fill(Color(hex: "#FF6B6B").opacity(0.08)))
                    }
                    .buttonStyle(LiquidButtonStyle())
                }
                .padding(.vertical, 4)

                if i < vm.prompts.count - 1 {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .sketchCard()
    }

    // MARK: - Add Prompt Card
    private var addPromptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                LiquidGlassShape(radius: 2)
                    .fill(Color(hex: "#4ECDC4").opacity(0.7))
                    .frame(width: 3, height: 14)
                Text("添加提示词")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
            }

            ZStack(alignment: .topLeading) {
                if vm.newPrompt.isEmpty {
                    Text("输入提示词...")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#8B9CC8").opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                TextEditor(text: $vm.newPrompt)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                    .tint(Color(hex: "#6C8EFF"))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .background(LiquidGlassShape(radius: 12).fill(Color.white.opacity(0.05)))
            .overlay(LiquidGlassShape(radius: 12).stroke(Color.white.opacity(0.1), lineWidth: 0.8))

            Button {
                let trimmed = vm.newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    vm.prompts.append(trimmed)
                    vm.newPrompt = ""
                }
            } label: {
                HStack(spacing: 6) {
                    RHIcon(name: .plus, size: 14, color: .white)
                    Text("添加").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(
                    LiquidGlassShape(radius: 10)
                        .fill(vm.newPrompt.isBlank
                            ? Color.white.opacity(0.05)
                            : LinearGradient(
                                colors: [Color(hex: "#4ECDC4"), Color(hex: "#2BA8A0")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(vm.newPrompt.isBlank ? 0.06 : 0.2), lineWidth: 0.8))
                .shadow(color: vm.newPrompt.isBlank ? .clear : Color(hex: "#4ECDC4").opacity(0.35), radius: 8)
            }
            .disabled(vm.newPrompt.isBlank)
            .buttonStyle(LiquidButtonStyle())
        }
        .sketchCard()
    }

    // MARK: - Submit Button
    private var submitButton: some View {
        Button { Task { await vm.submitAll() } } label: {
            HStack(spacing: 8) {
                if vm.isSubmitting {
                    ProgressView().tint(.white)
                    Text("提交中 \(vm.submittedCount)/\(vm.prompts.count)...")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                } else {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 14)).foregroundColor(.white)
                    Text("批量提交 \(vm.prompts.count) 个任务")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                LiquidGlassShape(radius: 14)
                    .fill(vm.isSubmitting
                        ? Color.white.opacity(0.06)
                        : LinearGradient(
                            colors: [Color(hex: "#FF6B6B"), Color(hex: "#E05555")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(LiquidGlassShape(radius: 14).stroke(Color.white.opacity(vm.isSubmitting ? 0.06 : 0.2), lineWidth: 1))
            .shadow(color: vm.isSubmitting ? .clear : Color(hex: "#FF6B6B").opacity(0.4), radius: 16, x: 0, y: 4)
        }
        .disabled(vm.isSubmitting || !vm.workflowLoaded)
        .buttonStyle(LiquidButtonStyle())
    }

    // MARK: - Task List Card
    private var taskListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                LiquidGlassShape(radius: 2)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3, height: 14)
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.6), radius: 4)
                Text("提交结果")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                Spacer()
                Text("\(vm.tasks.count) 个")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
            }

            ForEach(vm.tasks) { task in
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
                        Text(task.workflowName).font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "#F0F4FF")).lineLimit(1)
                        Text(task.status.displayName).font(.system(size: 11)).foregroundColor(task.status.color)
                    }

                    Spacer()

                    Text(task.createdAt.timeString())
                        .font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
                }
                .padding(.vertical, 4)

                if task.id != vm.tasks.last?.id {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .sketchCard()
    }
}
