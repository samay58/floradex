# 🎮 FLORADEX 🌱

> A wild PLANT appeared! Would you like to catch it?

Floradex transforms plant identification into a retro gaming experience. Snap photos of plants, watch them transform into adorable GameBoy-style pixel sprites, and collect them in your very own botanical Pokédex!

![Floradex Banner](assets/floradex_banner.png)

## ⚡ QUICK START

```bash
git clone https://github.com/yourname/plantlife.git
open plantlife.xcodeproj
# Add your API keys to Secrets.xcconfig
```

## 🕹️ FEATURES

### 📸 SNAP & IDENTIFY
Capture plants with your camera or photo library. Our machine learning pipeline combines:
- On-device Core ML processing
- PlantNet API recognition 
- GPT-4o Vision analysis

### 🧩 PIXEL-PERFECT SPRITES
Every identified plant gets its own custom-generated 64x64 pixel sprite, rendered in authentic GameBoy style!

### 📚 PLANT ENCYCLOPEDIA 
Access detailed care information, growth requirements, and fun facts for each plant in your collection with interactive gauges and visual indicators.

### 🎭 RETRO UI/UX
- GameBoy-inspired design with liquid tab bar
- Satisfying haptic feedback and sound effects
- Dark/light mode support
- Card collection grid with ID numbering
- Live Activities for real-time identification progress
- Custom animated confidence meters and progress indicators

### 🧰 COLLECTION MANAGEMENT
- Swipe to delete entries
- Context menu support
- Auto-renumbering to maintain order
- Advanced filtering and search capabilities
- Tag-based organization system
- CloudKit sync across devices

## 📱 SCREENSHOTS

<div align="center">
  <img src="screenshots/grid_light.png" width="30%" alt="Grid Light Mode">
  <img src="screenshots/grid_dark.png" width="30%" alt="Grid Dark Mode">
  <img src="screenshots/details.png" width="30%" alt="Plant Details">
</div>

## 🛠️ TECH SPECS

- SwiftUI + iOS 17+
- SwiftData with CloudKit integration
- Ensemble ML pipeline combining:
  - OpenAI GPT-4o Vision
  - PlantNet API
  - Core ML on-device processing
  - USDA Plants Database
  - Perenual API
  - Wikipedia integration
- Actor-based concurrency for thread safety
- MVVM architecture with repository pattern
- Custom retro-inspired UI components
- "Press Start 2P", "M PLUS 1 Code", and "JetBrains Mono" fonts
- Live Activities and Dynamic Island support
- Comprehensive unit and UI test coverage

## 💾 WHY "FLORADEX"?

Remember the thrill of filling your Pokédex? Floradex brings that same joy to botany!

Each plant you identify becomes a new entry in your growing collection. The retro pixel art transforms ordinary houseplants and garden flowers into charming digital collectibles.

## 🔐 PRIVACY & SECURITY

- Plant photos stay on your device unless remote ID is needed
- Optional analytics with user consent
- No ads, ever
- API keys stored securely in Secrets.xcconfig (not committed)
- Comprehensive permissions management
- Local image caching with automatic cleanup

## 🌟 CONTRIBUTING

Pull requests welcome! Sprite generation improvements, UI enhancements, and feature ideas are all appreciated.

## 🚀 DEVELOPMENT

### Building the Project
```bash
# Build for simulator
xcodebuild -scheme floradex build

# Run tests
xcodebuild -scheme floradex test -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Required Setup
1. Create `Secrets.xcconfig` with your API keys:
   ```
   OPENAI_API_KEY = your_openai_key
   PLANTNET_API_KEY = your_plantnet_key
   PERENUAL_API_KEY = your_perenual_key
   ```
2. Open `plantlife.xcodeproj` in Xcode
3. Select your development team
4. Build and run on iOS 17+ device or simulator

## 📜 LICENSE

MIT. Open source and free to use.

---

<div align="center">
  <pre>
  FLORADEX v1.0
  © 2023 
  PRESS START TO IDENTIFY
  </pre>
</div>