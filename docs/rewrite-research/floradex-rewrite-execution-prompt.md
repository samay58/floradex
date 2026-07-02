# Floradex rewrite execution prompt: phases 2 through 8

You are Claude (Fable) working in `/Users/samaydhawan/Projects/parked/floradex`. Note that `/Users/samaydhawan/floradex` is a symlink to the same checkout. You are on branch `rewrite/foundation`; last commit `7d74d22`. Phases 0 and 1 of the rewrite are done and committed: the rewrite spec, the research doc, and the standalone FloradexKit package with 72 green Swift Testing tests.

Your mission is to execute the remaining phases of the rewrite spec at maximum sustainable speed, using subagents and workflows for parallelism where safe. You have my standing approval for multi-agent orchestration (Workflow tool and Agent tool) throughout this run. Finish as much of phases 2 through 8 as can be genuinely verified on this machine. Do not fake completion of anything that needs a physical device, real API keys, or my accounts; surface those instead.

Read before any code edit, in this order:

1. `CLAUDE.md` at the repo root; the "Rewrite (in progress)" section is current
2. `docs/rewrite-research/floradex-rewrite-spec.md`; this is the contract, especially Hero loop, App architecture, Data model, Implementation phases
3. `docs/rewrite-research/floradex-modern-ios-research.md` for platform decisions with sources
4. Skim `docs/rewrite-research/floradex-fable-rewrite-prompt.md` for the product ethos

## Ground truth about this machine

- Xcode 26.6, Swift 6.3, iOS 26.5 SDK and simulator platform are installed. No simulator devices exist yet. Create one first (`xcrun simctl list devicetypes`, then `xcrun simctl create`), after which `xcodebuild test` works.
- The app target does not compile at baseline. One error: `plantlife/UI/Components/AnimatedConfidenceMeter.swift:7` declares `ClassifierService.Source`, which must become `ClassifierResult.Source`. The test target has additional stale-API errors; the spec's current-state section lists them.
- No API keys are configured anywhere. All provider work must be verified through the fixture corpus and scripted providers. Live calls are unverifiable here and must never be a checkpoint dependency.
- FloradexKit verifies with `cd FloradexKit && swift test` on macOS. Keep it that way: no SwiftUI or UIKit imports in the Kit, ever.
- The pbxproj uses folder-sync groups (objectVersion 77): files added or deleted under `plantlife/` and `plantlifeTests/` join or leave the target automatically, with no project edits.

## Standing rules

- Never hand-edit `project.pbxproj` text. For the project mutations the spec batches (add the FloradexKit local package reference, remove the lottie-ios dependency, flip `IPHONEOS_DEPLOYMENT_TARGET` to 26.0, and later flip `SWIFT_VERSION` to 6 with default MainActor isolation), use the `xcodeproj` Ruby gem from a script committed under `scripts/`. By running this prompt I approve that scripted path. Protocol per mutation: commit a checkpoint first, run the script, review `git diff plantlife.xcodeproj/` line by line against the intended change, then prove it with a green build before anything else proceeds. If the gem is unavailable and cannot be installed, post the exact Xcode click-through checklist for me as a blocking item and continue with unblocked work.
- Never break the build at a commit boundary after the phase 2 fix lands. Commit at every green checkpoint. Commit messages: plain sentences, no em-dashes, ending with the Co-Authored-By trailer.
- New code conventions: `@Observable` (never ObservableObject), structured concurrency only (no `Task.detached`, no `DispatchQueue.asyncAfter` choreography), `os.Logger` (never `print`), no force unwraps, view bodies under 100 lines, Swift Testing for new tests. Per-frame gesture state lives in `@GestureState` and local view state, never in an observable model.
- Do not invent iOS 26 API names. If you are not certain an API exists, check Apple docs with WebFetch or write the boring fallback that compiles. Compile early and often; a small verified step beats a large speculative one.
- The fixture rule applies to you: any bug you find and fix in Kit logic lands with its test or fixture in the same commit.
- Keep the docs current: when reality forces a deviation from the spec, amend the relevant spec section in the same commit. Update the CLAUDE.md rewrite section at each phase boundary.

## Subagent strategy

- Parallelize only work that is independent at the file level, and keep a single writer per directory tree. Any subagent that writes app code in parallel with another writer runs with worktree isolation; the main loop merges serially. Never let a subagent commit.
- Good parallel splits: Kit provider clients vs app camera and UI code (different roots); per-screen builds in phase 5; research and review agents at any time.
- After each phase, run two verification agents in parallel: one executes the phase gates and reports raw results; one adversarially reviews the diff for spec violations (silent failure paths, `print`, ObservableObject, per-frame state in models, invented APIs, Kit importing UI frameworks).

## Execution order and gates

**Phase 2, unblock and shrink.** Fix the one-token compile error. Delete the dead-code inventory named in the spec: the Live Activity subsystem, the four unused API services (Wikipedia, USDA, Trefle, Perenual), FloradexHomeScreen, DexCardPager with its card views (OverviewCard, CareCard, GrowthCard, AnyDexDetailCard), ActivityView, both PermissionsOverlay files, LottieView, Analytics, and the unused bundled pixel fonts with their Info.plist registrations. Prune the test target to what compiles: keep DexEntryTests, prune DexRepositoryTests to its valid subset, delete the rest. Create a simulator device. Gates: app build green; `build-for-testing` green; the kept unit tests pass on simulator; grep returns zero hits for every deleted symbol. Commit.

**Phase 3, project wiring.** Scripted per the standing rule: wire FloradexKit into the app target, remove lottie-ios, flip the deployment target to 26.0, enable strict-concurrency warnings while `SWIFT_VERSION` stays 5. Add one real `import FloradexKit` usage to prove linkage. Gates: build green with the Kit linked; project diff reviewed line by line; warning inventory snapshotted to `docs/rewrite-research/warning-baseline.md` (the count must only shrink from here). Commit.

**Phase 4, hero loop.** The largest phase; overbuild it per the spec. In the Kit: an `IdentificationOrchestrator` actor that drives `EscalationEngine` and the reducer's effects against the provider protocols, with per-step timeouts and cancellation; real provider clients (Kindwise plant.id REST, Pl@ntNet multipart, an OpenAI vision reasoner, and a gpt-image-2 sprite client) behind the existing protocols using URLSession and CredentialBroker; async orchestrator tests that replay the entire fixture catalog. In the app: a `CameraSession` actor with pre-warm and the responsive-capture APIs; the capture screen; the staged reveal card (name, then confidence, then details, sprite last with a pixel-silhouette placeholder); haptics at the spec's semantic boundaries only; a thin `CaptureFlowModel` bridging the reducer; a signpost-backed PerceivedQualityRecorder plus a debug HUD. Strangler cut: the new flow replaces the Identify tab route in the same change; the old pipeline may still compile but must be grep-verified unreachable from any live route. Wire a debug scheme flag that swaps the scripted fixture providers in, so the full loop is demonstrable without keys. Gates: Kit tests green including orchestrator fixture replay; app build green; the app boots on simulator and capture-to-reveal-to-collect runs end to end against fixtures; capture a screenshot of the reveal via `simctl io screenshot` for the report. Commit.

**Phase 5, collection surfaces and wave-2 deletions.** New dex grid and entry detail per the spec's UX flows, a native TabView and NavigationStack root, and the plain-list escape hatch. SwiftData v2 schema in the app layer implementing the Kit's DexStore: stable numbers via a persisted DexNumberLedger, a real DexEntry-to-species relationship, media through FileMediaStore; VersionedSchema migration from v1 with a seeded migration test. Then wave-2 deletions: ClassificationViewModel, the old repositories, GPT4oService, PlantNetService, SpriteService, APIClient, ImageSelectionService, LiquidTabBar, and the old views they fed. Gates: build green; all tests green; the migration test proves v1 data survives with its numbers frozen; grep zero for wave-2 symbols; deprecation warnings at or near zero. Commit.

**Phase 6, trust states and the Swift 6 flip.** Correction flow (alternatives first, then species search override), re-identify, disagreement surfacing, the offline capture queue, and the permission-denied and credential-missing diagnostic states, all driven by reducer states that already exist. Then the scripted `SWIFT_VERSION` flip to 6 with default MainActor isolation. Gates: build green under Swift 6 with zero concurrency errors; each trust state covered by a reducer or UI test. Commit.

**Phase 7, fixture materialization and E2E.** Deterministic replay assets (procedurally generated placeholder images are fine; determinism beats realism), recorded-payload replay through the real orchestrator with zero network, an XCUITest smoke of the hero path on simulator, and Maestro flows for the hero path if maestro installs cleanly via brew; otherwise commit the flow files with run instructions. Gates: the full 15-case corpus replays green offline; `xcodebuild test` green on simulator. Commit.

**Phase 8, best-effort polish and proxy scaffolding.** Dynamic type and small-screen passes on the new screens; designed empty states; accessibility labels. Scaffold the Cloudflare Workers proxy under `proxy/` (Worker source, App Attest verification stub, per-device quota sketch, wrangler config, and a README with deploy steps), and implement `ProxyCredentialBroker` in the Kit behind the existing seam with tests. Do not attempt to deploy; that needs my account. Commit.

## What blocks on me

Batch these into one list at the end rather than stalling mid-run: the provider licensing decision (Kindwise credits vs a Pl@ntNet license), a Cloudflare account for the proxy deploy, physical-device verification of capture latency and haptics, and App Store intent. The only acceptable mid-run ask is the pbxproj fallback if the scripted path fails.

## Final deliverable

A report listing: phases completed with gate evidence (the commands run and their results), files changed per phase, the simulator screenshot(s), the blocked-on-me list, and exact next steps. Update the CLAUDE.md rewrite section, append a line to `~/.progress.jsonl`, run slopcheck on any prose you wrote (docs, READMEs, commit bodies), and leave every commit on `rewrite/foundation`.
