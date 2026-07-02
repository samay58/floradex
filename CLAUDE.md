# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Floradex is a SwiftUI iOS app (iOS 26 deployment target, Xcode 26) that identifies plants from photos and saves pixel-art "dex" entries with care details. Naming quirk: the Xcode project, app target, and Swift module are all named `plantlife`, but the only scheme is `floradex`. Use `-scheme floradex` in xcodebuild commands and `@testable import plantlife` in tests.

## Commands

```bash
# Build for simulator
xcodebuild -project plantlife.xcodeproj -scheme floradex -sdk iphonesimulator build

# Run all tests (destination must name an installed simulator; check `xcrun simctl list devices`)
xcodebuild -project plantlife.xcodeproj -scheme floradex test -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class or method
xcodebuild -project plantlife.xcodeproj -scheme floradex test \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:plantlifeTests/DexRepositoryTests/testAddEntryAndAutoIncrementId
```

If XcodeBuildMCP tools are available, prefer them over raw xcodebuild.

API keys are development environment variables (`KINDWISE_API_KEY`, `PLANTNET_API_KEY`, `OPENAI_API_KEY`) resolved through `CredentialBroker` at request time; there is no xcconfig path and nothing key-shaped in the repo. `FLORADEX_FIXTURES=1` runs the app with no keys at all.

## Architecture (rewrite in progress, phases 2 through 4 landed)

Read `docs/rewrite-research/floradex-rewrite-spec.md` before any structural change; it defines the architecture, the 8-phase plan, and what is deliberately deferred. `docs/rewrite-research/floradex-modern-ios-research.md` holds the platform decisions with sources. Branch: `rewrite/foundation`.

**The seam**: `FloradexKit/` is a local Swift package (Swift 6 mode, no SwiftUI/UIKit) linked into the app target. Domain logic, policies, the hero-loop reducer, the orchestrator actor, provider API clients, and the fixture catalog live there. Verify with `cd FloradexKit && swift test` (runs on macOS, no simulator). Boundary rule: needs SwiftUI or live hardware → `plantlife/`; otherwise → the Kit.

**Hero loop** (`plantlife/Features/`): `CaptureHomeView` (Identify tab) → `CameraSession` actor (pre-warm, responsive capture) → `CaptureFlowModel` (`@Observable`, executes effects only; all sequencing lives in the Kit's `IdentificationFlowReducer`) → `IdentificationOrchestrator` actor drives the data-driven `EscalationPolicy` over providers (Kindwise, Pl@ntNet, OpenAI vision reasoner) → staged `RevealCard` with undo window → commit assigns the dex number (monotonic, never reused; deletes leave gaps). `FLORADEX_FIXTURES=1` + `FLORADEX_AUTORUN=1` run the whole loop on a simulator with canned providers and no keys.

**Credentials**: all provider calls resolve keys through `CredentialBroker` at request time (env vars `KINDWISE_API_KEY`, `PLANTNET_API_KEY`, `OPENAI_API_KEY` in development; a Cloudflare Workers + App Attest proxy broker replaces it before release). Missing keys throw typed `.credentialMissing` errors; there are no silent no-ops and no keys in the binary.

**Legacy surfaces still standing** (die in phase 5 remainder): `FloradexCollectionView`/`DexGrid`/`DexCard`, entry-only `PlantDetailsView`, `LiquidTabBar` root, v1 `@Model` classes (`DexEntry`, `SpeciesDetails`, joined by `latinName` string), `@MainActor` repositories in `DataHandling/`. The v2 schema (real relationship, persisted number ledger, media on disk) is specced but not yet built.

**Tests**: Kit logic in Swift Testing (96 tests, `swift test`); app unit tests in XCTest on simulator (`-only-testing:plantlifeTests`, use `-parallel-testing-enabled NO`). The 16-case fixture corpus in `FloradexKitFixtures` replays through the real escalation engine and orchestrator.

## Rewrite status and rules

- Done: phase 2 (dead code wave 1, test repair, iOS 26 crash fixes), phase 3 (project wiring, deployment target 26.0, strict-concurrency warnings), phase 4 (Kit orchestrator + provider clients + hero loop UI, old pipeline deleted in wave 2).
- Next: phase 5 remainder (SwiftData v2 schema + migration test, new dex grid/detail surfaces, native TabView root), phase 6 (trust states, `SWIFT_VERSION` 6 flip), phase 7 (fixture assets, Maestro/XCUITest), phase 8 (polish, proxy scaffold in `proxy/`).
- Never hand-edit `project.pbxproj`; use `scripts/wire_floradexkit.rb` as the pattern (xcodeproj gem, checkpoint commit, line-by-line diff review, green build) for any further project mutations.
- Warning budget: 78 at last build (`docs/rewrite-research/warning-baseline.md` started at 140); the count must only shrink, and new code merges with zero warnings.
- Path note: `/Users/samaydhawan/floradex` is a symlink to this checkout, not a separate worktree.
