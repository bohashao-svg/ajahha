import SwiftUI
import Photos

// MARK: - SwiftUI bridge for ImagePickerController
struct ImagePickerSheet: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onDismiss: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> ImagePickerController {
        let config = ImagePickerConfiguration()
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
