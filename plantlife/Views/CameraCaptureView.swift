import SwiftUI
import AVFoundation
import PhotosUI

struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var imageService: ImageSelectionService
    @State private var isFlashEnabled: Bool = false
    @State private var cameraController: CameraViewController?
    @State private var showingPhotoPicker = false
    @State private var captureAnimation = false
    
    var body: some View {
        ZStack {
            // Full-screen camera preview
            CameraViewControllerRepresentable(
                flashEnabled: isFlashEnabled,
                cameraController: $cameraController
            ) { image in
                // Capture animation
                withAnimation(.easeOut(duration: 0.1)) {
                    captureAnimation = true
                }
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                print("Image captured: \(image.size.width)x\(image.size.height)")
                imageService.selectedImage = image
                
                // Delay dismiss to show capture animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    dismiss()
                }
            }
            .ignoresSafeArea()
            
            // Flash overlay for capture animation
            if captureAnimation {
                Color.white
                    .ignoresSafeArea()
                    .opacity(captureAnimation ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: captureAnimation)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            captureAnimation = false
                        }
                    }
            }
            
            // Top controls overlay
            VStack {
                HStack {
                    // Close button
                    Button {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    
                    Spacer()
                    
                    // Flash button
                    Button {
                        HapticManager.shared.buttonTap()
                        isFlashEnabled.toggle()
                        cameraController?.flashEnabled = isFlashEnabled
                    } label: {
                        Image(systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isFlashEnabled ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60) // Account for status bar
                
                Spacer()
                
                // Bottom controls
                HStack(alignment: .center, spacing: 60) {
                    // Photo library button
                    Button {
                        HapticManager.shared.buttonTap()
                        showingPhotoPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    
                    // Capture button
                    Button {
                        HapticManager.shared.cameraCapture()
                        if let controller = cameraController {
                            controller.capturePhoto()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.primaryGreen)
                                .frame(width: 70, height: 70)
                            
                            Circle()
                                .stroke(Theme.Colors.primaryGreen.opacity(0.3), lineWidth: 6)
                                .frame(width: 80, height: 80)
                        }
                    }
                    .scaleEffect(captureAnimation ? 0.9 : 1.0)
                    
                    // Spacer for balance
                    Color.clear
                        .frame(width: 50, height: 50)
                }
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPickerView()
                .environmentObject(imageService)
        }
        .onAppear {
            print("CameraCaptureView appeared")
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
    private var isCapturing = false
    
    // Callback
    var onImageCaptured: ((UIImage) -> Void)?
    var flashEnabled: Bool = false {
        didSet {
            // Update flash mode when changed
            configureFlashMode()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[CameraViewController] viewDidLoad")
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("[CameraViewController] viewWillAppear")
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("[CameraViewController] viewWillDisappear")
        stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update preview layer frame to fill the entire view
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = view.bounds
        CATransaction.commit()
    }
    
    private func setupCamera() {
        print("[CameraViewController] Setting up camera")
        
        // Check camera permission first
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            print("[CameraViewController] Camera not authorized")
            return
        }
        
        // Initialize session
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Set preset for high quality photos
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        captureSession = session
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("[CameraViewController] No back camera available")
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
                print("[CameraViewController] Camera input added")
            } else {
                print("[CameraViewController] Cannot add camera input")
                session.commitConfiguration()
                return
            }
        } catch {
            print("[CameraViewController] Error creating camera input: \(error)")
            session.commitConfiguration()
            return
        }
        
        // Add photo output
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            // Configure for best quality
            output.maxPhotoQualityPrioritization = .quality
            photoOutput = output
            print("[CameraViewController] Photo output added")
        } else {
            print("[CameraViewController] Cannot add photo output")
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        
        // Add to view's layer
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
        
        print("[CameraViewController] Camera setup completed successfully")
    }
    
    private func startSession() {
        guard let session = captureSession else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning {
                session.startRunning()
                print("[CameraViewController] Camera session started")
            }
        }
    }
    
    private func stopSession() {
        guard let session = captureSession else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning {
                session.stopRunning()
                print("[CameraViewController] Camera session stopped")
            }
        }
    }
    
    private func configureFlashMode() {
        // Flash configuration will be applied when taking photo
    }
    
    @objc public func capturePhoto() {
        guard !isCapturing else {
            print("[CameraViewController] Already capturing")
            return
        }
        
        guard let photoOutput = photoOutput else {
            print("[CameraViewController] Photo output not available")
            return
        }
        
        guard let session = captureSession, session.isRunning else {
            print("[CameraViewController] Capture session is not running")
            return
        }
        
        isCapturing = true
        
        // Configure photo settings
        let settings = AVCapturePhotoSettings()
        
        // Configure flash
        if photoOutput.supportedFlashModes.contains(.auto) {
            settings.flashMode = flashEnabled ? .on : .auto
        }
        
        // Enable best quality
        settings.photoQualityPrioritization = .quality
        
        // Capture the photo
        print("[CameraViewController] Capturing photo with flash: \(flashEnabled ? "on" : "auto")")
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            isCapturing = false
        }
        
        if let error = error {
            print("[CameraViewController] Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("[CameraViewController] No image data")
            return
        }
        
        guard let image = UIImage(data: imageData) else {
            print("[CameraViewController] Failed to create UIImage from data")
            return
        }
        
        // Fix orientation based on device orientation
        let fixedImage: UIImage
        if let cgImage = image.cgImage {
            // For back camera in portrait mode, the image needs to be rotated right
            fixedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .right)
        } else {
            fixedImage = image
        }
        
        print("[CameraViewController] Photo captured successfully: \(fixedImage.size)")
        
        // Call completion handler on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onImageCaptured?(fixedImage)
        }
    }
}

// MARK: - Preview
#Preview {
    CameraCaptureView()
        .environmentObject(ImageSelectionService.shared)
} 