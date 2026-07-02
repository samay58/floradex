# Floradex

An iOS app that turns plant identification into a friendly, retro experience. Point the camera at a plant, watch the reveal, and collect a pixel-art dex entry with care notes. Entries get permanent numbers; deleting one leaves an honest gap.

## Quick start

```bash
git clone https://github.com/samay58/floradex.git
open plantlife.xcodeproj
```

In Xcode: select the `floradex` scheme, pick an iOS 26 simulator, Run. With no API keys the app runs in fixture mode when launched with `FLORADEX_FIXTURES=1`: canned providers drive the whole capture-reveal-collect loop, no network needed.

For live identification, set these environment variables in the scheme (Run > Arguments):

- `KINDWISE_API_KEY`: Kindwise plant.id, the primary identifier
- `PLANTNET_API_KEY`: Pl@ntNet, the second opinion
- `OPENAI_API_KEY`: vision arbitration, care text, and sprite generation

Keys resolve at request time through `CredentialBroker`; a missing key surfaces as a typed error, never a silent no-op. Nothing is compiled into the binary, and a proxy broker (Cloudflare Workers + App Attest) replaces the env-var path before release.

## How identification works

The Swift package `FloradexKit/` owns the logic: a data-driven escalation policy walks Kindwise, then Pl@ntNet, then an OpenAI vision reasoner, stopping as soon as combined confidence clears the bar without provider disagreement. An agreement scorer merges candidates by normalized Latin name. The app layer (`plantlife/Features/`) is a thin shell: camera actor, an `@Observable` flow model that executes effects, and the reveal card with its undo window. Sequencing rules live in the Kit's reducer, so they are tested on macOS without a simulator.

## Build and test

```bash
# Kit logic tests (Swift Testing, runs on macOS, no simulator)
cd FloradexKit && swift test

# App build
xcodebuild -project plantlife.xcodeproj -scheme floradex -sdk iphonesimulator build

# App unit tests (destination must name an installed simulator)
xcodebuild -project plantlife.xcodeproj -scheme floradex test \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:plantlifeTests -parallel-testing-enabled NO
```

Naming quirk: the Xcode project and module are `plantlife`; the scheme is `floradex`.

## Demo loop on a simulator

Launch with `FLORADEX_FIXTURES=1` and `FLORADEX_AUTORUN=1` (as `SIMCTL_CHILD_` variables when using `simctl launch`) and the app captures a generated leaf photo, runs the full identification loop against canned providers, and commits a dex entry unattended.

## Notes

- Requires Xcode 26 and iOS 26.
- The rewrite through phase 6 (architecture, hero loop, v2 schema, Swift 6, app icon) is merged to `main`; phases 7 and 8 (fixtures/UI tests, polish and proxy) continue on `rewrite/foundation`. `docs/rewrite-research/` holds the spec and status.
- No telemetry. Perceived-quality metrics are local os_signpost events.
