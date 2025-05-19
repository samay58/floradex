import SwiftUI
import UIKit

/// A single tag chip rendered with UIKit so we can use `UIDynamicAnimator` for fun spring-loaded wobble.
/// ‑ Parameter isSelected: bound to the parent so toggling updates selection state.
struct PhysicsTagChip: UIViewRepresentable {
    let tagName: String
    @Binding var isSelected: Bool

    // MARK: ‑ Coordinator
    class Coordinator {
        var parent: PhysicsTagChip
        init(parent: PhysicsTagChip) { self.parent = parent }

        @objc func tapped(_ sender: ChipButton) {
            // Toggle state through the binding
            parent.isSelected.toggle()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> ChipButton {
        let button = ChipButton(tagName: tagName)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped(_:)), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ChipButton, context: Context) {
        uiView.updateAppearance(isSelected: isSelected)
    }
}

// MARK: ‑ Internal UIButton subclass
final class ChipButton: UIButton {
    private var animator: UIDynamicAnimator?

    init(tagName: String) {
        super.init(frame: .zero)
        setTitle(tagName, for: .normal)
        titleLabel?.font = UIFont.preferredFont(forTextStyle: .caption1).withTraits(traits: .traitBold)
        setupStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    /// Apply Floradex styling.
    private func setupStyle() {
        setTitleColor(UIColor(Theme.Colors.primary), for: .normal)
        backgroundColor = UIColor.systemFill.withAlphaComponent(0.2)
        layer.borderWidth = 1
        layer.borderColor = UIColor.tintColor.withAlphaComponent(0.25).cgColor
        clipsToBounds = true
    }

    /// Public API for SwiftUI wrapper.
    func updateAppearance(isSelected: Bool) {
        isSelected ? applySelectedStyle() : applyNormalStyle()
        if isSelected { wobble() }
    }

    private func applySelectedStyle() {
        setTitleColor(.white, for: .normal)
        backgroundColor = UIColor.tintColor
        layer.borderColor = UIColor.tintColor.withAlphaComponent(0.0).cgColor
    }

    private func applyNormalStyle() {
        setTitleColor(UIColor(Theme.Colors.primary), for: .normal)
        backgroundColor = UIColor.systemFill.withAlphaComponent(0.2)
        layer.borderColor = UIColor.tintColor.withAlphaComponent(0.25).cgColor
    }

    /// Kick off a spring wobble with `UIDynamicAnimator`.
    private func wobble() {
        // Clean existing behaviours
        animator?.removeAllBehaviors()
        animator = UIDynamicAnimator(referenceView: superview ?? self)

        guard let animator = animator else { return }
        // Attach the button to its current centre with a spring.
        let attachment = UIAttachmentBehavior(item: self, attachedToAnchor: center)
        attachment.damping = 0.25
        attachment.frequency = 3.0
        animator.addBehavior(attachment)

        // Give it a quick nudge so it oscillates.
        let push = UIPushBehavior(items: [self], mode: .instantaneous)
        let angle = CGFloat.random(in: (.pi/4)...(.pi*3/4))
        push.setAngle(angle, magnitude: 0.015)
        animator.addBehavior(push)

        // Fade out the motion after ~0.8s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.animator?.removeAllBehaviors()
        }
    }
}

// MARK: ‑ Small UIFont helper
fileprivate extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0) // 0 maintains the size
    }
} 