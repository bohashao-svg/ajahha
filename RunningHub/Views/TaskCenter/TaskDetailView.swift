import SwiftUI
import Photos

// MARK: - Task Detail View
// Layout: large output image hero → collapsible info sheet → action buttons
struct TaskDetailView: View {
    let task: RHTask
    let vm: TaskCenterViewModel
    var appState: AppState = AppState.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isDecoding = false
    @State private var decodeError: String?
    @State private var showDecodeSheet = false
    @State private var showToolPicker = false
    @State private var pendingTool: DecodeTool? = nil
    @State private var decodePassword = ""
    @State private var saveToast: String?
    // Decode results stored locally — never written back to AppState/StorageService
    @State private var localDecodedData: Data? = nil
    @State private var localDecodedIsDuck: Bool = false
    @State private var infoExpanded = false

    enum DecodeTool { case duck, ttV2 }

    private var liveTask: RHTask {
        appState.tasks.first(where: { $0.id == task.id }) ?? task
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // ── Output hero ──────────────────────────────────────────
                outputHero

                // ── Info + actions ───────────────────────────────────────
                VStack(spacing: 14) {
                    statusBar
                    if infoExpanded { infoGrid }
                    actionRow
                    if let err = decodeError {
                        Text(err).font(.system(size: 12)).foregroundColor(Color(hex: "#FF6B6B"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if liveTask.status == .running || liveTask.status == .queued {
                        cancelButton
                    }
                }
                .padding(16)
            }
        }
        .background(AnimatedMeshBackground().ignoresSafeArea())
        .overlay(toastOverlay, alignment: .bottom)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("任务详情")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showDecodeSheet) { decodeSheet }
        // Native confirmationDialog — zero UIKit, zero crash risk
        .confirmationDialog("选择解码工具", isPresented: $showToolPicker, titleVisibility: .visible) {
            Button("鸭鸭图 (LSB 隐写)") {
                pendingTool = .duck
                showDecodeSheet = true
            }
            Button("TT Tool V2 (彩色图)") {
                pendingTool = .ttV2
                showDecodeSheet = true
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - Output Hero
    @ViewBuilder
    private var outputHero: some View {
        let imageUrls = liveTask.outputUrls.filter {
            !["mp4","mov","webm"].contains($0.split(separator:".").last?.lowercased() ?? "")
        }
        let videoUrls = liveTask.outputUrls.filter {
            ["mp4","mov","webm"].contains($0.split(separator:".").last?.lowercased() ?? "")
        }

        if imageUrls.isEmpty && videoUrls.isEmpty {
            // Placeholder while running
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 280)
                if liveTask.status == .running {
                    VStack(spacing: 12) {
                        ProgressView().tint(Color(hex: "#6C8EFF")).scaleEffect(1.4)
                        Text("生成中 \(Int(liveTask.progress * 100))%")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundColor(Color.white.opacity(0.15))
                }
            }
        } else if imageUrls.count == 1 {
            // Single image — full width hero
            ZStack(alignment: .bottomTrailing) {
                RHRemoteImage(url: imageUrls[0], contentMode: .fill, cornerRadius: 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipped()

                // Decode + save overlay
                HStack(spacing: 8) {
                    if liveTask.status == .completed && localDecodedData == nil {
                        Button { handleDecodeTap() } label: {
                            Label(isDecoding ? "解码中" : "解码", systemImage: "lock.open.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .disabled(isDecoding)
                        .buttonStyle(LiquidButtonStyle())
                    }
                    Button { saveImageFromURL(imageUrls[0]) } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(LiquidButtonStyle())
                }
                .padding(14)
            }
        } else if imageUrls.count > 1 {
            // Multiple images — horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(imageUrls, id: \.self) { url in
                        OutputCardView(
                            imageURL: url,
                            title: liveTask.workflowName.isEmpty ? "生成结果" : liveTask.workflowName,
                            subtitle: liveTask.workflowType
                        )
                        .frame(width: 200, height: 260)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }

        // Decoded result
        if let data = localDecodedData {
            decodedResultView(data: data, isDuck: localDecodedIsDuck)
        }

        // Video items
        ForEach(videoUrls, id: \.self) { url in
            videoRow(url: url)
        }
    }

    // MARK: - Status Bar
    private var statusBar: some View {
        HStack(spacing: 12) {
            // Status indicator
            HStack(spacing: 6) {
                if liveTask.status == .running {
                    ProgressView().scaleEffect(0.7).tint(liveTask.status.color)
                } else {
                    Circle().fill(liveTask.status.color).frame(width: 8, height: 8)
                        .shadow(color: liveTask.status.color.opacity(0.7), radius: 4)
                }
                Text(liveTask.status.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(liveTask.status.color)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(liveTask.status.color.opacity(0.1))
            .clipShape(Capsule())

            if liveTask.status == .running {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#6C8EFF"), Color(hex: "#4ECDC4")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * liveTask.progress, height: 4)
                            .animation(.easeInOut(duration: 0.4), value: liveTask.progress)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            // Expand info toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    infoExpanded.toggle()
                }
            } label: {
                Image(systemName: infoExpanded ? "chevron.up" : "info.circle")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
    }

    // MARK: - Info Grid (collapsible)
    private var infoGrid: some View {
        VStack(spacing: 0) {
            infoRow("任务 ID", liveTask.id)
            infoRow("工作流", liveTask.workflowName)
            infoRow("类型", liveTask.workflowType)
            infoRow("模式", liveTask.isPlusMode ? "✦ Plus" : "标准")
            infoRow("创建", liveTask.createdAt.relativeString())
            if let err = liveTask.errorMsg, !err.isEmpty {
                infoRow("错误", err, valueColor: Color(hex: "#FF6B6B"))
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func infoRow(_ label: String, _ value: String, valueColor: Color = Color.white.opacity(0.7)) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundColor(Color.white.opacity(0.35)).frame(width: 56, alignment: .leading)
            Text(value).font(.system(size: 12, weight: .medium)).foregroundColor(valueColor).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: - Action Row
    private var actionRow: some View {
        HStack(spacing: 10) {
            if liveTask.status == .completed && !liveTask.outputUrls.isEmpty {
                // Share
                if let urlStr = liveTask.primaryOutputUrl, let url = URL(string: urlStr) {
                    ShareLink(item: url) {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(LiquidButtonStyle())
                }
            }
        }
    }

    // MARK: - Cancel Button
    private var cancelButton: some View {
        Button { vm.cancelTask(liveTask) } label: {
            Label("取消任务", systemImage: "xmark.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#FF6B6B"))
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Color(hex: "#FF6B6B").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "#FF6B6B").opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(LiquidButtonStyle())
    }

    // MARK: - Decoded Result
    private func decodedResultView(data: Data, isDuck: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isDuck ? "鸭鸭图解码结果" : "TT Tool 解码结果",
                  systemImage: isDuck ? "tortoise.fill" : "wand.and.stars")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isDuck ? Color(hex: "#FFD166") : Color(hex: "#6C8EFF"))
                .padding(.horizontal, 16).padding(.top, 14)

            if let img = UIImage(data: data) {
                // Image result
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: img).resizable().scaledToFit()
                    Button { saveImage(img) } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(LiquidButtonStyle())
                    .padding(12)
                }
            } else {
                // Non-image result (video, zip, etc.) — save to Photos/Files
                HStack(spacing: 14) {
                    Image(systemName: isVideoData(data) ? "video.fill" : "doc.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "#6C8EFF"))
                        .frame(width: 52, height: 52)
                        .background(Color(hex: "#6C8EFF").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isVideoData(data) ? "解码成功（视频）" : "解码成功")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        Text("\(data.count / 1024) KB")
                            .font(.system(size: 12)).foregroundColor(Color.white.opacity(0.4))
                    }

                    Spacer()

                    Button {
                        if isVideoData(data) { saveVideo(data) }
                        else { saveRawData(data) }
                    } label: {
                        Label("保存", systemImage: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(LinearGradient(
                                colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(LiquidButtonStyle())
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
    }

    // Detect video by magic bytes (MP4: ftyp, MOV: ftyp/wide, WebM: 0x1A45DFA3)
    private func isVideoData(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let bytes = [UInt8](data.prefix(12))
        // MP4/MOV: bytes 4-7 == "ftyp" or "wide" or "moov"
        if bytes.count >= 8 {
            let sig = String(bytes: bytes[4..<8], encoding: .ascii) ?? ""
            if ["ftyp", "wide", "moov", "mdat"].contains(sig) { return true }
        }
        // WebM: starts with 0x1A 0x45 0xDF 0xA3
        if bytes[0] == 0x1A && bytes[1] == 0x45 && bytes[2] == 0xDF && bytes[3] == 0xA3 { return true }
        return false
    }

    private func saveRawData(_ data: Data) {
        let ext = "bin"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + ext)
        do {
            try data.write(to: tmp)
            showToast("文件已保存到临时目录")
        } catch {
            showToast("保存失败：\(error.localizedDescription)")
        }
    }

    private func videoRow(url: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "video.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#6C8EFF"))
                .frame(width: 44, height: 44)
                .background(Color(hex: "#6C8EFF").opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("视频已生成").font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            Spacer()
            if let urlObj = URL(string: url) {
                Link(destination: urlObj) {
                    Label("下载", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#6C8EFF"))
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16).padding(.top, 8)
    }

    // MARK: - Toast
    private var toastOverlay: some View {
        Group {
            if let msg = saveToast {
                Label(msg, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: saveToast)
            }
        }
    }

    // MARK: - Decode Sheet
    private var decodeSheet: some View {
        DecodeToolSheetView(
            password: $decodePassword,
            // Use pendingTool set by handleDecodeTap so the sheet always
            // knows which tool was selected (even when coming from confirmationDialog)
            forcedTool: pendingTool,
            onDismiss: { showDecodeSheet = false },
            onConfirm: { tool in
                showDecodeSheet = false
                triggerDecode(tool: tool, password: decodePassword)
            }
        )
    }

    // MARK: - Helpers
    private func handleDecodeTap() {
        decodePassword = ""
        pendingTool = nil
        if liveTask.isDuckEncoded {
            pendingTool = .duck; showDecodeSheet = true
        } else if liveTask.isTTEncoded {
            pendingTool = .ttV2; showDecodeSheet = true
        } else {
            showToolPicker = true
        }
    }

    private func triggerDecode(tool: DecodeTool, password: String) {
        guard let url = liveTask.primaryOutputUrl else { return }
        isDecoding = true
        decodeError = nil
        localDecodedData = nil
        Task {
            do {
                let data: Data
                switch tool {
                case .duck:
                    let f = try await DuckDecodeService.shared.decode(imageUrl: url, password: password)
                    data = f.data
                    await MainActor.run {
                        localDecodedData = data
                        localDecodedIsDuck = true
                    }
                case .ttV2:
                    let f = try await TTDecodeService.shared.decode(imageUrl: url, password: password)
                    data = f.data
                    await MainActor.run {
                        localDecodedData = data
                        localDecodedIsDuck = false
                    }
                }
                // Do NOT write back to AppState — keeps task list clean and avoids crash
            } catch {
                await MainActor.run { decodeError = error.localizedDescription }
            }
            await MainActor.run { isDecoding = false }
        }
    }

    private func saveImageFromURL(_ urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async { saveImage(img) }
        }.resume()
    }

    private func saveImage(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    RHBanner.success("已保存到相册")
                    showToast("已保存到相册")
                } else { showToast("请在设置中允许访问相册") }
            }
        }
    }

    private func showToast(_ msg: String) {
        saveToast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveToast = nil }
    }
}

// MARK: - Decode Tool Sheet
private struct DecodeToolSheetView: View {
    @Binding var password: String
    // forcedTool: set when the tool is already known (duck/TT flag on task,
    // or selected via confirmationDialog). nil = show both options.
    let forcedTool: TaskDetailView.DecodeTool?
    let onDismiss: () -> Void
    let onConfirm: (TaskDetailView.DecodeTool) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Tool selector only when tool is unknown
                if forcedTool == nil {
                    VStack(spacing: 10) {
                        toolButton("鸭鸭图", subtitle: "LSB 隐写解码", icon: "tortoise.fill",
                                   color: Color(hex: "#FFD166"), tool: .duck)
                        toolButton("TT Tool V2", subtitle: "彩色图解码", icon: "wand.and.stars",
                                   color: Color(hex: "#6C8EFF"), tool: .ttV2)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: forcedTool == .duck ? "tortoise.fill" : "wand.and.stars")
                            .foregroundColor(forcedTool == .duck ? Color(hex: "#FFD166") : Color(hex: "#6C8EFF"))
                        Text(forcedTool == .duck ? "鸭鸭图解码" : "TT Tool V2 解码")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("解码密码（无密码留空）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                    SecureField("留空表示无密码", text: $password)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .tint(Color(hex: "#6C8EFF"))
                        .padding(.horizontal, 14).padding(.vertical, 13)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let tool = forcedTool {
                    Button { onConfirm(tool) } label: {
                        Text("确认解码")
                            .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(LinearGradient(
                                colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 12, y: 4)
                    }
                    .buttonStyle(LiquidButtonStyle())
                }

                Spacer()
            }
            .padding(20)
            .background(AnimatedMeshBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("解码").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { onDismiss() }
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
        }
    }

    private func toolButton(_ title: String, subtitle: String, icon: String, color: Color, tool: TaskDetailView.DecodeTool) -> some View {
        Button { onConfirm(tool) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
                    .frame(width: 44, height: 44).background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(Color.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color.white.opacity(0.2))
            }
            .padding(14)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(LiquidButtonStyle())
    }
}
