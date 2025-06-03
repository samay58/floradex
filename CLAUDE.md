# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
```bash
# Build the project
xcodebuild -scheme floradex build

# Run unit tests
xcodebuild -scheme floradex test -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild -scheme floradex test -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:plantlifeUITests
```

### Project Setup
- Open `plantlife.xcodeproj` in Xcode
- Add API keys to `Secrets.xcconfig` (not committed to repo)
- Uses Swift Testing framework (not XCTest)
- Minimum iOS 17+ target

## Architecture Overview

**Floradex** is a SwiftUI iOS app that gamifies plant identification with a retro GameBoy aesthetic. Users photograph plants, which get identified through an ML pipeline and converted into collectible pixel sprites.

### Core Architecture Pattern
- **MVVM with SwiftUI/SwiftData**: Clean separation between business logic and UI
- **Repository Pattern**: `SpeciesRepository` (actor) and `DexRepository` (@MainActor) provide data access abstraction
- **Service Layer**: Modular API integration for plant identification services

### Key Data Flow
```
Image Capture → ClassificationViewModel → ML Pipeline → Repository Layer → SwiftData → UI Updates
```

### ML Classification Pipeline
The app uses ensemble classification combining multiple sources:
1. **Local ML** (Core ML/Vision) → 
2. **PlantNet API** → 
3. **GPT-4o Vision** → 
4. **Ensemble voting** → 
5. **Details fetch** → 
6. **Sprite generation** → 
7. **Dex entry creation**

### Data Models
- `DexEntry` (@Model): User's plant collection with sprites, photos, tags
- `SpeciesDetails` (@Model): Botanical information, care requirements, parsed gauge data
- Both use SwiftData for persistence with CloudKit sync

### Service Architecture
- `APIClient`: Base HTTP client for all network requests
- Multiple plant APIs: `PlantNetService`, `GPT4oService`, `PerenualService`, etc.
- `SpriteService`: Generates 64x64 GameBoy-style sprites
- `EnsembleService`: Combines results from multiple classifiers
- `ClassifierService`: Orchestrates local and remote classification

### UI Components
- Modular SwiftUI components with GameBoy-inspired design
- Custom gauges for plant care data: `SunlightGaugeView`, `ThermoRangeView`, `DropletLevelView`
- Reusable cards: `DexCard`, `CareCard`, `OverviewCard`, `GrowthCard`, `InfoCardView`
- Advanced UI components: `LiquidTabBar`, `AnimatedConfidenceMeter`, `MultiServiceProgressView`
- Filtering and search: `SearchFilterView`, `TagFilterView`, `TagChip`
- Loading states: `SkeletonView`, `EmptyStateView`
- Consistent theming via `Theme.swift` with retro typography and colors

### State Management
- `ClassificationViewModel`: Main business logic coordinator
- `@StateObject` for ViewModels, `@EnvironmentObject` for shared services
- SwiftData `@Query` for reactive database queries
- Managers: `ImageCacheManager`, `PermissionsManager`, `SoundManager`
- `AppSettings`: Global app configuration and preferences

### Key Patterns
- **Actor Model**: Thread-safe data operations in `SpeciesRepository`
- **Combine/Publishers**: Reactive UI updates via `@Published` properties
- **Feature Flags**: Conditional feature enablement via `FeatureFlag`
- **Live Activities**: Real-time identification progress updates via `PlantIdentificationActivity`
- **Extensions**: Utility extensions in `Extensions.swift` for common operations
- **Analytics**: User interaction tracking via `Analytics.swift`
- **Formatters**: Specialized data formatting via `FactsFormatter.swift` and `TagGenerator.swift`

## API Services Integration
- `PlantNetService`: Primary plant identification via PlantNet API
- `GPT4oService`: AI-powered plant analysis and description generation
- `PerenualService`: Plant care and growing information
- `USDAService`: Official botanical data and nomenclature
- `TrefleService`: Additional botanical database integration
- `WikipediaService`: Rich plant information and facts
- `SpriteService`: Custom 64x64 GameBoy-style sprite generation

## Testing Strategy
- Unit tests for core components: `DexRepositoryTests`, `DexEntryTests`
- UI component tests: `UIComponentsTests`, `CameraCaptureViewTests`
- View-specific tests: `DexDetailViewTests`
- Live Activity tests: `LiveActivityTests`
- Uses Swift Testing framework (import Testing, not XCTest)

## Performance Considerations
- Image resizing utilities in `UIImage+Resize.swift`
- Efficient caching via `ImageCacheManager`
- Lazy loading and skeleton states for better UX
- Optimized SwiftData queries with proper indexing

## Important Notes
- API keys must be configured in `Secrets.xcconfig` 
- Uses Swift Testing framework (import Testing, not XCTest)
- GameBoy aesthetic is central to the app's identity - maintain retro design patterns
- Sprite generation is a key differentiator - preserve 64x64 pixel art style
- Maintain thread safety using actors for data operations
- Follow MVVM architecture patterns consistently