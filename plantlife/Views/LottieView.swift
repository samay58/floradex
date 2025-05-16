import SwiftUI

#if canImport(Lottie)
import Lottie

struct LottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode = .playOnce

    func makeUIView(context: Context) -> some UIView {
        let view = AnimationView(name: animationName)
        view.contentMode = .scaleAspectFit
        view.loopMode = loopMode
        view.play { _ in }
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
#else
// Fallback stub when Lottie package not linked yet
struct LottieView: View {
    let animationName: String
    var body: some View { EmptyView() }
}
#endif 