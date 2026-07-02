import SwiftUI

/// Tactile press feedback for chips, seals, and undo: 0.96 scale on a
/// quick interruptible spring. Anything smaller reads exaggerated.
/// Disabled buttons desaturate like dead hardware; Reduce Motion keeps the
/// scale change but drops the spring.
struct FloraPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(reduceMotion ? nil : Floradex.Motion.press, value: configuration.isPressed)
    }
}
