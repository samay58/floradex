# PlantLife – High-Level Project Plan

## 1. Objective
Build an iOS 17+ SwiftUI application that identifies plant species from user photos, then surfaces concise care information in a playful, haptic-rich card interface while respecting user privacy and ensuring low-latency interactions.

## 2. Success Criteria
- ✅ Accurate on-device identification (>80% Top-1 accuracy on common houseplants).
- ✅ ≤2 s median latency from photo selection to first result.
- ✅ Offline-first UX; remote calls only when local confidence < threshold.
- ✅ ≥90% crash-free sessions (Firebase Crashlytics).
- ✅ Passed App Store review & public TestFlight release.

## 3. Tech Stack & Key Frameworks
- Swift 5.10, Xcode 15, iOS 17 SDK
- SwiftUI + Combine
- Core ML (MobileNet-derived model)
- AVFoundation / PhotosUI (image intake)
- Core Data ✕ CloudKit (caching)
- Firebase Crashlytics
- Lottie (animations)
- UINotificationFeedbackGenerator & Core Haptics
- External APIs: PlantNet, GPT-4o Vision, Wikipedia REST, USDA PLANTS JSON

## 4. Architectural Overview
```
+────────────────────────────+      +──────────────────────────+
|        SwiftUI UI         |◀────▶|   ViewModels  (Combine)  |
+────────────┬──────────────+      +────────────┬─────────────+
             │                                      │
             ▼                                      ▼
+────────────────────────────+      +──────────────────────────+
|     EnsembleService        |◀────▶|   ClassifierService      |
+────────────┬──────────────+      +────────────┬─────────────+
             │                                      │
             ▼                                      ▼
+────────────────────────────+      +──────────────────────────+
|  FactsAggregatorService    |◀────▶|  Network / Persistence   |
+────────────────────────────+      +──────────────────────────+
```
Key flows:
1. Image → Combine pipeline → ClassifierService.
2. Multiple classifiers run in parallel. EnsembleService decides.
3. FactsAggregator fetches Wikipedia/USDA data, caches via Core Data.
4. UI subscribes to publishers, renders card stack, triggers haptics.

## 5. Phased Roadmap (Milestones)
1. Project Setup & CI skeleton
2. Image Intake (Photo + Camera)
3. Local Classification & Confidence gating
4. Remote Classification (PlantNet, GPT-4o)
5. Data Aggregation & Persistence
6. Card UI, Animations & Haptics
7. Accessibility & Localization pass
8. QA, Performance, Crashlytics
9. TestFlight Beta & App Store submission

## 6. Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Low ML accuracy | Fine-tune model on Flora Incognita dataset; fallback to remote APIs |
| API rate limits | Cache results; add exponential back-off; allow user retries |
| Latency spikes | Parallelize requests; show loading animation & haptics |
| Core Data sync conflicts | Use conflict-free merge policy; test extensively |
| GPT-4o cost over-run | Gate behind confidence threshold; limit resolution |

## 7. Glossary
- **EnsembleService** – Combines outputs from multiple classifiers.
- **SpeciesInfo** – Struct holding normalized plant facts.
- **Card Stack UI** – Two-layer draggable interface inspired by ChatGPT message bubbles.

*Last updated: 2025-05-14* 