import SwiftUI

// MARK: - Task Detail View
struct TaskDetailView: View {
    let task: RHTask
    let vm: TaskCenterViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showDuckDecoded = false
    @State private var retryPassword = ""
    @State private var showRetrySheet = false
    @State private var selectedImageUrl: String?

    // Live task from appState
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
                    if liveTask.status == .running || liveTask.status == .pending { cancelButton }
                }
                .padding(16)
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
            if let err = liveTask.errorMsg {
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
                OutputItemView(url: url, task: liveTask)
            }
        }
    }

    // MARK: - Duck Section
    private var duckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RHIcon(name: .duck, size: 16, color: .rhWarning)
                Text("鸭鸭图解码")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.rhSecondary)
                Spacer()
                if liveTask.decodedImageData == nil && liveTask.status == .completed {
                    Button { showRetrySheet = true } label: {
                        Text("手动解码")
                            .font(.system(size: 12))
                            .foregroundColor(.rhAccent)
                    }
                }
            }

            if let decoded = liveTask.decodedImageData,
               let uiImage = UIImage(data: decoded) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .overlay(
                        HStack {
                            Spacer()
                            Button {
                                UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                            } label: {
                                RHIcon(name: .download, size: 18, color: .white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(8)
                            }
                            .padding(8)
                        }, alignment: .bottomTrailing
                    )
            } else if liveTask.status == .completed {
                Text("解码失败或尚未解码")
                    .font(.system(size: 13))
                    .foregroundColor(.rhSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.rhBackground)
                    .cornerRadius(10)
            }
        }
        .rhCard()
    }

    // MARK: - Cancel Button
    private var cancelButton: some View {
        Button {
            vm.cancelTask(liveTask)
        } label: {
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.rhBackground)
                    .cornerRadius(12)
                Button {
                    vm.retryDecode(task: liveTask, password: retryPassword)
                    showRetrySheet = false
                } label: {
                    Text("解码")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(retryPassword.isEmpty ? Color.rhSecondary.opacity(0.4) : Color.rhAccent)
                        .cornerRadius(12)
                }
                .disabled(retryPassword.isEmpty)
            }
            .padding(.horizontal)
            Spacer()
        }
    }
}

// MARK: - Output Item View
private struct OutputItemView: View {
    let url: String
    let task: RHTask

    var body: some View {
        if url.hasSuffix(".mp4") || url.hasSuffix(".mov") || url.hasSuffix(".webm") {
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
                    .overlay(saveButton(for: img), alignment: .bottomTrailing)
            case .failure:
                failPlaceholder
            case .empty:
                ProgressView().frame(height: 120)
            @unknown default:
                EmptyView()
            }
        }
    }

    private var videoItem: some View {
        HStack(spacing: 10) {
            RHIcon(name: .video, size: 20, color: .rhAccent)
            Text("视频已生成")
                .font(.system(size: 14))
                .foregroundColor(.rhPrimary)
            Spacer()
            Link(destination: URL(string: url)!) {
                RHIcon(name: .download, size: 18, color: .rhAccent)
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
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color.rhBackground)
        .cornerRadius(10)
    }

    private func saveButton(for image: Image) -> some View {
        Button {
            if let urlObj = URL(string: url) {
                URLSession.shared.dataTask(with: urlObj) { data, _, _ in
                    if let data = data, let img = UIImage(data: data) {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                    }
                }.resume()
            }
        } label: {
            RHIcon(name: .download, size: 18, color: .white)
                .padding(8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
        }
        .padding(8)
    }
}
