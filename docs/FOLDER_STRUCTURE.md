# Folder Structure

- `plantlife/`: App source code (SwiftUI, models, services, views)
  - `Networking/`: API endpoints and clients (PlantNet, OpenAI, Perenual, Trefle)
  - `ImageProcessing/`: Local ML classification helpers
  - `Managers/`, `ViewModels/`, `Views/`, `UI/`: App layers and components
  - `Shared/`: Utilities, constants, simple helpers
- `plantlifeTests/`, `plantlifeUITests/`: Unit and UI tests
- `plantlife.xcodeproj/`: Xcode project
- `build/`: Local build outputs (ignored)
- `docs/`: User-facing docs
- `Secrets.xcconfig.example`: Template for API keys

Notes
- Keep `Secrets.xcconfig` and `plantlife/Shared/Secrets.swift` out of version control.
- No generated or local caches should be committed.
