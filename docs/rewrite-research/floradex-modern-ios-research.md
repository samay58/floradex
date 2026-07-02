# Floradex modern iOS research (July 2026)

Decision-oriented findings for the rewrite. Each entry: question, best current answer, evidence, implication, and whether it changes the rewrite spec. Anything that didn't change product, architecture, privacy, or testing decisions was left out.

## SwiftUI state management

**Question.** What replaces the app's all-`ObservableObject` view models?

**Answer.** `@Observable` (Observation framework) is the 2026 default: field-level change tracking, no `@Published` boilerplate, `@State`/`@Environment` for ownership. Never pair it with `@StateObject`/`@ObservedObject`. Swift 6.2 introduced default MainActor isolation (SE-0466); Xcode 26 enables it for new targets, and consensus (Donny Wals, SwiftLee) is to turn it on for app targets and mark only true off-main work (`nonisolated`, actors). Architecture consensus for a mid-size app is lightweight MV/MVVM with `@Observable` services in the environment. TCA-style ceremony is overkill at this scale.

**Evidence.** swift.org 6.2 release notes; SE-0466; donnywals.com on default MainActor isolation; avanderlee.com same topic; jessesquires.com on `@Observable` not being a drop-in swap.

**Implication.** Rewrite standardizes on `@Observable` plus a default-MainActor app target; networking, ML, and camera become actors or `nonisolated`.

**Changes spec: yes.**

## Deployment target

**Question.** Minimum iOS for a new-in-2026 app?

**Answer.** iOS 27 was announced at WWDC 2026 (June) and drops no devices vs iOS 26. iOS 26 sits at roughly 79% of all iPhones (June 2026), and building against the iOS 26 SDK is already mandatory for App Store submission (April 2026 deadline). The Liquid Glass opt-out (`UIDesignRequiresCompatibility`) is expected to disappear in the Xcode 27 cycle. By a realistic Floradex launch in late 2026, iOS 26+ coverage should reach 85% or better.

**Evidence.** MacRumors iOS 26 adoption stats (June 2026); Daring Fireball adoption post; Apple SDK submission deadline coverage; Donny Wals on the Liquid Glass opt-out.

**Implication.** Minimum target iOS 26 (current project is at 18.4). Design for Liquid Glass natively rather than fighting it. One nuance: Foundation Models needs Apple-Intelligence hardware (iPhone 15 Pro/16 and later), a narrower set than "iOS 26 devices," so gate that capability.

**Changes spec: yes.**

## SwiftData in mid-2026

**Question.** Keep SwiftData, or move to GRDB/SQLite? How should photos be stored?

**Answer.** SwiftData is production-usable for a single-store, local-first app. The sharp edges are CloudKit sync (dev-vs-prod schema deployment failures, migration propagation, an iOS 26 `BAD_REQUEST` regression wave) and concurrency (use `@ModelActor` for background writes). GRDB is warranted only for heavy queries or high-volume writes, which is not Floradex's shape. For photos: never inline blobs. Either `@Attribute(.externalStorage)`, which blocks predicates on those fields, or files on disk with paths and metadata in the DB. Files on disk is the stronger pattern for bulk images.

**Evidence.** fatbobman on CloudKit sync production failures; Apple Dev Forums thread 811675 (iOS 26 sync regression); Hacking with Swift on externalStorage; deirdre.dev on SwiftData image patterns.

**Implication.** SwiftData stays as the metadata store. Photos and sprites become files on disk with path references. CloudKit sync is deferred to a post-launch milestone with explicit schema-deployment work budgeted.

**Changes spec: partially** (storage layout yes; store choice no).

## Camera

**Question.** Is there a first-party SwiftUI camera view yet? What makes capture feel instant?

**Answer.** No first-party SwiftUI camera. The pattern remains `AVCaptureSession` plus `AVCapturePhotoOutput`, preview layer bridged via `UIViewRepresentable`, session managed off-main by an actor (Apple's AVCam sample is the reference). The responsiveness stack: Zero Shutter Lag (automatic since iOS 17 link), `isResponsiveCaptureEnabled`, `isFastCapturePrioritizationEnabled`, and iOS 26's Deferred Start API for faster perceived session start, plus `AVCaptureDevice.dynamicAspectRatio`. Permissions: request at point of use with a pre-prompt, handle `.denied` with a Settings route, offer the photo-picker path as fallback.

**Evidence.** Apple docs for the named APIs; WWDC23 session 10105 (responsive camera); WWDC25 session 253 (capture controls).

**Implication.** Keep AVFoundation with a representable bridge; enable the full responsiveness stack; pre-warm the session before the user reaches the camera.

**Changes spec: minor** (confirms direction, names the specific APIs).

## Plant identification providers

**Question.** What should the provider lineup be?

**Answer.**
- **Kindwise plant.id**: credit-based (about €0.05/credit at low volume, €0.01 at high), strong houseplant and cultivar coverage, plant-health diagnosis, commercial-friendly. Best primary fit for a consumer collecting app.
- **Pl@ntNet**: free tier of 500 IDs/day is non-commercial only; commercial is €1,000/yr for 200k requests. Strong wild-flora taxonomy. Good secondary.
- **iNaturalist**: no sanctioned public identification API (the model is private; the known CV endpoint is unsupported). They publish small ~500-taxa on-device models at testing quality, not production.
- **VisionKit Visual Look Up**: identifies plants for users but exposes no structured species results to third-party apps. Not a backend.
- **On-device Core ML**: possible via converted community models (iNat-derived); useful as an offline fast path later, never as the primary.

**Evidence.** my.plantnet.org pricing and terms; kindwise.com pricing; iNaturalist forum "hidden computer vision API" thread plus inaturalist/model-files repo; Apple VisionKit docs (`visualLookUp` interaction type).

**Implication.** Provider abstraction with Kindwise as candidate primary, Pl@ntNet secondary, an LLM vision reasoner for disagreement and no-plant cases, optional Core ML offline path later. The current PlantNet-then-GPT cascade survives in shape but not in providers. Commercial commitment (Kindwise credits vs a Pl@ntNet license) is an open question for the owner.

**Changes spec: yes.**

## OpenAI APIs and Apple Foundation Models

**Question.** Current model choices for vision reasoning, sprite generation, and care text?

**Answer.** `gpt-4o-mini` is legacy. The current cheap vision models are the GPT-5.4 family: gpt-5.4-nano ($0.20/$1.25 per 1M tokens in/out) and gpt-5.4-mini ($0.75/$4.50); mini for image reasoning, nano for cheap text. `gpt-image-1` is superseded by gpt-image-2 ($30/1M image-out tokens, roughly $0.005 to $0.21 per image depending on quality). Apple's Foundation Models framework (iOS 26) runs a ~3B on-device LLM with guided generation and tool calling: free, offline, private. Ideal for care text and fun facts, but only on Apple-Intelligence hardware, so it needs a cloud fallback.

**Evidence.** developers.openai.com pricing and model catalog; openai.com GPT-5.5 announcement; Apple FoundationModels docs and the Sept 2025 newsroom post.

**Implication.** Sprite pipeline moves gpt-image-1 to gpt-image-2. Vision reasoning moves gpt-4o-mini to gpt-5.4-mini. Care text prefers on-device Foundation Models with gpt-5.4-nano fallback, cutting cost, latency, and privacy exposure.

**Changes spec: yes.**

## API key security

**Question.** Can provider keys stay in the client?

**Answer.** No. Consensus is firm: keys in an iOS binary are extractable and become an open tab on the bill; shipping them is also an abuse and App Review concern. The indie-scale pattern is a lightweight edge proxy (Cloudflare Workers) that holds the real keys and enforces quotas, gated by App Attest, which gives hardware-backed proof the request comes from an unmodified build. DeviceCheck is the weaker, broader-compatibility option. A proxy without attestation and rate limits is just a public relay.

**Evidence.** ufukozen.com (Cloudflare Workers plus App Attest walkthrough); george.tsiokos.com "your API key doesn't belong in the app"; bearologics.com (Workers plus DeviceCheck).

**Implication.** The rewrite designs a `CredentialBroker` seam now (static keys for development) and ships a Workers-plus-App-Attest proxy before any public release. On-device Foundation Models sidesteps the problem for care text.

**Changes spec: yes, architectural.**

## Testing

**Question.** What does the test stack look like?

**Answer.** Swift Testing (`#expect`/`#require`) is the default for new unit tests on Xcode 26; XCTest remains for UI and performance tests. Maestro is viable for native iOS E2E in 2026: it drives real or simulated devices, is framework-agnostic, and supports screenshot assertions. swift-snapshot-testing supports Swift Testing but has an open iOS 26 crash (`UIHostingController` trait setup, issue #1089, reproduced through ~1.19.2), so SwiftUI snapshotting on iOS 26 simulators is currently unreliable.

**Evidence.** developer.apple.com/xcode/swift-testing; pointfree.co blog post 146; github.com/pointfreeco/swift-snapshot-testing issue #1089; docs.maestro.dev iOS support.

**Implication.** Unit and policy tests in Swift Testing, runnable on macOS via the FloradexKit package with no simulator needed. Hero-loop E2E via Maestro once a simulator runtime is installed. Snapshot testing gates nothing until #1089 resolves.

**Changes spec: partially** (confirms Swift Testing and Maestro; removes snapshot testing from the critical path).

## Net spec changes, biggest first

1. Client-side API keys out: `CredentialBroker` seam now, Cloudflare Workers plus App Attest proxy before release.
2. `ObservableObject` out: `@Observable` plus Swift 6.2 default-MainActor isolation.
3. Deployment target 18.4 to 26.0; design for Liquid Glass.
4. AI stack: gpt-4o-mini to gpt-5.4-mini/nano; gpt-image-1 to gpt-image-2; Foundation Models on-device for care text (gated, with fallback).
5. Provider lineup: Kindwise primary candidate, Pl@ntNet secondary; iNaturalist and Visual Look Up ruled out.
6. Photos and sprites as files on disk with DB path references; CloudKit sync deferred.
7. Swift Testing plus Maestro; snapshot testing off the critical path.
