# PlantLife — Implementation Checklist

> Use this file as a living document. Check boxes as tasks finish and feel free to break large items into finer-grained todos.

---

## Floradex Evolution — Implementation Plan (Current / High Priority)

**Goal:** Transform PlantLife into Floradex with a retro collection/tracking UI while maintaining core plant identification functionality.

### Phase 1: Foundation (Week 1)

- [x] **Branch & Project Setup**
  - [x] Create `feat/floradex-foundation` branch from main
  - [x] Rename scheme from "PlantLife" to "Floradex" (preserve bundle ID)
  - [x] Update app icons and launch screen with Floradex-style assets
  - [x] Create `Theme.swift` containing color tokens, corner radius, and animation presets

- [x] **Font Integration** 
  - [x] Add "Press Start 2P" Google Font for headlines/numbers (SIL OFL license)
    - [x] Download .ttf file and add to Xcode project
    - [x] Add entry to Info.plist under "Fonts provided by application"
  - [ ] Add "M PLUS 1 Code" Google Font for Japanese katakana overlay effects (optional)
  - [x] Create Font extension with static accessors for app typography

- [x] **Persistence Layer: DexEntry Model**
  - [x] Create `Models/DexEntry.swift` with the following structure:
    ```swift
    @Model
    final class DexEntry {
        @Attribute(.unique) var id: Int              // running "Floradex number"
        var createdAt: Date = .now                   // for sort options
        var latinName: String                        // FK into SpeciesDetails
        var snapshot: Data?                          // original jpeg (≤1 MB)
        var sprite: Data?                            // 64×64 png – generated
        var tags: [String] = []                      // user editable
        var notes: String?                           // optional user memo
        var spriteGenerationFailed: Bool = false     // prevent retry loops
    }
    ```
  - [x] Implement SwiftData migrations for existing app data
  - [x] Create unit tests for DexEntry model
  - [x] Ensure `DexEntry` is added to `ModelContainer` schema

- [x] **DexRepository Implementation**
  - [x] Create `DataHandling/DexRepository.swift` with core CRUD operations
    ```swift
    actor DexRepository {
        func addEntry(latin: String, snapshot: UIImage, tags: [String]) async throws -> DexEntry
        func all(sort: DexSort = .numberAsc) -> [DexEntry]
        func update(_ entry: DexEntry, tags: [String], notes: String?)
        func delete(_ entry: DexEntry)
        enum DexSort { case numberAsc, newest, alpha, tag(String) }
    }
    ```
  - [x] Implement ID auto-increment logic (fetch max(id) + 1)
  - [x] Add test cases for sorting and filtering options

### Phase 2: Sprite Generation Service (Week 1-2)

- [x] **SpriteService Implementation**
  - [x] Create `Networking/SpriteService.swift` with OpenAI Image API integration:
    ```swift
    enum SpriteEndpoint: APIEndpoint {
        case generate(prompt: String, apiKey: String)
        
        var baseURL: URL { URL(string: "https://api.openai.com")! }
        var path: String { "/v1/images/generations" }
        var method: HTTPMethod { .post }
        var headers: [String: String]? {
            switch self {
            case .generate(_, let key): return ["Authorization": "Bearer \(key)"]
            }
        }
        var parameters: [String: Any]? {
            switch self {
            case .generate(let prompt, _):
                return ["model": "gpt-image-1",
                        "prompt": prompt,
                        "n": 1,
                        "size": "256x256",
                        "style": "pixel-art"]
            }
        }
    }
    ```
  - [x] Implement `spriteURL(for latin: String)` function to generate prompts (achieved via `generateSprite` returning `Data`)
  - [x] Add image downloading with URLSession.shared.data(from:)
  - [x_] Implement image downsizing to 64x64px for sprites (API provides 256x256, then resized)
  - [x] Wire into ClassificationViewModel after successful identification
  - [x] Add retry logic and error handling (basic error handling in place; `APIClient` may have retries)
  - [ ] Create usage tracking system to implement rate limiting *(Pending)*
  - [ ] Implement SHA-1 based caching for `latinName+style` to avoid duplicate API calls for *new* entries of same species *(Pending, if desired)*

### Phase 3: Core UI Components (Week 2-3)

- [x] **Design System**
  - [ ] Create `DesignTokens.xcassets` with color sets: *(User task: Manual asset creation)*
    - DexBackground: #E7E4D8 (beige)
    - DexCardSurface
    - DexCardSurfaceDark
    - DexShadow
    - Type-based accent colors
  - [x] Implement `Theme.swift` with global styling constants *(Initial Floradex elements added)*
  - [x] Create `PreviewHelper.swift` with sample data for SwiftUI Previews (`plantlife/Shared/PreviewHelper.swift` created)

- [x] **DexCard Component**
  - [x] Create `UI/Components/DexCard.swift` component
  - [x] Implement snapshot + overlay with latinName, ID, and stats *(Basic structure with placeholders)*
  - [x] Add sprite watermark with Japanese text effect *(Japanese text overlay and sprite display implemented)*
  - [ ] Create hover effects and interaction states *(Pending)*
  - [x] Implement accessibility labels for VoiceOver *(Basic accessibility from standard components; needs review)*

- [x] **DexGrid Component**
  - [x] Create `UI/Components/DexGrid.swift` with masonry/2-column layout *(LazyVGrid 2-column implemented)*
  - [x] Implement MatchedGeometryEffect for smooth transitions *(Basic hero transition implemented)*
  - [x] Add pull-to-refresh and empty state handling
  - [ ] Implement filtering capability based on tags *(Pending, part of Tag Filter System in Phase 4)*

### Phase 4: Screen Implementations (Week 3-4)

- [x] **Tag Filter System**
  - [x] Create `UI/Components/TagChip.swift` for tag visualization
  - [x] Implement horizontal tag scroller at top of grid (`UI/Components/TagFilterView.swift` created)
  - [x] Create tag selection/filtering logic *(Initial logic in `FloradexHomeScreen.swift`)*
  - [ ] Add tag management UI (add/remove) *(Pending)*
  - [x] Integrate TagFilterView and DexGrid into `Views/FloradexHomeScreen.swift`

- [ ] **Details Screen Redesign (`DexDetailView.swift`)**
  - [x] Create `DexDetailView.swift` as a replacement for `InfoCardView`, using `TabView` for sections. *(Initial structure with Overview, Care, Growth tabs implemented)*
  - [x] Fetch `SpeciesDetails` dynamically based on `DexEntry.latinName`. *(Implemented via @Query in init)*
  - [x] Tab navigation uses "Overview", "Care", "Growth" sections. *(Note: Plan mentioned "About/Care/Evolutions"; "Evolutions" is a future consideration if desired)*
  - [x] Flesh out tab content for `OverviewTabView`, `CareTabView`, `GrowthTabView`. *(Content for summary, facts, notes, care info, growth info, and learn more link added; placeholder data for gauge implemented).* 
  - [ ] ~~Replace segment bar with SegmentedControl pills (white text, alpha background)~~ *(Superseded by TabView with Label icons/text)*
  - [ ] Implement stats display (e.g., using `Gauge`): *(Started - Placeholder Gauge for 'Care Difficulty' added with mock data derivation)*
    - [ ] Define and map actual `SpeciesDetails` data (e.g. care level, growth rate) to numerical/categorical values for gauges. *(Pending definition of new SpeciesDetails fields or complex heuristics)*
    - [ ] Implement utility to extract dominant color from sprite for tinting gauges. *(Pending)*
  - [ ] Adapt existing species data visualization to new design *(Ongoing - InfoRow used, tab content generally adapted, further refinements may be needed)*
  - [ ] Ensure dark/light mode adaptivity *(Pending review and specific adjustments)*

- [ ] **Main Capture Flow Integration**
  - [ ] Modify current capture flow to create DexEntry after identification
  - [ ] Trigger sprite generation after species identification
  - [ ] Update navigation flow to show collection after capture
  - [ ] Add success animation and haptic feedback

### Phase 5: Polish & Optimization (Week 4)

- [ ] **Performance Optimization**
  - [ ] Profile and optimize image processing pipeline
  - [ ] Implement progressive loading for sprite generation
  - [ ] Add caching for frequently accessed data
  - [ ] Optimize list rendering with lazy loading

- [ ] **Camera Bug Fixes**
  - [ ] Fix black-screen capture bug:
    - [ ] Add `preview.frame = view.bounds` in `viewDidLayoutSubviews`
    - [ ] Check authorization status before starting session
    - [ ] Set `output.isHighResolutionCaptureEnabled = true` after adding output
  - [ ] Eliminate light-mode grey halo:
    - [ ] Use `.custom` button type instead of `.system`
    - [ ] Set explicit background colors or use `.buttonStyle(.plain)`

- [ ] **Usage Analytics & Limits**
  - [ ] Track sprite generation usage in UserDefaults
  - [ ] Implement weekly limits with subscription prompts
  - [ ] Add analytics events for key user actions
  - [ ] Create telemetry for performance monitoring

- [ ] **Final Testing & Documentation**
  - [ ] Create UI tests for core user flows
  - [ ] Document architecture and implementation details
  - [ ] Create sample data for demo purposes
  - [ ] Prepare release notes and marketing materials

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