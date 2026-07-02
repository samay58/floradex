# Warning baseline (rewrite phase 3)

Snapshot taken 2026-07-02 immediately after the phase 3 project wiring: FloradexKit linked, lottie-ios removed, deployment target 26.0, and `SWIFT_STRICT_CONCURRENCY = complete` on the app target with `SWIFT_VERSION = 5.0`.

Command: `xcodebuild -project plantlife.xcodeproj -scheme floradex -destination 'platform=iOS Simulator,name=Floradex-Sim' build`

**Total: 140 warnings.** This number must only shrink. New code merges with zero warnings; the legacy carriers below are scheduled for deletion in phases 4 and 5, which is how most of this count disappears.

Checkpoints since the snapshot (same command): 102 after the phase 4/5 waves; 78 after the de-sloppify pass (InfoCardView and SkeletonView deleted with eleven other dead files, repositories rewritten). Remaining carriers are AnimationConstants (dies with LiquidTabBar in phase 5), the asset catalog, and the SwiftData keypath-Sendability class on the v1 models (dies with the v2 schema).

Top carriers by file:

| Count | File |
|---|---|
| 19 | Shared/AnimationConstants.swift |
| 14 | Assets.xcassets (unassigned children) |
| 8 | Views/InfoCardView.swift |
| 7 | DataHandling/DexRepository.swift |
| 5 | Views/CameraCaptureView.swift (includes a real actor-isolation warning on `photoOutput`) |
| 5 | UI/Components/SkeletonView.swift |
| 5 | UI/Components/DexGrid.swift |
| 3 | Managers/SoundManager.swift |
| 2 each | PlantDetailsView, PhotoPickerView, ClassificationViewModel, SearchFilterView, AppSettings, PlantNetService, ClassifierService |

Notable classes of warning, all of which become errors under Swift 6, which is why the SWIFT_VERSION flip waits until phase 6 after these carriers die:

- `@Model` classes declaring `Sendable` with mutable persisted properties (`DexEntry`, `SpeciesDetails`): the false conformances come off with the v2 schema in phase 5
- Non-`Sendable` `KeyPath` captures inside `#Predicate` macro expansions in `DexRepository`, `SpeciesRepository`, `PlantDetailsView`, and `DexCard`
- Main-actor-isolated `photoOutput` delegate conformance in `CameraCaptureView`, replaced wholesale by the phase 4 `CameraSession` actor
- Deprecated API use (`NavigationView`, single-parameter `onChange`) in legacy screens scheduled for phase 5 deletion
