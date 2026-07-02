# Where we left off

Updated 2026-07-02, end of the de-sloppify session. Branch `rewrite/foundation`.

## State in one paragraph

Phases 0 through 4 are done, plus phase 5's deletion wave, plus the de-sloppify pass below. The hero loop runs end to end on the iOS 26.5 simulator via `FLORADEX_FIXTURES=1` + `FLORADEX_AUTORUN=1` (re-verified this session with fresh screenshots in `docs/rewrite-research/screenshots/` and the session scratchpad). FloradexKit has 96 green Swift Testing tests; the 8 app unit tests pass on simulator. Full phase statuses with commit hashes are in the spec's Implementation phases section; the architecture summary is in CLAUDE.md.

## What the de-sloppify pass changed

**Kit and hero-loop hardening (adversarial review findings, all fixed and tested):**
- All-infrastructure provider failures now surface as `providersUnavailable` instead of masquerading as "no plant found"; the distinction lives in the orchestrator's terminal event, pinned by two new orchestrator tests and a sixteenth fixture case (`providers-down`).
- `identificationSettled` was double-recorded (orchestrator and reducer); the reducer now emits only UI-perceived metrics.
- A slow sprite could paint onto a later capture's reveal card; the UI write now checks the state still shows that entry. Persistence still lands either way.
- The shutter path encoded a full-size JPEG on the main actor; encoding moved into the detached identification task, and the `currentPayload` state variable is gone (retry re-encodes from the frozen frame).
- `DexRepository.addEntry` swallowed save errors and returned an unsaved entry, so a failed commit could show a dex number that was never persisted; it now throws and the flow reports `commitFailed`.
- The camera session stops on scene background and re-warms on active.
- `Species.displayName` moved into the Kit (the sprite prompt had a duplicate); `CareTextProvider` and `onDeviceCareText` (dead declarations) are gone; the scorer's force-unwraps are gone.

**Legacy surface reduction:**
- 13 dead files deleted outright (TagFilterView, SkeletonView, ModernPageIndicator, Buttons, FactsFormatter, PhotoCardView, Font+Floradex, InfoCardView, PlantInfoRowView, SFSymbolHelper, TagChip, InfoRow, PreviewHelper), plus dead scaffolding (`examples/`, `Secrets.xcconfig.example`).
- Dead types stripped from surviving files: `CollectionPlantCard`, `CachedImageView`, `CameraEmptyStateView`/`CameraFrameCorner`, the `OverviewContent`/`CareContent`/`GrowthContent` cluster (only `FlowLayout` survives in DetailContentViews), SpeciesDetails' unused Codable conformance and dead parsed members, Extensions.swift down to one used helper.
- All 36 `print` statements are gone (deleted with their files, replaced with `os.Logger` in the repositories, or simply removed). Both TODO markers resolved by deleting the do-nothing Favorite/Share buttons. The thinking-out-loud comment blocks in DexRepository, SpeciesRepository, SpeciesDetails, and DexEntry are gone; both repositories were rewritten clean.
- Reveal card: the committed-state line no longer truncates (wraps beside the number band). Radii decision: the 24pt card stays, deliberately; the 6-8px doctrine targets web surfaces, and 24pt continuous is platform-idiomatic for iOS 26 material cards. Accent stays in one band per surface.
- README rewritten against current reality (env-var credentials, fixture mode, Kit architecture, correct scheme); FOLDER_STRUCTURE.md rewritten; CLAUDE.md commands and credentials section corrected. All edited docs pass slopcheck.
- Warnings: unique-deduped count 60 before the pass, 42 after (the raw baseline-methodology number is in `warning-baseline.md`). Remaining carriers: AnimationConstants (15, dies with LiquidTabBar in phase 5), asset catalog (6), and the SwiftData keypath-Sendability class on the v1 models (dies with the v2 schema).

**Known cosmetic item deferred to phase 8:** the identifying-to-provisional crossfade briefly shows the outgoing layout mid-transition (about 0.45s); tighten alongside device-verified animation work.

## Next, in order

**Phase 5 remainder** (per the spec): SwiftData v2 schema (real DexEntry-to-species relationship, persisted `DexNumberLedger`, media as files via `FileMediaStore`) with a seeded migration test, the new dex grid and entry detail surfaces, and the native TabView root replacing `LiquidTabBar`. Then phases 6 (trust states, `SWIFT_VERSION` 6 flip), 7 (fixture assets, Maestro/XCUITest), 8 (polish, proxy scaffold). The committed execution prompt (`floradex-rewrite-execution-prompt.md`) still describes these accurately.

## Deferred decisions parked with Samay

1. Provider licensing: Kindwise credits vs a Pl@ntNet Pro license, driven by App Store intent.
2. Cloudflare account for the proxy deploy (phase 8).
3. Physical-device verification of capture latency and haptics; simulators cannot judge either.

## Verify before building

```bash
cd FloradexKit && swift test                        # expect 96 green
xcodebuild -project plantlife.xcodeproj -scheme floradex \
  -destination 'platform=iOS Simulator,name=Floradex-Sim' build-for-testing
xcodebuild ... test-without-building -only-testing:plantlifeTests \
  -parallel-testing-enabled NO                      # expect 8 green
# Full-loop demo: install the built app on Floradex-Sim, then launch with
# SIMCTL_CHILD_FLORADEX_FIXTURES=1 SIMCTL_CHILD_FLORADEX_AUTORUN=1
```
