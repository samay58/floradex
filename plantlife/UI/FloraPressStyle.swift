import SwiftUI

/// Tactile press feedback for chips, seals, and undo: 0.96 scale on a
/// quick interruptible spring. Anything smaller reads exaggerated.
struct FloraPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Floradex.Motion.press, value: configuration.isPressed)
    }
}
