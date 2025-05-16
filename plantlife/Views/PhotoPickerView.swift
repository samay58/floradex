import SwiftUI
import PhotosUI

// Publishes the latest chosen or captured UIImage across the app
final class ImageSelectionService: ObservableObject {
    static let shared = ImageSelectionService()
    @Published var selectedImage: UIImage? = nil
    private init() {}
}

// SwiftUI wrapper for PHPickerViewController
struct PhotoPickerView: UIViewControllerRepresentable {
    @EnvironmentObject private var imageService: ImageSelectionService

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    // MARK: - Coordinator
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        init(parent: PhotoPickerView) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard
                let provider = results.first?.itemProvider,
                provider.canLoadObject(ofClass: UIImage.self)
            else { return }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let self else { return }
                if let img = object as? UIImage {
                    DispatchQueue.main.async { self.parent.imageService.selectedImage = img }
                } else if let error {
                    print("PhotoPicker error: \(error.localizedDescription)")
                }
            }
        }
    }
} 