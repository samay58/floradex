import SwiftUI
import PhotosUI

/// The hero surface: full-bleed viewfinder, shutter in the thumb arc,
/// picker inlet one reach away, reveal card overlaid when a capture is in
/// flight. Permission denial is a designed state with a Settings route.
struct CaptureHomeView: View {
    let model: CaptureFlowModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            background
            VStack {
                Spacer()
                if model.state != .idle {
                    RevealCard(model: model)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 12)
                }
                controls
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.state == .idle)
        .task {
            await model.startCamera()
            #if DEBUG
            // Drives the fixture demo unattended (simulator screenshots,
            // future Maestro flows). Pairs with FLORADEX_FIXTURES=1.
            if ProcessInfo.processInfo.environment["FLORADEX_AUTORUN"] == "1" {
                try? await Task.sleep(for: .seconds(1))
                model.imported(SampleLeaf.image())
            }
            #endif
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            pickerItem = nil
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    model.imported(image)
                }
            }
        }
        // Release the camera promptly in the background (privacy indicator,
        // battery) instead of waiting for the system to suspend it.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await model.startCamera() }
            case .background:
                Task { await model.camera.stop() }
            default:
                break
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        switch model.cameraAvailability {
        case .ready:
            CameraPreviewView(source: model.camera.previewSource)
                .ignoresSafeArea()
        case .denied:
            FallbackBackground(
                symbol: "video.slash",
                title: "Camera access is off",
                message: "Floradex uses the camera to identify plants. You can turn it on in Settings, or pick a photo instead."
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .unavailable:
            FallbackBackground(
                symbol: "camera.on.rectangle",
                title: "No camera here",
                message: "Pick a photo from your library to identify a plant."
            )
        case .unknown:
            Color(.systemBackground).ignoresSafeArea()
        }
    }

    private var controls: some View {
        HStack(spacing: 44) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .frame(width: 52, height: 52)
                    .background(.regularMaterial, in: Circle())
            }
            .disabled(!model.canStartCapture)

            ShutterButton(enabled: model.canStartCapture && model.cameraAvailability == .ready) {
                Task { await model.shutterPressed() }
            }

            #if DEBUG
            Button {
                model.imported(SampleLeaf.image())
            } label: {
                Image(systemName: "leaf.circle")
                    .font(.title2)
                    .frame(width: 52, height: 52)
                    .background(.regularMaterial, in: Circle())
            }
            .disabled(!model.canStartCapture)
            .accessibilityLabel("Identify a sample leaf")
            #else
            Color.clear.frame(width: 52, height: 52)
            #endif
        }
        .padding(.bottom, 24)
    }
}

private struct ShutterButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(.white)
                    .frame(width: 62, height: 62)
            }
            .shadow(radius: 6)
            .opacity(enabled ? 1 : 0.4)
        }
        .disabled(!enabled)
        .accessibilityLabel("Capture plant photo")
    }
}

private struct FallbackBackground: View {
    let symbol: String
    let title: String
    let message: String
    var settingsAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Color.floraGreen)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if let settingsAction {
                Button("Open Settings", action: settingsAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.floraGreen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}

#if DEBUG
enum SampleLeaf {
    /// A generated stand-in photo so the whole loop runs on simulators with
    /// no camera; pairs with the fixture-provider composition.
    static func image() -> UIImage {
        let size = CGSize(width: 600, height: 800)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let leaf = UIBezierPath()
            leaf.move(to: CGPoint(x: 300, y: 120))
            leaf.addQuadCurve(to: CGPoint(x: 300, y: 660), controlPoint: CGPoint(x: 560, y: 400))
            leaf.addQuadCurve(to: CGPoint(x: 300, y: 120), controlPoint: CGPoint(x: 40, y: 400))
            UIColor.systemGreen.setFill()
            leaf.fill()

            let vein = UIBezierPath()
            vein.move(to: CGPoint(x: 300, y: 140))
            vein.addLine(to: CGPoint(x: 300, y: 640))
            vein.lineWidth = 6
            UIColor.white.withAlphaComponent(0.6).setStroke()
            vein.stroke()
        }
    }
}
#endif
