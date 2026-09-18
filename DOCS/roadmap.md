# SoundMesh — Engineering Roadmap

**Document Status:** REQUIRED
**Document Type:** Engineering Roadmap / Build Plan
**Applies To:** Entire SoundMesh repository
**Primary Authority:** Development sequencing, milestones, dependencies, and scope

**Related Documents:**

* `DOCS/blueprint.md`
* `DOCS/architecture.md`
* `DOCS/networking.md`
* `DOCS/synchronization.md`
* `DOCS/audio.md`
* `DOCS/ui-ux.md`
* `DOCS/decisions.md`
* `DOCS/testing.md`
* `DOCS/AI/ai-context.md`
* `DOCS/AI/rules.md`
* `DOCS/AI/task-protocol.md`
* `AGENTS.md`

---

# 1. Purpose

This document defines the recommended development order for SoundMesh.

The roadmap exists to prevent the project from becoming:

* UI-first
* feature-heavy
* architecture-heavy without proof
* difficult to debug
* overloaded with speculative infrastructure
* focused on low-risk features while the core technical risk remains unproven

SoundMesh must be built in an order that attacks the highest-risk assumptions first.

---

# 2. Core Roadmap Principle

The project follows:

> **Prove the hardest technical assumption first, then build the product around the proven system.**

For the current SoundMesh architecture, the highest-risk question is:

> **Can SoundMesh capture eligible external-app audio on Android, transport that live audio between nearby devices, and produce sufficiently synchronized physical audio output across heterogeneous phones?**

This is substantially different from the previous file-distribution architecture.

SoundMesh no longer depends on:

* transferring an audio file
* storing a shared audio asset
* decoding the same file on every device
* SoundMesh-owned media playback
* synchronized play/pause/seek commands

The external media application is now the source of truth for media playback.

SoundMesh synchronizes the **live sound produced by that external application**.

---

# 3. Development Strategy

The roadmap follows:

```text
Repository Foundation
        ↓
Flutter / Native Foundation
        ↓
Android Capture Feasibility
        ↓
Two-Device Local Networking
        ↓
Room + QR Bootstrap
        ↓
Live Audio Transport
        ↓
Native Audio Output
        ↓
End-to-End Capture Pipeline
        ↓
Clock Synchronization
        ↓
Two-Device Synchronization
        ↓
Drift Detection / Correction
        ↓
Multi-Device Scaling
        ↓
Failure Recovery
        ↓
Full Product UX
        ↓
Physical Validation
        ↓
Performance / Reliability
        ↓
Competition Hardening
```

The roadmap deliberately brings **external-audio capture and live transport forward** because these are fundamental architectural risks.

---

# 4. Phase 0 — Repository Foundation

**Status:** REQUIRED

## Objective

Create a clean engineering foundation before implementing product functionality.

## Tasks

* initialize repository structure
* establish branches
* establish documentation
* establish `AGENTS.md`
* establish AI development rules
* configure formatting
* configure linting
* configure basic testing
* establish package/project naming
* establish development conventions
* establish issue/task conventions

## Expected Result

The repository is ready for multiple developers and AI coding agents.

## Exit Criteria

* repository builds
* project structure is understood
* documentation is accessible
* AI agents have repository instructions
* basic CI/static checks exist where practical

---

# 5. Phase 1 — Flutter Application Shell

**Status:** REQUIRED

## Objective

Create the smallest working Flutter application.

## Tasks

* initialize Flutter project
* configure Android
* establish app entry point
* establish basic navigation
* establish theme
* establish design tokens
* create placeholder screens

## Initial Screens

```text
Home
Create Room
Join Room
Room
Settings
Diagnostics
```

These do not need complete functionality yet.

The MVP platform target is Android.

iOS is not a required implementation target for the current architecture because arbitrary external-app audio capture is not part of the MVP.

## Exit Criteria

* application launches
* navigation works
* theme is applied
* Android build works
* design foundation exists

---

# 6. Phase 2 — Native Android Bridge

**Status:** REQUIRED

## Objective

Establish a clean Flutter-to-native boundary for functionality that cannot safely live entirely in Flutter.

Conceptually:

```text
Flutter
   ↓
Typed interface
   ↓
Native Android
```

## Initial Native Capabilities

The bridge should eventually expose controlled interfaces for:

* device information
* native timing
* networking
* audio capture
* audio output
* session state

Do not implement the entire system at once.

## Important Rule

Realtime audio and timing-critical operations must remain native.

Flutter must not become the realtime audio processing or scheduling layer.

## Exit Criteria

A simple typed Flutter → native → Flutter operation works reliably.

---

# 7. Phase 3 — Android External-Audio Capture Feasibility

**Status:** CRITICAL / HIGHEST EARLY RISK

## Objective

Prove that SoundMesh can capture eligible external-app audio on real Android hardware.

This phase exists **before building the complete audio pipeline**.

## Core Experiment

```text
External Media App
        ↓
Android AudioPlaybackCapture
        ↓
Captured Audio Frames
        ↓
Local inspection
```

## Tasks

Implement the smallest possible native capture prototype that can:

* request required user permission
* create the MediaProjection session
* configure AudioPlaybackCapture
* capture eligible external-app audio
* inspect captured frames
* report capture format
* report capture timestamps where available
* detect capture interruption
* stop capture cleanly

## Test Sources

Test multiple real applications where permitted, for example:

* YouTube
* VLC
* Spotify
* browser-based media

Do not assume every application allows capture.

## Required Failure Cases

Test:

* permission denied
* permission revoked
* source application refuses capture
* capture becomes unavailable
* unsupported format
* capture interruption
* route changes
* application backgrounding

## Exit Criteria

At least one eligible external audio source can be captured reliably on physical Android hardware.

The capture pipeline must produce inspectable audio frames.

If Android capture limitations prevent the required product behavior, the architecture must be reconsidered before substantial downstream work continues.

---

# 8. Phase 4 — Local Networking Foundation

**Status:** CRITICAL

## Objective

Prove that nearby physical Android devices can establish reliable local connections.

## First Target

Two physical devices.

## Flow

```text
Host
 ↓
Create room
 ↓
Expose connection information
 ↓
Participant
 ↓
Connect
 ↓
Handshake
```

## Basic Messages

```text
PING
PONG
HELLO
WELCOME
```

## Do Not Build Yet

* live audio transport
* complex discovery
* cloud infrastructure
* large-room management
* advanced authentication
* unnecessary network abstraction

## Existing Verification

The original two-device networking spike has already been verified on physical Android hardware in both host and participant role directions.

TCP hosting, connection, and structured message exchange were confirmed after resolving:

* main-thread dispatch for Pigeon Flutter API callbacks
* hosting-socket idempotency/generation guards
* frame-parser state corruption caused by payload-length state being reused across header/payload phases

iOS remains structurally implemented but untested and is not an MVP requirement.

## Exit Criteria

Two physical Android devices reliably connect and exchange structured messages over the intended local network.

---

# 9. Phase 5 — Room Protocol

**Status:** REQUIRED

## Objective

Turn the networking foundation into an actual SoundMesh room.

## Implement

* room ID
* participant ID
* session ID
* host state
* participant state
* protocol version
* message IDs
* generation numbers
* connection state
* capture/session state
* room lifecycle

## Basic Room Lifecycle

```text
CREATED
   ↓
DISCOVERABLE
   ↓
JOINING
   ↓
READY
   ↓
CLOSED
```

The production state machine will later expand to represent active audio sessions and recovery.

## Exit Criteria

Two devices can join and maintain a valid room state.

---

# 10. Phase 6 — QR Room Bootstrap

**Status:** REQUIRED

## Objective

Replace technical connection setup with the intended user experience.

## Flow

```text
Host
 ↓
Create Room
 ↓
Display QR

Participant
 ↓
Join Room
 ↓
Scan QR
 ↓
Connect
```

## Requirements

* QR generation
* QR parsing
* protocol-version validation
* room identification
* short-lived join information
* invalid QR handling
* expired token handling
* connection failure handling

## Exit Criteria

A participant can join a room without manually entering an IP address.

---

# 11. Phase 7 — Live Audio Transport

**Status:** CRITICAL

## Objective

Transport captured audio frames from the host to participants in realtime.

This replaces the obsolete audio-file distribution pipeline.

## Flow

```text
Host Capture
     ↓
Captured Frames
     ↓
Timestamp
     ↓
Sequence Number
     ↓
Packetization
     ↓
Local Audio Transport
     ↓
Participant
```

## Conceptual Frame

```text
AudioFrame {
    sessionGeneration
    sequenceNumber
    captureTimestamp
    sampleFormat
    sampleRate
    channels
    payload
}
```

The exact wire representation remains implementation-defined.

## Requirements

* frame sequencing
* timestamps
* bounded buffering
* packet framing
* packet loss detection
* reordering detection
* jitter measurement
* backpressure
* stream start/stop
* stream configuration
* stream statistics

## Transport

The exact transport is not permanently decided by this roadmap.

Candidate approaches may include:

* TCP
* WebSocket
* UDP-based transport
* QUIC
* another suitable local streaming mechanism

The decision must be driven by measurements.

A live-audio transport must avoid allowing control traffic or unrelated congestion to introduce unacceptable audio latency.

## Exit Criteria

One host can transmit captured live audio frames to one participant over the local network with measurable latency and sequence integrity.

---

# 12. Phase 8 — Native Synchronized Audio Output

**Status:** CRITICAL

## Objective

Prove that participant devices can turn received audio frames into stable native audio output.

## Requirements

* native audio output
* audio buffer
* jitter buffer
* frame scheduling
* output timestamps
* underrun detection
* route detection
* output-state reporting

## Flow

```text
Received Frames
      ↓
Jitter Buffer
      ↓
Timing / Scheduling
      ↓
Native Audio Output
```

## Important

Do not attempt to hide this pipeline inside Flutter.

Realtime audio output must remain native.

## Exit Criteria

A physical Android participant can receive test audio frames and output them reliably through its native audio system.

---

# 13. Phase 9 — End-to-End Capture Pipeline

**Status:** MILESTONE

## Objective

Connect the actual host capture system to the participant output system.

## Full Flow

```text
External Media App
        ↓
AudioPlaybackCapture
        ↓
Captured Frames
        ↓
Timestamp + Sequence
        ↓
Audio Transport
        ↓
Participant Jitter Buffer
        ↓
Native Audio Output
```

## Test

Host:

```text
External media app plays audio
```

Participant:

```text
Receives and outputs the captured audio
```

## Measure

* capture latency
* transport latency
* jitter
* buffer fill
* output latency
* underruns
* dropped frames
* sequence gaps

## Exit Criteria

A real external audio source on the host can be heard on a participant through the complete SoundMesh pipeline.

This is a major proof milestone.

---

# 14. Phase 10 — Monotonic Clock and Clock Synchronization

**Status:** CRITICAL

## Objective

Create a measurable timing relationship between participating devices.

## Implement

* monotonic timestamps
* timestamp exchange
* RTT calculation
* clock-offset estimation
* multiple measurements
* outlier rejection
* timing uncertainty
* confidence

## Test

Run repeated measurements between two physical Android devices.

## Exit Criteria

The system produces a stable and inspectable timing relationship.

---

# 15. Phase 11 — Audio Timing and Calibration

**Status:** CRITICAL

## Objective

Measure the timing differences that matter specifically to live audio.

Clock synchronization alone is insufficient.

The system must account for:

* capture timing
* network timing
* participant buffering
* output scheduling
* output-device latency
* host direct-output latency

## Critical Model

The host may hear the external application's audio directly while participants hear captured and replayed audio.

Therefore:

```text
Host external output
        ↓
      latency A

Host capture
        ↓
Network
        ↓
Participant buffer
        ↓
Participant output
        ↓
      latency B
```

SoundMesh must measure the relevant difference.

## Objective

Determine whether the host's direct output and participant output can be aligned sufficiently for the intended experience.

## Exit Criteria

The system has measurable timing information for the capture-to-output pipeline and can establish an experimentally validated synchronization target.

---

# 16. Phase 12 — Shared Live-Audio Timeline

**Status:** CRITICAL

## Objective

Create a shared timeline for live audio frames.

Instead of:

```text
PLAY
```

the system works conceptually as:

```text
Captured frame
      ↓
Capture timestamp
      ↓
Shared timeline
      ↓
Future output target
      ↓
Native scheduled output
```

Participants should receive enough buffered audio to schedule output against a future target rather than immediately outputting every received packet.

## Exit Criteria

Two devices can use the shared timing model to schedule captured live audio toward a common timeline.

---

# 17. Phase 13 — Two-Device External-Audio Synchronization

**Status:** MILESTONE 1 / HIGHEST PRODUCT PROOF

## Objective

Prove the complete SoundMesh concept with two physical Android devices.

## Full Flow

```text
Host creates room
        ↓
Participant scans QR
        ↓
Connect
        ↓
Capture permission
        ↓
External media app
        ↓
Live audio capture
        ↓
Audio stream
        ↓
Participant buffering
        ↓
Clock calibration
        ↓
Timing calibration
        ↓
Shared live-audio timeline
        ↓
Scheduled native output
        ↓
Physical synchronization measurement
```

## Exit Criteria

Two physical Android devices demonstrate repeatable, perceptually coherent synchronized audio from an external media source.

## Required Evidence

Record:

* application version
* device models
* Android versions
* source application
* source audio
* network conditions
* calibration results
* synchronization measurements
* repeated runs
* anomalies
* failure cases

This is the first definitive proof that the actual SoundMesh architecture works.

---

# 18. Phase 14 — Drift Detection

**Status:** REQUIRED

## Objective

Detect gradual divergence between devices during a live session.

## Implement

* output timing monitoring
* drift estimation
* synchronization error calculation
* health state
* threshold detection

## States

```text
SYNCHRONIZED
DEGRADED
RECOVERING
RESYNC_REQUIRED
```

## Exit Criteria

The system can detect synchronization degradation during an active live-audio session.

---

# 19. Phase 15 — Drift Correction

**Status:** REQUIRED

## Objective

Correct gradual timing divergence without destabilizing the audio experience.

## Preferred Correction Hierarchy

```text
Detect
  ↓
Estimate
  ↓
Small timing/rate correction
  ↓
Re-measure
  ↓
Controlled position correction
  ↓
Full resynchronization if necessary
```

The exact correction mechanism remains an engineering decision.

## Requirements

Corrections must avoid:

* audible artifacts
* oscillation
* repeated unnecessary correction
* unstable feedback loops
* buffer instability

## Exit Criteria

Controlled drift can be detected and corrected without destabilizing the live session.

---

# 20. Phase 16 — Multi-Device Scaling

**Status:** REQUIRED

## Progression

```text
2
 ↓
3
 ↓
5
 ↓
10
```

The actual supported maximum should be determined experimentally.

## Measure

* synchronization spread
* startup time
* calibration duration
* RTT
* jitter
* packet loss
* CPU
* memory
* bandwidth
* buffer behavior
* underruns
* battery
* recovery behavior

## Exit Criteria

The architecture behaves predictably as participant count increases.

---

# 21. Phase 17 — Device Heterogeneity

**Status:** REQUIRED

## Objective

Determine how synchronization behaves across different Android hardware.

Test combinations involving:

* older + newer Android devices
* different manufacturers
* different chipsets
* different speaker hardware
* different Android versions
* different output routes

Identical-device testing is insufficient.

## Exit Criteria

Known compatible device classes and known limitations are documented.

Unsupported/problematic configurations are explicitly documented.

---

# 22. Phase 18 — Failure and Recovery

**Status:** CRITICAL

## Implement and Test

* participant disconnect
* participant reconnect
* temporary network interruption
* network change
* packet loss
* jitter spikes
* audio underrun
* capture interruption
* capture permission revocation
* source application becoming unavailable
* calibration failure
* output failure
* audio route change
* late joining
* host failure

## Participant Recovery

A reconnecting participant should:

```text
Reconnect
   ↓
Re-establish timing
   ↓
Receive current stream configuration
   ↓
Refill buffer
   ↓
Synchronize to future target
   ↓
Rejoin active output
```

There is no file to download or old playback position to seek to.

## Host Failure

Controlled recovery is acceptable.

Seamless host migration is not required for MVP.

## Exit Criteria

Expected failures produce controlled states instead of crashes or silent corruption.

---

# 23. Phase 19 — Production Room State Machine

**Status:** REQUIRED

Expand the room/session state model.

Target conceptual lifecycle:

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
DEGRADED
   ↓
RECOVERING
   ↓
ACTIVE
   ↓
ENDING
   ↓
CLOSED
```

Error states may branch from appropriate points.

The application must reject invalid transitions.

## Important

Do not reintroduce:

```text
PLAYING
PAUSED
RESUMING
SEEKING
```

as SoundMesh-owned media-player states.

If the external media application stops producing audio, SoundMesh should represent the resulting capture/session condition rather than pretending it controlled the external playback.

---

# 24. Phase 20 — Real SoundMesh UI

**Status:** REQUIRED

The polished UI can now be integrated around proven system capabilities.

## Implement

* Home
* Create Room
* Room Waiting
* QR display
* Join Room
* QR scanner
* Device list
* Mesh visualization
* Capture permission UX
* Capture-ready state
* External media handoff
* Waiting for audio state
* Live audio session
* Synchronization state
* Device details
* Diagnostics
* Settings
* Error/recovery states

## Do Not Implement

* audio picker
* media library
* track list
* Now Playing screen
* SoundMesh-owned seek bar
* playback controls
* file-transfer progress

## Principle

The UI exposes simple actions while hiding technical complexity.

---

# 25. Phase 21 — UX Refinement

**Status:** REQUIRED

Improve:

* transitions
* loading states
* empty states
* capture permission explanations
* external media handoff
* errors
* recovery guidance
* accessibility
* responsive layouts
* animation
* typography
* spacing
* visual hierarchy
* background-session feedback
* notification UX

## Quality Bar

The application should feel intentional and premium rather than like a technical prototype.

---

# 26. Phase 22 — Diagnostics

**Status:** REQUIRED

Implement a diagnostic interface useful during development and advanced testing.

## Possible Metrics

```text
Connected devices
Connection state
RTT
Clock offset
Timing uncertainty
Calibration confidence

Capture state
Capture source availability
Capture format

Audio stream state
Packet loss
Sequence gaps
Jitter
Buffer fill
Underruns

Output route
Output latency
Capture-to-network latency
Network-to-output latency

Estimated synchronization error
Drift rate
Correction state

Recovery events
Reconnect count
```

## Rule

Diagnostics should expose actual measurements.

Do not invent metrics simply because they look useful.

---

# 27. Phase 23 — Performance Optimization

**Status:** REQUIRED

Optimize only after measurement.

## Measure

* CPU
* memory
* battery
* thermal behavior
* bandwidth
* startup time
* connection time
* calibration time
* capture latency
* transport latency
* buffer behavior
* output latency
* audio underruns

## Priority

```text
Audio stability
      ↓
Synchronization
      ↓
Capture reliability
      ↓
Networking
      ↓
Application responsiveness
      ↓
Visual performance
```

Visual optimization must never compromise realtime audio.

---

# 28. Phase 24 — Reliability Campaign

**Status:** CRITICAL

Run repeated complete sessions.

Example:

```text
50 sessions
100 sessions
```

where practical.

Record:

* successful room creation
* successful joining
* successful capture
* successful stream startup
* successful synchronization
* synchronization failures
* packet-loss behavior
* recovery failures
* capture failures
* crashes
* audio underruns
* abnormal termination

The exact number of runs may change depending on available hardware and development time.

---

# 29. Phase 25 — Physical Synchronization Validation

**Status:** CRITICAL

Software timing metrics are not sufficient.

Validate the actual physical sound.

## Procedure

```text
Multiple phones
      ↓
Known test signal
      ↓
Simultaneous acoustic recording
      ↓
Waveform analysis
      ↓
Measured onset differences
```

The test signal must pass through the same relevant capture/output architecture being validated.

## Goal

Determine whether software synchronization corresponds to physical acoustic synchronization.

## Required Reporting

For important experiments:

* test ID
* device models
* Android versions
* source application
* source/test signal
* network conditions
* software version
* number of runs
* measured spread
* anomalies
* conclusion

---

# 30. Phase 26 — External Source Compatibility

**Status:** REQUIRED

## Objective

Establish which external media applications can actually be captured.

Test a representative set of applications.

For each source, record:

```text
Source application
Capture permitted?
Capture format
Capture stability
Background behavior
Observed limitations
```

Do not claim universal compatibility.

## Exit Criteria

The supported source-app behavior is documented and the UI communicates unsupported sources correctly.

---

# 31. Phase 27 — Competition Differentiation

**Status:** REQUIRED

The project should identify and demonstrate measurable strengths.

Potential demonstrated strengths:

* fast QR onboarding
* local-first operation
* external-app compatibility where permitted
* automatic calibration
* synchronization diagnostics
* drift correction
* heterogeneous Android support
* robust recovery
* measurable physical synchronization

Claims must be supported by evidence.

Do not claim:

> “Perfect synchronization”

unless the evidence genuinely supports that statement under a clearly defined test condition.

---

# 32. Phase 28 — Demo Engineering

**Status:** REQUIRED

Create a reliable demonstration environment.

## Demo Goal

The first impression should communicate:

> **Multiple phones are behaving like one speaker.**

## Demo Sequence

```text
Open SoundMesh
      ↓
Create Room
      ↓
Show QR
      ↓
Multiple phones scan
      ↓
Devices appear
      ↓
Allow audio capture
      ↓
Devices synchronize
      ↓
Open external media app
      ↓
Play audio
      ↓
SoundMesh captures it
      ↓
All phones output together
      ↓
Show synchronization
```

The demo should avoid unnecessary technical explanations.

The external media app should remain visibly separate from SoundMesh's own UI model.

---

# 33. Phase 29 — Competition Hardening

**Status:** REQUIRED

Before submission:

* freeze major architecture
* resolve critical bugs
* test supported devices
* test core flows repeatedly
* verify Android build/release process
* verify repository cleanliness
* verify open-source requirements
* verify documentation
* verify demo
* verify synchronization evidence
* verify competition requirements
* verify submission materials

No major architecture changes should be introduced immediately before submission without strong justification.

---

# 34. Phase 30 — Submission Preparation

**Status:** REQUIRED

Prepare:

* final source repository
* license
* README
* demo video
* project description
* technical explanation
* screenshots
* architecture summary
* testing evidence
* physical synchronization evidence
* student verification materials
* required competition submission information

Competition requirements must be checked against the current official rules before submission.

---

# 35. Milestone Definitions

## M0 — Repository Ready

```text
Docs
 +
Project structure
 +
AI rules
 +
Build
```

---

## M1 — Android Capture Proven

```text
External Media App
        ↓
AudioPlaybackCapture
        ↓
Captured Frames
```

At least one eligible external source produces usable captured audio on physical Android hardware.

---

## M2 — Two Devices Connected

```text
Phone A
   ↕
Phone B
```

Structured local communication works.

---

## M3 — Live Audio Transport

```text
Host Capture
     ↓
Network
     ↓
Participant
```

Captured audio frames successfully travel between devices.

---

## M4 — Native Participant Output

```text
Captured Audio
      ↓
Transport
      ↓
Jitter Buffer
      ↓
Native Output
```

The participant can hear the live captured audio.

---

## M5 — End-to-End Pipeline

```text
External App
     ↓
Capture
     ↓
Transport
     ↓
Buffer
     ↓
Output
```

The real external audio source works through the entire system.

---

## M6 — Two-Device Synchronization

```text
Phone A
   +
Phone B
   ↓
Shared Timeline
   ↓
Measured Synchronized Output
```

This is the most important technical milestone.

---

## M7 — Synchronization Maintained

Drift is:

* measured
* detected
* controlled

---

## M8 — Five Devices

Five physical Android phones participate in one room.

---

## M9 — Recovery

Disconnects, interruptions, packet loss, and other expected failures are handled predictably.

---

## M10 — Production UX

The complete intended user experience is implemented.

---

## M11 — Physical Validation Complete

Physical measurements support the project's synchronization claims.

---

## M12 — Reliability Validated

Repeated real-device sessions demonstrate acceptable reliability.

---

## M13 — Competition Ready

The project is:

* stable
* documented
* demonstrable
* measurable
* open source
* submission-ready

---

# 36. Dependency Graph

The approximate dependency structure is:

```text
Repository
    ↓
Flutter Shell
    ↓
Native Android Bridge
    ↓
Android Capture Feasibility
    ↓
Local Networking
    ↓
Room Protocol
    ↓
QR Bootstrap
    ↓
Live Audio Transport
    ↓
Native Audio Output
    ↓
End-to-End Capture Pipeline
    ↓
Clock Synchronization
    ↓
Timing / Latency Calibration
    ↓
Shared Live-Audio Timeline
    ↓
Two-Device Synchronization
    ↓
Drift Detection
    ↓
Drift Correction
    ↓
Multi-Device Scaling
    ↓
Failure / Recovery
    ↓
Production UX
    ↓
Physical Validation
    ↓
Reliability
    ↓
Competition Hardening
```

---

# 37. What Must NOT Happen

The following development order is discouraged:

```text
Beautiful UI
    ↓
Animations
    ↓
Settings
    ↓
Cloud backend
    ↓
Accounts
    ↓
Social features
    ↓
Playlists
    ↓
Media library
    ↓
Eventually investigate audio capture
    ↓
Eventually investigate synchronization
```

This is backwards for SoundMesh.

The core technical risk must be attacked early.

---

# 38. Obsolete Development Patterns

The following architecture must NOT be reintroduced:

```text
Select audio
    ↓
Identify audio asset
    ↓
Transfer file
    ↓
Verify hash
    ↓
Store locally
    ↓
Decode
    ↓
Prepare playback
    ↓
PLAY
```

That workflow belonged to the previous SoundMesh architecture.

The current architecture is:

```text
External media app
       ↓
Live audio capture
       ↓
Capture timestamp
       ↓
Live transport
       ↓
Jitter buffer
       ↓
Shared timeline
       ↓
Scheduled native output
```

---

# 39. Parallel Development

Some work can happen in parallel after dependencies are stable.

Example:

```text
Audio / Synchronization
        │
        ├── Clock model
        ├── Timing calibration
        ├── Jitter buffer
        └── Drift correction

Networking
        │
        ├── Room protocol
        ├── QR joining
        ├── Audio transport
        └── Recovery

Android Audio
        │
        ├── Capture
        ├── Native output
        ├── Route management
        └── Foreground service

UI
        │
        ├── Screens
        ├── Components
        ├── Session states
        └── Diagnostics
```

Parallel work must respect file ownership and architectural boundaries.

Two AI agents must not simultaneously modify the same critical subsystem without coordination.

---

# 40. AI Development Strategy

AI agents should receive small, well-defined tasks.

Bad:

> Build SoundMesh.

Good:

> Implement participant-side timestamp exchange described in `synchronization.md`, add unit tests for RTT and offset estimation, and do not modify the audio transport layer.

Every AI task should specify:

* objective
* scope
* allowed files
* relevant specifications
* acceptance criteria
* tests
* known constraints

The detailed procedure belongs in:

```text
DOCS/AI/task-protocol.md
```

---

# 41. Definition of Phase Completion

A phase is not complete because code exists.

A phase is complete when:

```text
Implementation
      +
Tests
      +
Real-device verification where applicable
      +
Documentation
      +
Acceptance criteria
```

have been satisfied.

For realtime audio phases, real-device validation is strongly preferred over emulator-only validation.

---

# 42. Roadmap Change Policy

This roadmap is a living plan.

It may change when:

* experiments invalidate an assumption
* Android platform limitations appear
* capture compatibility is lower than expected
* a transport approach proves unreliable
* synchronization measurements reveal a better approach
* competition requirements change
* testing reveals a better architecture

However, roadmap changes must not silently change architectural decisions.

Architecture changes belong in:

```text
DOCS/decisions.md
```

---

# 43. Priority Levels

Every roadmap task should be classified as:

## P0 — Core Risk

Must be investigated immediately.

Examples:

* Android external-audio capture
* live audio transport
* native output
* clock synchronization
* timing calibration
* two-device synchronization
* physical synchronization measurement

---

## P1 — Core Product

Required for MVP.

Examples:

* room protocol
* QR joining
* capture permission UX
* live session
* drift detection
* recovery
* multi-device support

---

## P2 — Quality

Important after the core system works.

Examples:

* diagnostics
* performance optimization
* accessibility refinement
* source compatibility testing
* improved recovery UX

---

## P3 — Polish

Useful but not blocking.

Examples:

* advanced animations
* visual refinement
* secondary interaction improvements

---

## P4 — Future

Not part of MVP.

Examples:

* iOS support
* cloud rooms
* remote sessions
* social features
* large-scale Internet-based rooms
* advanced host migration

---

# 44. Recommended Immediate Build Sequence

The current implementation sequence should be:

```text
1. Flutter project
2. Native Android bridge
3. Android external-audio capture spike
4. Two-device local networking
5. Room protocol
6. QR joining
7. Live audio frame transport
8. Native participant audio output
9. End-to-end capture → transport → output
10. Clock synchronization
11. Capture/output latency measurement
12. Shared live-audio timeline
13. Two-device synchronized external audio
14. Physical synchronization measurement
15. Drift monitoring
16. Drift correction
17. Three-device testing
18. Five-device testing
19. Recovery
20. External-source compatibility testing
21. Full UI integration
22. Diagnostics
23. Performance optimization
24. Reliability campaign
25. Competition hardening
```

This sequence deliberately prioritizes the highest-risk assumptions.

---

# 45. Hard Stop Conditions

Development should pause and reassess the architecture if any of the following occurs:

### Capture

* required external audio cannot be captured on Android
* supported applications consistently refuse capture
* capture is too unstable for live use
* capture timestamps cannot support the required timing model

### Transport

* local transport introduces unacceptable latency
* buffering becomes unbounded
* packet loss causes unrecoverable audio behavior
* transport blocks the entire session because of one slow participant

### Output

* native output cannot schedule audio reliably
* output latency cannot be measured sufficiently
* device route changes destroy synchronization

### Synchronization

* clock relationship cannot be estimated reliably
* capture/output latency cannot be calibrated
* physical output cannot be brought into a sufficiently coherent timing relationship

### Product Model

* SoundMesh begins requiring users to select, transfer, or manage media files
* SoundMesh begins implementing its own media-player controls
* SoundMesh's architecture becomes dependent on a media library

These conditions require investigation before simply adding more features.

---

# 46. The Most Important Milestone

The single most important milestone is:

> **Two real Android phones receiving the same live external-app audio through SoundMesh and producing measured, repeatable, perceptually coherent synchronized sound.**

The important word is **live**.

The system must demonstrate:

```text
External App
     ↓
Capture
     ↓
Network
     ↓
Buffer
     ↓
Scheduling
     ↓
Physical Output
     ↓
Measured Synchronization
```

A synchronized local test file is no longer sufficient to prove the actual SoundMesh architecture.

---

# 47. Evidence-Driven Development

For every high-risk subsystem:

```text
Unknown
   ↓
Experiment
   ↓
Measurement
   ↓
Evidence
   ↓
Decision
   ↓
Implementation
   ↓
Test
   ↓
Reliable Feature
```

Examples:

```text
Can Android capture this source?
        ↓
Test it
        ↓
Record result
        ↓
Document compatibility
```

```text
Can two devices stay synchronized?
        ↓
Measure it
        ↓
Analyze drift
        ↓
Implement correction
        ↓
Re-measure
```

Do not turn assumptions into architecture merely because they sound technically reasonable.

---

# 48. Final Roadmap Principle

Do not ask:

> “What feature should we build next?”

Ask:

> **“What is the highest-risk assumption we can prove or disprove next?”**

That question should guide SoundMesh development.

The project should continuously move from:

```text
Unknown
   ↓
Experiment
   ↓
Evidence
   ↓
Decision
   ↓
Implementation
   ↓
Test
   ↓
Reliable Feature
```

rather than:

```text
Idea
   ↓
Code
   ↓
Hope
```

---

# 49. Final Objective

The roadmap ultimately leads to one simple demonstration:

```text
              SOUND MESH

          📱         📱
            \       /
             \     /
              📱
             /   \
            /     \
          📱       📱

             🔊 🔊 🔊

        One synchronized system
```

The underlying system may contain:

* Android audio capture
* realtime networking
* timestamps
* jitter buffers
* clock synchronization
* latency calibration
* native scheduling
* drift correction
* recovery
* multi-device coordination

But the user should experience only:

```text
Create
  ↓
Join
  ↓
Connect
  ↓
Allow capture
  ↓
Open media app
  ↓
Play
  ↓
Everyone hears it together
```

The roadmap exists to ensure that engineering complexity is introduced **only when it is necessary to make that experience reliable.**

**End of Engineering Roadmap.**
