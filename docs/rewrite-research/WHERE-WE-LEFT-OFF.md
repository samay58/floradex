# Where we left off

Updated 2026-07-02, end of the de-sloppify plus phase 5 and 6 session. Branch `rewrite/foundation`.

## State in one paragraph

Phases 0 through 6 are done (phase 6 minus the offline queue, which moved to phase 8 with a note in the spec): the de-sloppify pass below, then the full phase 5 remainder in the same session. The v2 SwiftData schema is live (real DexEntry-to-SpeciesRecord relationship, persisted DexLedger, media on disk keyed by mediaID), with an in-place migration from v1 that froze numbers, tombstoned gaps, and exported image blobs to disk; the migration ran for real against the simulator's existing store and its seeded test is green. The hero loop commits through `SwiftDataDexStore` (the Kit's `DexStore` seam); the new `DexGridView` and `EntryDetailView` replace the legacy collection subtree; the root is a native `TabView`. Nothing legacy remains: no repositories, no LiquidTabBar, no AnimationConstants, no v1 model files outside the versioned schema. FloradexKit has 101 green Swift Testing tests; the app suite is the seeded migration test plus six store tests, all green on simulator under Swift 6. Warnings are down to 15 (from 140 at baseline, 102 at the session start), every one of them the missing app-icon assets. The full loop was re-verified on the iOS 26.5 simulator with screenshots at each stage, before and after the Swift 6 flip.

## Phase 6 specifics worth knowing

- Trust states on the reveal card: raw confidence behind a tap on the badge, a "2 of 3 sources agree" line for multi-provider results, correction cancel and free-text override, honest offline and credential-missing copy.
- `scripts/flip_swift6.rb` flipped SWIFT_VERSION to 6.0 everywhere and set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the app target only; XCTestCase's nonisolated lifecycle rejects the default, so the test target isolates classes explicitly and uses `setUp() async throws`.
- Deliberately off-main types are marked `nonisolated`: `CameraPreviewSource`, `PhotoCaptureDelegate`, `UIImage.resized`, `MediaLocations`.
- The keypath-Sendability warning class vanished under Swift 6, as the baseline doc predicted. Warnings: 15, all missing app-icon assets plus one toolchain line; zero Swift source warnings.

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

**Known cosmetic items deferred to phase 8:** the identifying-to-provisional crossfade briefly shows the outgoing layout mid-transition (about 0.45s).

## Update, 2026-07-02 afternoon: app icon landed early

The app icon (a phase 8 item) is done: ChatGPT Images artwork iterated over three rounds (a leaf dissolving from smooth vector into chunky pixel art, the capture-to-dex story in one mark), then palette-quantized to the brand hexes and written into all three universal 1024 slots (light, dark on near-black green, tinted grayscale). Small-size legibility was checked at 60px and against the corner mask. Project warnings went from 15 to zero; the only build-log line left is appintentsmetadataprocessor toolchain noise. The generation and finalize scripts are session scratch, not in the repo; the three PNGs in `AppIcon.appiconset` are the artifact. Note: a parallel session's sprite-fix commit (0776e6c) picked these PNGs up mid-write; content verified intact.

Environment findings from the same afternoon, verify before trusting simulators:

- The iOS simulator runtime disk image is gone (`simctl runtime list` shows zero images; likely purged under disk pressure, the disk is at about 16GB free). Device folders still exist but nothing can boot. Reinstall with `xcodebuild -downloadPlatform iOS` (about 8GB) before any simulator test or demo run. Kit tests (`swift test`) are unaffected and were green (101) after this state.
- `xcode-select` points at CommandLineTools; prefix builds with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
- A corrupted DerivedData build database produced disk I/O errors mid-build once; deleting the project's DerivedData folder fixed it.

## Next, in order

**Phase 7** (per the spec): fixture corpus materialization (deterministic photo assets and recorded payloads behind the catalog), an XCUITest smoke of the hero path, and Maestro flows if it installs cleanly. Then phase 8: polish (reveal-transition tightening, frame pacing on device; the app icon is already done, see the update below), the offline capture queue (moved from phase 6), and the Cloudflare Workers + App Attest proxy scaffold. The committed execution prompt (`floradex-rewrite-execution-prompt.md`) still describes these accurately.

## Deferred decisions parked with Samay

1. Provider licensing: Kindwise credits vs a Pl@ntNet Pro license, driven by App Store intent.
2. Cloudflare account for the proxy deploy (phase 8).
3. Physical-device verification of capture latency and haptics; simulators cannot judge either.

## Verify before building

```bash
cd FloradexKit && swift test                        # expect 101 green
xcodebuild -project plantlife.xcodeproj -scheme floradex \
  -destination 'platform=iOS Simulator,name=Floradex-Sim' build-for-testing
xcodebuild ... test-without-building -only-testing:plantlifeTests \
  -parallel-testing-enabled NO                      # expect 7 green (migration + store)
# Full-loop demo: install the built app on Floradex-Sim, then launch with
# SIMCTL_CHILD_FLORADEX_FIXTURES=1 SIMCTL_CHILD_FLORADEX_AUTORUN=1
```
