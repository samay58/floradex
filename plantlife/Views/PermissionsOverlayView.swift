import SwiftUI
import AVFoundation

/// A full-screen overlay prompting the user to grant Camera & Photo library access.
struct PermissionsOverlayView: View {
    @EnvironmentObject private var permissions: PermissionsManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: Theme.Metrics.Padding.large) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white)
                
                Text("Camera Access Required")
                    .font(Theme.Typography.title2)
                    .foregroundStyle(.white)
                
                Text("Please allow camera access to take photos of plants for identification.")
                    .font(Theme.Typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal)
                
                Button {
                    permissions.requestCameraAccess()
                } label: {
                    Text("Allow Camera Access")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .pillButton(backgroundColor: .white, foregroundColor: .black)
                .padding(.horizontal, 32)
                .padding(.top, 8)
                
                Button {
                    dismiss()
                } label: {
                    Text("Not Now")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(32)
        }
    }
}

#Preview {
    PermissionsOverlayView()
        .environmentObject(PermissionsManager.shared)
} 