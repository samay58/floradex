# 🎮 FLORADEX 🌱

> A wild PLANT appeared! Would you like to catch it?

Floradex transforms plant identification into a retro gaming experience. Snap photos of plants, watch them transform into adorable GameBoy-style pixel sprites, and collect them in your very own botanical Pokédex!

![Floradex Banner](assets/floradex_banner.png)

## ⚡ QUICK START

```bash
git clone https://github.com/yourname/floradex.git
open Floradex.xcodeproj
# Add your API keys to Secrets.xcconfig
```

## 🕹️ FEATURES

### 📸 SNAP & IDENTIFY
Capture plants with your camera or photo library. Our machine learning pipeline combines:
- On-device Core ML processing
- PlantNet API recognition 
- GPT-4o Vision analysis

### 🧩 PIXEL-PERFECT SPRITES
Every identified plant gets its own custom-generated 8-bit sprite, rendered in authentic GameBoy style!

### 📚 PLANT ENCYCLOPEDIA 
Access care tips and fun facts for each plant in your collection.

### 🎭 RETRO UI/UX
- GameBoy-inspired design
- Satisfying haptic feedback
- Dark/light mode support
- Card collection grid with ID numbering

### 🧰 COLLECTION MANAGEMENT
- Swipe to delete entries
- Context menu support
- Auto-renumbering to maintain order

## 📱 SCREENSHOTS

<div align="center">
  <img src="screenshots/grid_light.png" width="30%" alt="Grid Light Mode">
  <img src="screenshots/grid_dark.png" width="30%" alt="Grid Dark Mode">
  <img src="screenshots/details.png" width="30%" alt="Plant Details">
</div>

## 🛠️ TECH SPECS

- SwiftUI + iOS 17+
- SwiftData (Core Data + CloudKit)
- OpenAI GPT-4o Vision
- Core ML on-device processing
- Combine reactive programming
- Custom retro-inspired UI components
- "Press Start 2P" and "M PLUS 1 Code" fonts

## 💾 WHY "FLORADEX"?

Remember the thrill of filling your Pokédex? Floradex brings that same joy to botany!

Each plant you identify becomes a new entry in your growing collection. The retro pixel art transforms ordinary houseplants and garden flowers into charming digital collectibles.

## 🔐 PRIVACY

- Plant photos stay on your device unless remote ID is needed
- No analytics tracking
- No ads, ever
- API keys stored securely in Secrets.xcconfig (not committed)

## 🌟 CONTRIBUTING

Pull requests welcome! Sprite generation improvements, UI enhancements, and feature ideas are all appreciated.

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