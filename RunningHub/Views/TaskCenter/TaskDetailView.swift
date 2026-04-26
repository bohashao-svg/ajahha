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

            // Save toast
            if let toast = saveToast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(20)
                        .padding(.bottom, 40)
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
            Divider().padding(.leading, 16)
            infoRow(label: "工作流", value: liveTask.workflowName)
            Divider().padding(.leading, 16)
            infoRow(label: "类型", value: liveTask.workflowType)
            Divider().padding(.leading, 16)
            infoRow(label: "模式", value: liveTask.isPlusMode ? "Plus" : "标准")
            Divider().padding(.leading, 16)
            infoRow(label: "状态", value: liveTask.status.displayName, valueColor: liveTask.status.color)
            if liveTask.status == .running {
                Divider().padding(.leading, 16)
                progressRow
            }
            if let err = liveTask.errorMsg, !err.isEmpty {
                Divider().padding(.leading, 16)
                infoRow(label: "错误", value: err, valueColor: .rhError)
            }
            Divider().padding(.leading, 16)
            infoRow(label: "创建时间", value: liveTask.createdAt.relativeString())
        }
        .background(Color.rhCard)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func infoRow(label: String, value: String, valueColor: Color = .rhPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.rhSecondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(valueColor)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var progressRow: some View {
        HStack {
            Text("进度")
                .font(.system(size: 13))
                .foregroundColor(.rhSecondary)
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.rhBorder).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(Color.rhAccent)
                        .frame(width: geo.size.width * liveTask.progress, height: 6)
                }
            }
            .frame(height: 6)
            Text("\(Int(liveTask.progress * 100))%")
                .font(.system(size: 12))
                .foregroundColor(.rhSecondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Output Section
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("生成结果")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.rhSecondary)

            ForEach(liveTask.outputUrls, id: \.self) { url in
                OutputItemView(url: url) { showToast($0) }
            }
        }
    }

    // MARK: - Duck Section
    private var duckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RHIcon(name: .duck, size: 16, color: .rhWarning)
                Text("鸭鸭图")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.rhSecondary)
                Spacer()
            }

            if let decoded = liveTask.decodedImageData, let uiImage = UIImage(data: decoded) {
                // Show decoded image with save button
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .overlay(
                        Button {
                            saveImage(uiImage)
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.55))
                                .cornerRadius(10)
                        }
                        .padding(10),
                        alignment: .bottomTrailing
                    )
            } else if liveTask.status == .completed, let url = liveTask.primaryOutputUrl {
                // Show original duck image with decode button overlay
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit().cornerRadius(12)
                            .overlay(duckOverlay, alignment: .bottomTrailing)
                    case .empty:
                        ProgressView().frame(height: 120)
                    default:
                        Color.rhBackground.frame(height: 120).cornerRadius(12)
                            .overlay(duckOverlay, alignment: .bottomTrailing)
                    }
                }

                if let err = decodeError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.rhError)
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
                    .cornerRadius(10)
            } else {
                Button {
                    if liveTask.duckPassword?.isEmpty == false {
                        triggerDecode(password: liveTask.duckPassword!)
                    } else {
                        showRetrySheet = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 13))
                        Text("解码")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.rhWarning.opacity(0.9))
                    .cornerRadius(10)
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
            Text("取消任务")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.rhError)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.rhError.opacity(0.08))
                .cornerRadius(12)
        }
    }

    // MARK: - Retry Decode Sheet
    private var retryDecodeSheet: some View {
        VStack(spacing: 20) {
            Text("输入解码密码")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 24)
            SecureField("密码", text: $retryPassword)
                .padding(12)
                .background(Color.rhBackground)
                .cornerRadius(10)
                .padding(.horizontal)
            HStack(spacing: 12) {
                Button("取消") { showRetrySheet = false }
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(Color.rhBackground).cornerRadius(12)
                Button {
                    showRetrySheet = false
                    triggerDecode(password: retryPassword)
                } label: {
                    Text("解码")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(retryPassword.isEmpty ? Color.rhSecondary.opacity(0.4) : Color.rhAccent)
                        .cornerRadius(12)
                }
                .disabled(retryPassword.isEmpty)
            }
            .padding(.horizontal)
            Spacer()
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saveToast = nil
        }
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
        if isVideo {
            videoItem
        } else {
            imageItem
        }
    }

    private var imageItem: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFit().cornerRadius(12)
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
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.black.opacity(0.55))
                .cornerRadius(10)
        }
        .padding(10)
    }

    private var videoItem: some View {
        HStack(spacing: 10) {
            RHIcon(name: .video, size: 20, color: .rhAccent)
            Text("视频已生成")
                .font(.system(size: 14))
                .foregroundColor(.rhPrimary)
            Spacer()
            if let urlObj = URL(string: url) {
                Link(destination: urlObj) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.rhAccent)
                }
            }
        }
        .padding(12)
        .background(Color.rhBackground)
        .cornerRadius(10)
    }

    private var failPlaceholder: some View {
        HStack {
            RHIcon(name: .image, size: 20, color: .rhSecondary)
            Text("图片加载失败")
                .font(.system(size: 13))
                .foregroundColor(.rhSecondary)
        }
        .frame(height: 80).frame(maxWidth: .infinity)
        .background(Color.rhBackground).cornerRadius(10)
    }
}
