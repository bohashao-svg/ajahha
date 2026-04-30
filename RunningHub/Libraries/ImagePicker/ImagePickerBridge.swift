import SwiftUI
import Photos

// MARK: - ImagePickerSheet (Liquid Glass)
struct ImagePickerSheet: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onDismiss: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> ImagePickerController {
        let config = ImagePickerConfiguration()
        config.mainColor = UIColor(hex: "#6C8EFF")
        config.backgroundColor = UIColor(hex: "#0A0E1A")
        config.gallerySeparatorColor = UIColor(white: 1, alpha: 0.06)
        config.settingsColor = UIColor(hex: "#F0F4FF")
        config.noImagesTitle = "暂无图片"
        config.noCameraTitle = "相机不可用"
        config.cancelButtonTitle = "取消"
        config.doneButtonTitle = "完成"
        config.allowMultiplePhotoSelection = false
        config.recordLocation = false

        let vc = ImagePickerController(configuration: config)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ImagePickerController, context: Context) {}

    final class Coordinator: NSObject, ImagePickerDelegate {
        let parent: ImagePickerSheet
        init(_ parent: ImagePickerSheet) { self.parent = parent }

        func wrapperDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {}

        func doneButtonDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
            parent.selectedImage = images.first
            imagePicker.dismiss(animated: true) { self.parent.onDismiss?() }
        }

        func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
            imagePicker.dismiss(animated: true) { self.parent.onDismiss?() }
        }
    }
}

// MARK: - Multi-Image Picker Sheet
struct MultiImagePickerSheet: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    var maxCount: Int = 9
    var onDismiss: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> ImagePickerController {
        let config = ImagePickerConfiguration()
        config.allowMultiplePhotoSelection = true
        config.recordLocation = false
        config.mainColor = UIColor(hex: "#6C8EFF")
        config.backgroundColor = UIColor(hex: "#0A0E1A")
        config.gallerySeparatorColor = UIColor(white: 1, alpha: 0.06)
        config.settingsColor = UIColor(hex: "#F0F4FF")
        config.noImagesTitle = "暂无图片"
        config.cancelButtonTitle = "取消"
        config.doneButtonTitle = "完成"

        let vc = ImagePickerController(configuration: config)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ImagePickerController, context: Context) {}

    final class Coordinator: NSObject, ImagePickerDelegate {
        let parent: MultiImagePickerSheet
        init(_ parent: MultiImagePickerSheet) { self.parent = parent }

        func wrapperDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {}

        func doneButtonDidPress(_ imagePicker: ImagePickerController, images: [UIImage]) {
            parent.selectedImages = Array(images.prefix(parent.maxCount))
            imagePicker.dismiss(animated: true) { self.parent.onDismiss?() }
        }

        func cancelButtonDidPress(_ imagePicker: ImagePickerController) {
            imagePicker.dismiss(animated: true) { self.parent.onDismiss?() }
        }
    }
}

// MARK: - Liquid Glass Image Picker Button
struct LiquidImagePickerButton: View {
    @Binding var selectedImage: UIImage?
    @State private var showPicker = false
    var label: String = "选择图片"
    var icon: String = "photo.on.rectangle.angled"

    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    LiquidGlassShape(radius: 10)
                        .fill(Color(hex: "#6C8EFF").opacity(0.12))
                        .frame(width: 40, height: 40)
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(LiquidGlassShape(radius: 10))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#6C8EFF"))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedImage != nil ? "已选择图片" : label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: selectedImage != nil ? "#F0F4FF" : "#8B9CC8"))
                    if selectedImage != nil {
                        Text("点击重新选择")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#8B9CC8"))
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
        .sheet(isPresented: $showPicker) {
            ImagePickerSheet(selectedImage: $selectedImage)
        }
    }
}
