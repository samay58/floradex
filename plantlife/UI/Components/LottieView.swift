#if canImport(Lottie)

import SwiftUI
import Lottie // Requires lottie-ios package

struct LottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let contentMode: UIView.ContentMode
    @Binding var play: Bool // Binding to control playback

    private let animationView = LottieAnimationView()

    init(animationName: String,
         loopMode: LottieLoopMode = .playOnce,
         contentMode: UIView.ContentMode = .scaleAspectFit,
         play: Binding<Bool> = .constant(true)) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.contentMode = contentMode
        self._play = play
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        animationView.animation = LottieAnimation.named(animationName)
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if play {
            if !animationView.isAnimationPlaying {
                animationView.play { _ in
                    if loopMode == .playOnce {
                        DispatchQueue.main.async { self.play = false }
                    }
                }
            }
        } else {
            if animationView.isAnimationPlaying { animationView.stop() }
        }
    }
}

#else

import SwiftUI

// Fallback stub when Lottie package is not available.
struct LottieView: View {
    // Mimic the API so call-sites compile even without the real package.
    typealias LottieLoopMode = Int

    let animationName: String
    let loopMode: LottieLoopMode
    @Binding var play: Bool

    // Convenience init matching real signature defaults
    init(animationName: String,
         loopMode: LottieLoopMode = 0,
         contentMode: UIView.ContentMode = .scaleAspectFit,
         play: Binding<Bool> = .constant(true)) {
        self.animationName = animationName
        self.loopMode = loopMode
        self._play = play
    }

    var body: some View {
        // Placeholder – immediately end "animation" so callers reset state
        EmptyView()
            .onAppear {
                // Ensure any bindings reset so sprites become visible
                if play { play = false }
            }
    }
}

// Provide `.playOnce` constant so call-sites like `loopMode: .playOnce` compile when Lottie isn't linked.
extension Int {
    static let playOnce: Int = 0
}

#endif

#if DEBUG
struct LottieView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Lottie Animation Preview")
            LottieView(animationName: "sampleLottieAnim")
                .frame(width: 200, height: 200)
            Text("Note: Requires 'sampleLottieAnim.json' & Lottie pkg")
                .font(.caption)
        }
    }
}
#endif 