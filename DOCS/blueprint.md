# SoundMesh — Product Blueprint

**Document status:** Living specification
**Document role:** Master product definition
**Authority:** This document defines what SoundMesh is, why it exists, what the MVP must accomplish, and the boundaries within which engineering decisions are made.

> **Important:** Technical implementation details belong primarily in the specialized documents under `DOCS/`. When this document conflicts with a specialized technical specification, the conflict must be resolved explicitly and recorded in `DOCS/decisions.md`. AI agents must not silently choose between conflicting requirements.

---

# 1. Product Identity

## 1.1 Name

**SoundMesh**

## 1.2 One-Sentence Description

SoundMesh is a local-first Android application that allows multiple nearby smartphones to synchronize their speakers and reproduce the host device's external-app audio together, turning a group of phones into a coordinated distributed speaker system.

## 1.3 Core Concept

A user may have several smartphones available but no physical speaker.

SoundMesh allows those phones to cooperate so that their built-in speakers reproduce the same live audio as a coordinated system.

The host does not need to import or select an audio file inside SoundMesh. Instead, the host may use an existing external media application such as YouTube, Spotify, VLC, a browser, or another compatible media player.

SoundMesh captures eligible audio produced by that external application on the host device, distributes the live captured audio to participating devices, and coordinates when that audio should be reproduced.

The central technical challenge is therefore not merely sending audio to multiple phones.

The central challenge is:

> **Coordinating independent mobile devices so that live audio remains perceptually synchronized despite differences in clocks, network conditions, capture latency, buffering, audio-output latency, hardware, and operating-system behavior.**

## 1.4 Core Product Statement

> **We had music, we had five phones, and we didn't have a speaker — so we built one.**

This statement captures the origin and intended simplicity of the product.

The user should experience SoundMesh as a simple way to make multiple phones behave like one speaker system, even though the underlying engineering is a distributed real-time audio system.

---

# 2. Problem Statement

## 2.1 User Problem

People sometimes have access to multiple smartphones but do not have access to a physical Bluetooth or wired speaker.

Individually, each phone can produce sound.

Collectively, several phones could provide greater audible coverage of a physical space.

However, independently playing the same external media on multiple phones is not sufficient because even small timing differences can produce:

* echoes
* flanging
* phase-related artifacts
* rhythmic smearing
* duplicated sound
* an unpleasant listening experience

SoundMesh addresses this by creating a synchronized live-audio path between participating devices.

Therefore the core problem is:

> **How can multiple independent smartphones reproduce live audio closely enough in time that listeners perceive them as one coordinated distributed speaker system?**

---

# 3. Product Goals

## 3.1 Primary Goal

Create an Android application that makes it extremely easy for a group of nearby phones to reproduce the host's external-app audio together with reliable, perceptually tight synchronization.

## 3.2 Secondary Goals

SoundMesh should aim to:

1. Require minimal setup.
2. Work primarily over local connectivity.
3. Avoid requiring a cloud service for ordinary sessions.
4. Support a host/participant room model.
5. Make joining a room fast and understandable.
6. Automatically handle timing calibration where technically feasible.
7. Stream live captured audio with bounded latency.
8. Continue functioning under realistic local-network conditions.
9. Handle participant joining, leaving, and temporary failures gracefully.
10. Provide useful diagnostics when synchronization cannot be maintained.
11. Make synchronization quality measurable rather than merely claimed.
12. Hide technical complexity from ordinary users.

## 3.3 Engineering Goal

The project should prioritize **synchronization quality and reliability over feature count**.

A smaller application with excellent synchronized audio is preferable to a feature-rich application with unreliable synchronization.

---

# 4. Non-Goals

The following are not core objectives of the MVP.

## 4.1 Physical Speaker Replacement

SoundMesh is not intended to reproduce the acoustic quality of a dedicated physical speaker.

It coordinates existing smartphone speakers.

## 4.2 Professional Multi-Room Audio

The MVP is not intended to compete with professional multi-room audio systems.

## 4.3 Long-Distance Streaming

The MVP is designed for nearby devices participating in a local group.

Internet-based long-distance synchronization is not a core requirement.

## 4.4 Music Streaming Service

SoundMesh is not a music catalog, streaming platform, or media-discovery service.

It does not own the media being played.

The external media application remains responsible for:

* media selection
* media playback
* playback controls
* seeking
* playback speed
* subtitles
* media formats
* content licensing
* media library functionality

SoundMesh is responsible for synchronizing the resulting audio session.

## 4.5 Media Player

SoundMesh is **not a media player**.

The MVP must not require:

* importing songs
* selecting local audio assets
* browsing a media library
* play/pause controls for the external media
* seek controls
* previous/next controls
* media-file management
* SoundMesh-owned playback position

The host controls the actual media using the external application.

## 4.6 File Distribution System

SoundMesh does not depend on distributing a complete audio file to every participant before playback.

The active-session architecture is based on **live captured-audio transport**.

File distribution, local audio caching, and asset synchronization are not required for the MVP.

## 4.7 Social Network

User profiles, followers, messaging, public rooms, feeds, and similar social features are outside the MVP.

## 4.8 Cloud Dependency

A remote server must not be required for the fundamental local session unless a later documented architectural decision determines that a specific cloud dependency is necessary.

## 4.9 Unlimited Device Support

The architecture should allow multiple devices to participate, but the MVP must establish a realistic, experimentally tested device-count target.

---

# 5. Target User Experience

## 5.1 Desired Experience

A user should be able to:

1. Open SoundMesh.
2. Create a room.
3. Display a simple join mechanism such as a QR code.
4. Have nearby devices join the room.
5. Allow SoundMesh to establish communication and synchronization.
6. Grant the required audio-capture permission on the host.
7. Switch to the external media application of their choice.
8. Play music, video, or other compatible media normally.
9. Have SoundMesh capture eligible host audio.
10. Hear participating phones reproduce that audio together.
11. Add or remove devices without unnecessarily disrupting the session.

The external media application remains the source of truth for what media is actually playing.

SoundMesh synchronizes the **audio produced by that application**, not the application's user interface or media state.

## 5.2 Simplicity Requirement

Users should not need to understand:

* clock synchronization
* network latency
* buffering
* timestamps
* drift correction
* device clock offsets
* packet timing
* sample rates
* capture latency
* output latency
* audio session configuration

Those concepts belong to the implementation.

The product should hide technical complexity wherever possible.

---

# 6. Core Product Model

SoundMesh consists conceptually of:

```text
              HOST PHONE
┌───────────────────────────────────┐
│ External Media App                │
│ YouTube / Spotify / VLC / Browser │
└─────────────────┬─────────────────┘
                  │
                  ▼
       Android AudioPlaybackCapture
                  │
                  ▼
          Live Captured Audio
                  │
                  ▼
          SoundMesh Host
                  │
                  │ Local Network
                  ▼
       ┌──────────┼──────────┐
       │          │          │
       ▼          ▼          ▼
   Phone A    Phone B    Phone C
   Speaker    Speaker    Speaker
```

The exact network topology is defined by `DOCS/networking.md` and `DOCS/architecture.md`.

The product blueprint intentionally does not permanently mandate a specific transport protocol.

---

# 7. Fundamental Audio Model

## 7.1 External Media Is the Source of Truth

The host's external media application owns the actual media experience.

For example:

```text
YouTube
Spotify
VLC
Browser
Downloaded video player
        │
        ▼
Host device audio output
        │
        └──► SoundMesh capture path
```

SoundMesh does not need to know which song, video, stream, or media file is being played.

It operates on the resulting eligible audio signal.

## 7.2 Live Audio Capture

The Android host captures eligible external application audio using the platform's supported audio-capture mechanism.

Conceptually:

```text
External App
     ↓
AudioPlaybackCapture
     ↓
Captured audio frames
     ↓
Timestamp + sequence number
     ↓
Live network transport
     ↓
Participant jitter buffer
     ↓
Scheduled native output
```

Capture availability depends on Android platform rules, permissions, and whether the source application permits capture.

The product must therefore gracefully handle sources that cannot be captured.

## 7.3 Live Streaming Is the Active-Session Model

During an active SoundMesh session, audio is treated as a live stream.

The system must account for:

* packetization
* timestamps
* sequence numbers
* buffering
* jitter
* packet loss
* packet reordering
* backpressure
* bounded latency
* stream interruption
* capture interruptions
* output underruns

The exact transport and audio representation are implementation decisions documented separately.

## 7.4 Host Output Latency

A critical product constraint is that the host may hear audio directly through the external application's normal audio path while participants hear captured and replayed audio through SoundMesh.

These paths can have different latencies.

Therefore:

> **Synchronizing participant devices with one another is not automatically sufficient to synchronize them with the sound physically produced by the host phone.**

The system must experimentally measure and account for relevant capture, transport, buffering, and output latency.

The exact host-output strategy remains an engineering decision and must not be silently assumed.

## 7.5 SoundMesh Does Not Own Media Playback

SoundMesh may control the lifecycle of its **audio synchronization session**, but it does not control the external media application.

SoundMesh must not become responsible for:

* selecting media
* starting the external song
* pausing the external song
* seeking the external song
* changing playback speed
* changing the media position

The user performs those actions in the external application.

---

# 8. Synchronization Is the Core Technology

Synchronization is the defining technical problem of SoundMesh.

The system must not assume that receiving or processing the same audio data at approximately the same time results in simultaneous audible playback.

Each device has its own:

* hardware
* monotonic clock
* audio subsystem
* capture/output pipeline
* buffering behavior
* processing latency
* network latency
* operating-system scheduling
* audio route

Therefore SoundMesh requires an explicit synchronization strategy.

## 8.1 Synchronization Objectives

The synchronization system should investigate and, where technically feasible, implement:

* device clock offset estimation
* network latency measurement
* timestamp exchange
* capture timestamping
* output timestamping
* synchronized future output scheduling
* startup calibration
* jitter buffering
* drift detection
* drift correction
* recovery after temporary network disruption
* late-joining synchronization
* audio-route change handling
* interruption handling

## 8.2 Perceptual Synchronization

The product should target synchronization sufficiently close for listeners to perceive the devices as a coordinated sound source.

The project must **not** claim mathematically perfect synchronization without measurements supporting such a claim.

Acceptance thresholds must be experimentally determined and documented in `DOCS/synchronization.md` and `DOCS/testing.md`.

## 8.3 Synchronization Must Be Measured

The system should expose meaningful timing information during development, including where practical:

* estimated inter-device output offset
* capture-to-network latency
* network-to-output latency
* buffer depth
* clock offset
* drift
* correction magnitude
* synchronization error

---

# 9. Device Roles

## 9.1 Host

The host coordinates the room and live audio session.

The host may be responsible for:

* creating the room
* coordinating joining
* maintaining room/session state
* distributing session configuration
* initiating the live audio session
* providing the captured audio stream
* establishing shared timing information
* coordinating synchronization targets
* monitoring participants
* coordinating recovery

The host should not necessarily perform every computational task if doing so creates an unnecessary bottleneck.

The host is the room authority, but it is not automatically assumed to be the perfect physical audio clock.

## 9.2 Participant

A participant contributes its phone speaker to the SoundMesh session.

A participant should:

* join the room
* establish communication
* receive session configuration
* synchronize timing
* receive live audio frames
* buffer incoming audio
* schedule native audio output
* report relevant synchronization state
* respond to synchronization corrections
* handle temporary connection loss
* recover from interruptions
* leave the session gracefully

---

# 10. Room Model

A SoundMesh room represents a group of devices participating in a session.

A room should have:

* a unique room/session identifier
* a host
* participating devices
* session generation
* capture/session state
* synchronization state
* connection state
* live audio stream state

The exact protocol belongs in `DOCS/networking.md`.

## 10.1 Room Lifecycle

Conceptually:

```text
CREATED
   ↓
DISCOVERABLE
   ↓
JOINING
   ↓
READY
   ↓
CAPTURE_PERMISSION_REQUIRED
   ↓
CAPTURING
   ↓
STREAMING
   ↓
SYNCHRONIZING
   ↓
ACTIVE
   ↓
DEGRADED / RECOVERING
   ↓
ACTIVE
   ↓
ENDING
   ↓
CLOSED
```

The exact state machine must be defined technically before complex session behavior is implemented.

## 10.2 External Media Stopping

If the external media application stops producing capturable audio, SoundMesh must not pretend that it has paused a media player.

Instead, SoundMesh should represent the relevant capture/session condition, such as:

* no capturable audio currently detected
* capture interrupted
* source changed
* capture stopped
* stream inactive

The external application remains responsible for its own playback state.

---

# 11. Joining a Room

Joining should be intentionally simple.

A preferred MVP UX direction is a QR code.

Conceptually:

```text
Host
 ↓
Create Room
 ↓
Display QR / Join Code
 ↓
Participant Scans
 ↓
Connect
 ↓
Synchronize
 ↓
Ready
```

The join payload may contain information such as:

* protocol version
* room identifier
* host connection information
* short-lived join credential

The exact contents belong in `DOCS/networking.md`.

---

# 12. Audio Session

SoundMesh treats the audio session as a first-class system component.

The audio subsystem must account for:

* Android external-audio capture
* capture permission
* source-app capture compatibility
* captured audio format
* sample rate
* channel configuration
* frame timing
* buffering
* jitter
* network delivery
* native output
* output latency
* audio route changes
* interruptions
* foreground/background behavior
* capture revocation
* output failures

These details belong in `DOCS/audio.md`.

## 12.1 Capture Permission

The host must explicitly grant the platform permissions required for external-audio capture.

If permission is denied, the session must clearly communicate that audio capture cannot begin.

## 12.2 Capture Compatibility

Not every external application or audio source is guaranteed to permit capture.

SoundMesh must detect and communicate capture incompatibility instead of silently presenting a broken session.

## 12.3 Background Operation

SoundMesh is intended to remain active while the host uses another application.

Where Android requires a foreground service or persistent notification for continued capture/session operation, the implementation must follow the applicable platform requirements.

The user should understand when SoundMesh is actively capturing audio.

---

# 13. Networking Principles

SoundMesh should follow these principles.

### Local-first

The fundamental experience should work using nearby connectivity whenever technically feasible.

### No mandatory Internet

The core local session should not depend on Internet access.

### Live audio

Active audio sessions require live captured-audio transport.

### Separation of responsibilities

Networking should logically separate:

* control traffic
* live audio traffic
* timing traffic

These may share a physical connection where practical, but the logical responsibilities must remain distinct.

### Resilience

Temporary network problems should not unnecessarily destroy an entire session.

### Bounded latency

Live audio must not accumulate unbounded buffering simply to avoid packet loss.

### Measurability

Networking behavior relevant to synchronization must be measurable rather than assumed.

Detailed requirements belong in `DOCS/networking.md`.

---

# 14. Synchronization Principles

The synchronization system should follow these principles:

1. Never assume device clocks are identical.
2. Never assume network latency is zero.
3. Never assume network latency is constant.
4. Never assume audio capture latency is identical.
5. Never assume audio-output latency is identical.
6. Prefer scheduled future output over reacting to packet arrival time.
7. Measure timing wherever practical.
8. Correct drift rather than assuming alignment remains perfect.
9. Design for heterogeneous devices.
10. Keep timing-critical work outside Flutter's UI frame loop.
11. Make synchronization state observable during development.
12. Establish measurable acceptance criteria through testing.

Detailed synchronization architecture belongs in `DOCS/synchronization.md`.

---

# 15. Heterogeneous Device Requirement

SoundMesh must be designed for phones with different:

* CPU performance
* RAM capacity
* speaker hardware
* Android versions
* audio hardware
* sample rates
* capture pipelines
* output latency
* network hardware
* Wi-Fi performance
* battery states
* thermal conditions

Testing on only one device is insufficient evidence that the synchronization architecture works.

The system must therefore be tested across multiple physical Android devices where available.

---

# 16. Failure Handling

SoundMesh must assume that failures will happen.

Potential failures include:

* participant disconnects
* host disconnects
* Wi-Fi changes
* network temporarily becomes unavailable
* device locks
* application loses foreground status
* foreground service is interrupted
* audio output route changes
* another application interrupts audio
* capture permission is denied
* MediaProjection is revoked
* source application refuses capture
* captured audio format is unsupported
* capture stops unexpectedly
* device becomes overloaded
* audio stream experiences packet loss
* audio stream experiences packet reordering
* jitter buffer underruns
* participant joins too late
* synchronization calibration fails
* clock estimation becomes stale
* playback output drifts
* participant temporarily loses connectivity

The application must define expected behavior for important failure conditions.

No AI developer should invent failure behavior silently.

If behavior is undecided, it must be marked as `UNDECIDED` and recorded in the appropriate documentation.

---

# 17. MVP Definition

The MVP should demonstrate the fundamental SoundMesh thesis.

## 17.1 Required MVP Capability

The MVP must be capable of:

* creating a local room
* joining a local room
* identifying participating devices
* operating without mandatory Internet connectivity
* establishing communication between devices
* obtaining the required host capture permission
* capturing eligible external-app audio
* transporting live captured audio to participants
* preserving frame sequence/timing information
* buffering incoming audio on participants
* producing audio through native output
* synchronizing output across at least two physical devices
* monitoring synchronization quality
* handling basic drift
* handling basic connection/capture failures
* displaying basic connection/session state
* ending a session cleanly

The MVP does **not** require SoundMesh to import, store, or distribute a complete media file.

## 17.2 MVP Platform

The MVP is **Android-only**.

This is an intentional product boundary because the core experience depends on Android's supported external-audio capture capabilities.

Future platform support may be investigated separately.

## 17.3 MVP Device Target

The first engineering milestone should prioritize:

**2 physical Android devices**

before attempting larger groups.

Once two-device synchronization is reliable, testing should expand to:

**3 → 5 → larger tested groups**

The exact maximum target must be determined experimentally.

## 17.4 MVP Success

The MVP is not successful merely because:

> "The audio reaches both phones."

It is successful when:

> **"The phones reproduce the same live audio closely enough that the result is perceptually coherent, while remaining reliable under realistic local conditions."**

---

# 18. Quality Requirements

SoundMesh should prioritize:

### Reliability

A normal session should not require repeated manual reconnection or timing adjustment.

### Synchronization

The system should maintain synchronization within a measured, documented target.

### Simplicity

The user should not need technical knowledge to create or join a session.

### Transparency

When something fails, the application should communicate the state clearly rather than silently appearing broken.

### Performance

The synchronization system should avoid unnecessary CPU, memory, battery, and network consumption.

### Maintainability

Networking, synchronization, audio capture/output, session state, and UI should be modular enough to develop and test independently.

### Compatibility

The application should clearly communicate when an external audio source or Android configuration is unsupported.

---

# 19. Measurement and Validation

SoundMesh must be treated as an engineering experiment as well as an application.

Important claims must be measurable.

Potential measurements include:

* estimated inter-device output offset
* synchronization error over time
* startup synchronization error
* synchronization error after correction
* capture latency
* network round-trip time
* network jitter
* packet loss
* packet sequence gaps
* jitter-buffer depth
* audio underruns
* calibration duration
* join duration
* recovery time
* CPU usage
* memory usage
* battery impact
* maximum reliably tested device count

The exact methodology must be defined in:

`DOCS/testing.md`

and, for timing-specific measurements:

`DOCS/synchronization.md`.

---

# 20. Product Differentiation

The basic concept of synchronizing multiple phones as speakers is not itself assumed to be novel.

SoundMesh should therefore not depend on novelty of the basic concept.

Potential differentiation areas include:

* extremely simple onboarding
* live external-app audio capture
* automated synchronization
* automatic latency calibration
* synchronization across heterogeneous phones
* local-first operation
* QR-based room setup
* resilient session management
* drift detection and correction
* synchronization diagnostics
* measurable engineering results
* graceful recovery from network and device problems
* architecture optimized for consumer smartphones

These are product and engineering hypotheses and must be validated through testing and competitive research.

---

# 21. Competitive Awareness

Existing applications and prior projects demonstrate that multi-device synchronized audio is an established concept.

Therefore the development team must not make unsupported claims such as:

* "SoundMesh is the first app to do this."
* "Nobody has ever built this."
* "This technology has never been attempted."

Unless such a claim has been specifically researched and verified, it must not appear in product materials.

The project should instead emphasize:

* implementation quality
* synchronization engineering
* user experience
* reliability
* measured results
* the specific problem SoundMesh solves

Competitive research belongs in the appropriate project documentation and should be updated when significant competitors are identified.

---

# 22. Security and Privacy Principles

SoundMesh should follow a local-first privacy model where practical.

The MVP should minimize unnecessary collection of:

* personal information
* user accounts
* location information
* usage analytics
* cloud-stored audio
* persistent device-identifying information

Communication should protect room membership against unintended access.

The system should use appropriate authenticated/encrypted mechanisms rather than implementing custom cryptography.

Detailed security requirements belong in the networking documentation once the transport architecture is finalized.

---

# 23. Architecture Constraints

The implementation should avoid unnecessary complexity.

The team should prefer:

* simple protocols
* explicit state machines
* measurable behavior
* modular components
* well-defined interfaces
* deterministic behavior where practical
* local processing
* bounded buffering
* native timing-critical processing

The team should avoid:

* premature microservices
* unnecessary cloud infrastructure
* unnecessary authentication systems
* unnecessary databases
* feature creep
* speculative abstractions
* unnecessary dependencies
* turning SoundMesh into a media player
* making file distribution a hidden dependency of the live-audio architecture
* pushing high-frequency audio data through Flutter UI mechanisms

---

# 24. Technology Decision Policy

The blueprint does **not** permanently mandate a specific:

* networking transport
* audio representation
* codec
* native audio engine
* synchronization algorithm
* state-management library
* discovery mechanism

These decisions must be made after technical investigation.

Every significant architectural decision should document:

1. The problem.
2. Candidate approaches.
3. Evidence.
4. Advantages.
5. Disadvantages.
6. Constraints.
7. Chosen approach.
8. Reason for choosing it.
9. Consequences.
10. What would cause the decision to be reconsidered.

Significant decisions belong in:

`DOCS/decisions.md`

---

# 25. Documentation Authority

The project documentation has specialized responsibilities.

| Document              | Responsibility                                              |
| --------------------- | ----------------------------------------------------------- |
| `blueprint.md`        | Product definition and overall requirements                 |
| `architecture.md`     | System architecture and component relationships             |
| `synchronization.md`  | Timing and synchronization engineering                      |
| `networking.md`       | Device communication and live-audio networking              |
| `audio.md`            | External-audio capture, audio processing, and native output |
| `ui-ux.md`            | Interface and user experience                               |
| `testing.md`          | Testing strategy and validation                             |
| `decisions.md`        | Architectural and technical decisions                       |
| `roadmap.md`          | Development phases and milestones                           |
| `AI/ai-context.md`    | High-value project context for AI developers                |
| `AI/rules.md`         | Rules AI developers must follow                             |
| `AI/task-protocol.md` | Standard workflow for AI-generated development tasks        |

The root `AGENTS.md` provides the operational rules that AI coding agents must follow inside the repository.

---

# 26. Requirement Status Vocabulary

To prevent AI developers from treating assumptions as facts, requirements should use explicit status terminology.

### `REQUIRED`

Must be implemented.

### `PREFERRED`

Strongly desired, but may be changed if technical evidence demonstrates a better approach.

### `OPTIONAL`

May be implemented if time and architecture permit.

### `UNDECIDED`

Not yet determined.

AI agents must not silently convert `UNDECIDED` requirements into implementation decisions.

### `REJECTED`

Explicitly ruled out.

### `EXPERIMENTAL`

Being investigated or prototyped and not yet part of the stable architecture.

---

# 27. Change Management

This blueprint is a living document.

When an important product requirement changes:

1. Update this document.
2. Identify affected specialized documentation.
3. Update affected documents.
4. Record the decision in `DOCS/decisions.md` when appropriate.
5. Check whether implementation tasks or roadmap items are now obsolete.
6. Inform active developers/AI agents of the change.

AI agents must not modify product requirements merely to make their implementation easier.

A change that alters the fundamental audio model must be treated as an architectural change rather than a normal implementation detail.

---

# 28. Definition of Done for the Product Blueprint

This document should be considered sufficiently mature when:

* the core problem is unambiguous
* the product's purpose is unambiguous
* the external-media relationship is unambiguous
* the live-audio architecture is unambiguous
* MVP platform boundaries are clear
* major non-goals are explicit
* synchronization is identified as a core engineering problem
* networking responsibilities are clear
* audio-capture responsibilities are clear
* failure handling is recognized
* measurable quality requirements exist
* important unknowns are explicitly marked
* specialized documentation responsibilities are defined
* AI developers can understand the product without guessing its fundamental purpose

---

# 29. Current Open Questions

The following questions must be answered through research, experiments, or explicit architectural decisions.

1. Which exact Android versions should the MVP support?
2. Which local networking transport provides the required reliability and latency?
3. Which audio representation should be transported: PCM, compressed audio, or another representation?
4. What frame size and packetization strategy provide acceptable latency?
5. How should packet loss, reordering, and jitter be handled?
6. How should the participant jitter buffer be sized and controlled?
7. Which external applications permit Android audio playback capture reliably?
8. How should capture-denied or capture-incompatible sources be communicated?
9. How should host direct-output latency be measured?
10. How should host and participant output paths be aligned?
11. What synchronization error is perceptually acceptable?
12. How should synchronization be measured objectively?
13. How should device clock offsets be estimated?
14. How should drift be detected?
15. How should drift be corrected without producing audible artifacts?
16. What happens when a participant joins after a live stream has already started?
17. How should a participant recover after temporary network loss?
18. What happens if the host disconnects?
19. What happens when Android revokes or interrupts capture?
20. What happens when the audio output route changes?
21. What background/foreground-service behavior is required for the supported Android versions?
22. What is the maximum reliably supported device count for the MVP?
23. What CPU, memory, battery, and network usage are acceptable?
24. What security mechanism should protect room membership?
25. What technical claims can be experimentally demonstrated for the final submission?

These questions must be resolved in the appropriate technical documents before they become hidden assumptions in implementation.

---

# 30. Guiding Principle

SoundMesh should always optimize for:

> **Make multiple independent phones behave like one coordinated speaker system, while hiding the complexity required to make that happen.**

The product should feel simple because the engineering underneath it is rigorous.

> **The user should control their media normally. SoundMesh should synchronize the sound.**

**User experience should feel effortless.
Engineering should not be.**
