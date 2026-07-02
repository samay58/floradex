import AVFoundation
import Foundation

/// Hands the capture session to the preview layer across isolation domains.
/// AVCaptureSession is documented thread-safe for the operations used here
/// (configuration happens inside the actor; the preview layer only renders).
struct CameraPreviewSource: @unchecked Sendable {
    let session: AVCaptureSession
}

enum CameraSessionError: Error {
    case notAuthorized
    case cameraUnavailable
    case captureFailed(String)
}

/// Owns the AVFoundation capture stack off the main actor. Pre-warm on app
/// foreground so glass-to-glass latency is near zero by the time the
/// viewfinder is visible; responsive-capture options keep the shutter
/// feeling mechanical.
actor CameraSession {
    nonisolated let previewSource = CameraPreviewSource(session: AVCaptureSession())

    private let photoOutput = AVCapturePhotoOutput()
    private var configured = false
    private var inFlight: [UUID: PhotoCaptureDelegate] = [:]

    private var session: AVCaptureSession { previewSource.session }

    static func authorize() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func prewarm() throws {
        if configured {
            if !session.isRunning { session.startRunning() }
            return
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw CameraSessionError.cameraUnavailable
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            throw CameraSessionError.cameraUnavailable
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        if photoOutput.isResponsiveCaptureSupported {
            photoOutput.isResponsiveCaptureEnabled = true
            if photoOutput.isFastCapturePrioritizationSupported {
                photoOutput.isFastCapturePrioritizationEnabled = true
            }
        }
        session.commitConfiguration()
        session.startRunning()
        configured = true
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
    }

    /// Encoded photo data (HEIC or JPEG per system default).
    func capturePhoto() async throws -> Data {
        guard configured else { throw CameraSessionError.cameraUnavailable }
        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate(continuation: continuation) { [weak self] in
                Task { await self?.finish(id) }
            }
            inFlight[id] = delegate
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }

    private func finish(_ id: UUID) {
        inFlight[id] = nil
    }
}

/// Bridges the delegate callback to a continuation. Retained by the session
/// actor until the capture completes; the callback arrives on the photo
/// output's queue, hence the unchecked-Sendable contract.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<Data, Error>?
    private let onFinish: @Sendable () -> Void

    init(continuation: CheckedContinuation<Data, Error>, onFinish: @escaping @Sendable () -> Void) {
        self.continuation = continuation
        self.onFinish = onFinish
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer { onFinish() }
        if let error {
            continuation?.resume(throwing: CameraSessionError.captureFailed(error.localizedDescription))
        } else if let data = photo.fileDataRepresentation() {
            continuation?.resume(returning: data)
        } else {
            continuation?.resume(throwing: CameraSessionError.captureFailed("photo produced no data"))
        }
        continuation = nil
    }
}
