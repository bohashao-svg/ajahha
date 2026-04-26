import SwiftUI
import Photos

// MARK: - Task Detail View
struct TaskDetailView: View {
    let task: RHTask
    let vm: TaskCenterViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var retryPassword = ""
    @State private var showRetrySheet = false
    @State private var isDecoding = false
    @State private var decodeError: String?
    @State private var saveToast: String?

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
                    if liveTask.isDuckEncoded { duckSection }
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
        .sheet(isPresented: $showRetrySheet) {
            retryDecodeSheet
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
                OutputItemView(url: url) { showToast($0) }
            }
        }
        .rhCard()
    }

    // MARK: - Duck Section
    private var duckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                    RHIcon(name: .duck, size: 15, color: .rhWarning)
                    Text("鸭鸭图")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.rhPrimary)
                    Spacer()
                }

            if let decoded = liveTask.decodedImageData, let uiImage = UIImage(data: decoded) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
                    .overlay(
                        Button { saveImage(uiImage) } label: {
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
                        .padding(12),
                        alignment: .bottomTrailing
                    )
            } else if liveTask.status == .completed, let url = liveTask.primaryOutputUrl {
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit().cornerRadius(16)
                        case .empty:
                            ProgressView().frame(height: 120)
                        default:
                            Color.rhBackground.frame(height: 120).cornerRadius(16)
                        }
                    }

                    duckOverlay
                }

                if let err = decodeError {
                    HStack(spacing: 6) {
                        Circle().fill(Color.rhError).frame(width: 6, height: 6)
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.rhError)
                    }
                }
            }
        }
        .rhCard()
    }

    private var duckOverlay: some View {
        HStack(spacing: 8) {
            if isDecoding {
                ProgressView()
                    .tint(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(12)
            } else {
                Button {
                    showRetrySheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 12))
                        Text("解码")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [Color.rhGold, Color.rhGold.opacity(0.8)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding(10)
    }

    private func triggerDecode(password: String) {
        guard let url = liveTask.primaryOutputUrl else { return }
        isDecoding = true
        decodeError = nil
        Task {
            do {
                let data = try await DuckDecodeService.shared.decode(imageUrl: url, password: password)
                var updated = liveTask
                updated.decodedImageData = data
                appState.updateTask(updated)
            } catch {
                decodeError = "解码失败：\(error.localizedDescription)"
            }
            isDecoding = false
        }
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

    // MARK: - Retry Decode Sheet
    private var retryDecodeSheet: some View {
        // 解码弹窗
        VStack(spacing: 20) {
            Text("输入解码密码")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 28)

            Text("留空则以无密码方式解码")
                .font(.system(size: 12))
                .foregroundColor(.rhSecondary)

            SecureField("留空则无密码", text: $retryPassword)
                .font(.system(size: 14))
                .padding(12)
                .background(Color.rhBackground)
                .cornerRadius(12)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button("取消") { showRetrySheet = false }
                    .font(.system(size: 15))
                    .foregroundColor(.rhSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.rhBackground)
                    .cornerRadius(12)

                Button {
                    showRetrySheet = false
                    triggerDecode(password: retryPassword)
                } label: {
                    Text("解码")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.rhWarning)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.rhBackground.ignoresSafeArea())
    }

    // MARK: - Helpers
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
            case .failure:
                failPlaceholder
            case .empty:
                ProgressView().frame(height: 120)
            @unknown default:
                EmptyView()
            }
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
