# Where we left off

Updated 2026-07-02 (evening), end of the design identity session. Branch `rewrite/foundation`.

## Update, 2026-07-02 evening: the design identity session

The phase 8 visual identity landed, run as explore, decide, systemize, build, audit (`floradex-design-exploration-prompt.md` was the brief).

**The decision.** Three directions were built as real cards behind a DEBUG picker, screenshot on simulator, and presented for a pick: herbarium (specimen label), cartridge (game artifact), instrument (machined glass). Samay chose herbarium as the base with cartridge and instrument borrowed only where they earn it. The register rule that keeps it coherent, written into `plantlife/UI/FloradexTheme.swift`: words are serif on paper; the collection's own artifacts (sprites, dex numbers) are pixel; motion is machined. The registers never trade places.

**What landed, one commit per wave, all verified (build green, 101 kit tests, 7 app tests, fixture-loop screenshots in `screenshots/`).**

- Tokens: `FloradexTheme` (semantic warm-paper colors with dark variants, band palette deepened for contrast, radius language 16/12/3, signature spring plus stamp settle, pixel face scoped to dex numbers via `FloraNumberRole`), `FloraPressStyle`, `DitherField`, `PixelScaledImage`. `Theme.swift` and its dead aliases are gone.
- Departure Mono Regular (OFL 1.1, license bundled beside the font) registered via UIAppFonts; it renders dex numbers and nothing else. This settles spec open question 5: single-purpose revival, for numbers rather than headers; headers went to New York serif instead.
- Reveal card: opaque paper specimen label, serif name over latin italic, mounted photo, sprite in a dithered plate, confidence as a stamped seal (raw number still on tap), redacted breathing rows instead of a spinner, dex number stamped in pixel ink with a settle spring and a rigid single-hit haptic (`HeroHaptics.stamp()` replaced the success notification at commit). Reduce Motion collapses everything to crossfades.
- Capture home: camera-missing states are designed scenes on warm ground; shutter compresses on press.
- Dex grid: paper tiles, pixel numbers, dithered sprite plates, retired numbers shown in number order as dash-bordered gap tiles, designed first-run empty state. `FLORADEX_ENTRY=1` (DEBUG) opens the first entry for screenshots and Maestro.
- Entry detail: one continuous herbarium sheet (hairline-ruled sections with typed field labels; the stacked boxes are gone), pixel number in the nav bar, destructive delete pinned red so it stops inheriting the brand tint.
- The app icon needed no rework: the vector-dissolving-into-pixels leaf is the chosen hybrid exactly.

**Audit state (screenshots in `screenshots/`, `wave*-` and `audit-` prefixes).** Light: identifying, provisional, committed, camera-missing, credential-missing failure, empty dex, populated dex, entry detail. Dark: provisional, dex grid, entry detail. Dynamic Type XXL: dex grid (pixel numbers scale via their anchor styles). Warning budget still zero; the only build-log line remains the appintentsmetadataprocessor noise.

**Not screenshot this session, verified in code only:** the correcting state and the gap tile need a tap, and every headless route was closed (no computer-use MCP connected; XcodeBuildMCP UI automation and idb refuse the CommandLineTools xcode-select). The phase 7 XCUITest smoke should capture both. The offline failure state is unreachable headlessly until phase 7 wires the fixture catalog's case 8 into the app composition (fixture mode today composes only the happy path). The identifying-to-provisional crossfade item: header geometry is now identical across those states, which removes the layout jump; confirm the remaining text crossfade feels right on device.

**Parked for Samay:** whether the sources-agree line should also appear on the committed card, and physical-device verification of the stamp haptic (rigid, single hit) alongside the existing capture-latency item.

**Late addition, same evening:** the shutter was rebuilt as dimensional hardware after Samay flagged it (Not Boring Camera as the register): ceramic housing, convex green glass key with gloss and inner bevel, camera.macro mark, press depression, sibling ceramic keys for picker and sample leaf, and a scrim seating the deck on the live viewfinder. Simulators only ever show the desaturated disabled key (camera never reaches ready), so the green enabled state and the press feel join the device checklist.

## State in one paragraph (as of the afternoon session)

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
