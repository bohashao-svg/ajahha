import SwiftUI
import PhotosUI

// MARK: - AI App View
struct AppView: View {
    @StateObject private var vm = AppViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var imagePickerNodeKey: String?
    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        inputCard
                        if !vm.nodes.isEmpty { nodeFormCard }
                        if vm.isPolling { pollingCard }
                        if !vm.outputUrls.isEmpty { outputCard }
                        if vm.taskFailed { failedCard }
                    }
                    .padding(16)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.nodes.isEmpty)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.outputUrls.isEmpty)
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
                    Text("AI 应用")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            // photosPicker 放在 NavigationView 内层，确保能正常弹出
            .photosPicker(
                isPresented: Binding(
                    get: { imagePickerNodeKey != nil },
                    set: { if !$0 { imagePickerNodeKey = nil } }
                ),
                selection: $photoPickerItem,
                matching: .images
            )
            .onChange(of: photoPickerItem) { item in
                guard let key = imagePickerNodeKey, let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run { vm.selectedImages[key] = img }
                    }
                    photoPickerItem = nil
                    imagePickerNodeKey = nil
                }
            }
        }
    }

    // MARK: - Input Card
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 应用")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.rhSecondary)

            HStack(spacing: 10) {
                TextField("输入 AI 应用 ID 或链接", text: $vm.webappInput)
                    .font(.system(size: 15))
                    .foregroundColor(.rhPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.rhBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rhBorder, lineWidth: 1))
                    .onSubmit { Task { await vm.fetchNodes() } }

                Button {
                    Task { await vm.fetchNodes() }
                } label: {
                    if vm.isLoading {
                        ProgressView().frame(width: 40, height: 40)
                    } else {
                        RHIcon(name: .refresh, size: 18, color: .white)
                            .frame(width: 40, height: 40)
                            .background(Color.rhAccent)
                            .cornerRadius(10)
                    }
                }
                .disabled(vm.isLoading || vm.webappInput.isBlank)
                .buttonStyle(ScaleButtonStyle())
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.rhError)
                    .transition(.opacity)
            }
        }
        .rhCard()
    }

    // MARK: - Node Form Card
    private var nodeFormCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Color.rhAccent).frame(width: 3, height: 14)
                Text("节点参数")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.rhPrimary)
            }
            .padding(.bottom, 12)

            ForEach(vm.nodes.indices, id: \.self) { i in
                nodeRow(index: i)
                if i < vm.nodes.count - 1 {
                    Divider().padding(.vertical, 8)
                }
            }

            Divider().padding(.vertical, 12)

            submitButton
        }
        .rhCard()
    }

    private func nodeRow(index: Int) -> some View {
        let node = vm.nodes[index]
        let key = node.nodeId + node.fieldName
        let ft = node.fieldType.uppercased()

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(node.description ?? node.fieldName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.rhPrimary)
                Spacer()
                Text(ft)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.rhAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.rhAccentSoft)
                    .cornerRadius(5)
            }

            if ft == "IMAGE" || ft == "AUDIO" || ft == "VIDEO" {
                imagePickerRow(key: key, fieldType: ft, index: index)
            } else if ft == "LIST" {
                listFieldRow(index: index)
            } else {
                // STRING or other text types
                TextField(node.fieldValue.isEmpty ? "输入值..." : node.fieldValue,
                          text: Binding(
                            get: { vm.nodes[index].fieldValue },
                            set: { vm.nodes[index].fieldValue = $0 }
                          ))
                    .font(.system(size: 14))
                    .foregroundColor(.rhPrimary)
                    .padding(10)
                    .background(Color.rhBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rhBorder, lineWidth: 1))
            }
        }
    }

    private func imagePickerRow(key: String, fieldType: String, index: Int) -> some View {
        Button {
            imagePickerNodeKey = key
        } label: {
            HStack(spacing: 10) {
                if let img = vm.selectedImages[key] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .cornerRadius(8)
                        .clipped()
                    Text("已选择图片")
                        .font(.system(size: 13))
                        .foregroundColor(.rhPrimary)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.rhAccentSoft)
                            .frame(width: 44, height: 44)
                        RHIcon(name: .image, size: 20, color: .rhAccent)
                    }
                    Text("点击选择\(fieldType == "IMAGE" ? "图片" : "文件")")
                        .font(.system(size: 13))
                        .foregroundColor(.rhSecondary)
                }
                Spacer()
                RHIcon(name: .chevron, size: 12, color: .rhBorder)
            }
            .padding(10)
            .background(Color.rhBackground)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rhBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func listFieldRow(index: Int) -> some View {
        let node = vm.nodes[index]
        let options: [String] = {
            if let arr = node.fieldData?.arrayValue {
                return arr.compactMap { $0.stringValue }
            }
            return []
        }()

        return Group {
            if options.isEmpty {
                TextField("输入值...", text: Binding(
                    get: { vm.nodes[index].fieldValue },
                    set: { vm.nodes[index].fieldValue = $0 }
                ))
                .font(.system(size: 14))
                .foregroundColor(.rhPrimary)
                .padding(10)
                .background(Color.rhBackground)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rhBorder, lineWidth: 1))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options, id: \.self) { opt in
                            let selected = vm.nodes[index].fieldValue == opt
                            Button {
                                vm.nodes[index].fieldValue = opt
                            } label: {
                                Text(opt)
                                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                    .foregroundColor(selected ? .white : .rhPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selected ? Color.rhAccent : Color.rhBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selected ? Color.clear : Color.rhBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            Task { await vm.submit() }
        } label: {
            HStack(spacing: 8) {
                if vm.isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    RHIcon(name: .plus, size: 16, color: .white)
                }
                Text(vm.isSubmitting ? "提交中..." : "提交任务")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(vm.isSubmitting ? Color.rhSecondary.opacity(0.35) : Color.rhAccent)
            .cornerRadius(14)
        }
        .disabled(vm.isSubmitting || vm.isPolling)
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Polling Card
    private var pollingCard: some View {
        HStack(spacing: 14) {
            ProgressView().tint(.rhAccent)
            VStack(alignment: .leading, spacing: 3) {
                Text("任务运行中")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rhPrimary)
                if let tid = vm.taskId {
                    Text("ID: \(tid)")
                        .font(.system(size: 11))
                        .foregroundColor(.rhSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .rhCard(padding: 14)
    }

    // MARK: - Output Card
    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Color.rhAccent).frame(width: 3, height: 14)
                Text("生成结果")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.rhPrimary)
            }
            ForEach(vm.outputUrls, id: \.self) { url in
                AppOutputItemView(url: url)
            }
        }
        .rhCard()
    }

    // MARK: - Failed Card
    private var failedCard: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.rhError).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text("任务失败")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rhError)
                if let reason = vm.failedReason {
                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundColor(.rhSecondary)
                }
            }
            Spacer()
        }
        .rhCard(padding: 14)
    }
}

// MARK: - App Output Item View
private struct AppOutputItemView: View {
    let url: String

    var isVideo: Bool {
        ["mp4", "mov", "webm"].contains(url.split(separator: ".").last?.lowercased() ?? "")
    }

    var body: some View {
        if isVideo {
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
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 18))
                            Text("下载").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.rhAccent)
                    }
                }
            }
            .padding(12)
            .background(Color.rhBackground)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rhBorder, lineWidth: 1))
        } else {
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit().cornerRadius(16)
                        .overlay(
                            Link(destination: URL(string: url)!) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("查看")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.55))
                                .cornerRadius(12)
                            }
                            .padding(10),
                            alignment: .bottomTrailing
                        )
                case .failure:
                    HStack(spacing: 8) {
                        RHIcon(name: .image, size: 18, color: .rhSecondary)
                        Text("图片加载失败").font(.system(size: 13)).foregroundColor(.rhSecondary)
                    }
                    .frame(height: 80).frame(maxWidth: .infinity)
                    .background(Color.rhBackground).cornerRadius(14)
                case .empty:
                    ProgressView().frame(height: 120)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}
