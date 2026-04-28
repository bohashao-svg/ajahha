import SwiftUI
import Photos

// MARK: - Task Detail View
struct TaskDetailView: View {
    let task: RHTask
    let vm: TaskCenterViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Unified decode state
    @State private var isDecoding = false
    @State private var decodeError: String?
    @State private var showDecodeToolSheet = false
    @State private var decodePassword = ""
    @State private var saveToast: String?

    enum DecodeTool { case duck, ttV2 }

    private var liveTask: RHTask {
        appState.tasks.first(where: { $0.id == task.id }) ?? task
    }

    var body: some View {
        ZStack {
            Color.rhBackground.ignoresSafeArea()

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

            if let toast = saveToast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Color(hex: "#2D1A0E").opacity(0.82))
                        .cornerRadius(22)
                        .padding(.bottom, 44)
                }
                .transition(.opacity)
                .animation(.easeInOut, value: saveToast)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("任务详情")
                    .font(.system(size: 17, weight: .semibold))
            }
        }
        .sheet(isPresented: $showDecodeToolSheet) {
            decodeToolSheet
        }
    }

    // MARK: - Info Card
    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(label: "任务 ID", value: liveTask.id)
            rhDivider
            infoRow(label: "工作流", value: liveTask.workflowName)
            rhDivider
            infoRow(label: "类型", value: liveTask.workflowType)
            rhDivider
            infoRow(label: "模式", value: liveTask.isPlusMode ? "✦ Plus" : "标准",
                    valueColor: liveTask.isPlusMode ? .rhGold : .rhPrimary)
            rhDivider
            infoRow(label: "状态", value: liveTask.status.displayName, valueColor: liveTask.status.color)
            if liveTask.status == .running {
                rhDivider
                progressRow
            }
            if let err = liveTask.errorMsg, !err.isEmpty {
                rhDivider
                infoRow(label: "错误", value: err, valueColor: .rhError)
            }
            rhDivider
            infoRow(label: "创建时间", value: liveTask.createdAt.relativeString())
        }
        .background(Color.rhCard)
        .cornerRadius(20)
        .shadow(color: Color(hex: "#C8392B").opacity(0.07), radius: 12, x: 0, y: 4)
    }

    private var rhDivider: some View {
        Rectangle()
            .fill(Color.rhBorder.opacity(0.6))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func infoRow(label: String, value: String, valueColor: Color = .rhPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.rhSecondary)
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
                .foregroundColor(.rhSecondary)
                .frame(width: 72, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.rhBorder).frame(height: 7)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color(hex: "#C8392B"), Color.rhGold],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * liveTask.progress, height: 7)
                        .animation(.easeInOut(duration: 0.4), value: liveTask.progress)
                }
            }
            .frame(height: 7)
            Text("\(Int(liveTask.progress * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.rhAccent)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Output Section
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Color.rhAccent).frame(width: 3, height: 14)
                Text("生成结果")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.rhPrimary)
            }
            ForEach(liveTask.outputUrls, id: \.self) { url in
                OutputItemView(
                    url: url,
                    showDecodeButton: liveTask.status == .completed && liveTask.decodedImageData == nil && liveTask.ttDecodedData == nil,
                    isDecoding: isDecoding,
                    onDecode: { handleDecodeButtonTap() },
                    onToast: { showToast($0) }
                )
            }

            // 解码结果展示
            if liveTask.status == .completed {
                decodeResultBlock
            }

            // 解码错误提示
            if let err = decodeError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.rhError)
                    .padding(.horizontal, 4)
            }
        }
        .rhCard()
    }

    // 点击解码按钮：统一弹窗输入密码
    private func handleDecodeButtonTap() {
        decodePassword = ""
        showDecodeToolSheet = true
    }

    @ViewBuilder
    private var decodeResultBlock: some View {
        let duckData = liveTask.decodedImageData
        let ttData   = liveTask.ttDecodedData
        if let data = duckData ?? ttData {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: duckData != nil ? "tortoise.fill" : "wand.and.stars")
                    .font(.system(size: 13))
                    .foregroundColor(duckData != nil ? .rhWarning : .rhAccent)
                Text(duckData != nil ? "鸭鸭图解码结果" : "TT Tool 解码结果")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rhPrimary)
                Spacer()
            }
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable().scaledToFit().cornerRadius(14)
                    .overlay(
                        Button { saveImage(uiImage) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down").font(.system(size: 12, weight: .semibold))
                                Text("保存").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(10)
                        }.padding(10),
                        alignment: .bottomTrailing
                    )
            } else {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.rhAccentSoft).frame(width: 38, height: 38)
                        RHIcon(name: .video, size: 18, color: .rhAccent)
                    }
                    Text("解码成功（视频）").font(.system(size: 13, weight: .medium)).foregroundColor(.rhPrimary)
                    Spacer()
                    Button { saveVideo(data) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down").font(.system(size: 12))
                            Text("保存").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.rhAccent).cornerRadius(10)
                    }
                }
                .padding(10).background(Color.rhBackground).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhBorder, lineWidth: 1))
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
                    var updated = liveTask; updated.decodedImageData = duckFile.data
                    await MainActor.run { appState.updateTask(updated) }
                case .ttV2:
                    let file = try await TTDecodeService.shared.decode(imageUrl: url, password: password)
                    var updated = liveTask; updated.ttDecodedData = file.data
                    await MainActor.run { appState.updateTask(updated) }
                }
            } catch {
                await MainActor.run { decodeError = error.localizedDescription }
            }
            await MainActor.run { isDecoding = false }
        }
    }

    // MARK: - Decode Tool Sheet
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
                RHIcon(name: .close, size: 14, color: .rhError)
                Text("取消任务")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.rhError)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.rhError.opacity(0.07))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.rhError.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers
    private func saveVideo(_ data: Data) {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        do {
            try data.write(to: tmpURL)
        } catch {
            showToast("保存失败：\(error.localizedDescription)")
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tmpURL)
                    }) { success, err in
                        DispatchQueue.main.async {
                            try? FileManager.default.removeItem(at: tmpURL)
                            showToast(success ? "视频已保存到相册" : "保存失败")
                        }
                    }
                } else {
                    showToast("请在设置中允许访问相册")
                }
            }
        }
    }

    private func saveImage(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    showToast("已保存到相册")
                } else {
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
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFit().cornerRadius(16)
                    .overlay(saveButton, alignment: .bottomTrailing)
                    .overlay(decodeOverlay, alignment: .bottomLeading)
            case .failure:
                failPlaceholder
            case .empty:
                ProgressView().frame(height: 120)
            @unknown default:
                EmptyView()
            }
        }
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
                .background(Color.rhAccent.opacity(0.88))
                .cornerRadius(10)
            }
            .disabled(isDecoding)
            .padding(10)
        }
    }

    private var saveButton: some View {
        Button {
            guard let urlObj = URL(string: url) else { return }
            URLSession.shared.dataTask(with: urlObj) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    DispatchQueue.main.async {
                        if status == .authorized || status == .limited {
                            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                            onToast("已保存到相册")
                        } else {
                            onToast("请在设置中允许访问相册")
                        }
                    }
                }
            }.resume()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                Text("保存")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.55))
            .cornerRadius(12)
        }
        .padding(10)
    }

    private var videoItem: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.rhAccentSoft)
                    .frame(width: 38, height: 38)
                RHIcon(name: .video, size: 18, color: .rhAccent)
            }
            Text("视频已生成")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.rhPrimary)
            Spacer()
            if let urlObj = URL(string: url) {
                Link(destination: urlObj) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18))
                        Text("下载")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.rhAccent)
                }
            }
        }
        .padding(12)
        .background(Color.rhBackground)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rhBorder, lineWidth: 1))
    }

    private var failPlaceholder: some View {
        HStack(spacing: 8) {
            RHIcon(name: .image, size: 18, color: .rhSecondary)
            Text("图片加载失败")
                .font(.system(size: 13))
                .foregroundColor(.rhSecondary)
        }
        .frame(height: 80).frame(maxWidth: .infinity)
        .background(Color.rhBackground).cornerRadius(14)
    }
}

// MARK: - Decode Tool Sheet View
private struct DecodeToolSheetView: View {
    @Binding var password: String
    let isDuckEncoded: Bool
    let isTTEncoded: Bool
    let onDismiss: () -> Void
    let onConfirm: (TaskDetailView.DecodeTool) -> Void

    // 已识别编码类型（工作流）
    private var knownTool: TaskDetailView.DecodeTool? {
        if isDuckEncoded { return .duck }
        if isTTEncoded   { return .ttV2 }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.rhBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 12).padding(.bottom, 20)

            Text("解码")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 6)

            if let tool = knownTool {
                // 工作流：已识别，显示工具名
                HStack(spacing: 6) {
                    Image(systemName: tool == .duck ? "tortoise.fill" : "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundColor(tool == .duck ? .rhWarning : .rhAccent)
                    Text(tool == .duck ? "鸭鸭图" : "TT Tool V2")
                        .font(.system(size: 12))
                        .foregroundColor(.rhSecondary)
                }
                .padding(.bottom, 24)
            } else {
                Text("请选择解码工具")
                    .font(.system(size: 12)).foregroundColor(.rhSecondary)
                    .padding(.bottom, 24)
            }

            // 密码输入
            VStack(alignment: .leading, spacing: 6) {
                Text("密码（留空则无密码）")
                    .font(.system(size: 12)).foregroundColor(.rhSecondary)
                SecureField("无密码请留空", text: $password)
                    .font(.system(size: 14)).padding(12)
                    .background(Color.rhCard).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rhBorder, lineWidth: 1))
            }
            .padding(.horizontal, 20).padding(.bottom, 20)

            if let tool = knownTool {
                // 工作流：单个确认按钮
                Button {
                    onConfirm(tool)
                } label: {
                    Text("确认解码")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.rhAccent).cornerRadius(14)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            } else {
                // AI 应用：两个工具按钮
                VStack(spacing: 10) {
                    Button { onConfirm(.duck) } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Color.rhWarning.opacity(0.15)).frame(width: 36, height: 36)
                                Image(systemName: "tortoise.fill").font(.system(size: 16)).foregroundColor(.rhWarning)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("鸭鸭图").font(.system(size: 14, weight: .semibold)).foregroundColor(.rhPrimary)
                                Text("LSB 隐写解码").font(.system(size: 11)).foregroundColor(.rhSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.rhBorder)
                        }
                        .padding(14).background(Color.rhCard).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rhBorder.opacity(0.6), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { onConfirm(.ttV2) } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Color.rhAccent.opacity(0.12)).frame(width: 36, height: 36)
                                Image(systemName: "wand.and.stars").font(.system(size: 16)).foregroundColor(.rhAccent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TT Tool").font(.system(size: 14, weight: .semibold)).foregroundColor(.rhPrimary)
                                Text("V2 彩色图解码").font(.system(size: 11)).foregroundColor(.rhSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.rhBorder)
                        }
                        .padding(14).background(Color.rhCard).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rhBorder.opacity(0.6), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
            }

            Button("取消") { onDismiss() }
                .font(.system(size: 14)).foregroundColor(.rhSecondary)
                .padding(.top, 20)

            Spacer()
        }
        .background(Color.rhBackground.ignoresSafeArea())
    }
}
