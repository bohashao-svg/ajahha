import SwiftUI
import PhotosUI

// MARK: - AI App View
struct AppView: View {
    @StateObject private var vm = AppViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var imagePickerNodeKey: String?
    @State private var showImagePicker = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        inputCard
                        if !vm.nodes.isEmpty { nodeFormCard }
                    }
                    .padding(16)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.nodes.isEmpty)
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
        }
        // 用 sheet 包裹 PHPickerView，与工作流图片选择方式一致，避免 NavigationView 层级问题
        .sheet(isPresented: $showImagePicker) {
            if let key = imagePickerNodeKey {
                PHPickerView { image in
                    if let image {
                        vm.selectedImages[key] = image
                    }
                    showImagePicker = false
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
                imagePickerRow(key: key, fieldType: ft)
            } else if ft == "LIST" {
                listFieldRow(index: index)
            } else {
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

    private func imagePickerRow(key: String, fieldType: String) -> some View {
        Button {
            imagePickerNodeKey = key
            showImagePicker = true
        } label: {
            HStack(spacing: 10) {
                if let img = vm.selectedImages[key] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .cornerRadius(10)
                        .clipped()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已选择图片")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.rhPrimary)
                        Text("点击重新选择")
                            .font(.system(size: 11))
                            .foregroundColor(.rhSecondary)
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.rhAccentSoft)
                            .frame(width: 56, height: 56)
                        RHIcon(name: .image, size: 22, color: .rhAccent)
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
        let options: [String] = node.fieldData?.arrayValue?.compactMap { $0.stringValue } ?? []

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
            Task {
                await vm.submit { dismiss() }
            }
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
        .disabled(vm.isSubmitting)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - PHPickerView (UIViewControllerRepresentable)
// 与工作流图片选择保持一致的实现方式，避免 PhotosPicker 在 sheet 内的层级问题
struct PHPickerView: UIViewControllerRepresentable {
    let onPick: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                onPick(nil)
                return
            }
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    self.onPick(object as? UIImage)
                }
            }
        }
    }
}
