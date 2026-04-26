import SwiftUI
import PhotosUI

// MARK: - Parameter Form View
struct ParameterFormView: View {
    @Binding var fields: [FormField]

    var body: some View {
        if !fields.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("参数配置")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.rhSecondary)

                ForEach($fields) { $field in
                    FieldRow(field: $field)
                    if field.id != fields.last?.id {
                        Divider().background(Color.rhBorder)
                    }
                }
            }
            .rhCard()
        }
    }
}

// MARK: - Field Row
private struct FieldRow: View {
    @Binding var field: FormField
    @FocusState private var isFocused: Bool
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RHIcon(name: field.type == .imageInput ? .image : .workflow, size: 13, color: .rhSecondary)
                Text(field.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.rhPrimary)
            }
            fieldInput
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var fieldInput: some View {
        switch field.type {
        case .multilineText:
            ZStack(alignment: .topLeading) {
                if field.value.isEmpty {
                    Text(field.placeholder)
                        .font(.system(size: 14))
                        .foregroundColor(.rhSecondary.opacity(0.5))
                        .padding(.top, 9)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $field.value)
                    .font(.system(size: 14))
                    .foregroundColor(.rhPrimary)
                    .frame(minHeight: 80, maxHeight: 160)
                    .focused($isFocused)
            }
            .padding(10)
            .background(Color.rhBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.rhAccent.opacity(0.5) : Color.rhBorder, lineWidth: 1)
            )
            .onTapGesture { isFocused = true }

        case .password:
            SecureField(field.placeholder, text: $field.value)
                .font(.system(size: 14))
                .foregroundColor(.rhPrimary)
                .padding(10)
                .background(Color.rhBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.rhAccent.opacity(0.5) : Color.rhBorder, lineWidth: 1)
                )
                .focused($isFocused)

        case .imageInput:
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 10) {
                    if let img = field.selectedImage {
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.rhBorder, lineWidth: 1)
                )
            }
            .onChange(of: photoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        field.selectedImage = img
                        field.value = "pending_upload"  // 占位，submit 时替换为 fileName
                    }
                }
            }

        case .text:
            TextField(field.placeholder, text: $field.value)
                .font(.system(size: 14))
                .foregroundColor(.rhPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(10)
                .background(Color.rhBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.rhAccent.opacity(0.5) : Color.rhBorder, lineWidth: 1)
                )
                .focused($isFocused)
        }
    }
}
