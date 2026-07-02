# Where we left off

Updated 2026-07-02, end of the de-sloppify plus phase 5 session. Branch `rewrite/foundation`.

## State in one paragraph

Phases 0 through 5 are done: the de-sloppify pass below, then the full phase 5 remainder in the same session. The v2 SwiftData schema is live (real DexEntry-to-SpeciesRecord relationship, persisted DexLedger, media on disk keyed by mediaID), with an in-place migration from v1 that froze numbers, tombstoned gaps, and exported image blobs to disk; the migration ran for real against the simulator's existing store and its seeded test is green. The hero loop commits through `SwiftDataDexStore` (the Kit's `DexStore` seam); the new `DexGridView` and `EntryDetailView` replace the legacy collection subtree; the root is a native `TabView`. Nothing legacy remains: no repositories, no LiquidTabBar, no AnimationConstants, no v1 model files outside the versioned schema. FloradexKit has 100 green Swift Testing tests; the app suite is the seeded migration test plus six store tests, all green on simulator. Warnings are down to 20 (from 140 at baseline, 102 at the session start). The full loop was re-verified on the iOS 26.5 simulator with screenshots at each stage.

## Phase 5 specifics worth knowing

- `FloradexSchema.swift` holds both versioned schemas; new mandatory v2 attributes carry stored property defaults because SwiftData materializes columns before `didMigrate` can patch rows (this bit once).
- `FloradexMigrationPlan.mediaRoot` is settable so the migration test can point at a temp directory.
- `FLORADEX_TAB=dex` (DEBUG) preselects the collection tab; built for screenshots and future Maestro flows.
- Deferred deliberately: correction-flow species search on the entry screen, "report a problem" inlet (phase 7 pairs it with fixtures), HEIC originals (JPEG for now), CloudKit (out of scope for launch).

## What the de-sloppify pass changed

**Kit and hero-loop hardening (adversarial review findings, all fixed and tested):**
- All-infrastructure provider failures now surface as `providersUnavailable` instead of masquerading as "no plant found"; the distinction lives in the orchestrator's terminal event, pinned by two new orchestrator tests and a sixteenth fixture case (`providers-down`).
- `identificationSettled` was double-recorded (orchestrator and reducer); the reducer now emits only UI-perceived metrics.
- A slow sprite could paint onto a later capture's reveal card; the UI write now checks the state still shows that entry. Persistence still lands either way.
- The shutter path encoded a full-size JPEG on the main actor; encoding now lives in a small `PayloadEncoder` actor (the spec's no-`Task.detached` doctrine holds), and the `currentPayload` state variable is gone (retry re-encodes from the frozen frame).
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

**Known cosmetic items deferred to phase 8:** the identifying-to-provisional crossfade briefly shows the outgoing layout mid-transition (about 0.45s); the app icon set is missing its 1024pt and iPad slots (six of the remaining warnings).

## Next, in order

**Phase 6** (per the spec): trust states in the UI (banded confidence surfaced honestly, disagreement line, correction flow completion) and the `SWIFT_VERSION` 6 flip; verify the SwiftData keypath-Sendability warning class actually clears under Swift 6 mode. Then phase 7 (fixture assets, Maestro/XCUITest) and phase 8 (polish including app icon and reveal-transition tightening, proxy scaffold). The committed execution prompt (`floradex-rewrite-execution-prompt.md`) still describes these accurately.

## Deferred decisions parked with Samay

1. Provider licensing: Kindwise credits vs a Pl@ntNet Pro license, driven by App Store intent.
2. Cloudflare account for the proxy deploy (phase 8).
3. Physical-device verification of capture latency and haptics; simulators cannot judge either.

## Verify before building

```bash
cd FloradexKit && swift test                        # expect 100 green
xcodebuild -project plantlife.xcodeproj -scheme floradex \
  -destination 'platform=iOS Simulator,name=Floradex-Sim' build-for-testing
xcodebuild ... test-without-building -only-testing:plantlifeTests \
  -parallel-testing-enabled NO                      # expect 7 green (migration + store)
# Full-loop demo: install the built app on Floradex-Sim, then launch with
# SIMCTL_CHILD_FLORADEX_FIXTURES=1 SIMCTL_CHILD_FLORADEX_AUTORUN=1
```
