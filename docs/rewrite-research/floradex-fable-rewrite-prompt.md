# Fable prompt: Floradex full rewrite spec and implementation plan

You are Fable working in the Floradex repo.

Repository:
- Worktree: `/Users/samaydhawan/floradex`
- Canonical GitHub repo: `samay58/floradex`
- Current app: SwiftUI/Xcode iOS project, currently named `plantlife` in code/project files

Your task is not to lightly patch Floradex. Your task is to spec and begin a first-principles rewrite that preserves the Floradex ethos and upgrades the project to modern iPhone-app quality.

Floradex ethos:
Floradex is a joyful Pokedex for the living world. It should make identifying plants feel like discovery, collecting, field notes, and tiny magic. It is not just a plant scanner or a generic AI camera app. It should feel like an iPhone-native field companion that turns a walk, a garden, or a random leaf into a small moment of curiosity.

Read in this order before editing code:

1. Inspect the current repo thoroughly.
   - `README.md`
   - `docs/FOLDER_STRUCTURE.md`
   - `plantlife.xcodeproj/project.pbxproj`
   - `plantlife/PlantLifeApp.swift`
   - `plantlife/ViewModels/ClassificationViewModel.swift`
   - `plantlife/Views/IdentifyLandingView.swift`
   - `plantlife/Views/FloradexHomeScreen.swift`
   - `plantlife/Views/PlantDetailsView.swift`
   - `plantlife/Views/FloradexCollectionView.swift`
   - `plantlife/Models/DexEntry.swift`
   - `plantlife/Models/SpeciesDetails.swift`
   - `plantlife/Networking/`
   - `plantlife/ImageProcessing/`
   - `plantlife/DataHandling/`
   - `plantlife/Shared/`
   - `plantlife/UI/`
   - `plantlifeTests/` and `plantlifeUITests/`

2. Read the saved iOS craft teardown notes:
   - `docs/rewrite-research/ios-craft-teardowns/second-teardown-avec-technical-stack.md`
   - `docs/rewrite-research/ios-craft-teardowns/first-teardown-avec-v0-ios-craft-systems.md`

Use the teardowns as craft input, not stack instructions. The lesson is not “use React Native.” The lesson is: choose the stack and architecture that make the heroic iPhone interaction feel physically excellent, then treat OS edge cases as product scope. Since Floradex is already a native SwiftUI/Xcode project, default to a native SwiftUI rewrite unless you have a strong reason not to.

3. Do targeted deep research as needed before writing the spec.

Do not make this a generic research dump. Use research to answer concrete first-principles architecture and craft questions raised by the repo and the teardowns. Prefer primary sources and current documentation when possible. Useful areas to check:

- current SwiftUI, SwiftData, Observation, Swift Concurrency, PhotosUI, AVFoundation, Vision, Core ML, MapKit, WidgetKit, App Intents, and Xcode testing guidance
- modern iOS camera/photo capture patterns and permission flows
- plant identification API options and whether secrets/provider calls should be proxied server-side
- local-first persistence and media storage best practices for photo-heavy apps
- snapshot testing, XCUITest, Maestro-style fixture flows, and visual regression options for iOS
- examples of excellent camera, collection, reveal, field-journal, or Pokedex-like mobile interaction patterns

Save only useful findings in `docs/rewrite-research/floradex-modern-ios-research.md`. Keep it short and decision-oriented:

- question researched
- best current answer
- source or evidence
- implication for Floradex
- whether it changes the rewrite spec

Research cap: do enough to make the architecture current and defensible, but do not spend the whole run researching. If a source does not change the product, architecture, privacy, or testing plan, leave it out.

Before code edits, produce a rewrite spec in `docs/rewrite-research/floradex-rewrite-spec.md` with these sections:

- Read this first: one-paragraph thesis
- Current-state read of the repo
- What Floradex should become
- What to preserve from the old app
- What to replace
- Brand and interaction principles
- Hero loop
- App architecture
- Data model
- AI/provider pipeline
- UX flows and screens
- Visual and motion direction
- Trust, privacy, and correction model
- Testing and fixture loop
- Implementation phases
- Open questions
- Non-goals

The hero loop should be physical, repeatable, and emotionally satisfying. A strong default is:

Open app -> capture or choose a plant photo -> get immediate tactile feedback -> watch a beautiful identification/reveal flow -> see confidence and alternatives -> save to Floradex -> receive a sprite/dex card/care summary/field note -> optionally correct or enrich later.

The rewrite should over-invest in this loop.

Technical direction to consider:

- SwiftUI app surface
- Swift Concurrency
- Observation framework where appropriate
- SwiftData or a cleaner local persistence layer
- PhotosUI and AVFoundation for camera/photo input
- Vision/Core ML for local-first classification where useful
- A provider abstraction for PlantNet, OpenAI/GPT vision, and future providers
- A tiny backend/proxy only if secrets or paid provider calls should not live in the client
- XCTest, snapshot tests, and Maestro or XCUITest flows for the heroic path and fixture corpus

Trust model requirements:

- Do not fake certainty. Plant identification is probabilistic.
- Show confidence, alternatives, provider disagreement, and “not sure” states cleanly.
- Support manual correction.
- Support retry with a better photo.
- Keep uploaded photo and location privacy clear.
- Treat wrong IDs and bad UI states as fixtures that become regression tests.

Quality loop requirements:

Borrow the Avec/Maestro lesson. Do not only fix bugs. Build a loop that turns real failures into reproducible tests. Include fixture coverage for:

- easy common plant photo
- ambiguous plant photo
- bad or blurred photo
- duplicate plant
- no plant in image
- provider timeout
- provider disagreement
- offline mode
- low confidence
- saved dex entry with missing details
- corrupted or missing sprite image
- long care text
- small-screen iPhone
- large dynamic type
- permission denied

Implementation rules:

- Create a branch before major edits.
- Do not destroy working project files without backing up or explaining why.
- Keep secrets out of git.
- Prefer native iOS quality over maximal feature scope.
- Run build/tests after each major phase when feasible.
- If the project does not currently build, document the failure exactly before changing code.
- Use concrete checkpoints. Do not do a giant unverified rewrite in one pass.

Recommended phase order:

1. Spec and architecture pass.
2. Stabilize project naming and folder structure if needed.
3. Define clean domain models and provider protocols.
4. Rebuild the hero capture/reveal/save loop.
5. Rebuild collection and detail surfaces.
6. Add trust/correction states.
7. Add fixture/test loop.
8. Polish visual/motion details only after the loop is real.

Final deliverable for this run:

- `docs/rewrite-research/floradex-rewrite-spec.md`
- A clear implementation plan with phases and checkpoints
- The first safe code phase, if the spec is complete and the worktree is clean enough
- A final report listing files changed, commands run, build/test result, and what remains
