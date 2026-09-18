# SoundMesh Audio API Contract

Status: EXPERIMENTAL
Model: DEC-085 (Model B — Capture, not Distribution)

---

# 1. Purpose

This contract defines how SoundMesh obtains audio from the host device and
makes it available, as a live stream, to the synchronization and playback
systems. It replaces the pre-DEC-085 file-distribution contract in full.

SoundMesh does not own, store, or manage audio files. It captures audio
that is already playing in another application on the host device and
transports it live to participants.

---

# 2. Scope

This contract covers:
- Requesting and managing capture permission on the host device
- Starting, stopping, and monitoring a capture session
- Discovering the format of captured audio
- Exposing captured audio as a live stream to the Audio Transport layer

This contract does NOT cover:
- Networking/packetization of the captured stream (see networking.md,
  Phase 8 transport work)
- Native audio output/rendering on participant devices (see playback-api.md)
- Any form of audio file selection, storage, or library browsing —
  these concepts do not exist in SoundMesh

---

# 3. Authority

This document is subordinate to `audio.md` and `decisions.md` (DEC-085).
Where they conflict, `decisions.md` wins, since it records the explicit,
dated pivot decision. If this document appears to conflict with either,
STOP and flag it rather than resolving the conflict inline.

---

# 4. Audio Mental Model

SoundMesh does not select, own, or store audio. The host does not pick a
song from within SoundMesh — the host opens some other app (a video app,
a music app, a browser) and plays audio there as normal. SoundMesh's job
is to capture that audio as it plays and deliver it live to participants.

```
External App (host device)
        ↓ (plays audio normally, unaware of SoundMesh)
Android AudioPlaybackCapture
        ↓
Native Capture Engine (this contract)
        ↓ (live PCM stream)
Audio Transport (networking.md / Phase 8)
        ↓
Native Output Engine (playback-api.md)
```

There is no "Audio Resource" with an ID, duration, or integrity hash.
There is no local storage of audio content. There is a live stream with a
start time, a format, and an end (when capture stops).

Continuous transport from host to participants is the expected model, not
an exception to be avoided. The old preference for one-time distribution
plus local playback (previously documented here) is retired by DEC-085.

---

# 5. Capture Session Identity

Each capture session has:
- `sessionId` — unique per capture start, not per audio content (there is
  no "audio content ID" anymore)
- `generation` — increments each time capture is (re)started, consistent
  with `networking.md`'s generation-awareness requirement, so downstream
  consumers can detect and discard stale-generation data

There is no persistent identity for "a piece of audio" — only for a
capture session.

---

# 6. Capture Metadata

Metadata available about an active capture session:
- `sessionId`
- `generation`
- `sampleRate` (discovered at capture start, not user-selectable)
- `channelCount` (discovered at capture start)
- `startedAt` (device-local monotonic timestamp, not wall clock)
- `sourceAppKnown` — UNDECIDED whether Android exposes which app is the
  audio source reliably; if it does not, this field should be omitted
  rather than guessed at

There is no title, artist, duration, or any file-derived metadata. None
of that exists for a live external capture.

---

# 7. Supported Audio Characteristics

SoundMesh does not restrict format by file type (there is no file). It
must instead support whatever `AudioPlaybackCapture` yields, which is
typically raw PCM at a sample rate/channel configuration determined by
the source app and the Android audio framework — not chosen by SoundMesh.

UNDECIDED: whether SoundMesh normalizes/resamples all captured audio to
one canonical internal format immediately at capture, or passes through
whatever format was captured and lets downstream layers adapt. This must
be decided based on Phase 5's real-device experiment results (do
different source apps actually yield different formats in practice?)
before Phase 8 (transport) can be finalized.

---

# 8. Capture Permission

Android requires explicit user consent (`MediaProjection`) before any
`AudioPlaybackCapture` session can start. This is a per-session grant, not
a persistent app permission — the user will see this prompt each time
capture starts, unless Android's platform behavior changes.

---

# 9. `requestCapturePermission()`

Requests the `MediaProjection` consent needed for capture.

Returns one of:
- `GRANTED`
- `DENIED`

Must not be called from a background/foreground-service-only context —
it requires an active Activity to present the system consent dialog.

---

# 10. `startCapture()`

Starts a capture session. Must only be called after
`requestCapturePermission()` has returned `GRANTED` for this session.

On success: transitions capture state to `CAPTURING`, assigns a new
`sessionId` and increments `generation`, and begins exposing a live PCM
stream to the Audio Transport layer.

On failure: returns one of the error codes in §14, and capture state
remains/returns to a non-capturing state.

---

# 11. `stopCapture()`

Stops the current capture session cleanly: releases the
`MediaProjection` session, stops the foreground service if one was
started for this purpose, and transitions capture state to `STOPPED`.

Must be safe to call even if no capture is active (no-op, not an error).

---

# 12. `getCaptureState()`

Returns the current capture state and, if capturing, the session
metadata from §6. Replaces the retired `getPlaybackState()` from the old
model — capture state is the source of truth now, not playback state.

---

# 13. Local Audio Availability

There is no concept of "local availability" — captured audio is never
stored, only streamed live. If a participant disconnects and reconnects,
they receive whatever is currently being captured from that point
forward; there is no "catching up" on missed audio, since nothing is
retained. (This may need revisiting for UX reasons — flag to Faraz if a
smoother rejoin experience becomes a requirement; do not build a hidden
buffer/cache to solve this without it being an explicit decision.)

---

# 14. Errors

- `PERMISSION_DENIED` — user declined `MediaProjection`
- `CAPTURE_UNSUPPORTED` — device/Android version does not support
  `AudioPlaybackCapture`
- `SOURCE_APP_BLOCKED` — the app currently playing audio has opted out of
  capture (Android allows apps to set this)
- `CAPTURE_START_FAILED` — generic native failure; must include the
  underlying exception/message, not just this code alone
- `CAPTURE_INTERRUPTED` — an active capture session was interrupted
  (source app stopped, another app took over audio focus in a way that
  ends capture, or the system revoked the `MediaProjection` grant)
- `NO_AUDIO_PLAYING` — UNDECIDED whether Android can reliably distinguish
  "capturing but silence because nothing is playing" from "capture
  failed" — if it can, this should be a distinct informational state, not
  an error; confirm during Phase 5's real-device experiment

---

# 15. Capture State

```
IDLE → REQUESTING_PERMISSION → PERMISSION_GRANTED → CAPTURING → STOPPED
                              ↘ PERMISSION_DENIED
CAPTURING → FAILED (on interruption/unrecoverable error)
```

This state must be observable by the UI (Mahin's side) as "Capture
Status," replacing the old playback-state concepts (`play`/`pause`/`seek`
states no longer apply here — see playback-api.md for what remains on the
output side).

---

# 16. Readiness

A participant is "ready" to receive audio once connected and the Audio
Transport layer (Phase 8) has confirmed format compatibility with the
currently active capture session (if one is active). There is no
"preparation" step involving loading/decoding a file — that entire
category of work is retired.

---

# 17. Playback Separation

Capture (this contract) is fully separate from output (`playback-api.md`).
The host captures; every device (host included, if it chooses to also
output the audio) plays via the native output engine. Capture does not
imply playback, and playback does not imply capture — a host could
theoretically capture without locally outputting, though this needs
explicit confirmation as a supported mode versus an oversight (UNDECIDED).

---

# 18. Sample Rate / Channel Configuration

Not user-selectable. Discovered at capture start (§6) and must be
propagated to participants before/at stream start so the output engine
(playback-api.md) can configure itself correctly. A change in captured
format mid-session (e.g. source app changes its own output format) is
UNDECIDED behavior — likely needs to be treated as a new generation
rather than an in-place format change; confirm during implementation and
flag if it happens in practice.

---

# 19. Resampling

If Phase 8 or Phase 9 requires a canonical sample rate different from
what was captured, resampling responsibility and location (capture side
vs. transport side vs. output side) is UNDECIDED — do not implement
resampling silently in this layer without it being agreed as this
layer's responsibility.

---

# 20. Audio Output Routing

Not this contract's concern — see `playback-api.md`. Capture is agnostic
to where output eventually renders.

---

# 21. Audio Interruptions

A capture session may be interrupted by:
- The source app stopping playback
- The source app losing audio focus to another app
- The user revoking the `MediaProjection` grant via system UI
- The system reclaiming resources

All of these must surface as `CAPTURE_INTERRUPTED` (§14), with as much
detail as Android provides about which case occurred, logged even if not
exposed as a distinct error code yet.

---

# 22. Background Behavior

Per Android requirements, capture must run inside a foreground service
with a persistent notification while active — this is a platform
requirement, not a SoundMesh design choice, and must not be worked around.
The foreground-service notification's exact UX is UNDECIDED and may need
Mahin's input — do not finalize its appearance unilaterally.

---

# 23. Native Audio Boundary

### Android
All capture logic (§9–§15) lives entirely natively (Kotlin), using
`AudioPlaybackCapture` and `MediaProjection`. Flutter only ever sees
Pigeon-typed state (`CaptureState`, `CaptureMetadata`, error codes) —
never raw PCM frames, never Android-specific capture APIs.

### iOS
Not supported. iOS sandboxing prevents an app from capturing audio
playing in another app in the background. iOS devices in SoundMesh are
participants/listeners only — they never implement this contract's
capture side, only the receive side defined in `playback-api.md`. This
is a documented platform limitation, not a gap to be filled.

---

# 24. Flutter Boundary

Flutter-facing surface is limited to:
- `requestCapturePermission()`
- `startCapture()`
- `stopCapture()`
- `getCaptureState()`
- A capture-state-changed event stream (state transitions, errors,
  metadata updates — not per-frame data)

No raw audio data crosses this boundary, per `architecture.md`'s
Flutter/native separation requirement.

---

# 25. Audio Events

Events emitted to Flutter (via the existing `Dispatchers.Main`-safe
callback pattern):
- `onCaptureStateChanged(state, metadata?)`
- `onCaptureError(errorCode, message)`

Both must be dispatched on the main dispatcher, consistent with the
existing audited pattern from the `onConnectionError` threading fix.

---

# 26. Errors

See §14 for the full list. All errors surfaced to Flutter must include
both a stable error code and a human-readable message with underlying
native detail where available — never a bare code with no context.

---

# 27. Concurrency

- Only one capture session may be active at a time per host device.
- `startCapture()` while already `CAPTURING` should return an error
  (UNDECIDED whether this is a distinct `ALREADY_CAPTURING` code or
  folded into `CAPTURE_START_FAILED` — propose, don't assume) rather than
  silently restarting.
- All native capture work happens off the Flutter/UI thread.

---

# 28. Generation Awareness

Every capture start increments `generation` (§5). Transport (Phase 8) and
output (Phase 9) layers must discard any data tagged with a generation
older than the current one, to avoid mixing audio from a stopped/restarted
session with the current one.

---

# 29. Caching

None. Captured audio is never cached, written to disk, or retained beyond
what's needed to hand frames to the transport layer in near-real-time.
This is a deliberate consequence of the live-capture model, not an
oversight — do not add caching without it being a new, explicit decision.

---

# 30. Audio Distribution

Retired concept. There is no distribution step — see §4. This section
number is kept only so cross-references from other documents predating
DEC-085 can be found and corrected; it has no active content.

---

# 31. Live Transport Handoff

Captured PCM frames are handed to the Audio Transport layer
(`networking.md`, Phase 8) as they arrive, with minimal internal
buffering (only enough to smooth over native scheduling jitter, not to
build up a meaningful backlog). Exact buffer sizing is UNDECIDED and
belongs to Phase 8's evidence-based transport decision, not this contract.

---

# 32. UI Consumption

Mahin's UI consumes:
- `CaptureState` (§15) — rendered as "Capture Status" per `ui-ux.md`
- `CaptureMetadata` (§6) — informational display only
- Error events (§14/§26) — rendered as user-facing failure messages,
  with copy appropriate to each error code (not a single generic
  "something went wrong")

The UI does not and cannot control capture format, source selection, or
any file-related concept — those controls do not exist in this model.

---

# 33. Contract Testing

### Permission
- Request granted → state transitions correctly
- Request denied → state transitions correctly, no capture starts

### Capture Lifecycle
- Start → Capturing → Stop → Idle, repeatable without leaks
- Start while already capturing → correct error, no duplicate session

### Format Discovery
- Metadata populated correctly at capture start
- Format propagated in a form Phase 8/9 can consume

### Interruption
- Source app stopped mid-capture → `CAPTURE_INTERRUPTED`
- MediaProjection revoked mid-capture → `CAPTURE_INTERRUPTED`

### Error Coverage
- Each error code in §14 has at least one test forcing that condition
  (where feasible on-device; some may only be testable manually)

---

# 34. Real-Device Testing

Required per Phase 5 (`farazwork.md` §10): capture tested against at
least 2–3 real external apps, on real hardware, with results (Android
version, device model, source app, granted Y/N, captured Y/N, format
observed, failure reason if any) recorded in the completion report and
in a new `decisions.md` entry. Simulators/mocks cannot substitute for
this — `AudioPlaybackCapture` behavior is not reliably mockable.

---

# 35. AI Implementation Rules

- Do not implement any operation not listed in §9–§12 without first
  adding it to this contract.
- Do not reintroduce any file-based concept (`selectAudio`, `audioId`,
  file paths, duration, format lists) — these are retired, not merely
  deprecated.
- Do not guess at any UNDECIDED item in this document — implement the
  minimum needed to make progress, flag the UNDECIDED item explicitly in
  the completion report, and do not treat your own choice as final.

---

# 36. AI Stop Conditions

STOP and report rather than proceeding if:
- A source app cannot be captured and no documented Android workaround
  exists
- Captured format varies unpredictably in a way that can't be reliably
  discovered before/at capture start
- The foreground-service notification requirement conflicts with an
  existing UI flow in a way that needs Mahin's input
- Any UNDECIDED item in this document turns out to block forward progress
  entirely (not just needing a placeholder default)

---

# 37. Contract Change Procedure

Any change to the operations in §9–§12, the error codes in §14, or the
state machine in §15 must follow: identify problem → propose change →
get it approved → update this document → update implementation → update
tests. No silent contract drift, per `rules.md`.

---

# 38. Dependency Map

```
Audio Capture (this contract)
        ↓ live PCM + metadata
Audio Transport (networking.md)
        ↓ ordered packet stream
Native Output (playback-api.md)
        ↓ scheduled playback
Synchronization (sync-api.md)
        ↑ timing coordination (independent of audio content)
```

Audio Capture has no dependency on Networking, Room, or Device systems —
it is intentionally isolated, per Phase 5's scope.

---

# 39. Relationship to Other Contracts

- `core-api.md` — already updated to reflect this model
  (`startCapture()`/`getCaptureState()` referenced there directly)
- `playback-api.md` — STILL PRE-DEC-085 as of this writing; must be
  rewritten to consume this contract's live stream instead of a prepared
  file resource before Phase 9 begins
- `networking.md` / `sync-api.md` — unaffected by this rewrite except
  where they reference the old audio-distribution model, which should be
  understood as superseded

---

# 40. Current Open Questions

1. Does capture format vary across different source apps in practice, or
   is it consistently normalized by Android? (Resolve in Phase 5.)
2. Can "capturing but source is silent" be distinguished from "capture
   failed"? (§14, §7)
3. Where should resampling responsibility live, if needed at all? (§19)
4. Is host-side simultaneous local output of the captured audio a
   supported mode, or does the host rely on hearing the source app
   directly? (§17)
5. What is the foreground-service notification's UX? (§22 — needs Mahin)
6. What happens to an in-progress capture session if the host device's
   screen locks or the app is backgrounded? (Not yet addressed — flag if
   this surfaces during Phase 5 testing.)
7. Exact `ALREADY_CAPTURING`-vs-`CAPTURE_START_FAILED` error distinction.
   (§27)

---

# 41. Definition of Done (for Phase 5's implementation of this contract)

- `requestCapturePermission()`, `startCapture()`, `stopCapture()`,
  `getCaptureState()` implemented and Pigeon-exposed
- Real external app audio captured and observed on a physical device
- All §14 error cases distinctly reachable and tested (where feasible)
- Real-device experiment table completed and recorded
- This document updated to match what was actually built, including
  resolving or explicitly carrying forward each §40 open question

---

# 42. Final Principle

SoundMesh does not manage audio. It borrows a moment of audio already
playing elsewhere and shares that moment, live, with other devices. Every
operation in this contract should be evaluated against that principle —
if an operation implies ownership, storage, or control over audio content
itself, it does not belong here.