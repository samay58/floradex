import SwiftUI
import AVFoundation

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published private(set) var isFullyAuthorized = false
    
    private init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isFullyAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isFullyAuthorized = granted
                }
            }
        default:
            isFullyAuthorized = false
        }
    }
    
    func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                self?.isFullyAuthorized = granted
            }
        }
    }
} 