import SwiftUI
import Photos

// MARK: - Profile View
struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    // 解码状态（复用 AI 应用流程：用户自选工具）
    @State private var selectedWork: ProfileWorkItem?
    @State private var showDecodeSheet = false
    @State private var decodePassword = ""
    @State private var isDecoding = false
    @State private var decodeResults: [String: Data] = [:]   // taskId → decoded Data
    @State private var decodeErrors: [String: String] = [:]  // taskId → error
    @State private var toast: String?

    // 大图预览
    @State private var previewUrl: String?

    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()

                Group {
                    if vm.isLoading {
                        loadingState
                    } else if let err = vm.errorMessage, vm.works.isEmpty {
                        errorState(err)
                    } else if vm.works.isEmpty {
                        emptyState
                    } else {
                        worksGrid
                    }
                }

                if let toast = toast {
                    toastView(toast)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        RHIcon(name: .close, size: 20, color: .rhSecondary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("我的作品")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.rhPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await vm.loadFirstPage() } } label: {
                        RHIcon(name: .refresh, size: 20, color: .rhSecondary)
                    }
                    .disabled(vm.isLoading)
                }
            }
        }
        .task { await vm.loadFirstPage() }
        .sheet(isPresented: $showDecodeSheet) {
            decodeSheet
        }
        .sheet(item: Binding(
            get: { previewUrl.map { PreviewItem(url: $0) } },
            set: { previewUrl = $0?.url }
        )) { item in
            ImagePreviewView(url: item.url, onToast: showToast)
        }
    }

    // MARK: - Works Grid
    private var worksGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(vm.works) { work in
                    WorkCell(
                        work: work,
                        decodedData: decodeResults[work.taskId],
                        decodeError: decodeErrors[work.taskId],
                        isDecoding: isDecoding && selectedWork?.taskId == work.taskId,
                        onTap: { url in previewUrl = url },
                        onDecode: {
                            selectedWork = work
                            decodePassword = ""
                            showDecodeSheet = true
                        }
                    )
                    .onAppear {
                        if work.id == vm.works.last?.id && vm.hasNext {
                            Task { await vm.loadNextPage() }
                        }
                    }
                }
            }

            if vm.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }

            if let err = vm.errorMessage, !vm.works.isEmpty {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.rhError)
                    .padding()
            }
        }
    }

    // MARK: - Decode Sheet
    private var decodeSheet: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.rhBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 12).padding(.bottom, 20)

            Text("解码")
                .font(.system(size: 16, weight: .semibold))
                .padding(.bottom, 6)

            Text("请选择解码工具")
                .font(.system(size: 12)).foregroundColor(.rhSecondary)
                .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 6) {
                Text("密码（留空则无密码）")
                    .font(.system(size: 12)).foregroundColor(.rhSecondary)
                SecureField("无密码请留空", text: $decodePassword)
                    .font(.system(size: 14)).padding(12)
                    .background(Color.rhCard).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rhBorder, lineWidth: 1))
            }
            .padding(.horizontal, 20).padding(.bottom, 20)

            VStack(spacing: 10) {
                Button { confirmDecode(.duck) } label: {
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

                Button { confirmDecode(.ttV2) } label: {
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

            Button("取消") { showDecodeSheet = false }
                .font(.system(size: 14)).foregroundColor(.rhSecondary)
                .padding(.top, 20)

            Spacer()
        }
        .background(Color.rhBackground.ignoresSafeArea())
    }

    private func confirmDecode(_ tool: DecodeTool) {
        showDecodeSheet = false
        guard let work = selectedWork,
              let url = work.outputUrls.first(where: { u in
                  let ext = u.split(separator: ".").last?.lowercased() ?? ""
                  return !["mp4", "mov", "webm"].contains(ext)
              }) ?? work.outputUrls.first
        else { return }

        isDecoding = true
        decodeErrors.removeValue(forKey: work.taskId)
        let pw = decodePassword
        let tid = work.taskId

        Task {
            do {
                switch tool {
                case .duck:
                    let data = try await DuckDecodeService.shared.decode(imageUrl: url, password: pw)
                    await MainActor.run { decodeResults[tid] = data }
                case .ttV2:
                    let file = try await TTDecodeService.shared.decode(imageUrl: url, password: pw)
                    await MainActor.run { decodeResults[tid] = file.data }
                }
            } catch {
                await MainActor.run { decodeErrors[tid] = error.localizedDescription }
            }
            await MainActor.run { isDecoding = false }
        }
    }

    // MARK: - States
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("加载中...").font(.system(size: 14)).foregroundColor(.rhSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36)).foregroundColor(.rhError.opacity(0.6))
            Text(msg).font(.system(size: 14)).foregroundColor(.rhSecondary).multilineTextAlignment(.center)
            Button("重试") { Task { await vm.loadFirstPage() } }
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.rhAccent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.rhAccentSoft).frame(width: 72, height: 72)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 30)).foregroundColor(.rhAccent.opacity(0.4))
            }
            Text("暂无作品").font(.system(size: 15)).foregroundColor(.rhSecondary)
            Text("提交任务后，完成的作品将在这里展示")
                .font(.system(size: 12)).foregroundColor(.rhSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toastView(_ msg: String) -> some View {
        VStack {
            Spacer()
            Text(msg)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(Color(hex: "#2D1A0E").opacity(0.82))
                .cornerRadius(22)
                .padding(.bottom, 44)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: toast)
    }

    private func showToast(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { toast = nil }
    }

    enum DecodeTool { case duck, ttV2 }
}

// MARK: - Preview Item (for sheet binding)
private struct PreviewItem: Identifiable {
    let url: String
    var id: String { url }
}

// MARK: - Work Cell
private struct WorkCell: View {
    let work: ProfileWorkItem
    let decodedData: Data?
    let decodeError: String?
    let isDecoding: Bool
    let onTap: (String) -> Void
    let onDecode: () -> Void

    private var displayUrl: String? { work.firstImageUrl }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 主图
            if let data = decodedData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .onTapGesture {
                        if let url = displayUrl { onTap(url) }
                    }
            } else if let url = displayUrl {
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    case .empty:
                        Color.rhCard
                            .aspectRatio(1, contentMode: .fill)
                            .overlay(ProgressView().scaleEffect(0.6))
                    default:
                        Color.rhCard
                            .aspectRatio(1, contentMode: .fill)
                            .overlay(
                                Image(systemName: "photo").font(.system(size: 20)).foregroundColor(.rhBorder)
                            )
                    }
                }
                .onTapGesture { onTap(url) }
            } else {
                // 视频或无图
                Color.rhCard
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(
                        Image(systemName: "video.fill").font(.system(size: 22)).foregroundColor(.rhAccent.opacity(0.5))
                    )
            }

            // 解码按钮（左下角）
            if decodedData == nil {
                Button { onDecode() } label: {
                    HStack(spacing: 3) {
                        if isDecoding {
                            ProgressView().scaleEffect(0.6).tint(.white)
                        } else {
                            Image(systemName: "lock.open.fill").font(.system(size: 9, weight: .semibold))
                        }
                        Text(isDecoding ? "解码中" : "解码")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(Color.rhAccent.opacity(0.88))
                    .cornerRadius(8)
                }
                .disabled(isDecoding)
                .padding(5)
            }

            // 解码成功标记（右上角）
            if decodedData != nil {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.rhSuccess)
                            .padding(5)
                    }
                    Spacer()
                }
            }

            // 错误提示
            if let err = decodeError {
                VStack {
                    Spacer()
                    Text(err)
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .background(Color.rhError.opacity(0.8))
                        .cornerRadius(6)
                        .padding(5)
                }
            }
        }
        .background(Color.rhCard)
    }
}

// MARK: - Image Preview View
private struct ImagePreviewView: View {
    let url: String
    let onToast: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                        .overlay(
                            Button {
                                saveImage(url)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.down").font(.system(size: 13, weight: .semibold))
                                    Text("保存").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.black.opacity(0.55))
                                .cornerRadius(12)
                            }.padding(16),
                            alignment: .bottomTrailing
                        )
                case .empty:
                    ProgressView().tint(.white)
                default:
                    Image(systemName: "photo").font(.system(size: 40)).foregroundColor(.white.opacity(0.4))
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
    }

    private func saveImage(_ urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let img = UIImage(data: data) else { return }
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
    }
}
