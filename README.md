# Floradex

## What it is
An iOS app that turns plant identification into a friendly, retro experience. Take a photo, get a species suggestion, and save a pixel-art “dex” entry with helpful care details.

## Quick start
```bash
git clone https://github.com/yourname/plantlife.git
open plantlife.xcodeproj
# Copy example config and fill keys
cp Secrets.xcconfig.example Secrets.xcconfig
```

In Xcode: select a team, choose a simulator or device, then Run.

Keys used: `OPENAI_API_KEY`, `PLANTNET_API_KEY` (optional: `TREFLE_API_KEY`, `PERENUAL_API_KEY`).

## Options and examples
- Local-only: run without keys to use on-device classification and offline UI.
- Remote ID: add keys to enable PlantNet and GPT-4o Vision.

Common commands:
```bash
# Build for simulator
xcodebuild -scheme plantlife -sdk iphonesimulator build

# Run tests (adjust destination as needed)
xcodebuild -scheme plantlife test -destination 'platform=iOS Simulator,name=iPhone 15'
```

## How it works
Multiple providers enrich results: on-device Core ML, PlantNet, and GPT-4o. A simple networking layer normalizes responses. The UI summarizes confidence, shows care info, and saves entries to a local store with optional iCloud sync.

## Sessions
No run sessions are stored in git. Build outputs and local artifacts are ignored.

## Notes
- Minimal local setup: Xcode 15+, iOS 17+.
- Secrets are never committed. Use `Secrets.xcconfig` or environment variables.
- No telemetry. Clear error messages and safe defaults.
