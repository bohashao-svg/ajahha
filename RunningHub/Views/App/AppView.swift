import SwiftUI
import PhotosUI

// MARK: - AI App View
struct AppView: View {
    @StateObject private var vm = AppViewModel()
    @Environment(\.dismiss) private var dismiss

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
                AppNodeRow(node: $vm.nodes[i], selectedImages: $vm.selectedImages)
                if i < vm.nodes.count - 1 {
                    Divider().padding(.vertical, 8)
                }
            }

            Divider().padding(.vertical, 12)

            submitButton
        }
        .rhCard()
    }

    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            Task { await vm.submit { dismiss() } }
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

// MARK: - App Node Row
// 每个节点独立持有 @State photoItem，与 ParameterFormView 的 FieldRow 写法完全一致
private struct AppNodeRow: View {
    @Binding var node: AppNodeInfo
    @Binding var selectedImages: [String: UIImage]
    @State private var photoItem: PhotosPickerItem?

    private var key: String { node.nodeId + node.fieldName }
    private var ft: String { node.fieldType.uppercased() }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                imagePickerField
            } else if ft == "LIST" {
                listField
            } else {
                TextField(node.fieldValue.isEmpty ? "输入值..." : node.fieldValue,
                          text: $node.fieldValue)
                    .font(.system(size: 14))
                    .foregroundColor(.rhPrimary)
                    .padding(10)
                    .background(Color.rhBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rhBorder, lineWidth: 1))
            }
        }
    }

    // 与 ParameterFormView imageInput case 完全一致的写法
    private var imagePickerField: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            HStack(spacing: 10) {
                if let img = selectedImages[key] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
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
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22))
                        .foregroundColor(.rhAccent.opacity(0.7))
                        .frame(width: 52, height: 52)
                        .background(Color.rhAccentSoft)
                        .cornerRadius(10)
                    Text("从相册选择图片")
                        .font(.system(size: 14))
                        .foregroundColor(.rhSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.rhBorder)
            }
            .padding(10)
            .background(Color.rhBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhBorder, lineWidth: 1))
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

    private var listField: some View {
        let options: [String] = node.fieldData?.arrayValue?.compactMap { $0.stringValue } ?? []
        return Group {
            if options.isEmpty {
                TextField("输入值...", text: $node.fieldValue)
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
                            let selected = node.fieldValue == opt
                            Button { node.fieldValue = opt } label: {
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
}
