# PlantLife — Implementation Checklist

> Use this file as a living document. Check boxes as tasks finish and feel free to break large items into finer-grained todos.

---

## Hotfix — Data Completeness (May-15)

**Goal:** eliminate empty info cards by enriching SpeciesDetails via GPT and improving tab discoverability.

- [x] Implement `GPT4oService.complete(details:)` with JSON-fill prompt & retry logic.
- [x] Reorder `SpeciesRepository.details()` so GPT completion runs before fun-facts and always triggers fun-facts fetch.
- [x] Guarantee a bullet list: if GPT fun-facts fail → fallback to FactsFormatter.
- [x] Placeholder strings ("Unknown") for nil care/growth fields to avoid collapsing.
- [x] UI: replaced paging TabView with segmented Picker for clear labels.

> Target: merged & tested by 2025-05-16.

---

## Repo Streamlining & Foundational Improvements (High Priority - Today)
- [x] Delete `plantlife-Bridging-Header.h` & LLVM build-setting.
- [x] Move services to `Networking/`, create `ImageProcessing/` etc. for clearer folder structure.
- [x] Create `Shared/Extensions.swift` for tiny helpers (e.g. `.nonEmpty`, `UIImage.resized`).
- [x] Temporarily disable Firebase/Lottie SPM packages until fully integrated to save build time.

---

## Architectural Upgrades (Backlog for 10x Better Codebase)
- [x] **SwiftData Migration:**
  - [x] Replace Core Data (`CoreDataStack`, `SpeciesEntity`) with SwiftData.
  - [x] Convert `SpeciesDetails` into a SwiftData `@Model`.
  - [x] Update data persistence logic.
- [x] **Single Unified APIClient:**
  - [x] Create `APIClient.swift` with shared `URLSession` (8s timeout), basic error enum (`APIError`).
  - [x] Define `APIEndpoint` protocol/struct for structured request definitions (path, method, headers, params, body).
  - [x] Implement generic `request<T: Decodable>(endpoint: APIEndpoint)` method in `APIClient`.
  - [x] Add retry logic with exponential backoff to `request` method.
  - [x] Add basic request/response logging to `APIClient`.
  - [x] Refactor `WikipediaService` to use `APIClient`.
  - [x] Refactor `PlantNetService` to use `APIClient` (handle multipart form data).
  - [x] Refactor `GPT4oService` to use `APIClient` (handle custom JSON body).
  - [x] Refactor `TrefleService` to use `APIClient`.
  - [x] Refactor `PerenualService` to use `APIClient`.
  - [x] Refactor `USDAService` to use `APIClient`.
- [x] **Parallel Async/Await Classification Pipeline:**
  - [x] Rewrite local classifier to be `async`.
  - [x] Use `async let` for concurrent local and remote classification.
    ```swift
    // Example:
    // async let local  = classifier.local(thumbnail)
    // async let remote = classifier.ensemble(thumbnail, after: local)
    // let winner       = await remote
    ```
- [ ] **SwiftUI Previews & Snapshot Tests:**
  - [ ] **A. Create SwiftUI Previews for significant views:**
    - [x] `InfoSheetView.swift` (loaded, loading, empty states)
    - [x] `ContentView.swift`
    - [ ] `PermissionsOverlayView.swift`
    - [ ] Key custom card views (e.g., `PhotoCardView`)
    - [ ] Helper: Static mock `SpeciesDetails` instances.
    - [ ] Helper: Preview `ClassificationViewModel` with mock data & states.
    - [ ] Helper: In-memory `SpeciesRepository` for previews.
  - [ ] **B. Implement Snapshot Tests (using Point-Free's SnapshotTesting):**
    - [ ] Add `swift-snapshot-testing` SPM package to test target.
    - [ ] `InfoSheetView.swift` (loaded, loading, dark mode states).
    - [ ] `ContentView.swift`.
    - [ ] Automate recording/verifying snapshots.
- [ ] **UI Polish Enhancements:**
  - [ ] **A. Add subtle scroll-bouncy hero photo:**
    - [ ] Target: Main plant image view (e.g., in `InfoSheetView` or `PhotoCardView`).
    - [ ] Use `ScrollView` + `GeometryReader` or named coordinate spaces.
    - [ ] Apply subtle `offset(y:)` and/or `scaleEffect()` based on scroll position.
  - [ ] **B. Tune accent gradients for dark mode:**
    - [ ] Locate accent color/gradient definitions.
    - [ ] Use `@Environment(\.colorScheme)` to adjust gradients.
    - [ ] Create a test view for all gradients in light/dark modes.
  - [ ] **C. Implement shimmer skeleton loading states:**
    - [ ] Target: `InfoSheetView` content while `classifierVM.details` is loading.
    - [ ] Apply `.redacted(reason: .placeholder)`.
    - [ ] Create/integrate a `ShimmerEffect` modifier (animated gradient overlay).

---

## Phase 1 — Project Setup
- [x] Create new "PlantLife" SwiftUI project (Xcode 15, iOS 17)
- [ ] Configure automatic signing & CI bundle identifiers
- [x] Add camera + photo library usage strings to `Info.plist`
- [ ] Integrate SPM packages
  - [ ] Firebase Crashlytics
  - [ ] Lottie-ios
- [ ] Initialize Firebase (`GoogleService-Info.plist`, run script, dSYM upload)
- [ ] Commit baseline to `main` branch

## Phase 2 — Image Intake
- [x] `PhotoPickerView` (PHPickerViewController wrapper)
- [x] `CameraCaptureView` (AVCapturePhotoOutput wrapper)
- [x] Combine `@Published` stream of `UIImage` (selected / captured)
- [x] Permissions UX (first-run coaching overlay)

## Phase 3 — Classification Pipeline
- [ ] Add MobileNet-derived `.mlmodel` asset
- [ ] Unit tests w/ sample fixtures
> **Deferred** — revisit after Phase 5 polish.
- [ ] (deferred) Add MobileNet-derived `.mlmodel` asset
- [ ] (deferred) Unit tests w/ sample fixtures
- [x] `ClassifierService`
  - [x] `classifyLocal(_: UIImage)` – Core ML inference
  - [x] `classifyPlantNet(_: UIImage)` – REST call
  - [x] `classifyGPT4o(_: UIImage)` – Vision API call
- [x] `EnsembleService.vote(_ results: [ClassifierResult])`
- [x] Timeout & error shielding in pipeline (removed hard timeout, keeps Combine shields)

## Phase 3B — Latency Optimisations
- [x] Local-first flow (show local result, skip remotes if confidence ≥ 0.75)
- [x] Progressive UI update (overwrite when remotes finish)
- [x] JPEG down-scaling to 600 px max side before upload
- [x] Skip GPT-4o unless PlantNet < 0.6 confidence/disagrees
- [x] Shared URLSession with 8 s request timeout
- [x] Cancel in-flight classification tasks when a new image arrives
- [ ] SHA-1 based result cache (photo→ClassifierResult)
- [x] Exponential-backoff retry for GPT4o & Trefle calls
- [ ] Async base64 encode in background task
- [ ] Evaluate BNNS/Metal model port

## Phase 4 — Facts Aggregation & Caching
- [x] `WikipediaService.fetchSummary(for latinName: String)`
- [x] `USDAService.fetchData(for latinName: String)` (growth habit stub)
- [x] `SpeciesInfo` model (name, description, careTips, images, sources)
- [x] Core Data stack (`NSPersistentCloudKitContainer`)
- [x] Offline caching & TTL eviction logic (7-day TTL)
- [x] Analytics events (`details_success` / `details_empty`) wired

## Phase 4B — Friendly Fact Packaging
- [x] NLP post-process raw text into concise bullet points
- [x] Heuristics to filter Latin terms / botanical jargon
- [x] Display bullet list UI under photo card
- [x] GPT-4o summarization endpoint (cache results)
- [x] Accessibility: VoiceOver reads bullets as separate items
- [x] Fixed missing string interpolation for growth habit bullet

## Phase 4C — Rich Species Details (NEW)
- [ ] Add `SpeciesDetails` struct per spec (see brief).
- [ ] Extend Core Data `SpeciesEntity` with `detailsJSON` text column.
- [x] Add `TrefleService` (temp token inline; will move to xcconfig) – map fields, derive water/temperature.
- [ ] Update `WikipediaService` (already done).
- [ ] Update `GPT4oService` with `funFacts` and `complete(details:)` endpoints / prompts.
- [ ] `SpeciesRepository` aggregation pipeline (parallel fetch, GPT fallback, 7-day TTL).
- [ ] Background pre-load of 20 common ornamentals on first launch.

## Phase 5 — UI, Animations & Haptics
- [x] Card stack container (`ZStack` + `DragGesture`)
- [x] Top photo card UI (PhotoCardView with accent border)
- [x] Bottom info card UI (expand/collapse via drag)
- [x] Segmented control inside info card ("Quick Facts" vs "Care" vs "More")
- [ ] Bottom info card UI (expand/collapse)
  - [ ] Theming (pastel palette, accent per species category)
  - [x] Integrate Lottie animation upon identification
  - [ ] Haptic feedback patterns (`UINotificationFeedbackGenerator` & Core Haptics)
  - [ ] VoiceOver labels & Dynamic Type support

## Phase 5B — UI/UX Polish (High-Priority Hotfixes)
- [ ] Replace custom CardStack with system `.sheet` using fractional detents (fix immovable sheet, responsive).
- [x] Convert `InfoCardView` to full `ScrollView` to avoid text clipping.
- [x] Move capture actions to `ToolbarItemGroup(.bottomBar)` with icon-only buttons.
- [x] Add mini header in InfoCard (latin + common name, confidence bar, share button).
- [x] Remove static offsets; switched to system sheet; custom offsets deleted.
- [x] Accent theming via `Color.accent(for:)` verified across light/dark.
- [x] Lottie "identified" animation + haptic success
- [x] Fixed collapsed `TabView` height so Quick/Care/More tabs render

## Phase 5C — New Info UI Tabs
- [ ] Replace segmented control with `TabView` + SF Symbols (doc.text / leaf / chart.bar).
- [ ] `OverviewTab` – summary + funFacts bullet list (+ Safari link).
- [ ] `CareTab` – sunlight, water, soil, temperature rows (hide empty).
- [ ] `GrowthTab` – growthHabit, bloomTime rows.
- [ ] `InfoRow` reusable component.
- [ ] Theming verified; dynamic type & accessibility labels for rows.

## Phase 6 — QA, Perf & Release
- [ ] Instruments pass (Time Profiler, Allocations)
- [ ] Energy diagnostics on device
- [ ] Snapshot & UI tests (XCTest)
- [ ] GitHub Actions / Xcode Cloud CI
- [ ] Crashlytics symbol upload automation
- [ ] TestFlight beta submission checklist

## Phase 0 — Security Cleanup (ASAP)
- [ ] Remove `Secrets.swift` from repo, add to `.gitignore`.
- [ ] Introduce `Secrets.xcconfig` and update build settings.
- [ ] Update code to read keys via `Bundle.main.infoDictionary` or `ProcessInfo`.
- [x] Migrated Trefle API key out of source; added placeholder in `Secrets.swift`.

---
> *Last updated: 2025-05-15* 