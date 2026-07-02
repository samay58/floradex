# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Floradex is a SwiftUI iOS app (iOS 17+, Xcode 15+) that identifies plants from photos and saves pixel-art "dex" entries with care details. Naming quirk: the Xcode project, app target, and Swift module are all named `plantlife`, but the only scheme is `floradex`. Use `-scheme floradex` in xcodebuild commands (the README's `-scheme plantlife` example is stale) and `@testable import plantlife` in tests.

## Commands

```bash
# One-time setup: API keys (app runs without them in local-only mode)
cp Secrets.xcconfig.example Secrets.xcconfig   # fill OPENAI_API_KEY, PLANTNET_API_KEY; optional TREFLE/PERENUAL

# Build for simulator
xcodebuild -project plantlife.xcodeproj -scheme floradex -sdk iphonesimulator build

# Run all tests (destination must name an installed simulator — check `xcrun simctl list devices`)
xcodebuild -project plantlife.xcodeproj -scheme floradex test -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class or method
xcodebuild -project plantlife.xcodeproj -scheme floradex test \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:plantlifeTests/DexRepositoryTests/testAddEntryAndAutoIncrementId

# Check which API providers are enabled from env vars
swift examples/provider_quick_check.swift
```

If XcodeBuildMCP tools are available, prefer them over raw xcodebuild.

Secrets resolution (`plantlife/Shared/Secrets.swift`): environment variables first, then build-time values from `Secrets.xcconfig`. Never commit `Secrets.xcconfig` or real keys.

## Architecture

**App composition** (`plantlife/PlantLifeApp.swift`): builds a SwiftData `ModelContainer` with the two `@Model` classes (`SpeciesDetails`, `DexEntry`), wraps its main context in two `@MainActor` repositories (`SpeciesRepository`, `DexRepository` in `DataHandling/`), and injects them into three tabs — Identify, Floradex (collection grid), Profile — via a custom `LiquidTabView`. Switching away from Identify cancels the in-flight pipeline via `ClassificationViewModel.cleanup()`.

**Identification pipeline** (`ViewModels/ClassificationViewModel.runPipeline`) — the core flow, an escalating cascade tuned to avoid paid API calls when possible:

1. On-device Core ML via `ClassifierService` (Vision + optionally bundled `PlantClassifier.mlmodelc`; returns confidence 0 if the model isn't bundled).
2. If local confidence < 0.75 → PlantNet API.
3. If still < 0.6 → GPT-4o vision.
4. Multiple results → `EnsembleService.vote()` (majority vote, ties broken by average confidence).

The winner then drives: species details fetch (SwiftData cache in `SpeciesRepository` keyed by `latinName`, miss → `GPT4oService.fetchPlantDetails`) → tag generation (`TagGenerator`) → `DexRepository.addEntry` (ids auto-increment as Floradex numbers) → detached background task generating a pixel-art sprite via `SpriteService` (OpenAI `gpt-image-1`), which updates the entry's `sprite` or sets `spriteGenerationFailed`. Image-hash dedup prevents reprocessing the same photo.

**Models**: `DexEntry` and `SpeciesDetails` are linked only by the `latinName` string — there is no SwiftData relationship between them.

**Networking** (`plantlife/Networking/`): each provider (PlantNet, GPT-4o, Sprite, Trefle, Perenual, USDA, Wikipedia) defines an enum conforming to the `APIEndpoint` protocol (`APIClient.swift`) and calls through the shared `APIClient`. Endpoints can override `timeout` (sprite generation uses 300s). Add new providers by following this pattern.

**Concurrency conventions**: repositories and `ClassificationViewModel` are `@MainActor`; all SwiftData operations must stay on the main actor. Services are `Sendable` singletons (`.shared`). Sprite generation is the one detached background task, and it hops back to `MainActor` for repository writes.

**Tests** (`plantlifeTests/`): XCTest with in-memory `ModelConfiguration(isStoredInMemoryOnly: true)` containers — see `DexRepositoryTests.swift` for the pattern. UI is exercised through state/model logic, not view hierarchy.

## Rewrite (in progress)

A first-principles rewrite is underway on branch `rewrite/foundation`. Read `docs/rewrite-research/floradex-rewrite-spec.md` before any structural change — it defines the architecture (FloradexKit package + thin app layer), the 8-phase plan, and what is deliberately deferred. `docs/rewrite-research/floradex-modern-ios-research.md` holds the platform decisions with sources.

- `FloradexKit/` is a standalone local Swift package (domain logic, Swift 6 mode, no SwiftUI/UIKit). Verify with `cd FloradexKit && swift test` — runs on macOS, no simulator needed. It is not yet wired into the app target (that is a scheduled Xcode session, spec phase 3).
- Boundary rule: needs SwiftUI or live hardware → `plantlife/`; otherwise → the Kit.
- Known baseline: the app target does not compile at `bad4257` (one error in `AnimatedConfidenceMeter.swift:7`, `ClassifierService.Source` should be `ClassifierResult.Source`); the test target has additional stale-API errors. Both are scheduled for spec phase 2, not ad-hoc fixes.
- Path note: `/Users/samaydhawan/floradex` is a symlink to this checkout, not a separate worktree.
