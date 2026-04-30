import SwiftUI
import Photos

// MARK: - Task Detail View
struct TaskDetailView: View {
    let task: RHTask
    let vm: TaskCenterViewModel
    // Use direct reference instead of @EnvironmentObject to avoid
    // crash when presented from a sheet (sheet breaks env chain).
    var appState: AppState = AppState.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isDecoding = false
    @State private var decodeError: String?
    @State private var showDecodeToolSheet = false
    @State private var decodePassword = ""
    @State private var saveToast: String?
    @State private var showActionSheet = false

    enum DecodeTool { case duck, ttV2 }

    private var liveTask: RHTask {
        appState.tasks.first(where: { $0.id == task.id }) ?? task
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                infoCard
                if !liveTask.outputUrls.isEmpty { outputSection }
                if liveTask.status == .running || liveTask.status == .pending || liveTask.status == .queued {
                    cancelButton
                }
            }
            .padding(16)
        }
        .background(AnimatedMeshBackground().ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast = saveToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#4ECDC4"))
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#F0F4FF"))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(LiquidGlassShape(radius: 22).fill(Color(hex: "#111827").opacity(0.9)))
                .overlay(LiquidGlassShape(radius: 22).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 6)
                .padding(.bottom, 44)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: saveToast)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("任务详情")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#F0F4FF"), Color(hex: "#8B9CC8")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }
        }
        .sheet(isPresented: $showDecodeToolSheet) {
            decodeToolSheet
        }
        .liquidActionSheet(
            isPresented: $showActionSheet,
            title: "选择解码工具",
            actions: [
                LiquidActionSheet.SheetAction(title: "鸭鸭图 (LSB)", icon: "tortoise.fill", style: .default) {
                    showDecodeToolSheet = true
                },
                LiquidActionSheet.SheetAction(title: "TT Tool V2", icon: "wand.and.stars", style: .default) {
                    showDecodeToolSheet = true
                },
            ]
        )
    }

    // MARK: - Info Card
    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(label: "任务 ID", value: liveTask.id)
            glassDivider
            infoRow(label: "工作流", value: liveTask.workflowName)
            glassDivider
            infoRow(label: "类型", value: liveTask.workflowType)
            glassDivider
            infoRow(label: "模式", value: liveTask.isPlusMode ? "✦ Plus" : "标准",
                    valueColor: liveTask.isPlusMode ? Color(hex: "#FFD166") : Color(hex: "#F0F4FF"))
            glassDivider
            infoRow(label: "状态", value: liveTask.status.displayName, valueColor: liveTask.status.color)
            if liveTask.status == .running {
                glassDivider
                progressRow
            }
            if let err = liveTask.errorMsg, !err.isEmpty {
                glassDivider
                infoRow(label: "错误", value: err, valueColor: Color(hex: "#FF6B6B"))
            }
            glassDivider
            infoRow(label: "创建时间", value: liveTask.createdAt.relativeString())
        }
        .glassCard(radius: 20)
    }

    private var glassDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func infoRow(label: String, value: String, valueColor: Color = Color(hex: "#F0F4FF")) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#8B9CC8"))
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(valueColor)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var progressRow: some View {
        HStack {
            Text("进度")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#8B9CC8"))
                .frame(width: 72, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    LiquidGlassShape(radius: 4).fill(Color.white.opacity(0.06)).frame(height: 7)
                    LiquidGlassShape(radius: 4)
                        .fill(LinearGradient(
                            colors: [Color(hex: "#6C8EFF"), Color(hex: "#4ECDC4")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * liveTask.progress, height: 7)
                        .shadow(color: Color(hex: "#6C8EFF").opacity(0.5), radius: 4)
                        .animation(.easeInOut(duration: 0.4), value: liveTask.progress)
                }
            }
            .frame(height: 7)
            Text("\(Int(liveTask.progress * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#6C8EFF"))
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Output Section
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                LiquidGlassShape(radius: 2)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3, height: 14)
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.6), radius: 4)
                Text("生成结果")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
            }

            let imageUrls = liveTask.outputUrls.filter {
                !["mp4", "mov", "webm"].contains($0.split(separator: ".").last?.lowercased() ?? "")
            }
            let videoUrls = liveTask.outputUrls.filter {
                ["mp4", "mov", "webm"].contains($0.split(separator: ".").last?.lowercased() ?? "")
            }

            if imageUrls.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(imageUrls, id: \.self) { url in
                            OutputCardView(
                                imageURL: url,
                                title: liveTask.workflowName.isEmpty ? "生成结果" : liveTask.workflowName,
                                subtitle: liveTask.workflowType
                            )
                            .frame(width: 220, height: 280)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            } else {
                ForEach(imageUrls, id: \.self) { url in
                    OutputItemView(
                        url: url,
                        showDecodeButton: liveTask.status == .completed
                            && liveTask.decodedImageData == nil
                            && liveTask.ttDecodedData == nil,
                        isDecoding: isDecoding,
                        onDecode: { handleDecodeButtonTap() },
                        onToast: { showToast($0) }
                    )
                }
            }

            ForEach(videoUrls, id: \.self) { url in
                OutputItemView(url: url, onToast: { showToast($0) })
            }

            if liveTask.status == .completed { decodeResultBlock }

            if let err = decodeError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#FF6B6B"))
                    .padding(.horizontal, 4)
            }
        }
        .rhCard()
    }

    private func handleDecodeButtonTap() {
        decodePassword = ""
        if liveTask.isDuckEncoded || liveTask.isTTEncoded {
            showDecodeToolSheet = true
        } else {
            showActionSheet = true
        }
    }

    @ViewBuilder
    private var decodeResultBlock: some View {
        let duckData = liveTask.decodedImageData
        let ttData   = liveTask.ttDecodedData
        if let data = duckData ?? ttData {
            Divider().background(Color.white.opacity(0.08))
            HStack(spacing: 6) {
                Image(systemName: duckData != nil ? "tortoise.fill" : "wand.and.stars")
                    .font(.system(size: 13))
                    .foregroundColor(duckData != nil ? Color(hex: "#FFD166") : Color(hex: "#6C8EFF"))
                Text(duckData != nil ? "鸭鸭图解码结果" : "TT Tool 解码结果")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                Spacer()
            }
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable().scaledToFit()
                    .clipShape(LiquidGlassShape(radius: 14))
                    .overlay(
                        Button { saveImage(uiImage) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down").font(.system(size: 12, weight: .semibold))
                                Text("保存").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(LiquidGlassShape(radius: 10).fill(Color.black.opacity(0.55)))
                            .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.15), lineWidth: 0.6))
                        }.padding(10),
                        alignment: .bottomTrailing
                    )
            } else {
                HStack(spacing: 10) {
                    ZStack {
                        LiquidGlassShape(radius: 8).fill(Color(hex: "#6C8EFF").opacity(0.1)).frame(width: 38, height: 38)
                        RHIcon(name: .video, size: 18, color: Color(hex: "#6C8EFF"))
                    }
                    Text("解码成功（视频）").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "#F0F4FF"))
                    Spacer()
                    Button { saveVideo(data) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down").font(.system(size: 12))
                            Text("保存").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 7)
                        .background(LiquidGlassShape(radius: 10).fill(LinearGradient(
                            colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                            startPoint: .leading, endPoint: .trailing
                        )))
                    }
                }
                .padding(10)
                .glassCard(radius: 12)
            }
        }
    }

    private func triggerDecode(tool: DecodeTool, password: String) {
        guard let url = liveTask.primaryOutputUrl else { return }
        isDecoding = true
        decodeError = nil
        Task {
            do {
                switch tool {
                case .duck:
                    let duckFile = try await DuckDecodeService.shared.decode(imageUrl: url, password: password)
                    var updated = liveTask
                    updated.decodedImageData = duckFile.data
                    await MainActor.run { appState.updateTask(updated) }
                case .ttV2:
                    let file = try await TTDecodeService.shared.decode(imageUrl: url, password: password)
                    var updated = liveTask
                    updated.ttDecodedData = file.data
                    await MainActor.run { appState.updateTask(updated) }
                }
            } catch {
                await MainActor.run { decodeError = error.localizedDescription }
            }
            await MainActor.run { isDecoding = false }
        }
    }

    private var decodeToolSheet: some View {
        DecodeToolSheetView(
            password: $decodePassword,
            isDuckEncoded: liveTask.isDuckEncoded,
            isTTEncoded: liveTask.isTTEncoded,
            onDismiss: { showDecodeToolSheet = false },
            onConfirm: { tool in
                showDecodeToolSheet = false
                triggerDecode(tool: tool, password: decodePassword)
            }
        )
    }

    // MARK: - Cancel Button
    private var cancelButton: some View {
        Button { vm.cancelTask(liveTask) } label: {
            HStack(spacing: 8) {
                RHIcon(name: .close, size: 14, color: Color(hex: "#FF6B6B"))
                Text("取消任务")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#FF6B6B"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(LiquidGlassShape(radius: 18).fill(Color(hex: "#FF6B6B").opacity(0.08)))
            .overlay(LiquidGlassShape(radius: 18).stroke(Color(hex: "#FF6B6B").opacity(0.2), lineWidth: 0.8))
        }
        .buttonStyle(LiquidButtonStyle())
    }

    private func saveVideo(_ data: Data) {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        do { try data.write(to: tmpURL) } catch {
            showToast("保存失败：\(error.localizedDescription)"); return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tmpURL)
                    }) { success, _ in
                        DispatchQueue.main.async {
                            try? FileManager.default.removeItem(at: tmpURL)
                            showToast(success ? "视频已保存到相册" : "保存失败")
                        }
                    }
                } else { showToast("请在设置中允许访问相册") }
            }
        }
    }

    private func saveImage(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    RHBanner.success("已保存到相册")
                    showToast("已保存到相册")
                } else {
                    RHBanner.warning("请在设置中允许访问相册")
                    showToast("请在设置中允许访问相册")
                }
            }
        }
    }

    private func showToast(_ msg: String) {
        saveToast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveToast = nil }
    }
}

// MARK: - Output Item View
private struct OutputItemView: View {
    let url: String
    var showDecodeButton: Bool = false
    var isDecoding: Bool = false
    var onDecode: (() -> Void)? = nil
    let onToast: (String) -> Void

    var isVideo: Bool {
        ["mp4", "mov", "webm"].contains(url.split(separator: ".").last?.lowercased() ?? "")
    }

    var body: some View {
        if isVideo { videoItem } else { imageItem }
    }

    private var imageItem: some View {
        RHRemoteImage(url: url, contentMode: .fit, cornerRadius: 16)
            .overlay(saveButton, alignment: .bottomTrailing)
            .overlay(decodeOverlay, alignment: .bottomLeading)
    }

    @ViewBuilder
    private var decodeOverlay: some View {
        if showDecodeButton {
            Button { onDecode?() } label: {
                HStack(spacing: 4) {
                    if isDecoding {
                        ProgressView().scaleEffect(0.7).tint(.white)
                    } else {
                        Image(systemName: "lock.open.fill").font(.system(size: 11, weight: .semibold))
                    }
                    Text(isDecoding ? "解码中" : "解码")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(LiquidGlassShape(radius: 10).fill(Color(hex: "#6C8EFF").opacity(0.85)))
                .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.2), lineWidth: 0.6))
            }
            .disabled(isDecoding)
            .padding(10)
        }
    }

    private var saveButton: some View {
        Button {
            guard let urlObj = URL(string: url) else { return }
            URLSession.shared.dataTask(with: urlObj) { data, _, _ in
                guard let data, let img = UIImage(data: data) else { return }
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    DispatchQueue.main.async {
                        if status == .authorized || status == .limited {
                            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                            onToast("已保存到相册")
                        } else { onToast("请在设置中允许访问相册") }
                    }
                }
            }.resume()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.and.arrow.down").font(.system(size: 13, weight: .semibold))
                Text("保存").font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(LiquidGlassShape(radius: 12).fill(Color.black.opacity(0.55)))
            .overlay(LiquidGlassShape(radius: 12).stroke(Color.white.opacity(0.15), lineWidth: 0.6))
        }
        .padding(10)
    }

    private var videoItem: some View {
        HStack(spacing: 12) {
            ZStack {
                LiquidGlassShape(radius: 10).fill(Color(hex: "#6C8EFF").opacity(0.1)).frame(width: 40, height: 40)
                RHIcon(name: .video, size: 18, color: Color(hex: "#6C8EFF"))
            }
            Text("视频已生成").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "#F0F4FF"))
            Spacer()
            if let urlObj = URL(string: url) {
                Link(destination: urlObj) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 18))
                        Text("下载").font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#6C8EFF"))
                }
            }
        }
        .padding(12)
        .glassCard(radius: 14)
    }
}

// MARK: - Decode Tool Sheet View
private struct DecodeToolSheetView: View {
    @Binding var password: String
    let isDuckEncoded: Bool
    let isTTEncoded: Bool
    let onDismiss: () -> Void
    let onConfirm: (TaskDetailView.DecodeTool) -> Void

    private var knownTool: TaskDetailView.DecodeTool? {
        if isDuckEncoded { return .duck }
        if isTTEncoded   { return .ttV2 }
        return nil
    }

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
            VStack(spacing: 0) {
                LiquidGlassShape(radius: 3)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12).padding(.bottom, 20)

                Text("解码").font(.system(size: 16, weight: .semibold)).foregroundColor(Color(hex: "#F0F4FF")).padding(.bottom, 6)

                if let tool = knownTool {
                    HStack(spacing: 6) {
                        Image(systemName: tool == .duck ? "tortoise.fill" : "wand.and.stars")
                            .font(.system(size: 12))
                            .foregroundColor(tool == .duck ? Color(hex: "#FFD166") : Color(hex: "#6C8EFF"))
                        Text(tool == .duck ? "鸭鸭图" : "TT Tool V2")
                            .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
                    }.padding(.bottom, 24)
                } else {
                    Text("请选择解码工具").font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8")).padding(.bottom, 24)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("密码（留空则无密码）").font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
                    SecureField("无密码请留空", text: $password)
                        .font(.system(size: 14)).foregroundColor(Color(hex: "#F0F4FF"))
                        .tint(Color(hex: "#6C8EFF"))
                        .nativeInput()
                }
                .padding(.horizontal, 20).padding(.bottom, 20)

                if let tool = knownTool {
                    Button { onConfirm(tool) } label: {
                        Text("确认解码").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LiquidGlassShape(radius: 14).fill(LinearGradient(
                                colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )))
                            .overlay(LiquidGlassShape(radius: 14).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                            .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 12)
                    }
                    .buttonStyle(.plain).padding(.horizontal, 20)
                } else {
                    VStack(spacing: 10) {
                        toolButton(title: "鸭鸭图", subtitle: "LSB 隐写解码", icon: "tortoise.fill",
                                   color: Color(hex: "#FFD166"), tool: .duck)
                        toolButton(title: "TT Tool", subtitle: "V2 彩色图解码", icon: "wand.and.stars",
                                   color: Color(hex: "#6C8EFF"), tool: .ttV2)
                    }.padding(.horizontal, 20)
                }

                Button("取消") { onDismiss() }
                    .font(.system(size: 14)).foregroundColor(Color(hex: "#8B9CC8")).padding(.top, 20)
                Spacer()
            }
        }
    }

    private func toolButton(title: String, subtitle: String, icon: String, color: Color, tool: TaskDetailView.DecodeTool) -> some View {
        Button { onConfirm(tool) } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#F0F4FF"))
                    Text(subtitle).font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(hex: "#8B9CC8").opacity(0.5))
            }
            .padding(14).glassCard(radius: 14)
        }
        .buttonStyle(.plain)
    }
}
