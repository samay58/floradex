# First teardown: Avec and v0 iOS craft systems

Source: Codex pasted attachment from the Floradex rewrite planning session.
Purpose: Use this as craft input for the Floradex rewrite. It compares Avec and v0 as iPhone product systems and extracts reusable mobile-app principles.

## Original pasted teardown

I’ll compare them as craft systems, anchoring on v0’s concrete engineering choices and Avec’s public product signals to extract reusable iPhone app principles without overclaiming private implementation details.

Thought for 3m 15s

Yes. The common pattern is very strong:

Both Avec and v0 seem to have treated the iPhone app as a new product surface, not as a shrunken web app. They picked one mobile-native workflow, made that workflow feel physically excellent, pushed business logic/server intelligence behind a thin client, and then obsessed over the OS-level details most teams underestimate.

v0 documents this explicitly. They say they did not set out to build a mobile IDE with feature parity to the website, but instead wanted a simple, delightful on-the-go AI creation experience centered around chat. They also say they built dozens of iterations, studied apps that “speak the iPhone’s language,” and eventually landed on React Native with Expo after experimentation.

Avec appears to have made the same strategic move for email: rather than building a Gmail clone, it rebuilt email around the phone’s native strengths: swiping, voice, smart notifications, one-card focus, and tiny bursts of progress. Its App Store positioning is literally “Reply by voice. Swipe to zero,” with AI prioritization, voice replies, swipe triage, one-tap unsubscribe, AI search, smart notifications, reminders, and multi-Gmail support.

The shared playbook
1. Do not port the desktop product. Reinterpret the job for the phone.

This is the biggest pattern.

v0 did not ask, “How do we fit our web IDE onto an iPhone?” It asked, “What is the right mobile job?” Their answer: capture an idea while away from your computer and turn it into something tangible without context switching. That led them to make chat the centerpiece, not code editor parity.

Avec seems to have done the equivalent for email. They did not ask, “How do we make Gmail’s inbox list nicer?” They asked, “What should email management feel like when the input devices are thumb, voice, notification, and a small screen?” That led to the stack: important emails one by one, swipe right to done/archive, swipe left to later, swipe down to unimportant, and hold-to-reply by voice.

Reusable principle:
A great iPhone app usually starts by throwing away desktop information architecture. The phone version should have a new primary interaction that is native to the body.

For v0, that primary interaction is:

type or paste into a floating composer, then watch AI output stream naturally in a mobile chat.

For Avec, it is:

swipe through one email at a time, then dictate replies when needed.

That is much deeper than “mobile responsive.”

2. Pick one heroic interaction, then make everything serve it.

v0’s heroic interaction is the chat composer plus streaming message list. Their requirements are telling: messages animate smoothly, new user messages scroll to the top, assistant messages fade in as they stream, the composer floats on top of content, existing chats open at the end, keyboard handling feels natural, paste supports images/files, text input supports gestures, and markdown stays fast.

Avec’s heroic interaction is the triage card stack. The stack is not just a visual gimmick. It defines the product grammar: done, later, unimportant, reply, unsubscribe, ask. TechCrunch reports the swipe mappings and notes that down-swiping unimportant emails teaches the app what to group later instead of forcing one-by-one triage.

Reusable principle:
Top-tier apps have a “hero path” that is overbuilt relative to everything else. The surrounding product can be simpler, but the hero path cannot be merely good.

For a downstream agent, I’d write this as:

Identify the one interaction that users will do 100+ times.
Make that interaction feel native, fast, forgiving, and emotionally satisfying.
Do not distribute polish evenly across the app.
Over-invest in the loop that creates habit.
3. Native feel is not a library choice. It is a thousand edge cases.

v0’s blog is basically a case study in this. They used React Native with Expo, but “native feel” came from custom engineering around measurement, scroll behavior, keyboard behavior, native menus, modal patches, and UI-thread animation. They say their keyboard hook was about 1,000 lines with many unit tests, and that there was no single trick, just dozens of hours noticing imperfections, tracing issues, and rewriting logic until it felt right.

Avec’s App Store changelog reveals the same attitude. They rebuilt the text rendering system for performance and multi-line selection, fixed Substack and GitHub digest rendering, added an “Email looks wrong” report path, improved Gmail signature rendering, improved inline images, long reply chains, Bcc labels, Reply-To handling, send-as aliases, voice recording reliability across built-in mic/AirPods/wired USB-C EarPods, audio pre-warming, lock-screen actions, and thumb-oriented menu ordering.

That is the most important shared craft pattern. Neither team stopped at the demo.

Reusable principle:
The difference between “cool prototype” and “iPhone-quality product” is usually hidden in boring OS and content edge cases.

For v0, boring edge cases are:

keyboard open/close
interactive keyboard dismissal
scroll position
dynamic content height
streaming text
pasted images
native menus
native sheets
modal flicker

For Avec, boring edge cases are:

HTML email rendering
inline images
signatures
reply chains
Bcc/Cc/Reply-To
send-as aliases
voice recording devices
notification actions
unstable networks
long content-heavy emails

The shared lesson: delight is what remains after edge cases stop breaking immersion.

4. Use React Native, but do not be religious about JavaScript.

v0 explicitly landed on React Native with Expo, but they leaned heavily on native-aware libraries and APIs: Reanimated, LegendList, React Native Keyboard Controller, native UIScrollView contentInset, native UIMenu via Zeego, native form sheets, local React Native patches, and upstream contributions.

Avec likely follows the same pattern. Product Hunt lists Expo among products used by Avec, and a search-indexed founder post says they started building Avec using React Native. Product Hunt also lists Claude as a coding and in-product model used by Avec. For rich text, React Native Enriched is highly relevant because it is a fully native rich-text input component with synchronous styling, HTML parsing, mobile support, and New Architecture support.

The pattern is not “React Native apps can feel native by default.” The pattern is:

Use React Native for iteration speed, then selectively drop to native primitives for the surfaces where users can feel the abstraction.

Those surfaces are almost always:

gesture handling
animation
keyboard
scrolling
text input
rich text
audio recording
haptics
menus
sheets
notifications
camera/photos/files

A mediocre team uses a cross-platform framework to avoid native complexity. A top-tier team uses it to move faster, then punches through the abstraction exactly where needed.

5. UI-thread work is sacred.

v0 is very explicit here. They use Reanimated shared values so animation state can update without triggering React re-renders, and they use useAnimatedProps to update contentInset on the UI thread each frame. They found that contentInset, a native UIScrollView property, performed far better than prior layout-based attempts.

Avec’s swipe stack almost certainly requires the same principle. A Tinder-like card cannot wait on React state updates or network responses. The active card needs to track the finger continuously, reveal the target action, cross thresholds, trigger haptics, animate away, and reveal the next card without jank. Publicly, TechCrunch confirms the stack interactions; the specific animation stack is inference, but the engineering requirement is straightforward.

Reusable principle:
For gesture-heavy or streaming-heavy apps, React state is for product state. UI-thread primitives are for physical interaction.

A good rule:

If it changes every frame, do not route it through normal React rendering.

For v0:

keyboard height
composer height
scroll inset
message fade-in
streaming layout

For Avec:

card translation
card rotation
threshold progress
next-card scale
haptic threshold crossing
swipe commit animation
6. The app should feel instant even when the backend is doing hard things.

v0’s app is doing inherently slow work: AI generation, code creation, streaming responses. The UX does not wait silently. The user message animates, the assistant response fades in, streaming text appears progressively, and scroll/composer behavior keeps the user oriented.

Avec is also doing slow work: Gmail sync, prioritization, summarization, AI search, voice transcription, draft generation, and notification classification. But the card stack must feel instantaneous. The user swipes, the card leaves, and the next card appears. The backend can reconcile later.

Reusable principle:
Great AI mobile apps separate perceived immediacy from actual computation.

The client should have a local optimistic loop:

user action
visual response now
local state update now
background mutation
server reconciliation
subtle recovery if needed

The AI/backend should work ahead:

pre-rank
pre-summarize
pre-fetch
pre-render
pre-warm
cache

Avec’s changelog even mentions audio session pre-warming while composing for quicker recording, which is exactly this philosophy applied to voice latency.

7. Make input feel luxurious.

For v0, input means the floating composer. It supports paste, images, files, keyboard-aware layout, pan gestures to focus/blur, Liquid Glass, and dynamic height behavior. Vercel says they used a native pasteboard-listening Expo module to support pasting images and files, and long text paste can become a .txt attachment.

For Avec, input means voice, rich text, reply composition, preference capture, and email-specific addressing. The App Store changelog mentions rich text editing, links, copying images into the body, AI polish, dragging recipient pills between To/Cc/Bcc, Gmail signature support, send-as aliases, and Reply-To behavior.

Reusable principle:
On iPhone, text entry is expensive. Elite apps compensate by making the composer magical.

The best apps do not treat input as a plain text box. They treat input as a mini operating system:

voice
paste
files
rich text
mentions or recipients
attachments
keyboard behavior
autofocus
draft persistence
undo
AI rewrite
native selection

This is why both v0 and Avec are so interesting: their input surfaces are not generic. v0 has an AI-building composer. Avec has an email-reply composer that understands thread context and voice.

8. Use AI as workflow acceleration, not as a separate chatbot.

v0’s AI is visible because the product is literally AI chat for building. But the blog makes clear that the iOS app is not trying to expose every feature from the web app. The mobile AI workflow is constrained around an on-the-go idea capture and generation loop.

Avec’s AI is more ambient. The App Store says AI surfaces important emails first, learns preferences, drafts voice replies, answers buried-thread questions, filters notifications, and resurfaces reminders. The user does not have to “chat with email” for the core experience to work. The AI is embedded in triage, search, notification, and drafting.

Reusable principle:
The best AI iPhone apps avoid making users manage the model. They use AI to reduce interaction cost inside a familiar job.

Bad pattern:

Open app
Open chatbot
Ask it to do the product's job
Copy result somewhere else

Good pattern:

Open app
Take the obvious native action
AI quietly completes the missing context
User reviews or corrects
Product learns
9. Shared API and server-side business logic beat shared UI.

This is one of the cleanest lessons from v0. They decided to share types and helper functions between web and native, but not UI or state management. They also moved business logic from client to server so the mobile app could be a thin wrapper over the API. They built a typed API layer using Zod, generated OpenAPI, consumed it with Hey API, and used TanStack Query on mobile.

Avec likely needs a similar architecture, even if not identical. The mobile app should not own Gmail sync, ranking, summarization, notification decisions, or preference learning. Those belong server-side. The iPhone app should own the tactile interaction: stack, voice capture, compose, thread view, notifications, local cache, optimistic UI.

Reusable principle:
For ambitious iPhone apps, share product truth through APIs, not through UI components.

A strong architecture looks like:

Server:
  sync
  ranking
  summarization
  search
  policy
  permissions
  durable mutations
  notification decisions

Client:
  native interaction
  local state
  optimistic UI
  animation
  input
  offline-ish continuity
  review and correction

This is especially important for agentic apps. The “brain” should be server-side and versioned. The phone should be fast, tactile, and recoverable.

10. Escape hatches increase trust.

v0 chose not to autoscroll blindly as assistant messages stream. Instead, it lets content fill naturally under the keyboard and provides a button to scroll to the end, following a behavior similar to ChatGPT’s iOS app.

Avec’s equivalent is keeping a plain list view alongside the card stack. TechCrunch explicitly notes that although the card interface is unique, Avec also offers a list-based view.

Reusable principle:
Opinionated defaults need non-magical fallbacks.

For AI products especially, users need to feel:

I can undo.
I can inspect.
I can use the old mode.
I can correct the system.
I can recover if the magic is wrong.

Without escape hatches, delightful becomes scary.

11. The “tiny physical details” are product strategy.

v0’s blog spends a huge amount of time on things many teams would consider implementation trivia: message blank size, scroll insets, keyboard transitions, composer height, native menus, modal flicker. But those details directly determine whether the app feels Apple-caliber.

Avec’s changelog has the same fingerprint. Long-press menus flip order when opening upward so the most-used action stays close to the thumb. The Stack/List switcher became a bigger pill. Hold-to-record tolerates small finger movement. Search handles senders with symbols like “B&H.” Background audio behavior can be changed in settings. These are not “nice-to-haves.” They are the product.

Reusable principle:
Great mobile UX is embodied. It cares about thumb distance, accidental movement, latency, haptics, sound, scroll physics, focus, and interruption.

A downstream agent should be told:

Do not only implement the feature.
Implement the physical experience of using the feature repeatedly while distracted, walking, one-handed, on spotty network, with headphones, with the keyboard half-open, and with an old thread full of weird content.

That sentence is basically the Avec/v0 shared philosophy.

Where they differ

The similarities are real, but the constraints differ.

Dimension	v0 iOS	Avec
Primary object	AI chat thread	Email triage card / thread
Main input	Keyboard composer, paste, files	Swipe, voice, rich text reply
Hardest OS surface	Keyboard, scroll, streaming layout	Gestures, audio, email rendering, notifications
AI visibility	Visible assistant output	Often invisible ranking, notification, search, drafting
Existing product context	Mature web product and API	Mobile-first Gmail client, likely backend sync-heavy
Escape hatch	Scroll/end controls, existing chat behavior	List view, undo, thread view
Trust failure mode	Chat feels janky or loses context	Email is misfiled, rendered wrong, or draft sounds wrong

The deeper shared pattern is: they each identified the one part of the iPhone that would make or break trust, then treated that part as infrastructure.

For v0, that was the keyboard/composer/scroll stack.

For Avec, that is the swipe/voice/rendering/notification stack.

A reusable “excellent iPhone app” spec from both

Here is the synthesis I would feed to an agent:

Build the iPhone app as a new product surface, not a port.

1. Define the mobile-native job.
   What can the user do on a phone that would be annoying or impossible on desktop?

2. Choose one heroic interaction.
   It should be physical, repeatable, and emotionally satisfying.

3. Make the heroic interaction run locally and immediately.
   No network, model call, or server mutation should block the first visual response.

4. Use React Native for speed, but use native primitives for feel.
   Gestures, animation, keyboard, scroll, audio, haptics, text input, menus, sheets, and notifications need native-grade treatment.

5. Move business logic to the server.
   Keep the client thin, tactile, optimistic, and cache-aware.

6. Precompute intelligence.
   Ranking, summaries, search indexes, suggested actions, and notifications should be ready before the user needs them.

7. Treat OS edge cases as core scope.
   Keyboard events, backgrounding, audio routes, pasteboard, notification actions, selection, signatures, and weird content all count as product quality.

8. Make input luxurious.
   Support voice, paste, files, rich text, attachments, correction, draft persistence, and AI rewrite where relevant.

9. Add escape hatches.
   Undo, inspect, fallback list, manual search, and explicit correction make magic trustworthy.

10. Instrument perceived quality.
   Track dropped frames, time-to-first-response, gesture cancellation, accidental actions, undo rate, input latency, audio-start latency, render failures, and correction rate.

11. Iterate against real content, not clean demos.
   Real emails, real chat threads, real pasted files, real headphones, real network instability, real long messages.
The punchline

The pattern is not “React Native plus AI.” That is too shallow.

The pattern is:

Mobile-native interaction model + server-side intelligence + native escape hatches + obsessive OS-edge-case polish.

v0 applied that to AI app generation.

Avec applied it to email.

That is why both feel like they belong on the iPhone rather than merely existing on it.

What did we learna bout closing the loop with Maestro from Avec's technical twitter post about the HTML rendering fix pipeline they built?

I’ll ground this in Avec’s actual post and extract the reusable lesson: how they turned fuzzy broken-email reports into a repeatable Maestro-driven visual regression loop.

Thought for 4m 3s

The key lesson is:

Avec did not try to “solve HTML email rendering” once. They built a machine that turns every ugly real-world email into a reproducible test case, then uses Maestro to verify the fix in the actual app surface.

That is the “closed loop.”

I can’t quote the X post verbatim because X is not exposing the thread text through the browser right now, but the pattern is corroborated by Avec’s App Store changelog: they added an in-app “Email looks wrong” report action, then shipped repeated rendering fixes for Gmail signatures, Substack, GitHub digests, inline images, markdown spacing, long reply chains, and their rebuilt text rendering system.

What “closing the loop with Maestro” means

The loop is roughly:

User sees bad email rendering
  -> taps "Email looks wrong"
  -> Avec captures the problematic email/render artifact
  -> team turns it into a fixture
  -> Maestro opens the app to that exact email
  -> Maestro takes screenshots / runs assertions
  -> engineer or agent fixes renderer
  -> Maestro re-runs on the fixture corpus
  -> fix ships
  -> that email class never regresses silently again

That is very different from the normal startup bug loop:

User says “this email looks broken”
  -> support screenshot
  -> engineer guesses
  -> fix one case manually
  -> ship
  -> another email breaks later

Avec’s version makes the bug reproducible, automatable, and promotable into regression coverage.

Why Maestro is the right primitive here

Maestro is useful because it tests the app as a user would use it. Its docs describe it as a black-box testing framework that simulates interactions at the device level through accessibility and device commands, rather than reaching into internal app code. It can reproduce physical user actions like taps, swipes, and text input, and it can run readable YAML “flows.”

That matters for HTML email rendering because the failure is not usually isolated to one pure function. The bug might involve:

raw MIME parsing
HTML sanitization
inline image rewriting
CSS normalization
native text renderer behavior
WebView behavior
viewport width
font metrics
dark mode
long-thread clipping
gesture/scroll behavior
safe areas

A unit test can tell you your parser emitted the expected intermediate representation. It cannot tell you the actual iPhone screen looks right.

Maestro can also capture screenshots and store them as test artifacts, which makes it useful for visual debugging and CI workflows. Its takeScreenshot command saves the current screen as a PNG, and its artifact system stores screenshots, logs, metadata, videos, command JSON, and AI reports.

Even more directly, Maestro has assertScreenshot, which compares the current screen to a known-good screenshot and fails if the visual output is too dissimilar. That gives the team a way to turn “this email looks wrong” into “this exact visual rendering must never drift past threshold again.”

The product-quality insight

The elegant part is that Avec put the feedback button inside the render surface.

The App Store changelog says that when an email renders poorly, the user can open the email, tap the toolbar menu, and choose “Email looks wrong.” That means the report is born with maximum context. The user does not need to explain CSS, MIME parts, dark mode, clipping, or inline images. The app already knows which message, which account, which renderer path, which version, which device, and probably which sanitized HTML snapshot was shown.

That is a huge “taste” lesson:

When the product has a gnarly correctness problem, let users report the problem from the exact place where correctness failed, then capture enough state to replay it automatically.

For an email app, the correct report affordance is not a generic “Send feedback” button in settings. It is “Email looks wrong” on the email itself.

The deeper engineering lesson

Avec appears to have transformed rendering bugs from support tickets into training data for the renderer.

Each reported broken email can become:

1. A sanitized fixture
2. A reproduction URL / deep link
3. A Maestro flow
4. A screenshot baseline
5. A regression test
6. A labeled example for future agentic repair

That is the real loop.

The phrase “closing the loop” matters because it connects five systems that are usually disconnected:

user pain
  -> bug capture
  -> deterministic reproduction
  -> implementation fix
  -> regression verification

Most teams stop at the first two. Top-tier teams connect all five.

Why this is especially important for agents

This is the part I think is most useful for your downstream primer.

An agent cannot reliably improve product quality if all it gets is vague prose like:

"Substack emails look weird"

But an agent can do real work if it gets:

raw/sanitized HTML fixture
actual screenshot
expected screenshot or prior baseline
device size
theme
renderer version
Maestro flow to reproduce
test command to verify

Then the agent’s job becomes bounded:

Make this screenshot match expected output without breaking the existing corpus.

That is the shift from “AI coding assistant” to “agent with an eval harness.”

Maestro’s own AI analysis layer also points in this direction: Maestro can analyze logs, command metadata, and screenshots, and it can generate reports identifying UI regressions, spelling errors, and layout breaks. Even if Avec built custom analysis around Maestro rather than relying entirely on Maestro’s built-in AI analysis, the principle is the same: the agent needs screenshots and executable flows, not just issue descriptions.

The best-practice pattern to copy

For any app with hard visual/content rendering problems, use this pattern:

1. Put a “looks wrong” button at the point of failure.
2. Capture the raw input and the rendered output.
3. Sanitize/private-redact the fixture.
4. Create a deterministic replay path.
5. Use Maestro to drive the real app to that state.
6. Capture screenshots.
7. Add screenshot or AI visual assertions.
8. Fix the renderer.
9. Keep the case forever as a regression test.
10. Run the corpus in CI before release.

For Avec, the corpus is broken emails.

For v0, the analogous corpus might be:

long streaming chats
keyboard edge cases
pasted files/images
composer resizing cases
modal/sheet transitions
scroll-to-bottom behavior

For a design-heavy consumer app, the corpus might be:

animation transitions
gesture states
empty states
dark mode
dynamic type
localization
one-handed reachability
The punchline

The lesson from Avec is not simply “use Maestro.”

It is:

Make every real-world UX failure automatically reproducible in the actual app, then promote it into a permanent regression test.

That is how a tiny team can attack a monster problem like HTML email rendering without drowning in one-off fixes. They built the loop, not just the renderer.