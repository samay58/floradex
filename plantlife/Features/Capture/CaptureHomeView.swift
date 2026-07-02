import SwiftUI
import PhotosUI

/// The hero surface: full-bleed viewfinder, shutter in the thumb arc,
/// picker inlet one reach away, reveal card overlaid when a capture is in
/// flight. Permission denial is a designed state with a Settings route.
struct CaptureHomeView: View {
    let model: CaptureFlowModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            background
            VStack {
                Spacer()
                if model.state != .idle {
                    RevealCard(model: model)
                        .transition(reduceMotion
                                    ? .opacity
                                    : .move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, Floradex.Space.m)
                }
                controls
            }
        }
        .animation(reduceMotion ? nil : Floradex.Motion.spring, value: model.state == .idle)
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
                // Seats the hardware keys against any scene the camera shows.
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.30)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
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
            Color.floraGround.ignoresSafeArea()
        }
    }

    private var controls: some View {
        HStack(spacing: 44) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                CameraKey(systemImage: "photo.on.rectangle")
            }
            .buttonStyle(FloraPressStyle())
            .disabled(!model.canStartCapture)

            ShutterButton(enabled: model.canStartCapture && model.cameraAvailability == .ready) {
                Task { await model.shutterPressed() }
            }

            #if DEBUG
            Button {
                model.imported(SampleLeaf.image())
            } label: {
                CameraKey(systemImage: "leaf.circle")
            }
            .buttonStyle(FloraPressStyle())
            .disabled(!model.canStartCapture)
            .accessibilityLabel("Identify a sample leaf")
            #else
            Color.clear.frame(width: 52, height: 52)
            #endif
        }
        .padding(.bottom, 24)
    }
}

/// The shutter as a piece of hardware: a warm ceramic housing holding a
/// convex green glass key, lit from above. The key visibly depresses, its
/// gloss compresses, and the housing shadow tightens, so the press reads
/// physical before the capture haptic lands.
private struct ShutterButton: View {
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Face is drawn by the style so every layer tracks isPressed.
            Color.clear.frame(width: 84, height: 84)
        }
        .buttonStyle(ShutterKeyStyle())
        .disabled(!enabled)
        .saturation(enabled ? 1 : 0)
        .opacity(enabled ? 1 : 0.55)
        .accessibilityLabel("Capture plant photo")
    }
}

private struct ShutterKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            housing(pressed: configuration.isPressed)
            key(pressed: configuration.isPressed)
        }
        .animation(Floradex.Motion.press, value: configuration.isPressed)
    }

    /// Warm ceramic ring, top-lit, resting on two shadow layers that
    /// tighten when pressed.
    private func housing(pressed: Bool) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.floraPaper, .floraGround],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 0.75))
            .frame(width: 84, height: 84)
            .shadow(color: .black.opacity(0.20), radius: pressed ? 5 : 11, y: pressed ? 3 : 7)
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
    }

    /// The green key: convex gradient with an inner bevel, a glass gloss
    /// cap, and the macro-flower mark embossed in white.
    private func key(pressed: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: pressed
                            ? [Color(red: 0.14, green: 0.56, blue: 0.36), Color(red: 0.10, green: 0.46, blue: 0.29)]
                            : [Color(red: 0.30, green: 0.83, blue: 0.55), Color(red: 0.12, green: 0.57, blue: 0.36)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .shadow(.inner(color: .white.opacity(0.45), radius: 1, y: 1.5))
                    .shadow(.inner(color: Color(red: 0.04, green: 0.30, blue: 0.18).opacity(0.55), radius: 3, y: -2))
                )
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(pressed ? 0.22 : 0.42), .white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 50, height: 28)
                .offset(y: -16)
            Image(systemName: "camera.macro")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0.05, green: 0.33, blue: 0.20).opacity(0.6), radius: 0.5, y: 1)
        }
        .frame(width: 68, height: 68)
        .scaleEffect(pressed ? 0.93 : 1)
    }
}

/// The shutter's smaller siblings: warm ceramic keys with the same top
/// light, carrying their marks in ink green.
private struct CameraKey: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(Color.floraPixelInk)
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.floraPaper, .floraGround],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .shadow(.inner(color: .white.opacity(0.5), radius: 1, y: 1))
                    )
            )
            .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
            .contentShape(Circle())
    }
}

/// Camera-missing states as designed scenes on warm ground: the icon sits
/// in a specimen plate, the title speaks serif, and the one action wears
/// the surface's accent.
private struct FallbackBackground: View {
    let symbol: String
    let title: String
    let message: String
    var settingsAction: (() -> Void)?

    var body: some View {
        VStack(spacing: Floradex.Space.m) {
            ZStack {
                RoundedRectangle(cornerRadius: Floradex.Radius.plate)
                    .fill(Color.floraPaper)
                RoundedRectangle(cornerRadius: Floradex.Radius.plate)
                    .strokeBorder(Color.floraHairline, lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: 30))
                    .foregroundStyle(Color.floraGreen)
            }
            .frame(width: 72, height: 72)
            .padding(.bottom, Floradex.Space.xs)
            Text(title)
                .font(.floraDisplay)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if let settingsAction {
                Button("Open Settings", action: settingsAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.floraGreen)
                    .padding(.top, Floradex.Space.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.floraGround)
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
