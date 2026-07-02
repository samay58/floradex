# Floradex rewrite spec

## Read this first

Floradex is a joyful Pokedex for the living world, and the rewrite exists to make one loop physically excellent: point the camera at a plant, feel the shutter, watch a beautiful identification reveal, and collect a dex entry you'll want to revisit. The current codebase has the right ethos and the wrong body: a non-functional identification cascade on a fresh clone, no reveal moment at all, dex numbers that get renumbered on delete, client-side API keys, a test target that doesn't compile, and a large graveyard of dead subsystems. The rewrite is native SwiftUI on iOS 26, built in place in this repo behind a compiler-enforced seam: a local Swift package (`FloradexKit`) holds every piece of testable policy and domain logic, while a thin, tactile app layer owns capture, reveal, and collection. Old code dies progressively at verified checkpoints, never in one unverifiable pass. Trust is a feature: identification is probabilistic, and the app says so cleanly, supports correction, and turns every real-world failure into a permanent regression fixture.

## Current-state read of the repo

Verified against the worktree at commit `bad4257` (branch `main`).

**What exists.** A SwiftUI + SwiftData app: Xcode project, target, and module are all named `plantlife` (bundle id is already `samayd.floradex`; the only scheme is `floradex`). The pbxproj is objectVersion 77 with folder-sync groups, so files added under `plantlife/` join the target with no project edits. Deployment target is iOS 18.4 with `SWIFT_VERSION = 5.0`. Two `@Model` classes (`DexEntry`, `SpeciesDetails`) are joined by a `latinName` string rather than a relationship. View models are `ObservableObject` throughout, with one stray `@Observable` (`AppSettings`). Navigation is a hand-rolled tab bar over an `Int` switch, with deprecated `NavigationView` in live screens. There are 172 `print` statements and no structured logging.

**The pipeline is fiction on a fresh clone.** The escalation cascade (local Core ML, then PlantNet under 0.75 confidence, then GPT-4o-mini under 0.6, then a majority vote) never starts locally because no `.mlmodel` exists in the repo; `ClassifierService` silently returns 0.0 confidence. No xcconfig is committed, so every API key resolves to an empty string and every remote call fails. Nothing surfaces these failures to the user.

**The hero loop has no hero.** Identification runs inside a details sheet that swaps a progress view for content when data arrives. The `DexEntry` is written to the store mid-pipeline, before the user has seen or confirmed anything. On delete, `DexRepository.renumberEntries()` reassigns every dex number, which inverts the Pokedex promise that numbers are permanent.

**Dead surface.** A full Live Activity subsystem with no widget target and no `Activity.request` call anywhere. Four networking services (Wikipedia, USDA, Trefle, Perenual) with zero call sites. Orphaned screens (`FloradexHomeScreen`, `DexCardPager` and its card views), an unused Lottie dependency, bundled pixel fonts registered in Info.plist and referenced nowhere, and an `Analytics` shim nobody calls.

**Tests don't compile.** The test target references removed symbols (`GlassBar`, `PixelButton`, `Font.pressStart2P`), a `SnapshotTesting` package that is not a dependency, drifted APIs (`addEntry(notes:)`, `PersistenceController`), and a `DexEntry(dateAdded:)` field that no longer exists. Only `DexEntryTests` and part of `DexRepositoryTests` reflect the current code.

**Build baseline (recorded 2026-07-01, before any changes).** Two layers of failure, documented in order.

First, the environment: this machine's Xcode 26.6 had no iOS platform component installed, so every destination failed with "iOS 26.5 is not installed. Please download and install the platform from Xcode > Settings > Components." The iOS 26.5 simulator platform (8.52 GB) was downloaded and installed as part of this run.

Second, with the platform installed, the app target itself does not compile at HEAD (`bad4257`):

```
plantlife/UI/Components/AnimatedConfidenceMeter.swift:7:35:
error: 'Source' is not a member type of class 'plantlife.ClassifierService'
```

Line 7 declares `let source: ClassifierService.Source`; the enum actually lives at `ClassifierResult.Source` (ImageProcessing/ClassifierService.swift). This is the only app-target compile error. The fix is one token, scheduled for phase 2 rather than this run, which deliberately leaves `plantlife/` untouched. The test target's additional source-level errors are listed above.

One path note: `/Users/samaydhawan/floradex` is a symlink to `/Users/samaydhawan/Projects/parked/floradex`; both names refer to the same checkout.

## What Floradex should become

An iPhone-native field companion that turns a walk, a garden, or a random leaf into a small moment of curiosity. Concretely:

- **One overbuilt loop.** Capture, reveal, collect. Everything else in the app is allowed to be merely good.
- **Honest intelligence.** Identification shows confidence, alternatives, and disagreement. "We're not sure" is a designed state, not an error.
- **A collection worth keeping.** Dex numbers are permanent. Entries accrete field notes, corrections, and better photos over time.
- **Works in a pocket.** One-handed, outdoors, on spotty network, with the camera pre-warmed before you need it.
- **Private by default.** Photos stay on device except for the identification request itself; no keys ship in the binary; location attached to an entry only with explicit consent.

## What to preserve from the old app

- **The ethos and the name.** Pokedex framing, dex numbers, pixel-art sprites, the collect instinct.
- **The escalation idea.** Cheap and local before expensive and remote, with an ensemble when providers disagree. The shape survives even though every implementation detail changes.
- **Sprite generation as identity.** The retro sprite is the product's signature artifact. It moves to gpt-image-2 and off the critical path, but it stays.
- **SwiftData plus `@MainActor` repositories** as the persistence direction, corrected (real relationship, files on disk for media, versioned schema).
- **A few genuinely good components as reference**: the two-tier `ImageCacheManager`, the detail view's parallax hero treatment, `DexGrid`'s selection mode, the multipart upload logic in `PlantNetService`. Reference, not carry-over; new code is written fresh under new conventions.
- **The bundle id** `samayd.floradex` and the existing App Store identity groundwork.

## What to replace

- The entire identification pipeline (`ClassificationViewModel`, `ClassifierService`, `EnsembleService`, `GPT4oService`, `PlantNetService`, `APIClient`) with `FloradexKit` policies, provider protocols, and an orchestrator actor.
- `ObservableObject` and `@Published` everywhere; replaced by `@Observable` under Swift 6.2 default MainActor isolation.
- Save-before-reveal; replaced by a provisional in-memory entry with an undo window, committed only after the window lapses.
- Renumber-on-delete; replaced by monotonic, never-reused numbers with tombstones.
- Client-side API keys; replaced by a `CredentialBroker` seam, with a Cloudflare Workers + App Attest proxy before public release.
- The hand-rolled tab bar and `NavigationView`; replaced by native `TabView` and `NavigationStack` under Liquid Glass.
- `print` logging; replaced by `os.Logger` with signposts for perceived-quality metrics.
- All dead subsystems (Live Activity, the four orphaned services, orphaned screens, Lottie, unused fonts, `Analytics`). Deleted, not migrated.
- The stale test suite; replaced by Swift Testing in the package plus Maestro flows for the hero path.

## Brand and interaction principles

1. **Discovery, not scanning.** The app never says "processing." It says what it's doing in field-guide language: looking, comparing, deciding.
2. **Physical first.** The shutter feels mechanical: freeze-frame within 100 ms, one prepared haptic, no dead frames. Per-frame gesture state lives in `@GestureState` and animatable values, never in an observable model.
3. **Reveal as ceremony, latency as choreography.** The wait for identification is the reveal animation. Name arrives first, then confidence, then details; the sprite lands last with its own small flourish. No blank spinners anywhere.
4. **Commit physics.** Swipes and dismissals use velocity-projected thresholds (`predictedEndTranslation`), forgiving of jitter, with the next card pre-mounted. Transforms only during drag; layout changes happen after.
5. **Haptics at semantic boundaries only.** Shutter, reveal stage, save, undo. Generators prepared before likely use, debounced at thresholds.
6. **Escape hatches everywhere magic exists.** Manual correction, re-identify, plain list view, undo. The user can always inspect, always recover.
7. **OS edge cases are product scope.** Permission denial, interruption mid-capture, offline, low storage, dynamic type, small screens, one-handed reach. Each is a designed state with a fixture.
8. **Numbers are sacred.** A dex number, once assigned, is never reused and never changes.

## Hero loop

The loop users repeat a hundred times, specified end to end:

1. **Open.** Camera tab is home. The capture session pre-warms on app foreground (iOS 26 Deferred Start), so glass-to-glass latency is near zero by the time the viewfinder is visible. Zero Shutter Lag, responsive capture, and fast-capture prioritization enabled.
2. **Capture.** Shutter tap freezes the frame in under 100 ms with a single prepared haptic. Photo picker and paste are first-class alternate inlets, one thumb-reach away.
3. **Provisional entry, instantly.** An in-memory provisional entry exists the moment the frame freezes. The reveal card appears with the frozen photo and a shimmering silhouette where the identity will land. No dex number is assigned yet.
4. **Staged reveal.** As the pipeline reports, the card fills in stages: common and Latin name first, then a confidence band with alternatives folded behind a disclosure, then care summary lines. Each stage has its own entrance. Time-to-first-reveal budget: p50 under 2.5 s on network, instrumented with signposts.
5. **Sprite, off the critical path.** A pixel silhouette placeholder holds the slot; the gpt-image-2 sprite replaces it whenever it arrives, even minutes later. Sprite latency never delays the reveal.
6. **Collect with undo.** The entry auto-saves with a success haptic and a visible undo affordance. The dex number and durable commit happen only when the undo window lapses, so undoing never burns a number. Duplicate detection ("you've collected this species") surfaces before commit, offering "add photo to existing entry" as the default.
7. **Correct or enrich later.** From the entry: pick an alternative candidate, search to override the species, re-identify with a better photo, add field notes. Corrections are recorded as signals, not shame.

Failure states are part of the loop, not exceptions to it: no plant found offers retake guidance; provider timeout falls back to whatever candidates exist; offline queues the identification and says so; missing credentials surface a first-run diagnostic instead of the current silent nothing.

## App architecture

**The seam.** A local Swift package at `FloradexKit/` holds everything testable without a simulator; the app layer under `plantlife/` (folder-synced, so no pbxproj edits for new files) holds everything that needs SwiftUI or live hardware. The boundary rule is mechanical: if a file needs `import SwiftUI` or a live `AVCaptureSession`, it belongs to the app; otherwise it belongs to the Kit. The package builds in Swift 6 language mode from day one and declares no UIKit/SwiftUI dependency, so the compiler enforces the boundary.

**Kit layout** (products `FloradexKit` and `FloradexKitFixtures`):

- `Domain/`: `Species`, `IdentificationCandidate`, `IdentificationResult`, `DexNumber`, `SpeciesDetailsContent`. Sendable value types with conformances declared in-Kit.
- `Policy/`: `DexNumberingPolicy` (monotonic, never-reuse, high-water mark, tombstones), `AgreementScorer` (taxon-normalized weighted vote plus a disagreement metric), `EscalationPolicy` (a data-driven rules table of thresholds, timeouts, and cost classes, evaluated by an engine; no hardcoded if-chains).
- `Flow/`: `IdentificationFlowState` and a pure reducer, `(state, event) -> (state, [effect])`, covering idle, captured, identifying, provisional, revealing, awaitingCommit, committed, failed, and correcting. The undo window and commit deferral live here, testable on macOS.
- `Providers/`: `PlantIdentificationProvider`, `SpeciesDetailsProvider`, `SpriteGenerationProvider`, `CareTextProvider` protocols; typed `ProviderError` including `.credentialMissing` (which kills the silent-failure class); `CredentialBroker` protocol with a static development implementation and, later, a proxy implementation.
- `Storage/`: `DexStore` protocol with an in-memory actor now and a SwiftData adapter in the app later; `MediaStore` owning the on-disk layout (`photos/{entryID}/original.heic`, `sprites/{entryID}/sprite-v{N}.png`).
- `Instrumentation/`: `RevealMetrics` and a `PerceivedQualityRecorder` protocol; the app provides a signpost-backed implementation, tests provide a spy that asserts ordering invariants (freeze-frame recorded before any provider request starts).
- `FloradexKitFixtures`: scriptable mock providers and the typed fixture catalog (below), consumable by tests, previews, and a dev harness without shipping in release.

**App layout** under `plantlife/Features/`: `Capture/` (a `CameraSession` actor wrapping AVFoundation, a thin `@Observable` `CaptureFlowModel` that delegates to the Kit reducer), `Reveal/`, `Dex/`, `Entry/`, plus `Support/` for haptics maps and design tokens. Isolation: app target adopts default MainActor isolation; the Kit's orchestrator and stores are actors; camera work is `nonisolated` behind the `CameraSession` actor.

**Concurrency doctrine.** Structured concurrency only; no `Task.detached`, no `DispatchQueue.asyncAfter` choreography. Long work is owned by actors; cancellation flows through the reducer's effects.

## Data model

SwiftData stays as the metadata store; images live on disk.

- **`DexEntry` v2**: stable `DexNumber` (assigned at commit, monotonic, never reused; deletes leave a tombstone that preserves the high-water mark), `createdAt`, a real relationship to `SpeciesRecord`, media references (paths, not blobs), `tags`, `notes`, capture context (optional, consented location), correction history, and provenance (which providers said what, at what confidence).
- **`SpeciesRecord`** (renames `SpeciesDetails`): canonical taxon (Latin name, common name, family), care profile (sunlight, water, soil, temperature, bloom time), fun facts, and `contentSource` (which provider or model produced it, when). No nils-by-design: fields the pipeline can't fill are omitted from the UI rather than rendered as permanently empty sections.
- **Media** via `MediaStore`: originals as HEIC at capture resolution, display derivatives generated lazily, sprites versioned (`sprite-v2.png` after regeneration) so a corrupted file never takes down an entry.
- **Migration**: `VersionedSchema` v1 (current shape) to v2 with a `SchemaMigrationPlan`; a macOS-runnable migration test seeds a v1 container, migrates, and asserts numbers and relationships survive. Existing users' renumbered ids are frozen as-is at migration; new numbers continue from the high-water mark.
- **CloudKit sync is out of scope for launch** (documented production sharp edges); the schema is designed not to preclude it.

## AI/provider pipeline

**Providers behind protocols.** Kindwise plant.id as candidate primary (houseplant coverage, commercial terms), Pl@ntNet secondary (wild flora; free tier is non-commercial, so the production posture depends on the licensing decision in Open questions), gpt-5.4-mini as a vision reasoner invoked for disagreement, no-plant arbitration, and long-tail cases. gpt-image-2 for sprites. Care text prefers on-device Foundation Models on capable hardware (iPhone 15 Pro/16+) with gpt-5.4-nano as cloud fallback. An on-device Core ML fast path is a future provider behind the same protocol, not a launch dependency.

**Escalation as data.** The old hardcoded threshold chain becomes a rules table: each rule names a trigger (confidence below X, timeout, disagreement above Y, offline), an action (invoke provider Z, return best-so-far, queue for retry), and a cost class. The engine walks the table; tests exercise the table directly. Budget caps stop escalation from compounding costs on ambiguous images.

**Agreement scoring.** Candidates are normalized (taxon synonymy, author strings stripped) before voting; the scorer emits both a winner and a disagreement metric that the UI surfaces honestly ("two of three sources agree").

**Credentials.** All provider calls go through `CredentialBroker`. Development uses static keys from the existing env/xcconfig mechanism; release blocks on the Cloudflare Workers proxy with App Attest gating and per-device quotas. `.credentialMissing` is a typed error with a designed first-run diagnostic state.

**Privacy posture in the pipeline.** The identification request sends the photo and nothing else by default; location is attached to the entry locally and never sent to providers unless a future feature asks and the user consents.

## UX flows and screens

- **Capture (home).** Full-bleed viewfinder, shutter in the thumb arc, picker and paste inlets, permission pre-prompt and denied-state with a Settings route. Interruption (call, Control Center) pauses and resumes the session gracefully.
- **Reveal card.** The staged reveal described in Hero loop. A digest surface, deliberately light: name, confidence band, sprite slot, two or three care lines, save/undo. Tapping pushes the full entry; the card itself never scrolls.
- **Dex collection.** A grid of collected entries (sprite, number, name), plus the plain-list escape hatch with search and sort. Stable numbers displayed proudly. Selection mode for batch delete (with tombstones) survives from the old app's one good interaction.
- **Entry detail.** Photo hero with the existing parallax treatment rebuilt cleanly, taxonomy, care profile rendered only for fields that exist, field notes, correction history, "report a problem with this identification" (the fixture inlet), re-identify and correct actions.
- **Correction flow.** Alternatives first (one tap), then species search, then free-text override. Every correction records provider provenance for the fixture loop.
- **Profile/settings.** Minimal: haptics and sound toggles, privacy explanations, licenses. The current stub tab earns its place only when it has content.
- **First-run.** Permissions as onboarding steps with plain-language reasons; the unconfigured-providers diagnostic if credentials are absent in a dev build.

## Visual and motion direction

- **Liquid Glass, natively.** Standard materials, toolbars, and transitions on iOS 26; no fighting the system look. The pixel-art identity lives in the content layer (sprites, dex numbering typography), not in chrome.
- **Retro as accent, not costume.** Sprites render with `interpolation(.none)` at fixed pixel multiples. A single display face for dex numbers and headers that nods to field-guide typography; body text stays system (Dynamic Type first). The bundled-but-unused pixel fonts either earn a deliberate single-purpose slot (dex numbers) or get deleted. (Decided 2026-07-02: the display role split deliberately. New York serif carries names and headers; Departure Mono, OFL, carries dex numbers and nothing else. The register rule lives in `FloradexTheme`.)
- **Motion doctrine.** One signature spring for card entrances; stage entrances in the reveal are choreographed with `PhaseAnimator`/`KeyframeAnimator` rather than `asyncAfter` chains. Grid tilt and scroll-velocity effects from the old app return only if they hold 120 Hz on device.
- **Light and dark from day one**, semantic colors only; the accent green `#2EB875` survives as the brand anchor.
- **Every empty state designed**: empty dex, no camera permission, offline queue, sprite pending.

## Trust, privacy, and correction model

- **Never fake certainty.** Confidence is banded (confident, likely, unsure) with the raw number available on tap. Below the unsure threshold, the app leads with alternatives and retake guidance instead of a single answer.
- **Disagreement is information.** When providers split, the card says so in one line and shows both candidates. The reasoner's tiebreak is labeled as such.
- **Correction is a first-class signal.** Corrections update the entry, feed the fixture corpus, and (later) inform provider weighting. The UI thanks the user; it never argues.
- **Photo privacy.** Photos leave the device only as identification requests to the configured providers, stated plainly in settings. No analytics SDK. Location is opt-in per the capture context and stored locally.
- **Key security.** No provider keys in the shipped binary. The proxy enforces App Attest and per-device quotas so a jailbroken client can't drain the account.
- **Failure honesty.** Every failure state names what happened and what the user can do. `.credentialMissing` and provider outages are distinguishable from "we looked and we're not sure."

## Testing and fixture loop

**The loop, borrowed from the Avec teardown:** user pain, bug capture, deterministic reproduction, fix, regression verification. Every real-world failure becomes a fixture; every fixture becomes a permanent test. The in-app inlet is "report a problem with this identification" on the entry, which captures the photo (with consent), provider responses, device and OS, and app version: a reproduction born with maximum context.

**Fixture corpus** (typed catalog in `FloradexKitFixtures`, all present from day one; a sixteenth, providers-down, was added during the de-sloppify pass):

| # | Fixture | Exercises |
|---|---------|-----------|
| 1 | Easy common plant | Happy path, high confidence |
| 2 | Ambiguous plant | Alternatives UI, banded confidence |
| 3 | Bad or blurred photo | Retake guidance state |
| 4 | Duplicate plant | Duplicate detection before commit |
| 5 | No plant in image | No-plant arbitration, honest empty result |
| 6 | Provider timeout | Escalation timeout rule, best-so-far |
| 7 | Provider disagreement | Agreement scorer, disagreement UI |
| 8 | Offline mode | Capture queue, deferred identification |
| 9 | Low confidence | Unsure state, lead-with-alternatives |
| 10 | Saved entry, missing details | Partial content rendering |
| 11 | Corrupted or missing sprite | Sprite versioning, placeholder recovery |
| 12 | Long care text | Layout resilience |
| 13 | Small-screen iPhone | Layout fixture (mini-class widths) |
| 14 | Large dynamic type | Accessibility layout fixture |
| 15 | Permission denied | Denied-state flow, Settings route |

**Layers.** Swift Testing suites in the Kit run on macOS with no simulator: numbering policy (including the anti-renumbering regression), agreement scoring, escalation tables, the reducer walked through every fixture's event sequence including undo rollback, media path logic, credential errors, and catalog completeness. Orchestrator tests drive scripted mock providers through the full state machine with metric-ordering assertions. App-level: Maestro flows for the hero path on simulator (once the platform component is installed), XCTest for anything needing the host app. swift-snapshot-testing is not a gate while its iOS 26 crash (issue #1089) is open; visual regression rides Maestro screenshot assertions instead.

**Rule:** a field bug does not merge its fix without landing its fixture first.

## Implementation phases

Verification constraint: until the iOS platform component finishes installing, checkpoints rest on `swift test` (macOS) and, once available, `xcodebuild build`. Simulator-run tests become a hard gate only at phase 7. All pbxproj mutations are batched into scheduled, checklisted Xcode GUI sessions and audited by reviewing `git diff plantlife.xcodeproj/` afterward; pbxproj is never hand-edited.

- **Phase 0: spec and research docs.** This document and its research companion. Checkpoint: docs merged; repo code untouched. Status: DONE (commit 7d74d22).
- **Phase 1: `FloradexKit` standalone.** The package described in App architecture, with its full Swift Testing suite. Zero diffs under `plantlife/` or the project file. Checkpoint: `swift build` and `swift test` green in Swift 6 mode on macOS; app tree untouched by `git diff --stat`. Status: DONE (7d74d22, 72 tests).
- **Phase 2: dead-code wave 1 and test-target repair.** Delete the dead subsystems (folder-sync makes deletions project-edit-free); prune the test target to its compiling subset. Checkpoint: app builds; `build-for-testing` compiles; grep-zero hits for deleted symbols. Status: DONE (a1117ec; also fixed three iOS 26 runtime crashes found by the revived tests: the broken `ClassifierService.Source` reference, the untranslatable tags predicate, and renumber-on-delete racing teardown).
- **Phase 3: the Xcode session.** Add the `FloradexKit` package reference, remove Lottie, flip deployment target 18.4 to 26.0, set strict-concurrency warnings (SWIFT_VERSION stays 5.0 for now). Checkpoint: build green with the Kit linked; project diff reviewed line by line; warning inventory snapshotted (140, `warning-baseline.md`). Status: DONE (9e57edd, scripted via `scripts/wire_floradexkit.rb` with approval).
- **Phase 4: hero loop rebuild.** `CameraSession` actor, capture and reveal features, orchestrator actor and real providers in the Kit, signpost recorder, haptics map. Strangler cut at the capture route. Checkpoint: build green; orchestrator tests cover every logic-reachable fixture; ordering invariants machine-checked; fixture demo runs the loop on simulator. Status: DONE (1f73531, 917953a, 0e253c7, 964588d; screenshots in `docs/rewrite-research/screenshots/`). Deferred from this phase: the debug HUD (signposts and logs exist), sprite kickoff during reveal rather than at commit.
- **Phase 5: collection and detail surfaces, dead-code wave 2, schema v2.** New dex and entry screens; `ClassificationViewModel` and the old routing and networking die here; v2 schema with migration test. Checkpoint: build green; grep-zero for wave-2 symbols; migration test green; deprecation warnings near zero because their carriers are gone. Status: DONE. Wave-2 deletions (dea5371), then schema v2 with the seeded migration test, the SwiftData-backed DexStore with the persisted ledger, media on disk via FileMediaStore, the new dex grid and entry detail, and the native TabView root all landed in the 2026-07-02 session; every legacy surface is deleted.
- **Phase 6: trust and correction states, Swift 6 flip.** Correction flows, disagreement surfacing, offline queue, permission and credential diagnostics. Second Xcode session flips SWIFT_VERSION to 6.x with default MainActor isolation, safe because every known offender was deleted in the waves. Checkpoint: build green under Swift 6 with zero concurrency errors; reducer covers every trust-state transition. Status: DONE except the offline queue (correction cancel and free-text override, raw-confidence-on-tap, sources-agree line, honest offline and credential copy; `scripts/flip_swift6.rb` flipped SWIFT_VERSION to 6.0 with default MainActor isolation on the app target, and the keypath-Sendability warning class cleared as hoped). The offline capture queue moves to phase 8: today offline is an honest failure state with retry, and queueing deserves its own design (persisted pending captures, connectivity retrigger).
- **Phase 7: fixture corpus materialization and E2E.** Real photo assets and recorded provider payloads behind the fixture catalog; deterministic replay through the real orchestrator; Maestro flows green on simulator; one `xcodebuild test` smoke run. Checkpoint: the full fixture corpus replays deterministically with no network.
- **Phase 8: polish and proxy.** Frame-pacing and haptic tuning against instrumented budgets; dynamic-type and small-screen fixtures; the Cloudflare Workers + App Attest proxy, which client-side is only swapping the broker implementation; optional cosmetic rename of the product to `floradex`. Checkpoint: on-device p50 time-to-first-reveal within budget; broker swap covered by Kit tests. Status: the visual identity landed early (2026-07-02 design session; see WHERE-WE-LEFT-OFF): herbarium direction with a pixel face scoped to dex numbers, the token layer in `plantlife/UI/FloradexTheme.swift`, all four surfaces restyled, app icon already done. Remaining here: offline queue, proxy, on-device frame pacing and haptic verification.

**Risk register (abridged).** No simulator until the platform lands (checkpoints designed around it); pbxproj mutations vs the no-hand-edit rule (batched Xcode sessions with diff audits); dual pipelines during the strangler window (in-memory provisional entries mean a single writer; old flow grep-verified unreachable, deleted one phase later); Swift 6 flip blast radius (two-step: warnings first, flip after the offenders are deleted); SwiftData v2 migration (versioned schema plus a seeded migration test); sprite latency (off the critical path by design); snapshot-testing breakage (never a gate); missing keys (typed error plus designed diagnostic, then the proxy).

## Open questions

1. **Provider licensing.** Kindwise credits (commercial-friendly, pay-per-use) versus a Pl@ntNet Pro license (€1,000/yr) versus Pl@ntNet's free tier (non-commercial only). Depends on whether Floradex ships to the App Store as a paid/commercial product. Owner call.
2. **Proxy hosting.** The Workers + App Attest proxy needs a Cloudflare account and a deploy story. Whose account, and does it block TestFlight or only public release?
3. **App Store intent and timeline.** Shapes the provider licensing answer, the proxy deadline, and how aggressively to chase iOS 27-era polish.
4. **Location on entries.** Field-companion value (where did I find this?) versus privacy surface. Proposed: opt-in at first save, off by default.
5. **The old pixel fonts.** Deliberate single-purpose revival for dex numbers, or deletion. Decide during phase 4 design.
6. **Existing installs.** Is there any real user base whose v1 data must migrate, or is the migration test an insurance policy? Affects how much phase 5 invests in migration tooling.

## Non-goals

- CloudKit sync at launch (schema stays sync-compatible; the work is deferred deliberately).
- Live Activities, widgets, and App Intents until the hero loop ships and earns them.
- Android, web, or any cross-platform layer.
- Social features, sharing feeds, or gamification beyond the collection itself.
- A custom on-device classifier at launch (the provider protocol leaves the door open).
- Care reminders and plant-care scheduling (a different app's job until the dex is excellent).
- iPad-optimized layouts (iPhone-first; iPad merely must not break).
