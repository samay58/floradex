# Folder Structure

- `FloradexKit/`: Local Swift package, Swift 6 mode, no SwiftUI/UIKit. Domain types, the flow reducer, the identification orchestrator, escalation policy, provider clients, fixture catalog, and its own Swift Testing suite (`swift test` on macOS).
- `plantlife/`: App target source (module name is `plantlife`; the scheme is `floradex`)
  - `Features/`: The hero capture-reveal-collect loop (camera actor, flow model, reveal card, composition root)
  - `Models/`, `DataHandling/`: v1 SwiftData models and repositories (replaced by the v2 schema in phase 5)
  - `Views/`, `UI/`, `Managers/`, `Shared/`: Legacy collection tab and shared UI, standing until phase 5
- `plantlifeTests/`: App unit tests (XCTest, simulator)
- `plantlife.xcodeproj/`: Xcode project (file-system-synchronized groups)
- `docs/rewrite-research/`: Rewrite spec, execution prompt, session handoffs, screenshots
- `scripts/`: Project maintenance scripts (`wire_floradexkit.rb` is the pattern for project mutations)

Notes
- API keys are environment variables read through `CredentialBroker` at request time; nothing key-shaped lives in the repo or the binary.
- No generated or local caches should be committed.
