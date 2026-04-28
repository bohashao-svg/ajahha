import SwiftUI
import Photos

// MARK: - Decode Tool
enum DecodeTool: String, CaseIterable {
    case duck = "鸭鸭解码"
    case tt   = "TT解码"
}

// MARK: - Profile Sheet Destination
enum ProfileSheet: Identifiable {
    case decodePassword(DecodeTool)
    case decodedImage(UIImage)
    case shareFile(URL)

    var id: String {
        switch self {
        case .decodePassword(let tool): return "decode_\(tool.rawValue)"
        case .decodedImage: return "decoded_image"
        case .shareFile(let url): return "share_\(url.path)"
        }
    }
}

// MARK: - Output Action Target
enum OutputActionTarget {
    case item(OutputHistoryItem)

    var item: OutputHistoryItem {
        switch self {
        case .item(let item): return item
        }
    }
}

// MARK: - OutputCard
struct OutputCard: View {
    let item: OutputHistoryItem
    let onMore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.filePreviewUrl ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .empty:
                    Color.rhBorder.opacity(0.3).overlay(ProgressView().scaleEffect(0.7))
                default:
                    Color.rhBorder.opacity(0.3).overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.rhBorder)
                    )
                }
            }
            .frame(width: 80, height: 80)
            .cornerRadius(10)
            .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(item.taskName ?? "未命名")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rhPrimary)
                    .lineLimit(1)

                Text(item.createTime ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.rhSecondary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(item.taskStatus))
                        .frame(width: 6, height: 6)
                    Text(statusText(item.taskStatus))
                        .font(.system(size: 11))
                        .foregroundColor(statusColor(item.taskStatus))
                }
            }

            Spacer()

            Button(action: onMore) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.rhSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.rhCard)
        .cornerRadius(12)
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.uppercased() {
        case "SUCCESS": return .rhSuccess
        case "FAILED": return .rhError
        default: return .rhSecondary
        }
    }

    private func statusText(_ status: String?) -> String {
        switch status?.uppercased() {
        case "SUCCESS": return "成功"
        case "FAILED": return "失败"
        default: return status ?? "未知"
        }
    }
}

// MARK: - Decode Password Sheet
struct DecodePasswordSheet: View {
    let tool: DecodeTool
    @Binding var password: String
    let isDecoding: Bool
    let errorMessage: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("解码密码")
                        .font(.system(size: 13))
                        .foregroundColor(.rhSecondary)
                    SecureField("无密码留空", text: $password)
                        .font(.system(size: 15))
                        .padding(12)
                        .background(Color.rhBackground)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rhBorder, lineWidth: 1))
                    if tool == .tt {
                        Text("TT编码图通常无需输入密码，直接点击解码即可")
                            .font(.system(size: 12))
                            .foregroundColor(.rhSecondary)
                    }
                }

                if let err = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.rhError)
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.rhError)
                    }
                    .padding(10)
                    .background(Color.rhError.opacity(0.08))
                    .cornerRadius(8)
                }

                Button(action: onConfirm) {
                    HStack {
                        if isDecoding {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        }
                        Text(isDecoding ? "解码中..." : "开始解码")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(isDecoding ? Color.rhAccent.opacity(0.6) : Color.rhAccent)
                    .cornerRadius(12)
                }
                .disabled(isDecoding)

                Spacer()
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(tool.rawValue).font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消", action: onCancel).foregroundColor(.rhAccent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Decoded Image Result Sheet
struct DecodedImageSheet: View {
    let image: UIImage
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                Button(action: {
                    onSave()
                    saved = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: saved ? "checkmark" : "square.and.arrow.down")
                        Text(saved ? "已保存" : "保存到相册")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(saved ? Color.rhSuccess : Color.rhAccent)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                .disabled(saved)

                Spacer()
            }
            .padding(.top, 16)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("解码结果").font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundColor(.rhAccent)
                }
            }
        }
    }
}

// MARK: - ProfileView
struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showLoginAlert = false

    @State private var toast: String? = nil
    @State private var selectedActionTarget: OutputActionTarget? = nil
    @State private var showActionDialog = false
    @State private var activeSheet: ProfileSheet? = nil
    @State private var decodePassword = ""
    @State private var isDecoding = false
    @State private var decodeError: String? = nil
    @State private var hasLoadedOnce = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()

                if let err = vm.errorMessage, vm.outputs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 36))
                            .foregroundColor(.rhBorder)
                        Text(err)
                            .font(.system(size: 14))
                            .foregroundColor(.rhSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("重试") {
                            vm.resetPagination()
                            Task { await vm.loadPage(1) }
                        }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.rhAccent)
                    }
                } else {
                    outputList
                }

                if let msg = toast {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(20)
                            .padding(.bottom, 24)
                    }
                    .transition(.opacity.combined(with: .scale))
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
                    Text("我的作品").font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .onAppear {
            guard !hasLoadedOnce else { return }
            hasLoadedOnce = true
            if !StorageService.shared.isLoggedIn {
                showLoginAlert = true
            } else {
                vm.resetPagination()
                Task { await vm.loadPage(1) }
            }
        }
        .alert("请先登录", isPresented: $showLoginAlert) {
            Button("确定") { dismiss() }
        } message: {
            Text("查看个人作品需要先登录账号")
        }
        .confirmationDialog("选择操作", isPresented: $showActionDialog, titleVisibility: .visible) {
            if let item = selectedActionTarget?.item {
                if item.outputType?.lowercased() != "zip" {
                    Button("保存原图到相册") { Task { await saveImage(for: item, useOriginal: true) } }
                    Button("保存预览图到相册") { Task { await saveImage(for: item, useOriginal: false) } }
                }
                Button("鸭鸭解码") { startDecode(.duck) }
                Button("TT解码") { startDecode(.tt) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(selectedActionTarget?.item.taskName ?? "")
        }
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .decodePassword(let tool):
                DecodePasswordSheet(
                    tool: tool,
                    password: $decodePassword,
                    isDecoding: isDecoding,
                    errorMessage: decodeError,
                    onConfirm: { Task { await runDecode(tool: tool) } },
                    onCancel: { activeSheet = nil }
                )
            case .decodedImage(let image):
                DecodedImageSheet(image: image, onSave: { Task { await saveDecodedImage(image) } })
            case .shareFile(let url):
                ShareSheet(items: [url])
            }
        }
    }

    private var outputList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.outputs.indices, id: \.self) { index in
                    let item = vm.outputs[index]
                    OutputCard(item: item) {
                        selectedActionTarget = .item(item)
                        showActionDialog = true
                    }
                }

                if vm.outputs.isEmpty && vm.isLoading {
                    ForEach(0..<6, id: \.self) { _ in OutputCardSkeleton() }
                }

                if vm.hasNext {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            guard !vm.isLoading else { return }
                            Task { await vm.loadPage(vm.currentPage + 1) }
                        }
                }

                if !vm.outputs.isEmpty && vm.isLoading {
                    ProgressView().padding()
                }
            }
            .padding(16)
        }
    }

    private func startDecode(_ tool: DecodeTool) {
        decodePassword = ""
        decodeError = nil
        activeSheet = .decodePassword(tool)
    }

    private func runDecode(tool: DecodeTool) async {
        guard let item = selectedActionTarget?.item else {
            decodeError = "未找到作品信息"
            return
        }
        let urlStr = item.fileUrl ?? item.filePreviewUrl ?? ""
        guard !urlStr.isEmpty else {
            decodeError = "没有可用的图片链接"
            return
        }

        isDecoding = true
        decodeError = nil
        do {
            let fileData: Data
            let fileExt: String
            switch tool {
            case .duck:
                fileData = try await DuckDecodeService.shared.decode(imageUrl: urlStr, password: decodePassword)
                fileExt = "png"
            case .tt:
                let ttFile = try await TTDecodeService.shared.decode(imageUrl: urlStr, password: decodePassword)
                fileData = ttFile.data
                fileExt = ttFile.ext
            }

            isDecoding = false
            let imageExts = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "heic"]
            if imageExts.contains(fileExt.lowercased()), let image = UIImage(data: fileData) {
                activeSheet = .decodedImage(image)
            } else {
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("decoded_\(Int(Date().timeIntervalSince1970)).\(fileExt)")
                try fileData.write(to: tmpURL)
                activeSheet = .shareFile(tmpURL)
            }
        } catch {
            decodeError = error.localizedDescription
            isDecoding = false
        }
    }

    private func saveImage(for item: OutputHistoryItem, useOriginal: Bool) async {
        let urlStr = useOriginal ? (item.fileUrl ?? "") : (item.filePreviewUrl ?? "")
        guard let url = URL(string: urlStr) else {
            showToast("链接无效")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                showToast("图片解析失败")
                return
            }
            await saveUIImageToAlbum(image)
        } catch {
            showToast("保存失败")
        }
    }

    private func saveDecodedImage(_ image: UIImage) async {
        await saveUIImageToAlbum(image)
    }

    private func saveUIImageToAlbum(_ image: UIImage) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .denied || status == .restricted {
            showToast("请在设置中允许访问相册")
            return
        }
        if status == .notDetermined {
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
            if !granted {
                showToast("未授权访问相册")
                return
            }
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            showToast("已保存到相册")
        } catch {
            showToast("保存失败：\(error.localizedDescription)")
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
