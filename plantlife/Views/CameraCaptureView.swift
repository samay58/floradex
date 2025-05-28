import SwiftUI
import AVFoundation

struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var imageService: ImageSelectionService
    @State private var isFlashEnabled: Bool = false
    @State private var appearedAnimation: Bool = false
    @State private var cameraController: CameraViewController?
    
    var body: some View {
        ZStack {
            // Black background for full-screen effect
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Modern toolbar with overlay buttons
                        HStack {
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            }
                            .circularButton(
                                size: 44,
                                backgroundColor: .black.opacity(0.5),
                                foregroundColor: .white,
                                hasBorder: false
                            )
                            
                            Spacer()
                            
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                isFlashEnabled.toggle()
                            } label: {
                                Image(systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isFlashEnabled ? .yellow : .white)
                            }
                            .circularButton(
                                size: 44,
                                backgroundColor: .black.opacity(0.5),
                                foregroundColor: isFlashEnabled ? .yellow : .white,
                                hasBorder: false
                            )
                        }
                        .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Modern camera preview with clean frame
                    ZStack {
                        // Camera controller with rounded corners
                        CameraViewControllerRepresentable(
                            flashEnabled: isFlashEnabled,
                            cameraController: $cameraController
                        ) { image in
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                
                                print("Image captured: \(image.size.width)x\(image.size.height)")
                                imageService.selectedImage = image
                                dismiss()
                            }
                        .frame(maxWidth: geometry.size.width - 32)
                        .frame(height: geometry.size.width - 32) // Square aspect ratio
                        .cornerRadius(Theme.Metrics.cornerRadiusLarge)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                        .opacity(appearedAnimation ? 1 : 0)
                        .offset(y: appearedAnimation ? 0 : 20)
                    }
                    .frame(maxHeight: .infinity)
                    
                    Spacer()
                    
                    // Modern shutter button at bottom
                    HStack {
                        Spacer()
                        
                        Button {
                            // Trigger camera capture
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            cameraController?.capturePhoto()
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .circularButton(
                            size: 72,
                            backgroundColor: Theme.Colors.primaryGreen,
                            foregroundColor: .white,
                            hasBorder: false
                        )
                        .scaleEffect(appearedAnimation ? 1 : 0.95)
                        .padding(.bottom, 40)
                        
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            print("CameraCaptureView appeared")
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appearedAnimation = true
            }
        }
    }
}

// MARK: - UIViewController Wrapper
struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    var flashEnabled: Bool = false
    @Binding var cameraController: CameraViewController?
    var onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onImageCaptured = onImageCaptured
        controller.flashEnabled = flashEnabled
        DispatchQueue.main.async {
            self.cameraController = controller
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.flashEnabled = flashEnabled
    }
}

// MARK: - Camera View Controller
class CameraViewController: UIViewController {
    // Camera components
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    
    // Callback
    var onImageCaptured: ((UIImage) -> Void)?
    var flashEnabled: Bool = false
    
    // Shutter button (will be controlled by SwiftUI now)
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
    
    @objc public func capturePhoto() {
        guard let photoOutput = photoOutput else {
            print("Photo output not available")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashEnabled ? .on : .auto
        
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