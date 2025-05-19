# Floradex 2025 Roadmap – Detailed Implementation Plan

*(Generated 2025-05-19 – UI Uplevel Plan Revision: 2025-05-20)*

---

## Guiding Principles
1. Retro-GameBoy vibe + modern iOS 17 polish.  
2. Haptic-rich, glanceable, interruption-friendly.  
3. Ship features incrementally behind feature flags ➜ TestFlight dog-food ➜ Gradual rollout.

---

## Milestone 1 – "Alive ID"  🔍🪴  (Target: 2 weeks) ✔️
> Real-time identification status via Live Activities / Dynamic Island.

| Task | Owner | Notes | Status |
| --- | --- | --- | --- |
| LiveActivity model (`PlantIdentificationActivity`) | Dev | `ActivityAttributes` with `phase: searching|analyzing|done`, `spritePNGData` in `ContentState` | Done |
| Start activity in `ClassificationViewModel` | Dev | Fires when user submits photo | Done |
| Update phases from Combine pipeline | Dev | Map Combine publishers to Activity updates | Done |
| Compact / Minimal UI design | Design | Radar sweep → sprite → CTA | Pending Design |
| Dynamic Island region layouts | Dev | Leading: sprite, Trailing: confidence%, Bottom: "Tap to open" | Done (Initial) |
| Feature flag `features.liveActivity` | Dev | Toggle in `AppSettings` (defaulted to true) | Done |
| Unit tests & preview | QA | Xcode Live Activity preview + XCTActivityTests (initial sketch) | Done (Initial Sketch) |

Done ⇢ enable for TestFlight group "Beta-Live". (Flag now defaults true for dev)

---

## Milestone 2 – "Feels Good"  🎛️  (Target: 1 week) ✔️
> Contextual haptics & subtle SFX.

| Interaction | Haptic | Sound | Impl | Status |
| --- | --- | --- | --- | --- |
| DexCard settles | `.soft` impact | "tap-wood.aif" | `DexCardPager.handleDragEnd` | Done |
| Delete entry confirm | `.rigid` | "trash.caf" | `DexCard.contextMenu` | Done |
| Scroll stops centre | `.light` | — | `onChange(of: scrollOffset)` | Covered by DexCard settle |
| Success identification | notification(.success) | 8-bit jingle | `ClassificationViewModel.triggerHaptic` | Done |

Add `SoundManager` (AVFoundation) + user toggle in Settings. (Status: Done - Sound files TBD by user)

---

## Milestone 3 – "Smooth Moves"  🌀  (Target: 3 weeks) ✔️
> Shared-element & hero animations.

1. `DexCard` ↔ `DexDetail` sprite matchedGeometryEffect (`namespace: spriteID`). (Status: Done)
2. Sprite "spawn" Lottie when newly generated. (Status: Done - Requires Lottie package & .json asset by user)
3. Parallax in `DexGrid`: `GeometryReader` offset → `.offset(y:) * 0.15` and desaturate. (Status: Done)
4. Sticky section headers in InfoCardView using `.background(.ultraThinMaterial).offset(y:-scroll)`. (Status: Done - Implemented in `OverviewCard`)

Deliverables: Demo in TestFlight build 0.9.0.

---

## Milestone 4: "UI Foundation Refinement" 🛠️✨ (Target: 2 weeks) ✔️
> Clean up current UI components and layouts for a polished foundation.

**Part 1: Detailed Instructions to Clean Up and Refine Current UI**

| Task | Target Files / Areas | Status |
| --- | --- | --- |
| **1. Refactor Core UI Components** | `SunlightGaugeView`, `DropletLevelView`, `ThermoRangeView`, `PixelGaugeView` | Done |
| Remove "Mini-Card" Styling | Outer `.padding()`, `.background()`, `.cornerRadius()`, `.shadow()` | Done |
| Remove Redundant Internal Titles | Titles duplicated by parent cards (`CareCard`, `GrowthCard`) | Done |
| Adjust Internal Padding/Spacing | Ensure good internal layout, no excessive outer margins | Done |
| **2. Refine Layout in Detail Cards** | `CareCard.swift`, `GrowthCard.swift` | Done |
| Consistent Section Spacing | Use `Theme.Metrics.Padding` between sections | Done |
| Review Fixed Frame Heights | Evaluated (removed most, needs testing) | Done |
| Adjust Card Content Padding | Standardize horizontal padding for main content | Done |
| **3. Improve `PlantInfo.InfoRow`** | `PlantInfo.InfoRow.swift` | Done |
| More Flexible Layout (HStack or Grid) | Flexible HStack implemented | Done |
| Consistent Value Display | Handle `nil`/empty values (e.g., "N/A") | Done |
| **4. Standardize Section Titles** | `OverviewCard`, `CareCard`, `GrowthCard` | Done |
| Consistent Font & Style Hierarchy | Main titles (16pt), sub-section titles (14pt) | Done |
| Adequate Padding Around Titles | Added where appropriate | Done |
| **5. Review Overall Card Presentation** | `DexDetailView.swift` | Done |
| Header Spacing & Background | Seems adequate with `Material.thin` | Done |
| `DexCardPager` Spacing | Handled by individual card horizontal padding | Done |

---

## Milestone 5: "Interactive Gauge Enhancements" 💧🌡️☀️ (Target: 2 weeks)
> Make care information gauges more interactive and visually engaging.

| Task | Component / Target File | Details | Status |
| --- | --- | --- | --- |
| **1. `DropletLevelView` Enhancements** | `DropletLevelView.swift` |  |  |
| Particle Effect on Drag | Emit pixelated water droplets upwards | Pending |
| Subtle Wave Animation | Gently undulating water surface | Pending |
| **2. `ThermoRangeView` Enhancements** | `ThermoRangeView.swift` |  |  |
| Out-of-Range Visual Feedback | Pulse/color change for mercury, optional warning icon | Pending |
| Animated Mercury (if dynamic) | Smooth fill animation for real-time temp changes | Pending |
| **3. `SunlightGaugeView` Enhancements** | `SunlightGaugeView.swift` |  |  |
| Enhanced Tap Feedback | Icon-specific animations (rays expand, sun peeks, cloud jiggles) | Pending |

---

## Milestone 6: "Whimsical Content & Micro-interactions" ✨🍃 (Target: 2 weeks)
> Add delightful interactions and animations to card content.

| Task | Component / Target File | Details | Status |
| --- | --- | --- | --- |
| **1. `OverviewCard` Enhancements** | `OverviewCard.swift` |  |  |
| Interactive Fun Facts | Tappable to expand/collapse, optional related icon | Pending |
| Animated "My Notes" | Line-by-line or typewriter effect on scroll-in | Pending |
| **2. `DexDetailView` Header Sprite** | `DexDetailView.swift` (`detailHeaderView`) |  |  |
| Subtle Idle Animation | Gentle bobbing effect | Pending |
| Tap Animation & Sound | Particle burst/wiggle, unique sound (`.spriteTap`) | Pending |

---

## Milestone 7: "Advanced Visual Polish & Theming" 🎨🖼️ (Target: 2 weeks)
> Elevate the overall visual style with dynamic backgrounds and themed elements.

| Task | Component / Target File(s) | Details | Status |
| --- | --- | --- | --- |
| **1. Dynamic Themed Backgrounds** | `OverviewCard`, `CareCard`, `GrowthCard` | Pixel-art patterns (leaves, ripples, rays) based on card type, tinted with `accentColor` | Pending |
| **2. Elegant Loading & Empty States** | Various Views | Custom Lottie/pixel art for loading (growing plant, scanning glass) & empty (empty pot, sleeping seed) | Pending |
| **3. Sleek Section Headers** | `OverviewCard.swift` (`StickyHeaderView`) | Subtle border/darker shade for material, ensure legibility, smoother stuck transition | Pending |

---

## Milestone 8: "Enhanced Pager Interactivity" ↔️👆 (Target: 1 week)
> Refine the main card pager for a more tactile experience.

| Task | Component / Target File | Details | Status |
| --- | --- | --- | --- |
| **1. Additional Haptic Feedback** | `DexCardPager.swift` | Light impact on drag start, medium on threshold cross | Pending |
| **2. Sound Design (Optional)** | `DexCardPager.swift` | Subtle "swoosh" sound on drag, pans L/R, volume by speed (Complex) | Pending |
| **3. Enhanced Next/Previous Peek** | `DexCardPager.swift` | Stronger blur/desaturation for non-current cards | Pending |

---

## DevX & Infra
- Add `.soundEnabled` & `.hapticsLevel` to `AppSettings` (swift-data). (Partially done with UserDefaults)
- Extend `.cursorrules` with `[live-activity]`, `[haptics-level]`, `[ar-prototype]`. (Tracked separately)
- Introduce `FeatureFlag` enum to gate milestones. (Done for Live Activity)
- **Asset Requirement:** Lottie JSON files for animations (spawn, confetti, loading, sprite tap, etc.) and sound files (.aif, .caf, .mp3) need to be provided by user/designer and added to the project bundle.

---

## Risks & Mitigations
| Risk | Mitigation |
| --- | --- |
| Battery drain from Live Activity | Stop after 15 min or when result delivered |
| Haptics overwhelm | User setting + respect system Reduce Motion |
| Widget data staleness | Timeline provider reload on background fetch |
| AR performance | Prototype first, use simplified models |
| Performance with new animations/effects | Profile with Instruments, use `TimelineView`, optimize drawing | New |
| Complexity of some UI enhancements (e.g., particle effects, continuous sound) | Start simple, iterate, consider simpler alternatives if too time-consuming | New |

---

## Definition of Done
• Feature flag default OFF (for major new systems, UI enhancements might be always on once stable).
• 95% unit-test coverage on new modules/logic.
• No accessibility regressions (VoiceOver pass).
• Crash-free sessions ≥ 98% on TestFlight.

---

*Priorities may shift based on user feedback. Iterate!* 