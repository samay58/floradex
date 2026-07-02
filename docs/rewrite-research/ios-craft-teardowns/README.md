# iOS craft teardowns for the Floradex rewrite

These notes are reference inputs for the Floradex rewrite spec and Fable handoff. They should not be treated as instructions to copy Avec or v0 directly. The point is to translate their mobile craft principles into a native Floradex app.

Files:

- `second-teardown-avec-technical-stack.md`: Avec technical architecture and stack analysis. Read this first because it names systems, latency boundaries, testing loops, and implementation phases.
- `first-teardown-avec-v0-ios-craft-systems.md`: Avec and v0 craft synthesis. Read this second because it extracts the product-quality principles behind excellent iPhone apps.

How Fable should use these:

1. Read the Floradex repo first. Do not start from the teardowns.
2. Read the second teardown, then the first teardown.
3. Extract principles, not stack cargo-culting. Floradex is currently a native SwiftUI/Xcode app, so React Native is not the default rewrite answer.
4. Translate the lessons into Floradex's core loop: capture a plant, identify it, reveal a beautiful dex result, save it, revisit it, and correct it when the model is unsure.
5. Build a fixture and regression loop for real-world failures: bad photos, low confidence, duplicate plants, provider disagreement, offline mode, permissions, small screens, dynamic type, and sprite/render issues.

Floradex ethos to preserve:

Floradex is a joyful Pokedex for the living world. It should make identifying plants feel like discovery, collecting, field notes, and tiny magic. It is not just a plant scanner. It should feel like an iPhone-native field companion that turns a walk, a garden, or a random leaf into a small moment of curiosity.
