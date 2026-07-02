# Second teardown: Avec technical stack and architecture

Source: Codex pasted attachment from the Floradex rewrite planning session.
Purpose: Use this as architecture input for the Floradex rewrite. It analyzes Avec as a React Native plus backend system, then extracts system-design lessons that should be translated rather than copied.

## Original pasted teardown

My current best read: **Avec is very likely a React Native + Expo-ish + native-module-heavy iOS app, backed by a serious Gmail sync backend, a Postgres-like canonical store, async workers, Gmail Pub/Sub, APNs, Claude-class LLMs, a separate speech-to-text path, and a custom email rendering/composition layer.**

I would not think of Avec as “an AI wrapper around Gmail.” I would think of it as:

> **A mobile-native Gmail client whose core product object is a ranked triage queue, not an inbox list.**

That framing determines the stack.

---

## 1. Publicly evidenced stack signals

Here is what I would treat as actually evidenced, versus inferred.

| Layer                       |                                                          Likely choice |          Confidence | Why                                                                                                                                                                                                                                                                              |
| --------------------------- | ---------------------------------------------------------------------: | ------------------: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mobile framework            |                                                       **React Native** |           Very high | A founder X post indexed by search says they started building Avec using React Native, and Software Mansion publicly said Avec uses React Native Enriched. ([X (formerly Twitter)][1])                                                                                           |
| App framework/build tooling |                    **Expo / EAS / prebuild, or Expo-like RN workflow** |         Medium-high | Product Hunt’s “built with” page lists Expo as a product used by Avec. I would treat this as useful but less authoritative than an engineering blog. ([Product Hunt][2])                                                                                                         |
| Rich text compose           |                                              **React Native Enriched** |                High | Software Mansion explicitly says Avec uses React Native Enriched. The library is a native rich text input for React Native, with synchronous text styling, HTML parsing, inline images, mobile support, and current support for RN New Architecture. ([LinkedIn][3])             |
| Email provider              |                                     **Gmail / Google Workspace first** |           Very high | Avec’s App Store copy says it works with personal and work Gmail, and Software Mansion says it integrates with Gmail and Google Workspace accounts. ([App Store][4])                                                                                                             |
| LLM provider                |               **Claude-class Anthropic usage, likely not exclusively** |              Medium | Product Hunt lists Claude by Anthropic under products used by Avec and says “our favorite coding and in-product models.” Avec’s privacy policy more generally says it uses third-party AI service providers for prioritization, drafting, and summarization. ([Product Hunt][2]) |
| Voice                       | **Client audio capture, server-side or hybrid STT, LLM rewrite/draft** |      High inference | TechCrunch describes hold-to-speak, release, transcription appears as a draft, then user reviews/sends. Avec’s privacy policy says it may process voice recordings/transcripts with AI providers. ([TechCrunch][5])                                                              |
| Sync/backend                |                            **Server-side Gmail sync, not client-only** | Very high inference | Smart notifications, ranking, AI search, multi-account support, and background learning basically require a backend. Gmail’s official push model uses Cloud Pub/Sub to notify a backend server of mailbox changes. ([App Store][4])                                              |

The big takeaway: **React Native is not a compromise here.** For a four-ish person team shipping quickly, RN gives velocity. The delight comes from being ruthless about which pieces stay pure RN and which pieces get native primitives.

---

## 2. My best guess at the actual Avec stack

### Mobile app

I would bet their app looks roughly like this:

```txt
React Native
TypeScript
Expo or Expo prebuild / custom dev client
React Native New Architecture
React Native Enriched for rich text compose
React Native Reanimated for card motion
React Native Gesture Handler for swipes and long-press gestures
Native iOS modules for audio session, haptics, notification actions, maybe email rendering
APNs for push
Sentry or similar for crash/perf
PostHog/Amplitude/Segment-like analytics
Local SQLite/MMKV/Zustand/TanStack Query-style cache
```

The two most important pieces are probably **Reanimated/Gesture Handler** and **React Native Enriched**. Reanimated is designed to run animations on the UI thread, which is exactly what a buttery card stack needs. Gesture Handler’s pan gesture gives translation and velocity data for continuous tracking. ([Software Mansion][6])

React Native Enriched matters because email compose is brutal. A normal text input will not cut it once you need links, inline images, selection, rich formatting, signatures, paste behavior, To/Cc/Bcc chips, Gmail aliases, and MIME-compatible HTML. The library’s native-input design is exactly the kind of foundation you need. ([GitHub][7])

### Backend

I would build, and suspect they built, something directionally like this:

```txt
TypeScript backend, likely Node
Postgres primary DB
pgvector or separate vector DB for Ask/search
Redis or equivalent cache
Durable async jobs: Temporal, Inngest, Cloud Tasks, BullMQ, or similar
Google Cloud Pub/Sub for Gmail watch notifications
Object storage for sanitized HTML snapshots, attachment metadata, audio temp files
LLM gateway abstraction over Anthropic/OpenAI/etc.
STT provider for voice, possibly OpenAI/Deepgram/AssemblyAI or hybrid Apple Speech + server finalization
APNs notification service
KMS/envelope encryption for OAuth tokens
```

I’d put the backend on **GCP Cloud Run** or another container/serverless runtime, but Gmail Pub/Sub makes GCP especially natural. Gmail’s push notifications explicitly use Cloud Pub/Sub, and Gmail’s docs show the backend receiving mailbox changes and storing the `historyId` returned by `watch`. ([Google for Developers][8])

The backend should be event-driven. Email apps look simple, but the real system is a sync engine plus a ranking engine plus an AI pipeline plus a native-feeling UI.

---

## 3. The core architecture

Think of Avec as six systems:

```txt
1. Gmail sync engine
2. Email normalization/rendering engine
3. Ranking and personalization engine
4. Triage action engine
5. Voice reply/draft engine
6. Mobile interaction shell
```

Each one has a different latency profile. The swipe shell has to be instant. Gmail mutations can be async. LLM ranking can be precomputed. Search can tolerate a second. Voice reply can tolerate a couple seconds if the UI feels alive.

That separation is probably the most important architectural decision.

---

# 4. Tactical build spec

## 4.1 Gmail integration

### OAuth scopes

For a real Avec-like client, you likely need:

```txt
gmail.modify
gmail.compose
gmail.send
gmail.labels
gmail.settings.basic, maybe, if you want signatures / aliases / settings
calendar readonly or calendar events scope, if you deep-link or reason over calendar events
contacts/people scope, if you personalize by contacts
```

Google classifies Gmail scopes carefully. `gmail.modify` is restricted and lets an app read, compose, and send email but does not allow immediate permanent deletion. Google also says apps should request the narrowest scopes possible, and restricted scopes require additional verification and, if stored/transmitted server-side, security assessment. ([Google for Developers][9])

### Sync model

Use server-side Gmail sync.

On connect:

```txt
1. User OAuths Gmail.
2. Store encrypted refresh token.
3. Fetch profile, aliases, labels, signatures, recent threads.
4. Full sync enough recent threads to make first-run useful.
5. Store latest Gmail historyId.
6. Call users.watch to subscribe the account to Gmail Pub/Sub.
```

Gmail’s sync docs describe full sync on first connect, then partial sync using stored `historyId`; they also note history records are typically available for at least a week but can be unavailable, in which case the app must do a full resync. ([Google for Developers][10])

On new mail:

```txt
Gmail mailbox changes
  -> Gmail Pub/Sub notification
  -> backend webhook / subscriber
  -> history.list from last historyId
  -> fetch changed messages/threads
  -> parse MIME
  -> classify/summarize/rank
  -> update stack queue
  -> maybe send smart notification
```

The key is: **the phone should not be the sync engine.** The phone should consume an already-ranked queue.

### Gmail mutation model

For triage actions:

```txt
Done      -> remove INBOX, optionally add Avec/Done or local done state
Later     -> add Avec/Later, remove INBOX, schedule re-surface
Unimportant -> add Avec/Unimportant or local preference signal, maybe bulk group
Trash     -> move to TRASH, not permanent delete
Unread    -> add UNREAD
Reply     -> create/update draft, then send
```

Gmail supports label management, system labels like `INBOX`, `TRASH`, `UNREAD`, and custom user labels. Labels are many-to-many over messages and threads. Gmail’s `batchModify` can add/remove labels on up to 1,000 message IDs per request. ([Google for Developers][11])

For sending/drafts, create MIME-compliant messages and call Gmail draft APIs. Gmail’s docs say drafts are containers with stable IDs, but the underlying message changes when replaced; sending a draft deletes the draft and creates a new sent message. ([Google for Developers][12])

---

## 4.2 Database schema

A good v1 schema:

```sql
users
  id
  created_at
  name
  email
  timezone

email_accounts
  id
  user_id
  provider               -- gmail
  provider_account_id
  email_address
  display_name
  avatar_url
  oauth_refresh_token_encrypted
  sync_status
  created_at

gmail_sync_state
  account_id
  history_id
  watch_expiration_at
  last_full_sync_at
  last_incremental_sync_at
  last_error

threads
  id
  account_id
  gmail_thread_id
  subject
  normalized_subject
  participants_json
  last_message_at
  unread
  inbox
  archived
  trash
  current_stack_state     -- untriaged, done, later, unimportant, draft, sent
  later_until
  importance_score
  urgency_score
  requires_reply_score
  bulk_score
  rank_score
  summary
  card_excerpt
  created_at
  updated_at

messages
  id
  thread_id
  gmail_message_id
  gmail_history_id
  rfc_message_id
  from_json
  to_json
  cc_json
  bcc_json
  reply_to_json
  sent_at
  received_at
  snippet
  plain_text_ref
  sanitized_html_ref
  raw_headers_json
  attachment_metadata_json
  list_unsubscribe_json
  has_calendar_invite
  has_inline_images
  created_at

triage_events
  id
  user_id
  account_id
  thread_id
  action                 -- seen, done, later, unimportant, undo, reply, send, unsubscribe
  source                 -- swipe, button, notification, automation
  gesture_velocity_x
  gesture_velocity_y
  previous_state
  next_state
  created_at

user_preferences
  id
  user_id
  preference_text
  source                 -- explicit, learned, inferred
  confidence
  created_at
  deleted_at

thread_embeddings
  id
  thread_id
  chunk_text
  embedding
  metadata_json

drafts
  id
  account_id
  thread_id
  gmail_draft_id
  html_body
  plain_body
  generated_from_voice
  transcript
  model_metadata_json
  status                 -- editing, saved, sent, discarded

render_reports
  id
  user_id
  thread_id
  message_id
  html_snapshot_ref
  screenshot_ref
  report_reason
  created_at

notifications
  id
  user_id
  account_id
  thread_id
  notification_type
  sent_at
  opened_at
  action_taken
```

Do **not** store full raw email forever by default. Cache enough to render and search, but treat Gmail as source of truth. Store OAuth tokens with envelope encryption. Keep raw MIME/attachments behind stricter retention rules.

---

## 4.3 Backend services

I’d split services like this:

```txt
api-service
  Auth, user/session, stack API, thread API, action API, draft API, search API

gmail-sync-worker
  Full sync, incremental sync, history reconciliation, watch renewal

message-parser-worker
  MIME parsing, plain text extraction, HTML sanitization, attachment metadata

ai-worker
  Summaries, priority classification, reply-needed detection, draft generation, preference extraction

ranking-worker
  Rank scores, user-specific queue construction, unimportant grouping

notification-worker
  Smart notification decisions, APNs payloads, notification actions

search-indexer
  Full-text index, vector embeddings, Ask retrieval

render-lab-worker
  Email rendering reports, regression corpus, screenshot comparison
```

The critical design choice: **every expensive operation is async, but the stack API always has something ready.**

The phone asks:

```txt
GET /stack?limit=10
```

The backend returns:

```json
{
  "cards": [
    {
      "threadId": "thr_123",
      "subject": "Finch Team IRL in Austin",
      "sender": "Dana Chen",
      "timestamp": "2026-05-27T16:22:00Z",
      "summary": "Dana asks whether you can meet the Finch team in Austin next Thursday...",
      "importanceReason": "Direct request, business trip, deadline",
      "actions": ["reply", "later", "done", "unimportant"]
    }
  ],
  "nextCursor": "..."
}
```

The client should never need to fetch a raw Gmail message just to show the next triage card.

---

# 5. Mobile app spec

## 5.1 Screens

```txt
Onboarding
  Google OAuth
  notification permission
  voice permission
  first-stack explainer

HomeStack
  one active card
  next card pre-rendered behind it
  voice reply button
  action affordances

ThreadView
  full thread
  Ask
  Reply
  Forward
  Done/Later/Unimportant
  render fallback/report

ComposeSheet
  rich text editor
  recipient chips
  voice polish
  signature handling
  draft save/send

Later
  deferred items
  reminders
  unmark done / move back

Important
  every thread that has ever needed attention

Ask/Search
  hybrid exact + semantic search

Settings
  accounts
  preferences
  notification controls
  privacy/data controls
```

Avec’s App Store changelog shows these exact categories of polish: Important mailbox, calendar shortcuts, email rendering fixes, Gmail signature rendering, Bcc labels, Reply-To handling, send-as alias handling, voice reliability, and thumb-oriented long-press menu ordering. ([App Store][4])

## 5.2 Local state

Use local state for three things:

```txt
1. Stack cards currently on-screen
2. Optimistic action queue
3. Draft/voice recording state
```

I’d use something like:

```txt
TanStack Query for server cache
Zustand or Jotai for interaction state
MMKV for tiny persisted settings
SQLite for offline stack/drafts, if you want robust offline support
```

The mistake would be putting drag gesture state into React state. Gesture state belongs in Reanimated shared values.

---

# 6. Swipe mechanism spec

This is the “Tinder for email” part.

TechCrunch reports the default mapping: left swipe adds to later, right swipe adds to done/archive, down marks unimportant, and the card stack also has a hold-to-voice-reply button. ([TechCrunch][5])

## Gesture state machine

```txt
Idle
  -> Dragging
  -> ThresholdPreview
  -> Commit
  -> AnimateOut
  -> OptimisticMutation
  -> NextCardReady

Idle
  -> Dragging
  -> Cancel
  -> SpringBack
```

## Implementation

Use:

```txt
Gesture.Pan()
  .onBegin(...)
  .onUpdate(...)
  .onEnd(...)

Reanimated shared values:
  translateX
  translateY
  rotateZ
  scale
  actionProgress
  activeAction
  thresholdCrossed
```

Pseudocode:

```ts
const SWIPE_X = width * 0.28
const SWIPE_Y = height * 0.16
const VELOCITY_COMMIT = 900

const action = deriveAction({
  dx: translateX.value,
  dy: translateY.value,
  vx: velocityX,
  vy: velocityY,
})

// right: done
// left: later
// down: unimportant

const shouldCommit =
  Math.abs(dx) > SWIPE_X ||
  dy > SWIPE_Y ||
  projectedDistance(dx, vx) > SWIPE_X ||
  projectedDistance(dy, vy) > SWIPE_Y
```

### UX rules

```txt
1. Card follows finger 1:1.
2. Direction labels appear before commit.
3. Haptic fires once when entering a threshold.
4. Commit haptic fires on release if accepted.
5. Next card is already mounted.
6. Server mutation is optimistic.
7. Undo is always available.
8. If mutation fails, recover without yanking the UI backward.
```

### The card should animate with transforms only

Use:

```txt
transform: translateX, translateY, rotateZ, scale
opacity
```

Avoid layout animations during drag. Layout is for after the card is gone.

### Gesture conflict

Do not make the stack card a full complex scroll view if you can avoid it. Use the card as a digest surface. If the user wants the long email, they tap into ThreadView. That keeps vertical scrolling from fighting with downward “unimportant.”

---

# 7. Voice reply spec

Avec’s voice loop is strategically great because it is **not a chatbot**. It is a press-and-hold command to generate a reply in context. TechCrunch says the user holds the bottom button, speaks, releases, sees the transcription as a draft, reviews/edits, then sends. ([TechCrunch][5])

## Client flow

```txt
User presses and holds voice button
  -> prepare audio session
  -> haptic tick
  -> start recording immediately
  -> show waveform / listening state
  -> tolerate small finger movement
  -> release
  -> upload audio
  -> show “drafting” skeleton
  -> receive transcript + draft
  -> open compose sheet with rich text body
```

The App Store changelog strongly suggests they spent a lot of time here: faster voice compose when switching recipients, preserving a thought when the user pauses mid-sentence, respecting Gmail signatures, tolerating small finger movement on hold-to-record, reliable recording across built-in mic/AirPods/wired headphones, and pre-warming the audio session. ([App Store][4])

## Backend flow

```txt
POST /voice/start
  -> returns upload URL/session id

POST /voice/complete
  -> STT transcription
  -> classify intent
  -> retrieve full thread context
  -> retrieve user style/preferences
  -> generate draft
  -> return { transcript, draft_html, draft_plain, confidence, warnings }
```

Prompt shape:

```txt
System:
  You write concise email replies in the user's style.
  Preserve factual accuracy.
  Do not invent commitments.
  Respect the thread context.

Inputs:
  latest email
  previous thread messages
  recipient relationship
  user's explicit preferences
  user's recent sent-email style samples
  transcript
  desired action if detectable

Output:
  subject if needed
  body_html
  body_plain
  missing_info_questions
```

Critical guardrail: never send automatically. Generate draft, user reviews, then send.

---

# 8. Email rendering spec

This is likely one of Avec’s hardest hidden systems.

Their changelog mentions Substack and GitHub digest rendering fixes, an “Email looks wrong” report path, Gmail signature rendering improvements, inline images, markdown spacing, long reply chains, Bcc labels, rich text editing, image paste crashes, and a rebuilt text rendering system for faster/smoother performance. ([App Store][4])

## Renderer architecture

Use **three renderers**, not one:

```txt
1. Card renderer
   Fast, native, simplified.
   Shows subject, sender, recipients, summary, key body excerpt.
   No complex HTML.

2. Thread renderer
   Hybrid.
   Native renderer for common email text blocks.
   WebView fallback for gnarly newsletters, tables, promos, receipts.

3. Compose renderer/editor
   React Native Enriched native rich text editor.
   Converts to HTML + plain text MIME.
```

## MIME pipeline

```txt
Fetch Gmail message
  -> parse MIME tree
  -> choose best body part
  -> extract plain text
  -> sanitize HTML
  -> rewrite image refs
  -> proxy/block tracking pixels
  -> normalize links
  -> detect list-unsubscribe
  -> detect calendar invite
  -> extract quoted replies/signatures
  -> produce card excerpt
  -> store sanitized representation
```

## HTML sanitization rules

```txt
Strip:
  script
  iframe
  object
  embed
  external JS
  dangerous CSS
  event handlers
  forms unless explicitly supported

Rewrite:
  links through safe opener
  remote images through proxy or gated loader
  cid:inline images to attachment URLs
  oversized images to responsive max-width
```

## Rendering fallback rule

If the normalized tree contains unsupported constructs:

```txt
tables with weird nesting
complex newsletters
CSS-dependent layouts
SVG/VML oddities
large inline style blocks
```

then render in a sandboxed WebView, but keep the card/summary native.

The important product lesson: do not make the whole app depend on perfect HTML rendering. The stack experience should stay fast even if a Substack digest is ugly.

---

# 9. Ranking and intelligence spec

Avec’s site says it prioritizes important emails one by one and learns preferences over time. The App Store says AI surfaces what matters, smart notifications only notify about emails that need the user, and reminders bring back replies/follow-ups/to-dos. ([Avec][13])

I would implement ranking as a layered system, not “ask an LLM to sort the inbox.”

## Stage 1: deterministic features

```txt
sender frequency
sender recency
direct-to-me vs cc/list
unread
thread age
last message age
has deadline
has question
has calendar invite
has attachment
is newsletter/promo
sender domain
prior reply history
VIP contacts
Gmail labels/categories
```

## Stage 2: LLM classifier

For each new/changed thread, ask:

```json
{
  "requires_user_attention": true,
  "requires_reply": true,
  "urgency": 0.72,
  "importance": 0.84,
  "category": "work_logistics",
  "summary": "...",
  "notification_summary": "...",
  "suggested_actions": ["reply", "later"],
  "reason": "Direct question about Thursday meeting"
}
```

## Stage 3: personalized ranker

Train from user events:

```txt
swiped done immediately     -> less important next time unless sender is VIP
swiped later                -> important but timing-sensitive
swiped down unimportant     -> suppress similar sender/category/content
opened thread               -> higher interest
replied                     -> requires attention
undo after done             -> false negative signal
manual preference           -> highest weight
notification ignored        -> lower notification threshold for that pattern
```

Model options:

```txt
v1: rules + logistic regression/lightGBM over features
v2: contextual bandit
v3: per-user preference embedding + global ranker
```

Do not start with a pure LLM ranker. It will be expensive, less debuggable, and hard to personalize. Use LLMs to extract features and summaries, then use a conventional ranker to order the queue.

---

# 10. Smart notifications spec

Smart notifications should be a separate decisioning service.

```txt
New thread arrives
  -> classify importance and urgency
  -> check user notification preferences
  -> check quiet hours
  -> check whether user recently saw thread in app
  -> generate concise notification body
  -> send APNs with categories/actions
```

Notification actions:

```txt
Open
Mark Done
Later
Trash
Reply maybe opens voice reply
```

Avec’s changelog says they added the ability to trash emails from the lock screen by long-pressing notifications, which implies iOS notification categories/actions and backend mutation handling. ([App Store][4])

---

# 11. Ask/Search spec

Search needs to be hybrid. Exact search matters in email.

The changelog note about searches for senders with symbols like “B&H” is telling: they are not just doing semantic search. They are tuning exact retrieval and ranking. ([App Store][4])

Use:

```txt
Postgres FTS / OpenSearch / Typesense for exact search
Vector embeddings for semantic Ask
Thread summaries as first retrieval target
Message chunks as second retrieval target
Participant/sender index for names and domains
```

Ask flow:

```txt
User asks: "what time is practice tonight?"
  -> query rewrite
  -> exact search over recent threads
  -> vector search over thread chunks
  -> rerank
  -> answer with source thread references
  -> allow tap-through
```

Do not let Ask become a hallucination surface. Email search should answer with grounding.

---

# 12. Haptics and interaction feel

Haptics should be a small internal service:

```ts
haptics.selection()       // threshold enter
haptics.success()         // committed action
haptics.warning()         // destructive action
haptics.softStart()       // voice recording started
haptics.softStop()        // voice recording ended
```

Rules:

```txt
1. Fire haptic on semantic boundary, not every frame.
2. Never fire repeated haptics while hovering around threshold.
3. Prepare haptic generators before likely use.
4. Sync haptic with visual threshold exactly.
```

In React Native, this is probably Expo Haptics or a native haptics module. Expo Haptics maps notification feedback to iOS `UINotificationFeedbackType`, which is enough for a first implementation. ([Expo Documentation][14])

---

# 13. The tactical MVP path

I would not start with the whole thing. I’d build it in this order.

## Phase 1: Fake inbox, real swipe quality

Goal: prove the interaction.

```txt
Mock cards
Real card stack
Real gestures
Real haptics
Real optimistic state
Undo
List/stack toggle
Thread mock view
```

Exit criteria:

```txt
120 fps on modern iPhones
No accidental commits
Swipe directions feel obvious
Next card feels instant
```

Do this before Gmail. If the swipe does not feel magical, nothing else matters.

## Phase 2: Gmail read-only sync

```txt
Google OAuth
Fetch recent threads
Parse basic MIME
Render native card excerpts
Thread view with sanitized basic HTML/plain text
Local cache
```

Exit criteria:

```txt
Can connect Gmail
Can see real recent emails
Can open real thread
Rendering is ugly but acceptable
```

## Phase 3: Triage mutations

```txt
Done/archive
Later label/local state
Unimportant
Undo
Batch label mutations
Sync reconciliation
```

Exit criteria:

```txt
Swiping mutates Gmail correctly
No duplicated cards
No lost thread state
Undo feels safe
```

## Phase 4: Ranking v1

```txt
Rule-based score
Direct-to-me detection
Newsletter/promotions suppression
Reply-needed classifier
Simple summaries
```

Exit criteria:

```txt
The top 10 cards are obviously better than chronological inbox
```

## Phase 5: Voice reply

```txt
Hold-to-record
Audio session pre-warm
Upload audio
STT
LLM draft
React Native Enriched compose
Gmail draft/send
```

Exit criteria:

```txt
Can speak a messy thought and get a usable draft
Signature, recipients, Reply-To, aliases handled correctly
```

## Phase 6: Rendering hardening

```txt
HTML sanitizer
Inline image handling
Long reply chains
Substack/newsletters
GitHub digests
Render report button
Regression corpus
```

Exit criteria:

```txt
Top 100 real-world email types render acceptably
Rendering failures are reportable and reproducible
```

## Phase 7: Smart notifications and Ask

```txt
APNs
Notification classifier
Lock-screen actions
Hybrid search
RAG Ask
Task reminders
```

Exit criteria:

```txt
Notifications feel useful, not noisy
Ask beats Gmail search for natural-language recall
```

---

# 14. What I’d copy from Avec tactically

The highest leverage build choices are:

1. **Make the stack the product primitive.** Do not build a Gmail clone and add swipes later.

2. **Precompute everything needed for the next card.** The stack API should return ranked, summarized, render-ready cards.

3. **Use React Native, but use native primitives for the hard parts.** Gestures, haptics, audio, rich text, notification actions, and rendering cannot feel webby.

4. **Treat Gmail as source of truth, but maintain your own product state.** Gmail labels alone are not enough to represent “this user thinks this sender is unimportant” or “this should come back later.”

5. **Use LLMs as feature extractors and drafters, not as the whole app brain.** Ranking needs deterministic features, personalization, and feedback loops.

6. **Build a rendering lab early.** The App Store changelog screams that email rendering was a major quality battlefield. ([App Store][4])

7. **Instrument interaction quality.** Track frame drops, gesture cancellations, undo rate, accidental swipes, time-to-next-card, voice start latency, draft acceptance rate, and render reports.

---

# 15. My “build Avec” reference architecture

If I were building this from scratch, this is the concrete stack I’d choose:

```txt
Mobile
  React Native + TypeScript
  Expo prebuild / custom dev client
  RN New Architecture
  React Native Reanimated
  React Native Gesture Handler
  React Native Enriched
  Expo Haptics or native haptics module
  expo-audio or native AVAudioSession module
  MMKV + SQLite
  TanStack Query
  Sentry
  PostHog or Amplitude

Backend
  TypeScript monorepo
  Fastify/Hono/NestJS or tRPC-style API
  Postgres
  pgvector
  Redis
  Temporal or Inngest for durable jobs
  GCP Pub/Sub for Gmail push
  Cloud Run or Fly/Render/Railway/Vercel serverless with a worker tier
  Object storage for sanitized HTML/audio/temp artifacts
  KMS for token encryption

AI
  Claude for summarization/drafting/classification if following public clues
  Separate STT provider for voice
  Embeddings via a dedicated embedding model
  Prompt/version registry
  Eval set from real anonymized/render-safe emails

Infra
  APNs
  Google OAuth verification/security assessment path
  Structured logging with email-body redaction
  Render regression corpus
  Feature flags
  Background watch-renewal jobs
```

I would **not** build this as a purely client-side Gmail app. I would also **not** start by overengineering the ML. The product breakthrough is the queue and interaction model; the ML can become increasingly sophisticated once the event loop exists.

The simplest accurate mental model:

```txt
Avec = Gmail sync engine
     + ranked triage queue
     + buttery card shell
     + voice-to-draft composer
     + brutal email rendering polish
     + personalization loop from every swipe
```

[1]: https://x.com/jnnnthnn/status/2053294866906636517?utm_source=chatgpt.com "we started building @avec using react native ..."
[2]: https://www.producthunt.com/products/avec/built-with "Products used by Avec | Product Hunt"
[3]: https://www.linkedin.com/posts/software-mansion_congratulations-on-the-amazing-launch-activity-7448336143198138369-ONLD "Congratulations on the amazing launch! 

Avec is an AI-powered email app that helps you manage your inbox. It integrates with existing Gmail and Google Workspace accounts. And it uses our very own… | Software Mansion"
[4]: https://apps.apple.com/ca/app/avec-ai-email-for-gmail/id6742199038 "‎Avec - AI Email for Gmail App - App Store"
[5]: https://techcrunch.com/2026/04/09/avecs-tinder-styled-email-app-allows-you-to-swipe-through-your-inbox/ "Avec's Tinder-style email app allows you to swipe through your inbox | TechCrunch"
[6]: https://docs.swmansion.com/react-native-reanimated/?utm_source=chatgpt.com "React Native Reanimated"
[7]: https://github.com/software-mansion/react-native-enriched "GitHub - software-mansion/react-native-enriched: Rich Text Editor for React Native · GitHub"
[8]: https://developers.google.com/workspace/gmail/api/guides/push "Configure push notifications in Gmail API  |  Google for Developers"
[9]: https://developers.google.com/workspace/gmail/api/auth/scopes "Choose Gmail API scopes  |  Google for Developers"
[10]: https://developers.google.com/workspace/gmail/api/guides/sync?utm_source=chatgpt.com "Synchronize clients with Gmail"
[11]: https://developers.google.com/workspace/gmail/api/guides/labels "Manage labels  |  Gmail  |  Google for Developers"
[12]: https://developers.google.com/workspace/gmail/api/guides/drafts "Create and send draft emails  |  Gmail  |  Google for Developers"
[13]: https://avec.ai/ "Avec — Handle your Gmail inbox in seconds"
[14]: https://docs.expo.dev/versions/latest/sdk/haptics/?utm_source=chatgpt.com "Haptics"
