import SwiftUI
import PhotosUI

// MARK: - AI App View
struct AppView: View {
    @StateObject private var vm = AppViewModel()
    @Environment(\.dismiss) private var dismiss
    var initialAppId: String = ""

    var body: some View {
        ZStack {
            AnimatedMeshBackground()

            ScrollView {
                VStack(spacing: 16) {
                    inputCard
                    if vm.isLoading {
                        NodeFormCardSkeleton()
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                    } else if !vm.nodes.isEmpty {
                        nodeFormCard
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        submitButton
                            .transition(.opacity)
                            .padding(.horizontal, 16)
                    }
                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.nodes.isEmpty)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    GlassIconButton(icon: .close, size: 18, color: Color(hex: "#8B9CC8"))
                }
            }
            ToolbarItem(placement: .principal) {
                Text("AI 应用")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#F0F4FF"), Color(hex: "#8B9CC8")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }
        }
        .onChange(of: vm.didSubmitSuccessfully) { success in
            if success {
                RHBanner.success("任务已提交", subtitle: "可在任务中心查看进度")
                dismiss()
            }
        }
        .onChange(of: vm.errorMessage) { err in
            if let err, !err.isEmpty {
                RHBanner.error("提交失败", subtitle: err)
            }
        }
        .onAppear {
            if !initialAppId.isEmpty {
                vm.webappInput = initialAppId
                Task { await vm.fetchNodes() }
            }
        }
    }

    // MARK: - Input Card
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                LiquidGlassShape(radius: 2)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3, height: 14)
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.6), radius: 4)
                Text("AI 应用")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#8B9CC8"))
            }

            HStack(spacing: 10) {
                TextField("输入 AI 应用 ID 或链接", text: $vm.webappInput)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                    .tint(Color(hex: "#6C8EFF"))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(LiquidGlassShape(radius: 10).fill(Color.white.opacity(0.05)))
                    .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                    .onSubmit { Task { await vm.fetchNodes() } }

                Button {
                    Task { await vm.fetchNodes() }
                } label: {
                    if vm.isLoading {
                        ProgressView().frame(width: 40, height: 40)
                    } else {
                        RHIcon(name: .refresh, size: 18, color: .white)
                            .frame(width: 40, height: 40)
                            .background(
                                LiquidGlassShape(radius: 10)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                            )
                            .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                            .shadow(color: Color(hex: "#6C8EFF").opacity(0.4), radius: 10)
                    }
                }
                .disabled(vm.isLoading || vm.webappInput.isBlank)
                .buttonStyle(LiquidButtonStyle())
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FF6B6B"))
                    .transition(.opacity)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(vm.nodes.isEmpty ? Color(hex: "#8B9CC8").opacity(0.4) : Color(hex: "#4ECDC4"))
                    .frame(width: 7, height: 7)
                    .shadow(color: vm.nodes.isEmpty ? .clear : Color(hex: "#4ECDC4").opacity(0.6), radius: 4)
                Text(vm.nodes.isEmpty ? "输入应用 ID 后点击刷新" : "已加载 \(vm.nodes.count) 个参数节点")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#8B9CC8"))
                Spacer()
            }
        }
        .rhCard()
        .padding(.horizontal, 16)
    }

    // MARK: - Node Form Card
    private var nodeFormCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                LiquidGlassShape(radius: 2)
                    .fill(Color(hex: "#8B9CC8").opacity(0.5))
                    .frame(width: 3, height: 14)
                Text("节点参数")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
            }

            ForEach(vm.nodes.indices, id: \.self) { i in
                AppNodeRow(node: $vm.nodes[i], selectedImages: $vm.selectedImages, selectedVideos: $vm.selectedVideos)
                if i < vm.nodes.count - 1 {
                    Divider().background(Color.white.opacity(0.08)).padding(.vertical, 4)
                }
            }
        }
        .rhCard()
        .padding(.horizontal, 16)
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
            .frame(height: 52)
            .background(
                LiquidGlassShape(radius: 14)
                    .fill(vm.isSubmitting
                        ? Color.white.opacity(0.06)
                        : LinearGradient(
                            colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(LiquidGlassShape(radius: 14).stroke(Color.white.opacity(vm.isSubmitting ? 0.06 : 0.2), lineWidth: 1))
            .shadow(color: vm.isSubmitting ? .clear : Color(hex: "#6C8EFF").opacity(0.45), radius: 16, x: 0, y: 4)
        }
        .disabled(vm.isSubmitting)
        .buttonStyle(LiquidButtonStyle())
    }
}

// MARK: - App Node Row
struct AppNodeRow: View {
    @Binding var node: AppNodeInfo
    @Binding var selectedImages: [String: UIImage]
    @Binding var selectedVideos: [String: URL]
    @State private var photoItem: PhotosPickerItem?
    @State private var videoItem: PhotosPickerItem?
    @State private var showLoraPicker = false

    private var key: String { node.nodeId + node.fieldName }
    private var ft: String { node.fieldType.uppercased() }
    private var isLora: Bool { ft == "LORA" || node.fieldName.lowercased().contains("lora") }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(node.description ?? node.fieldName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                Spacer()
                Text(isLora ? "LORA" : ft)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "#6C8EFF"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LiquidGlassShape(radius: 5).fill(Color(hex: "#6C8EFF").opacity(0.12)))
                    .overlay(LiquidGlassShape(radius: 5).stroke(Color(hex: "#6C8EFF").opacity(0.2), lineWidth: 0.6))
            }

            if isLora {
                loraField
            } else if ft == "IMAGE" || ft == "AUDIO" {
                imagePickerField
            } else if ft == "VIDEO" {
                videoPickerField
            } else if ft == "LIST" {
                listField
            } else if ft == "BOOLEAN" || ft == "BOOL" {
                Toggle(isOn: Binding(
                    get: { node.fieldValue.lowercased() == "true" },
                    set: { node.fieldValue = $0 ? "true" : "false" }
                )) { EmptyView() }
                .tint(Color(hex: "#6C8EFF"))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(node.fieldValue.isEmpty ? "输入值..." : node.fieldValue,
                          text: $node.fieldValue)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                    .tint(Color(hex: "#6C8EFF"))
                    .padding(10)
                    .background(LiquidGlassShape(radius: 10).fill(Color.white.opacity(0.05)))
                    .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
            }
        }
        .sheet(isPresented: $showLoraPicker) {
            LoRAPickerView { resource in
                let modelName = resource.nodeModelName ?? resource.resourceName ?? ""
                node.fieldValue = modelName
                if let tw = resource.firstTriggerWords, !tw.isEmpty {
                    NotificationCenter.default.post(
                        name: .loraDidSelect,
                        object: nil,
                        userInfo: ["triggerWords": tw, "nodeId": node.nodeId, "source": "app"]
                    )
                }
            }
        }
    }

    private var loraField: some View {
        Button { showLoraPicker = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    LiquidGlassShape(radius: 10)
                        .fill(Color(hex: "#6C8EFF").opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#6C8EFF"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    if node.fieldValue.isEmpty {
                        Text("点击选择 LoRA 模型")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#8B9CC8"))
                    } else {
                        Text(node.fieldValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#F0F4FF"))
                            .lineLimit(1)
                        Text("LoRA 模型").font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#8B9CC8").opacity(0.5))
            }
            .padding(10)
            .background(LiquidGlassShape(radius: 12).fill(Color.white.opacity(0.04)))
            .overlay(LiquidGlassShape(radius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private var imagePickerField: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            HStack(spacing: 10) {
                if let img = selectedImages[key] {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(LiquidGlassShape(radius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已选择图片").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "#F0F4FF"))
                        Text("点击重新选择").font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
                    }
                } else {
                    ZStack {
                        LiquidGlassShape(radius: 10)
                            .fill(Color(hex: "#6C8EFF").opacity(0.1))
                            .frame(width: 52, height: 52)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22)).foregroundColor(Color(hex: "#6C8EFF").opacity(0.7))
                    }
                    Text("从相册选择图片").font(.system(size: 14)).foregroundColor(Color(hex: "#8B9CC8"))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(hex: "#8B9CC8").opacity(0.5))
            }
            .padding(10)
            .background(LiquidGlassShape(radius: 12).fill(Color.white.opacity(0.04)))
            .overlay(LiquidGlassShape(radius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        }
        .onChange(of: photoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    selectedImages[key] = img
                    node.fieldValue = "pending_upload"
                }
            }
        }
    }

    private var videoPickerField: some View {
        PhotosPicker(selection: $videoItem, matching: .videos) {
            HStack(spacing: 10) {
                ZStack {
                    LiquidGlassShape(radius: 10)
                        .fill(Color(hex: "#6C8EFF").opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: selectedVideos[key] != nil ? "video.fill" : "video.badge.plus")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "#6C8EFF"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let videoURL = selectedVideos[key] {
                        Text(videoURL.lastPathComponent)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#F0F4FF"))
                            .lineLimit(1)
                        Text("点击重新选择").font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
                    } else {
                        Text("从相册选择视频")
                            .font(.system(size: 14)).foregroundColor(Color(hex: "#8B9CC8"))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(hex: "#8B9CC8").opacity(0.5))
            }
            .padding(10)
            .background(LiquidGlassShape(radius: 12).fill(Color.white.opacity(0.04)))
            .overlay(LiquidGlassShape(radius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        }
        .onChange(of: videoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    let ext = (newItem.supportedContentTypes.first?.preferredFilenameExtension ?? "mp4")
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + "." + ext)
                    try? data.write(to: tmp)
                    selectedVideos[key] = tmp
                    node.fieldValue = "pending_upload"
                }
            }
        }
    }

    private var listField: some View {
        let options: [String] = node.fieldData?.arrayValue?.compactMap { $0.stringValue } ?? []
        return Group {
            if options.isEmpty {
                TextField("输入值...", text: $node.fieldValue)
                    .font(.system(size: 14)).foregroundColor(Color(hex: "#F0F4FF"))
                    .tint(Color(hex: "#6C8EFF"))
                    .padding(10)
                    .background(LiquidGlassShape(radius: 10).fill(Color.white.opacity(0.05)))
                    .overlay(LiquidGlassShape(radius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options, id: \.self) { opt in
                            let selected = node.fieldValue == opt
                            Button { node.fieldValue = opt } label: {
                                Text(opt)
                                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                    .foregroundColor(selected ? .white : Color(hex: "#8B9CC8"))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(
                                        LiquidGlassShape(radius: 8)
                                            .fill(selected
                                                ? LinearGradient(
                                                    colors: [Color(hex: "#6C8EFF"), Color(hex: "#4A6FE8")],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                )
                                                : LinearGradient(colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                                            )
                                    )
                                    .overlay(
                                        LiquidGlassShape(radius: 8)
                                            .stroke(selected ? Color.white.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 0.8)
                                    )
                                    .shadow(color: selected ? Color(hex: "#6C8EFF").opacity(0.3) : .clear, radius: 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
