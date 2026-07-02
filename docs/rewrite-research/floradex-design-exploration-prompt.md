# Floradex design exploration and implementation

You are starting a dedicated design session on Floradex, an iOS 26 SwiftUI app that identifies plants from photos and collects them as numbered pixel-art dex entries. The engineering is in good shape: the architecture is clean, 101 Kit tests and 7 app tests are green, and the app runs end to end on device. The problem is that it looks like nobody decided anything. Your job is to give it a point of view, then build that point of view, without breaking what works.

## Read these first, in order

1. `CLAUDE.md`: architecture, commands, verification rules, warning budget.
2. `docs/rewrite-research/floradex-rewrite-spec.md`: the section "Visual and motion direction" is your inherited design brief; "UX flows and screens" lists every surface. The "Trust, privacy, and correction model" section contains product invariants you must not soften.
3. `docs/rewrite-research/WHERE-WE-LEFT-OFF.md`: current state and the known cosmetic items already on file.
4. The live surfaces: `plantlife/Features/Capture/CaptureHomeView.swift`, `plantlife/Features/Reveal/RevealCard.swift`, `plantlife/Features/Dex/DexGridView.swift`, `plantlife/Features/Entry/EntryDetailView.swift`, `plantlife/PlantLifeApp.swift`, and `plantlife/UI/Theme.swift` (a legacy remnant that this session should replace or earn).

## The problem, stated plainly

Every screen is system-default: system font, standard materials, one green accent, default paddings. The only personality carriers are the pixel sprites, and they render at 56 points. The spec called for "retro as accent, not costume" and "a single display face for dex numbers and headers that nods to field-guide typography". None of that was ever built. The result is functional and flat. The user's words: "it feels incredibly flat, it lacks opinionated design, it just feels boring."

## Reference points, and what to take from each

- **AVEC**: crafted single-purpose objects; every interaction feels machined; haptics and motion are choreographed, not sprinkled. Take: the reveal sequence as a designed set piece, not a state change.
- **Pool** (the screenshot app): personality in the chrome itself; playful without being childish; empty states and microcopy carry voice. Take: the dex grid and empty states as places where the app gets to be charming.
- **Vercel v0**: typographic confidence; one strong display decision doing most of the identity work; extreme restraint everywhere else. Take: the type system, especially the dex-number treatment.
- **The app's own fiction**: this is a field guide crossed with a creature collector. Specimen labels, botanical plates, expedition notebooks, and 8-bit collection games are all legitimate wells. The pixel sprites are already the retro anchor; the chrome should converse with them, not ignore them.

## Hard constraints (violating these is failure, not style)

- Light mode first, warm off-white over stark white. Dark mode must also work (semantic colors only) but is not the design driver.
- The accent stays in one band per surface. No colored text on colored backgrounds, no accent-flooded screens.
- One continuous surface per screen: no stacked, overlapping boxes with colliding corner radii.
- Sprites render with `interpolation(.none)` at fixed pixel multiples. Never scale them fractionally.
- System Dynamic Type for body text. A custom display face is welcome for numbers and headers only, and it must be a deliberate, licensed choice: audit the asset catalog and `Theme.swift` for bundled-but-unused fonts first; either a font earns the dex-number slot or it gets deleted this session.
- Motion doctrine: one signature spring for card entrances; staged sequences via `PhaseAnimator`/`KeyframeAnimator`, never `DispatchQueue.asyncAfter` chains; every animation uses the explicit `value:` form. Respect Reduce Motion.
- Trust states are sacred: confidence bands, the sources-agree line, alternatives-first when unsure, and honest failure copy survive any redesign visually intact in meaning. Never fake certainty for aesthetics.
- The reveal card never scrolls. The full entry screen is where depth lives.
- Kit code (`FloradexKit/`) does not change for design reasons. This is a `plantlife/` session.
- Warning budget: the build currently carries 15 warnings, all missing app-icon assets. Your work merges with zero new warnings; if you ship an icon as part of the identity work, the budget drops to zero or near it.
- All tests stay green: `cd FloradexKit && swift test` (101) and the app suite on simulator (7). The fixture loop (`FLORADEX_FIXTURES=1`, `FLORADEX_AUTORUN=1`, `FLORADEX_TAB=dex`) must still run to committed end-to-end.

## Process: explore, decide, systemize, build

**Phase A, exploration.** Produce three genuinely distinct directions, not three intensities of one idea. For each: a name, a one-paragraph stance, the type/color/texture decisions, what the reveal sequence feels like, and one risk. Ground at least one direction in the field-guide/botanical well and one in the collection-game well. Then build the same one screen (the reveal card in its provisional state, with fixture data) three times behind a DEBUG picker so they can be compared on device or simulator, not imagined. Present the three with screenshots via AskUserQuestion and let Samay pick. Do not proceed on your own pick.

**Phase B, systemize the winner.** A design-token layer replacing `Theme.swift`: type scale (including the display face decision), color system (semantic, light and dark), spacing, radii (decide the radius language deliberately; 24pt continuous is the current card default and is platform-idiomatic for iOS 26 material cards), motion tokens (the signature spring, stage timings), haptic map review (`HeroHaptics` exists; extend rather than replace). Write the token file with the same care as Kit code.

**Phase C, implementation: one surface per wave, verified per wave.** Suggested order: reveal card (the hero moment), capture home (viewfinder chrome, shutter, empty/denied states), dex grid (collection pride: number treatment, tile design, empty state), entry detail (the field-guide page), root TabView tint and app icon. After each wave: build green, tests green, fixture-loop screenshots taken and compared against the previous state, commit with the repo's commit style (lowercase subject, body explaining what and why, `Co-Authored-By: Claude`).

**Phase D, the audit.** Re-run the full fixture loop, capture every state screenshot (identifying, provisional, correcting, committed, failed, offline, credential-missing, empty dex, populated dex, entry detail), and do a slop pass against the constraints above: accent bleed, colliding radii, fractional sprite scaling, dead animations, copy that got cute at the expense of honesty. Fix what the audit finds before declaring done.

## Signature moments worth disproportionate effort

1. **The reveal**: freeze-frame, then name, then confidence, then care lines, each landing as a beat. This is the app's whole reason to exist; it should feel like turning over a trading card.
2. **The commit stamp**: the moment a permanent number is assigned. Numbers are never reused; the design should make a number feel earned (think: stamped specimen label, minted badge).
3. **The dex grid**: a collection you're proud to scroll. Gaps from deleted entries are honest; consider showing tombstones as designed absences rather than hiding them.
4. **Empty states**: the first-run dex, the denied camera, offline. Each is a designed scene with voice, not a system placeholder.
5. **The app icon**: currently missing entirely (it is the whole warning budget). It should come out of the chosen direction, not be an afterthought.

## Environment notes

- The iOS simulator runtime may have been deleted for disk space. Check `xcrun simctl runtime list`; if empty, re-download via Xcode Settings > Components before screenshot work, or use SwiftUI previews plus the physical device early on.
- Xcode 27 beta is the only installed toolchain; `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` if `xcode-select` misbehaves.
- Fixture mode requires no API keys and produces deterministic runs; use it for all screenshot comparisons.
- Update `WHERE-WE-LEFT-OFF.md` and the spec's phase 8 status when you finish; run `python3 ~/.claude/scripts/slopcheck.py` on any doc you touch.
- If design skills are available in your session (`impeccable`, `swiftui-pro`, `make-interfaces-feel-better`, `12-principles-of-animation`), invoke them at the phase they fit: exploration and critique in Phase A, motion review in Phase C, the audit in Phase D.

## Non-goals

No rebrand of the product concept, no new features, no information-architecture changes, no dark-mode-first inversion, no Kit changes, no touching the provider pipeline. The offline queue, correction search, and proxy remain phase 8 engineering work and are out of scope here. Make what exists feel inevitable instead of default.
