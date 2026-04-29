import SwiftUI
import PhotosUI

// MARK: - Gacha View
struct GachaView: View {
    @StateObject private var vm = GachaViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var promptFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        apiKeyCard
                        targetCard
                        if !vm.extraFields.isEmpty { extraFieldsCard }
                        promptCard
                        concurrencyCard
                        startButton
                        if !vm.gachaTasks.isEmpty { progressCard }
                        if vm.gachaTasks.contains(where: { $0.decodedData != nil || !$0.outputUrls.isEmpty }) {
                            resultsGrid
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("抽卡批量生成")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.rhPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.rhPrimary)
                            .frame(width: 30, height: 30)
                            .background(Color.rhCard)
                            .clipShape(SketchRoundedRect(radius: 8))
                            .overlay(SketchRoundedRect(radius: 8).stroke(Color.rhInk.opacity(0.18), lineWidth: 1.2))
                    }
                }
            }
        }
    }

    // MARK: - API Key Card
    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("独立 API Key", icon: "key.fill")
            HStack(spacing: 8) {
                SecureField("输入专用 API Key（与主程序隔离）", text: $vm.gachaApiKey)
                    .font(.system(size: 14)).foregroundColor(.rhPrimary)
                    .autocapitalization(.none).disableAutocorrection(true)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color.rhBackground)
                    .clipShape(SketchRoundedRect(radius: 9))
                    .overlay(SketchRoundedRect(radius: 9).stroke(Color.rhInk.opacity(0.15), lineWidth: 1.2))
                Button { vm.saveApiKey() } label: {
                    Text("保存")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Color.rhAccent)
                        .clipShape(SketchRoundedRect(radius: 9))
                        .shadow(color: Color.rhInk.opacity(0.12), radius: 0, x: 1, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            Text("该 Key 仅在抽卡功能内使用，不影响主程序设置")
                .font(.system(size: 11)).foregroundColor(.rhSecondary)
        }
        .sketchCard()
    }

    // MARK: - Target Card
    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("目标工作流 / AI 应用", icon: "target")
            HStack(spacing: 8) {
                TextField("输入工作流或 AI 应用 ID", text: $vm.targetId)
                    .font(.system(size: 14)).foregroundColor(.rhPrimary)
                    .autocapitalization(.none).disableAutocorrection(true)
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(Color.rhBackground)
                    .clipShape(SketchRoundedRect(radius: 9))
                    .overlay(SketchRoundedRect(radius: 9).stroke(Color.rhInk.opacity(0.15), lineWidth: 1.2))
                    .onSubmit { Task { await vm.fetchTarget() } }
                Button {
                    Task { await vm.fetchTarget() }
                } label: {
                    if vm.isLoadingTarget {
                        ProgressView().frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.rhAccent)
                            .clipShape(SketchRoundedRect(radius: 9))
                            .shadow(color: Color.rhInk.opacity(0.12), radius: 0, x: 1, y: 2)
                    }
                }
                .disabled(vm.isLoadingTarget || vm.targetId.isBlank)
                .buttonStyle(ScaleButtonStyle())
            }

            if let err = vm.errorMessage {
                Text(err).font(.system(size: 12)).foregroundColor(.rhError)
            }

            if vm.targetLoaded {
                HStack(spacing: 6) {
                    Circle().fill(Color.rhSuccess).frame(width: 7, height: 7)
                    Text(vm.isWebApp ? "AI 应用已识别" : "工作流已识别 · \(vm.workflowType.displayName)")
                        .font(.system(size: 12)).foregroundColor(.rhSecondary)
                    if vm.duckNodeInfo != nil {
                        Text("· 鸭鸭编码").font(.system(size: 12)).foregroundColor(.rhWarning)
                    }
                    if vm.isTTEncoded {
                        Text("· TT编码").font(.system(size: 12)).foregroundColor(.rhWarning)
                    }
                }
            }
        }
        .sketchCard()
    }

    // MARK: - Extra Fields Card
    private var extraFieldsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("附加参数（一次性配置）", icon: "slider.horizontal.3")
            Text("图片/LoRA 等参数只需配置一次，所有任务共用")
                .font(.system(size: 11)).foregroundColor(.rhSecondary)
            ParameterFormView(fields: $vm.extraFields)
        }
        .sketchCard()
    }

    // MARK: - Prompt Card
    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("提示词列表", icon: "text.alignleft")
            Text("每行一条提示词，每行对应一个生成任务")
                .font(.system(size: 11)).foregroundColor(.rhSecondary)

            ZStack(alignment: .topLeading) {
                if vm.promptsText.isEmpty {
                    Text("一行一条提示词，例如：\na beautiful sunset\na cute cat")
                        .font(.system(size: 13)).foregroundColor(.rhSecondary.opacity(0.5))
                        .padding(.top, 9).padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $vm.promptsText)
                    .font(.system(size: 13)).foregroundColor(.rhPrimary)
                    .frame(minHeight: 120, maxHeight: 240)
                    .focused($promptFocused)
            }
            .padding(10)
            .background(Color.rhBackground)
            .clipShape(SketchRoundedRect(radius: 10))
            .overlay(SketchRoundedRect(radius: 10).stroke(
                promptFocused ? Color.rhAccent.opacity(0.5) : Color.rhInk.opacity(0.15), lineWidth: 1.2))
            .onTapGesture { promptFocused = true }

            HStack {
                Spacer()
                if vm.promptCount > 0 {
                    Text("共 \(vm.promptCount) 条")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.rhAccent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.rhAccentSoft)
                        .clipShape(SketchRoundedRect(radius: 6))
                }
            }
        }
        .sketchCard()
    }

    // MARK: - Concurrency Card
    private var concurrencyCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                sectionLabel("并发数", icon: "arrow.triangle.branch")
                Text("同时执行的任务数量，建议 2-5")
                    .font(.system(size: 11)).foregroundColor(.rhSecondary)
            }
            Spacer()
            HStack(spacing: 12) {
                Button {
                    if vm.concurrency > 1 { vm.concurrency -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.rhPrimary)
                        .frame(width: 30, height: 30)
                        .background(Color.rhBackground)
                        .clipShape(SketchRoundedRect(radius: 8))
                        .overlay(SketchRoundedRect(radius: 8).stroke(Color.rhInk.opacity(0.18), lineWidth: 1.2))
                }
                .buttonStyle(ScaleButtonStyle())

                Text("\(vm.concurrency)")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.rhPrimary)
                    .frame(minWidth: 28)

                Button {
                    if vm.concurrency < 10 { vm.concurrency += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.rhPrimary)
                        .frame(width: 30, height: 30)
                        .background(Color.rhBackground)
                        .clipShape(SketchRoundedRect(radius: 8))
                        .overlay(SketchRoundedRect(radius: 8).stroke(Color.rhInk.opacity(0.18), lineWidth: 1.2))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .sketchCard(padding: 14)
    }

    // MARK: - Start Button
    private var startButton: some View {
        Button {
            Task { await vm.startBatch() }
        } label: {
            HStack(spacing: 8) {
                if vm.isRunning {
                    ProgressView().tint(.white)
                    Text("生成中...").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14)).foregroundColor(.white)
                    Text(vm.promptCount > 0 ? "开始抽卡（\(vm.promptCount) 条）" : "开始抽卡")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(vm.canStart ? Color.rhAccent : Color.rhSecondary.opacity(0.35))
            .clipShape(SketchRoundedRect(radius: 12))
            .overlay(SketchRoundedRect(radius: 12).stroke(Color.rhInk.opacity(vm.canStart ? 0.2 : 0), lineWidth: 1.5))
            .shadow(color: Color.rhInk.opacity(vm.canStart ? 0.18 : 0), radius: 0, x: 2, y: 3)
        }
        .disabled(!vm.canStart)
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Progress Card
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            let total = vm.gachaTasks.count
            let done = vm.gachaTasks.filter { $0.status == .completed || $0.status == .failed }.count
            let running = vm.gachaTasks.filter { $0.status == .running }.count

            HStack {
                sectionLabel("执行进度", icon: "chart.bar.fill")
                Spacer()
                Text("\(done)/\(total)")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.rhAccent)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.rhBorder.opacity(0.4))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(Color.rhAccent)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(done) / CGFloat(total) : 0, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: done)
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                statusPill(count: vm.gachaTasks.filter { $0.status == .queued }.count, label: "排队", color: .rhSecondary)
                statusPill(count: running, label: "生成中", color: .rhAccent)
                statusPill(count: vm.gachaTasks.filter { $0.status == .completed }.count, label: "完成", color: .rhSuccess)
                statusPill(count: vm.gachaTasks.filter { $0.status == .failed }.count, label: "失败", color: .rhError)
            }
        }
        .sketchCard()
    }

    private func statusPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(count)")
                .font(.system(size: 11)).foregroundColor(.rhSecondary)
        }
    }

    // MARK: - Results Grid
    private var resultsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("生成结果", icon: "photo.stack")
            let completed = vm.gachaTasks.filter { $0.decodedData != nil || !$0.outputUrls.isEmpty }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(completed) { task in
                    GachaResultCell(task: task)
                }
            }
        }
        .sketchCard()
    }

    // MARK: - Section Label
    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11)).foregroundColor(.rhAccent)
            Text(title)
                .font(.system(size: 13, weight: .semibold)).foregroundColor(.rhPrimary)
        }
    }
}

// MARK: - Result Cell
struct GachaResultCell: View {
    let task: GachaTask
    @State private var showSaveAlert = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = task.decodedData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else if let urlStr = task.outputUrls.first, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fill).clipped()
                    case .failure:
                        Color.rhBorder.overlay(Image(systemName: "exclamationmark.triangle").foregroundColor(.rhError))
                    default:
                        Color.rhBorder.overlay(ProgressView().tint(.rhAccent))
                    }
                }
            } else if task.status == .failed {
                Color.rhRedMuted
                    .overlay(Image(systemName: "xmark.circle").foregroundColor(.rhError))
            } else {
                Color.rhBorder.overlay(ProgressView().tint(.rhAccent))
            }

            // Status badge
            if task.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12)).foregroundColor(.white)
                    .padding(4)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(SketchRoundedRect(radius: 10))
        .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhInk.opacity(0.12), lineWidth: 1))
        .contextMenu {
            if let data = task.decodedData {
                Button {
                    if let img = UIImage(data: data) {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                    }
                } label: { Label("保存到相册", systemImage: "square.and.arrow.down") }
            }
        }
    }
}
