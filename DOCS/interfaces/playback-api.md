# SoundMesh Synchronized Audio Output API Contract

**File:** `DOCS/interfaces/playback-api.md`

**Status:** EXPERIMENTAL

**Owner:** Faraz

**Primary Consumers:** Core API, Audio API, Synchronization System, Device API, Room API, UI/Application Layer, Integration Tests

---

# 1. Purpose

The Playback API defines the authoritative interface through which SoundMesh turns synchronized live-audio frames into actual device audio output.

SoundMesh does **not** own the media being played.

The external media application remains the source of truth for:

* media content
* play/pause
* seeking
* playback position
* playback speed
* track selection
* subtitles
* media metadata
* media controls

SoundMesh instead owns the synchronized output path:

```text
External Media App
        ↓
Android AudioPlaybackCapture
        ↓
Captured Audio Frames
        ↓
Audio Transport
        ↓
Participant Jitter Buffer
        ↓
Playback API
        ↓
Scheduled Native Audio Output
        ↓
Device Speakers
```

The Playback API answers:

> **“Given synchronized audio data and timing instructions, how does SoundMesh safely schedule and execute the audio output?”**

It does not determine how external media is played.

It does not determine synchronization.

It executes synchronization decisions against the live captured-audio timeline.

---

# 2. Scope

The Playback API owns:

* native audio output
* audio output scheduling
* output buffering
* scheduled frame execution
* output lifecycle
* output readiness
* actual output state
* output timing observation
* cancellation of stale scheduled output
* output underrun reporting
* audio-route awareness
* output-related errors

The Playback API does **not** own:

* external media playback
* media controls
* media libraries
* audio file selection
* audio asset identity
* audio file distribution
* audio decoding policy
* room membership
* network transport
* clock synchronization
* latency estimation
* drift estimation
* drift correction algorithms
* QR joining
* UI rendering

Those responsibilities belong to their respective contracts.

---

# 3. Authority

The Playback API follows the SoundMesh authority hierarchy:

1. Approved architectural decisions
2. Interface contracts
3. Core architecture specification
4. Audio / Networking / Synchronization specifications
5. Approved integration tests
6. Existing implementation
7. AI assumptions

If implementation and documentation disagree, AI agents must not silently choose one.

---

# 4. Core Mental Model

SoundMesh is not a synchronized media player.

The old model:

```text
Select Audio
      ↓
Prepare Audio
      ↓
Play Audio
      ↓
Pause / Seek / Stop
```

is obsolete.

The authoritative model is:

```text
External Media App
      ↓
Live Audio Capture
      ↓
Audio Frames
      ↓
Network
      ↓
Jitter Buffer
      ↓
Synchronization Decision
      ↓
Playback Schedule
      ↓
Native Audio Output
```

The external media application controls the media.

SoundMesh controls the synchronized reproduction of captured audio.

---

# 5. Playback Output Model

For a participant:

```text
Captured Audio Frame
        ↓
Validate Generation
        ↓
Place Into Jitter Buffer
        ↓
Determine Target Output Time
        ↓
Schedule Native Audio
        ↓
Device Output
```

Playback MUST NOT simply execute:

```text
receive frame
     ↓
play immediately
```

because immediate execution would make network arrival time part of the audio timeline.

Instead:

```text
receive frame
     ↓
buffer
     ↓
timestamp
     ↓
schedule against shared timeline
     ↓
output at target time
```

---

# 6. Host and Participant Output

The host and participants may have different audio paths.

Host:

```text
External Media App
        ↓
Host Audio Output
```

Participant:

```text
External Media App
        ↓
Audio Capture
        ↓
Network
        ↓
Jitter Buffer
        ↓
Scheduled Output
```

Therefore SoundMesh MUST NOT assume:

```text
host output latency == participant output latency
```

Host-to-participant latency is an engineering variable that must be measured.

If the implementation requires compensating for host direct-output latency, that behavior must be explicitly defined by the synchronization/timing system.

The Playback API must not invent that compensation independently.

---

# 7. Playback Output States

The conceptual output states are:

```text
IDLE
INITIALIZING
READY
BUFFERING
SCHEDULED
PLAYING
UNDERRUN
INTERRUPTED
STOPPING
STOPPED
ERROR
```

These states are currently **EXPERIMENTAL**.

Exact transitions must be defined before they become a stable public contract.

An implementation must not invent externally visible states without updating this document.

---

# 8. Output Lifecycle

Conceptual lifecycle:

```text
IDLE
  ↓
INITIALIZING
  ↓
READY
  ↓
BUFFERING
  ↓
SCHEDULED
  ↓
PLAYING
  ↓
STOPPING
  ↓
STOPPED
```

Possible failure paths:

```text
INITIALIZING → ERROR
BUFFERING → ERROR
SCHEDULED → ERROR
PLAYING → UNDERRUN
PLAYING → INTERRUPTED
```

Recovery behavior remains implementation-dependent until explicitly defined.

---

# 9. Audio Frame Input

Playback consumes live audio frames rather than prepared media resources.

Conceptually:

```text
AudioFrame

├── sessionGeneration
├── sequenceNumber
├── captureTimestamp
├── sampleFormat
├── sampleRate
├── channels
└── payload
```

The authoritative frame contract belongs to the Audio/Networking specifications.

Playback must not redefine frame identity.

Playback must reject or safely ignore frames belonging to stale generations.

---

# 10. No Audio Resource Ownership

The Playback API MUST NOT expose concepts such as:

```text
AudioResource
audioId
audioFile
mediaAsset
preparePlayback(audioId)
load(audioId)
```

These belong to the obsolete file-distribution/media-player architecture.

SoundMesh does not need to know whether captured audio originated from:

* YouTube
* VLC
* Spotify
* a browser
* a video player
* a game
* another eligible Android application

Playback receives audio frames.

The original media identity is outside the Playback API.

---

# 11. `getPlaybackState()`

The API should expose authoritative output state.

Conceptually:

```json
{
  "state": "PLAYING",
  "generation": 12,
  "bufferedFrames": 18,
  "bufferedDurationMs": 120,
  "outputTimestamp": 482913420
}
```

This is illustrative only.

Exact fields and types remain:

**UNDECIDED**

The state must represent actual known native output state.

The API must not fabricate state based solely on expected commands.

---

# 12. `initializeOutput()`

Conceptually:

```text
initializeOutput(format)
```

Initializes the native audio output path.

Potential responsibilities:

* validate supported audio format
* initialize native output engine
* configure sample rate
* configure channel count
* configure sample format
* prepare output buffers
* establish output timing facilities
* detect current audio route

Initialization MUST NOT imply that audio should immediately play.

Exact request and response schemas remain:

**UNDECIDED**

---

# 13. `enqueueFrame()`

Conceptually:

```text
enqueueFrame(audioFrame)
```

Adds a validated live audio frame to the playback buffer.

The operation must:

1. validate session generation
2. validate frame ordering
3. handle duplicates
4. detect gaps
5. enforce buffer limits
6. place valid frames into the jitter buffer
7. expose relevant statistics

Playback must not block indefinitely waiting for a frame.

---

# 14. `scheduleFrame()`

Conceptually:

```text
scheduleFrame(frame, targetTime)
```

Schedules audio for future native output.

The target time is supplied by the synchronization system.

Playback executes the instruction.

Playback MUST NOT independently calculate a new group synchronization target.

Conceptually:

```text
Sync
 ↓
targetTime
 ↓
Playback
 ↓
native scheduled output
```

---

# 15. Scheduling Contract

A synchronization instruction may conceptually contain:

```text
PlaybackSchedule

├── sessionGeneration
├── sequenceNumber
├── targetTime
├── targetPosition
└── timingConfidence
```

Exact schema:

**UNDECIDED**

The Playback API must treat the supplied target as authoritative for that scheduling operation.

---

# 16. Future Scheduling

Audio should normally be scheduled for a future monotonic time rather than played immediately.

Conceptually:

```text
T_target = T_now + M
```

where:

* `T_now` = current monotonic time
* `M` = scheduling/buffering margin
* `T_target` = target output time

The exact margin is owned by the timing/synchronization system and must be determined experimentally.

Playback must not hard-code arbitrary synchronization margins as system-level truth.

---

# 17. Monotonic Time

Timing-critical output scheduling MUST use monotonic time.

Wall-clock time must not be used for synchronized audio execution.

On Android, an appropriate platform timing source may include:

```text
SystemClock.elapsedRealtime()
```

or a more appropriate native audio clock where required.

Exact clock selection belongs to the platform/timing implementation.

---

# 18. Actual Output Timing

Playback should expose actual native output timing where the platform allows it.

The implementation must distinguish between:

```text
Requested Target Time
```

and:

```text
Actual Output Time
```

They are not necessarily identical.

Differences may result from:

* native audio scheduling
* hardware buffering
* audio-route latency
* device-specific behavior
* underruns
* operating-system behavior
* output engine behavior

The Playback API reports observable facts.

Synchronization interprets those facts.

---

# 19. Output Position

SoundMesh should not expose a media-player-style position such as:

```text
positionMs = 12450
```

unless that position has a clearly defined relationship to the captured-audio timeline.

The relevant concepts are instead:

```text
captureTimestamp
targetOutputTime
actualOutputTimestamp
sequenceNumber
```

If a timeline-relative output position is required, its semantics must be explicitly defined.

The Playback API must not pretend that it knows the external application's media position.

---

# 20. Jitter Buffer

Playback consumes audio through a bounded jitter buffer.

The buffer must support:

* packet/frame reordering
* temporary network jitter
* late frame detection
* duplicate detection
* missing-frame detection
* bounded memory
* underrun detection
* stale-generation rejection

The exact buffer implementation is experimental.

Playback must not allow an unbounded stream of audio data to accumulate.

---

# 21. Buffering

The output system may enter:

```text
BUFFERING
```

when insufficient audio exists to safely begin or continue scheduled playback.

Playback must not falsely report `PLAYING` when no usable audio is available.

The exact buffering threshold is:

**UNDECIDED**

It must be determined through measurement.

---

# 22. Underruns

An underrun occurs when scheduled output requires audio that is not available.

Conceptually:

```text
Expected Frame
      ↓
Not Available
      ↓
OUTPUT UNDERRUN
```

Underruns must be observable.

Potential information:

```text
generation
expectedSequence
actualAvailableSequence
bufferDepth
timestamp
```

Exact event schema remains:

**UNDECIDED**

Playback must not silently convert repeated underruns into successful synchronized playback.

---

# 23. Frame Loss and Gaps

Missing frames may occur because of network loss.

Playback must distinguish between:

```text
late
missing
duplicate
out-of-order
stale
```

The exact concealment/recovery policy belongs to the audio/output design.

Playback must not invent arbitrary audio data without an explicit approved policy.

---

# 24. Scheduled Output Cancellation

If an output operation has been scheduled but the session ends or the generation changes, the pending operation must be cancelled or invalidated.

Example:

```text
Generation 10
Audio scheduled
      ↓
Session changes
      ↓
Generation 11
      ↓
Old schedule becomes stale
      ↓
Old audio MUST NOT start
```

This is mandatory for correctness.

---

# 25. Generation Protection

Every timing-sensitive output operation must be associated with a session generation.

Conceptually:

```text
if command.generation != activeGeneration:
    reject / ignore
```

Generation semantics are coordinated with Core/Room/Networking/Synchronization.

Playback must never allow stale audio from a previous session generation to leak into the current session.

---

# 26. Session Lifecycle

Playback output should be scoped to the active SoundMesh audio session.

Conceptually:

```text
Session Created
      ↓
Output Initialized
      ↓
Frames Received
      ↓
Output Buffered
      ↓
Scheduled
      ↓
Playing
      ↓
Session Ends
      ↓
Output Stopped
```

Ending an audio session must invalidate pending output work.

---

# 27. No Media Controls

The Playback API MUST NOT expose:

```text
play()
pause()
resume()
seek()
stop()
next()
previous()
```

as controls for the external media application.

Those controls belong to the external media application.

SoundMesh should not attempt to reproduce or control the external application's playback state.

The SoundMesh equivalent is session/output lifecycle:

```text
initializeOutput()
enqueueFrame()
scheduleFrame()
startOutputSession()
stopOutputSession()
flushOutput()
getPlaybackState()
```

Exact API names remain experimental.

---

# 28. External Media Playback

The external media application remains authoritative.

For example:

```text
User opens YouTube
       ↓
User presses Play in YouTube
       ↓
YouTube produces audio
       ↓
Android capture API captures eligible audio
       ↓
SoundMesh distributes captured frames
       ↓
Participants reproduce the audio
```

SoundMesh does not need to know that the user pressed Play.

It only observes captured audio becoming available.

---

# 29. Capture and Playback Boundary

Capture and Playback are separate responsibilities.

Capture:

```text
External App
     ↓
AudioPlaybackCapture
     ↓
PCM/audio frames
```

Playback:

```text
Audio frames
     ↓
Buffer
     ↓
Schedule
     ↓
Native output
```

Playback must not directly control or configure the external media application.

---

# 30. Synchronization Boundary

Synchronization answers:

```text
When should this audio be output?

What is the shared timeline?

How far is this device from the target?

How should timing be corrected?
```

Playback answers:

```text
Can I output this audio?

Can I schedule it?

Did the native output start?

What audio is buffered?

Did an underrun occur?

What was the observed output timing?

Did output fail?
```

Playback must not independently implement:

* clock synchronization
* offset estimation
* drift estimation
* drift correction
* group synchronization algorithms

---

# 31. Drift Handling

Playback may provide timing observations needed by Synchronization.

For example:

```text
actualOutputTimestamp
expectedOutputTimestamp
```

Synchronization may use those observations to determine drift.

Playback must not independently modify playback speed or timing to correct drift unless an explicit synchronization contract instructs it to do so.

---

# 32. Audio Route Changes

The output route may change:

```text
Built-in Speaker
      ↓
Bluetooth
```

or:

```text
Bluetooth
      ↓
Built-in Speaker
```

A route change may introduce a different output latency.

Playback must report observable route changes.

Synchronization may determine whether recalibration is required.

Playback must not assume route latency is unchanged.

---

# 33. Interruptions

Output may be interrupted by:

* phone calls
* system audio events
* application lifecycle changes
* audio-focus changes
* Bluetooth changes
* operating-system behavior

The Playback API should expose observable interruptions.

Recovery behavior remains:

**UNDECIDED**

Possible recovery:

```text
interrupted
    ↓
reinitialize / refill buffer
    ↓
resynchronize
    ↓
resume output
```

The exact behavior belongs to the recovery/synchronization contracts.

---

# 34. Background Operation

SoundMesh is expected to remain active while the user switches to an external media application.

Therefore the native audio/capture architecture must support the required Android lifecycle.

Playback must not assume that the Flutter UI remains foregrounded.

The exact foreground-service and lifecycle implementation belongs to the Android platform layer.

---

# 35. Flutter Boundary

Flutter should interact with the Playback API through a defined abstraction.

Conceptually:

```text
Flutter
   ↓
Core/Application
   ↓
Playback Abstraction
   ↓
Native Android Audio Output
```

High-frequency audio frames and timing-sensitive operations should remain outside ordinary Flutter UI state management.

Flutter must not:

* manipulate audio buffers
* schedule individual audio frames
* calculate synchronization offsets
* implement jitter buffering
* directly control native audio timing

---

# 36. Native Output

Timing-critical audio output should be implemented using appropriate Android native audio facilities.

Potential technologies include:

```text
AudioTrack
AAudio
Oboe
```

These are implementation options, not public API requirements.

The final technology must be selected based on:

* scheduling precision
* latency
* stability
* device compatibility
* measured performance
* implementation complexity

AI agents must not select a technology solely from assumption.

---

# 37. Output Errors

Potential structured errors include:

```text
OUTPUT_NOT_READY
OUTPUT_INITIALIZATION_FAILED
OUTPUT_UNAVAILABLE
OUTPUT_FORMAT_UNSUPPORTED
OUTPUT_ROUTE_UNAVAILABLE
OUTPUT_INTERRUPTED
OUTPUT_UNDERRUN
INVALID_GENERATION
STALE_FRAME
INVALID_FRAME
SCHEDULE_FAILED
SCHEDULE_CANCELLED
BUFFER_OVERFLOW
INTERNAL_ERROR
```

This taxonomy is currently:

**UNDECIDED**

Errors should contain structured information sufficient for Core/UI/Diagnostics.

UI code must not parse arbitrary error strings to determine behavior.

---

# 38. Playback Events

Potential events include:

```text
OUTPUT_READY
OUTPUT_BUFFERING
OUTPUT_SCHEDULED
OUTPUT_STARTED
OUTPUT_UNDERRUN
OUTPUT_INTERRUPTED
OUTPUT_STOPPED
OUTPUT_FAILED
OUTPUT_ROUTE_CHANGED
OUTPUT_FRAME_DROPPED
OUTPUT_GENERATION_CHANGED
```

The final event architecture is:

**UNDECIDED**

Event payloads must be contract-defined before implementation.

---

# 39. Stale Frame Protection

A frame from an old session must never be played in a newer session.

Example:

```text
Generation 20
Frames A/B/C

Session resets

Generation 21
Frames D/E/F

Old Frame B arrives
      ↓
Reject
```

This protection is mandatory.

---

# 40. Concurrent Operations

Operations may occur rapidly:

```text
initialize
schedule
flush
stop
restart
```

The implementation must prevent stale asynchronous work from affecting the active session.

Generation and cancellation mechanisms should be used.

Exact concurrency semantics remain:

**UNDECIDED**

AI agents must not invent a concurrency model when implementation decisions are required.

---

# 41. Flush Behavior

The output layer may need an operation conceptually equivalent to:

```text
flushOutput()
```

to discard buffered audio that is no longer valid.

Potential causes:

* session generation change
* synchronization reset
* route change
* unrecoverable underrun
* recovery
* session termination

Exact semantics remain:

**UNDECIDED**

A flush must not accidentally discard audio belonging to a newer generation.

---

# 42. Output Readiness

Output readiness is distinct from:

```text
Capture readiness
Network readiness
Buffer readiness
Synchronization readiness
Room readiness
```

Conceptually:

```text
Output READY
       +
Audio Available
       +
Buffer Sufficient
       +
Sync Schedule Valid
       =
Eligible for synchronized output
```

The exact readiness composition belongs to the Core/Synchronization contracts.

Playback must not claim that the entire room is ready based only on local output readiness.

---

# 43. Physical Timing Validation

Playback correctness must ultimately be validated on physical devices.

System-level synchronization targets are:

```text
Target:
≤ 20 ms group spread

Preferred:
≤ 10 ms
```

These are engineering targets, not guarantees.

Playback must not report synchronized success merely because frames were scheduled.

Actual synchronization evidence must come from physical timing measurements.

---

# 44. Contract Testing

Contract tests must cover at minimum:

### Initialization

```text
Output initializes correctly
Initialization does not automatically start playback
Unsupported formats are rejected
```

### Scheduling

```text
Audio can be scheduled for future output
Scheduled output executes at the requested timing
Scheduled output can be cancelled
Cancelled output cannot start later
```

### Buffering

```text
Frames enter the bounded buffer
Out-of-order frames are handled
Duplicate frames are handled
Missing frames are detectable
Buffer limits are enforced
```

### Generation

```text
Stale frames are rejected
Stale schedules cannot execute
Generation changes invalidate old output
```

### State

```text
Actual native state is reported
Underruns are observable
Interruptions are observable
Route changes are observable
```

### Output

```text
Audio reaches native output
Output can stop safely
Pending output is cancelled
Flush invalidates obsolete buffered audio
```

### Synchronization

```text
Playback consumes synchronization timing
Playback does not invent synchronization
Playback exposes timing observations
```

---

# 45. Real-Device Integration Testing

Playback must eventually be tested on physical Android devices.

Minimum target:

```text
2 physical phones
```

Then:

```text
3 phones
5 phones
10 phones
```

where practical.

Testing should include:

* live external-app audio
* synchronized output
* late frame arrival
* packet loss
* packet reordering
* jitter
* underruns
* session restart
* generation changes
* route changes
* Bluetooth
* interruptions
* background operation
* reconnection
* late joining
* long-duration sessions
* repeated start/stop
* synchronization recovery

---

# 46. AI Implementation Rules

AI agents implementing Playback functionality MUST:

1. Read this contract before modifying Playback code.
2. Read `audio.md`.
3. Read `synchronization.md`.
4. Read `architecture.md`.
5. Read `audio-api.md`.
6. Read `sync-api.md`.
7. Treat external media playback as outside SoundMesh ownership.
8. Preserve scheduled native output.
9. Never replace scheduled output with immediate frame playback.
10. Preserve generation protection.
11. Prevent stale audio from being played.
12. Preserve bounded buffering.
13. Report actual native output state.
14. Never fabricate timing measurements.
15. Never fabricate synchronization metrics.
16. Never implement synchronization logic inside Playback.
17. Add or update contract tests.
18. Validate timing on physical Android devices where applicable.
19. Document newly introduced behavior.
20. Never reintroduce file-based media playback APIs.

---

# 47. AI Stop Conditions

The agent MUST STOP and report a blocker when:

1. Scheduling semantics are required but undefined.
2. Output readiness requirements are undefined.
3. Generation behavior is unclear.
4. Frame lifecycle semantics are unclear.
5. Buffering semantics are unclear.
6. Route-change behavior affects synchronization but is undefined.
7. Actual output timing cannot be observed where required.
8. A requested feature requires controlling external media playback.
9. A requested feature requires changing Synchronization behavior.
10. A requested feature requires changing Audio API semantics.
11. A requested feature requires changing Room semantics.
12. Existing implementation contradicts this contract.
13. A new public Playback operation is required but unspecified.
14. The agent would need to invent timing behavior.
15. The agent would need to fabricate output state.
16. The agent would need to bypass scheduled output.
17. The agent would need to reintroduce audio-file ownership.

The agent must not resolve these conditions by guessing.

---

# 48. Contract Change Procedure

Any cross-subsystem Playback API change must document:

```text
Current Contract:

<existing behavior>

Proposed Change:

<new behavior>

Reason:

<why>

Affected Systems:

<Core / Audio / Sync / Room / Device / Networking>

Compatibility Impact:

<breaking or non-breaking>

Required Updates:

<code / tests / docs>

Decision:

UNDECIDED
```

Cross-subsystem changes require coordination before implementation.

---

# 49. Dependency Map

```text
                         ┌──────────────┐
                         │   Core API   │
                         └──────┬───────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  Playback API    │
                       └────────┬─────────┘
                                │
              ┌─────────────────┼─────────────────┐
              ▼                 ▼                 ▼
         Audio API          Sync API         Device API
              │                 │
              │                 │
              └────────┬────────┘
                       ▼
              Native Audio Output
                       │
                       ▼
              Physical Device
```

Live audio enters from Audio/Networking.

Timing instructions enter from Synchronization.

Playback turns those inputs into actual native audio output.

---

# 50. Relationship to Other Contracts

This contract must remain consistent with:

```text
DOCS/interfaces/README.md
DOCS/interfaces/core-api.md
DOCS/interfaces/room-api.md
DOCS/interfaces/device-api.md
DOCS/interfaces/audio-api.md
DOCS/interfaces/sync-api.md
DOCS/architecture.md
DOCS/audio.md
DOCS/synchronization.md
DOCS/networking.md
DOCS/testing.md
DOCS/contract-testing.md
DOCS/AI/rules.md
DOCS/AI/task-protocol.md
DOCS/AI/integration-protocol.md
```

---

# 51. Current Open Questions

The following remain intentionally unresolved:

```text
1. Exact PlaybackOutputState schema
2. Exact AudioFrame input schema
3. Exact generation semantics
4. Exact scheduling request schema
5. Scheduling margin
6. Exact jitter-buffer implementation
7. Buffer size and thresholds
8. Underrun handling
9. Missing-frame handling
10. Frame-loss concealment policy
11. Native Android audio implementation
12. Exact output timing source
13. Flutter/native communication model
14. Concurrency semantics
15. Cancellation semantics
16. Flush semantics
17. Audio-route recovery
18. Bluetooth behavior
19. Interruption recovery
20. Background-service integration
21. Exact error taxonomy
22. Exact event architecture
23. Host output latency compensation
24. Recovery after synchronization failure
```

These questions must remain explicit until resolved.

---

# 52. Definition of Done

Playback/output implementation is complete only when:

```text
□ Output state contract is defined
□ AudioFrame input contract is defined
□ Generation protection is implemented
□ Scheduled native output is implemented
□ Playback cannot bypass synchronization
□ Immediate frame playback is not used as the synchronization mechanism
□ Jitter buffering is implemented
□ Buffer bounds are enforced
□ Underruns are observable
□ Stale frames are rejected
□ Stale schedules are prevented
□ Output can be safely stopped
□ Pending output can be cancelled
□ Output can be flushed safely
□ Actual native output state is observable
□ Output timing is represented truthfully
□ Structured errors are implemented
□ Contract tests exist
□ Real-device integration tests exist
□ External-app live audio has been validated
□ Timing behavior has been physically measured
□ Documentation matches implementation
□ No undocumented public behavior exists
□ No fake timing metrics exist
□ No media-player ownership has been reintroduced
□ No file-distribution architecture has been reintroduced
□ Git diff has been reviewed
```

---

# 53. Final Principle

The Playback API answers:

> **“How does SoundMesh turn live audio frames and synchronization instructions into actual synchronized device output?”**

It does not answer:

> **“What song is playing?”**

The external media application owns that.

It does not answer:

> **“When should the group play?”**

Synchronization owns that.

It does not answer:

> **“How do devices communicate?”**

Networking owns that.

It does not answer:

> **“How is external audio captured?”**

Audio/Capture owns that.

It does not answer:

> **“Who belongs to the room?”**

Room owns that.

The fundamental boundary is:

```text
External Media App
        ↓
Capture provides live audio
        ↓
Networking carries live audio
        ↓
Sync provides timing
        ↓
Playback executes timing
        ↓
Device produces sound
```

**Audio provides the content.**

**Networking carries the content.**

**Sync provides the timing.**

**Playback executes the timing.**

**Room provides the participants.**

**The external media app owns media playback.**

The Playback API is the final execution boundary between SoundMesh's synchronized live-audio system and physical device audio output.
