import SwiftUI
import AVFoundation

struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var imageService: ImageSelectionService
    
    var body: some View {
        ZStack {
            // Camera controller
            CameraViewControllerRepresentable { image in
                print("Image captured: \(image.size.width)x\(image.size.height)")
                imageService.selectedImage = image
                dismiss()
            }
            .ignoresSafeArea()
            
            // Camera controls overlay
            VStack {
                // Close button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .circularButton(
                        size: 44,
                        backgroundColor: .black.opacity(0.5),
                        foregroundColor: .white,
                        hasBorder: false
                    )
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
            }
        }
        .onAppear {
            print("CameraCaptureView appeared")
        }
    }
}

// MARK: - UIViewController Wrapper
struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onImageCaptured = onImageCaptured
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

// MARK: - Camera View Controller
class CameraViewController: UIViewController {
    // Camera components
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    
    // Callback
    var onImageCaptured: ((UIImage) -> Void)?
    
    // Shutter button
    private lazy var shutterButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.layer.cornerRadius = 36
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.white.cgColor
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Camera view controller loaded")
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        // Initialize session
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        captureSession = session
        
        // Check camera permission
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            // Will be handled by the permissions overlay
            return
        }
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to get camera input")
            return
        }
        
        guard session.canAddInput(input) else {
            print("Cannot add input to session")
            return
        }
        session.addInput(input)
        
        // Add photo output
        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            print("Cannot add output to session")
            return
        }
        session.addOutput(output)
        output.isHighResolutionCaptureEnabled = true
        photoOutput = output
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        print("Camera setup completed")
    }
    
    private func setupUI() {
        // Add shutter button
        view.addSubview(shutterButton)
        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            shutterButton.widthAnchor.constraint(equalToConstant: 72),
            shutterButton.heightAnchor.constraint(equalToConstant: 72)
        ])
    }
    
    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            print("Camera session started")
        }
    }
    
    private func stopSession() {
        captureSession?.stopRunning()
        print("Camera session stopped")
    }
    
    @objc private func capturePhoto() {
        guard let photoOutput = photoOutput else {
            print("Photo output not available")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        photoOutput.capturePhoto(with: settings, delegate: self)
        print("Capture photo requested")
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to create image from captured data")
            return
        }
        
        // Get the correct orientation
        let newImage: UIImage
        if let cgImage = image.cgImage {
            newImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        } else {
            newImage = image
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onImageCaptured?(newImage)
            print("Photo captured successfully")
        }
    }
}

// MARK: - Preview
#Preview {
    CameraCaptureView()
        .environmentObject(ImageSelectionService.shared)
} 