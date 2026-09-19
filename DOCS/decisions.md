# SoundMesh — Engineering Decision Log

**Document Status:** REQUIRED
**Document Type:** Engineering Decision Record / Architecture Decision Log
**Applies To:** Entire SoundMesh repository
**Primary Authority:** Engineering and architectural decisions
**Last Updated:** 2026-09-16

---

# 1. Purpose

This document records important engineering, architectural, product, networking, audio, synchronization, and development decisions made for SoundMesh.

Its primary purpose is to prevent:

* accidental architectural drift
* repeated debates
* contradictory implementations
* AI agents silently changing decisions
* developers choosing technologies without understanding constraints
* previously rejected approaches being reintroduced without new evidence
* `UNDECIDED` questions being treated as decided
* experiments being mistaken for production architecture

This document is a **decision ledger**, not a general explanation of SoundMesh.

Detailed implementation requirements belong in the other specifications.

---

# 2. Decision Authority

When a decision is explicitly marked `DECIDED`, developers and AI agents should treat it as an established project constraint.

A `DECIDED` item must not be changed casually.

Changing a significant decision requires:

1. identifying the existing decision
2. explaining why it is no longer appropriate
3. documenting new evidence
4. evaluating consequences
5. recording the replacement decision
6. updating affected specifications

A newer `DECIDED` decision supersedes an older conflicting decision.

Historical decisions must remain in this log so that the reason for architectural changes is preserved.

---

# 3. Decision Status Vocabulary

## DECIDED

The project has committed to this approach.

Implementation should follow it.

---

## EXPERIMENTAL

The project is actively testing this approach.

It must not automatically be treated as permanent architecture.

Experimental implementations should be isolated where practical.

---

## UNDECIDED

The project has not made a final choice.

AI agents MUST NOT silently choose an option and treat it as an official decision.

---

## PREFERRED

One approach is currently favored, but evidence is insufficient for a final commitment.

---

## REJECTED

The approach has intentionally been rejected.

It should not be reintroduced unless meaningful new evidence changes the situation.

---

## SUPERSEDED

The decision was previously valid but has been replaced by a newer decision.

The historical record should remain.

---

# 4. Decision Rules

## Rule 1 — Do Not Silently Change Decisions

AI agents must not change a `DECIDED` architectural choice because another approach appears easier.

---

## Rule 2 — Do Not Resolve UNDECIDED Items Automatically

If a task depends on an undecided choice:

1. identify the dependency
2. determine whether a reversible experiment is possible
3. otherwise stop and request a decision

Do not silently convert:

```text
UNDECIDED
```

into:

```text
DECIDED
```

---

## Rule 3 — Evidence Beats Preference

Technical decisions should be based on:

* real-device testing
* platform documentation
* measured performance
* synchronization measurements
* compatibility
* reliability
* maintainability

rather than:

* personal preference
* familiarity
* hype
* assumptions
* what another project uses

---

## Rule 4 — MVP Simplicity

If two approaches satisfy the same requirement, prefer the approach with:

* fewer dependencies
* fewer moving parts
* lower maintenance cost
* clearer failure behavior
* easier testing
* easier debugging

---

## Rule 5 — Reversibility

When evidence is insufficient, prefer experiments that can be replaced without rewriting unrelated systems.

---

# 5. ADR Format

Significant future decisions should follow:

```text
Decision ID:

Title:

Status:

Date:

Category:

Context:

Decision:

Rationale:

Alternatives considered:

Rejected alternatives:

Consequences:

Dependencies:

Evidence:

Affected documents:

Follow-up:
```

---

# 6. DEC-001 — Product Concept

**Status:** DECIDED

**Category:** Product

### Decision

SoundMesh is a mobile application that allows multiple nearby phones to coordinate audio playback so that they behave as one synchronized speaker system.

### Core user promise

> **Turn nearby phones into one synchronized speaker.**

### Rationale

The product originated from a real-world situation:

* multiple people had phones
* no physical speaker was available
* the phones collectively had enough speaker hardware to produce useful sound
* the problem was coordinating them

The product therefore focuses on synchronization rather than simply audio playback.

### Consequences

The engineering system must prioritize:

* synchronization
* latency measurement
* drift correction
* reliable local networking
* simple joining
* coordinated audio output

---

# 7. DEC-002 — Product Name

**Status:** DECIDED

**Decision:** The project name is **SoundMesh**.

The name should be used consistently throughout:

* application UI
* repository
* documentation
* package/module naming where appropriate
* branding
* public submission materials

---

# 8. DEC-003 — Mobile-First Product

**Status:** SUPERSEDED by DEC-085

### Historical Decision

SoundMesh was originally defined as a cross-platform mobile application with Android and iOS as primary platforms.

### Current Authority

DEC-085 defines the current platform model:

* Android is the MVP host platform for external audio capture.
* Android and iOS may participate in the broader SoundMesh system.
* iOS cannot act as an external-audio-capture host for the MVP.
* iOS participation as a synchronized audio receiver remains a supported architectural direction.

---

# 9. DEC-004 — Flutter Application Layer

**Status:** DECIDED

### Decision

Flutter is the primary application framework.

Flutter owns:

* UI
* navigation
* application orchestration
* high-level room state
* user interaction
* design system
* presentation

### Consequence

Flutter must not become the realtime audio engine.

---

# 10. DEC-005 — Native Timing-Critical Systems

**Status:** DECIDED

### Decision

Timing-critical audio, capture, networking, and synchronization functionality should be implemented behind native platform abstractions where required.

Examples include:

* native audio capture
* native audio scheduling
* low-level playback timing
* native audio callbacks
* realtime networking
* platform-specific timing APIs
* audio route management

### Consequence

High-frequency realtime operations must not depend on Flutter widget or message-loop timing.

For the Android MVP, Android-native implementation is the primary timing-critical environment.

---

# 11. DEC-006 — Platform Integration Boundary

**Status:** DECIDED

### Decision

Flutter communicates with native platform implementations through strongly typed interfaces.

**Pigeon is the preferred mechanism** for platform APIs where practical.

### Rule

Do not pass high-frequency realtime audio data through Flutter.

Preferred structure:

```text
Flutter
   ↓
Typed platform interface
   ↓
Native implementation
   ↓
Audio / networking / synchronization subsystem
```

---

# 12. DEC-007 — Local-First Architecture

**Status:** DECIDED

### Decision

Normal SoundMesh sessions must not depend on Internet connectivity.

The core session operates over a local network.

### Preferred networks

* existing local Wi-Fi
* phone hotspot/local network

### Consequence

Internet/cloud infrastructure must not become a hidden dependency of MVP playback.

---

# 13. DEC-008 — Cloud Dependency

**Status:** REJECTED for MVP

SoundMesh will not require a cloud backend for ordinary local playback.

Rejected MVP dependencies include:

* cloud relay servers
* mandatory accounts
* mandatory cloud databases
* mandatory Internet authentication
* cloud audio streaming

Future features may introduce optional cloud functionality, but that would require a new decision.

---

# 14. DEC-009 — Host / Participant Model

**Status:** DECIDED

SoundMesh uses a conceptual room model with:

```text
Host
Participant
Participant
Participant
...
```

The host coordinates the room and active audio session.

Participants join the room and synchronize with the shared live-audio session.

### Important distinction

The host is a **coordination authority and audio-capture source** during a host-capture session.

The host is not necessarily responsible for arbitrary application-level media playback.

The external media application remains the source of the media being played.

---

# 15. DEC-010 — Audio Distribution Strategy

**Status:** SUPERSEDED by DEC-085

### Historical Decision

The original architecture preferred:

```text
Host selects audio
      ↓
Audio distributed to participants
      ↓
Each device prepares local audio
      ↓
All devices schedule local playback
```

### Current Authority

DEC-085 replaces this model with live external-audio capture and distribution.

The authoritative MVP path is:

```text
External media app
      ↓
Android AudioPlaybackCapture
      ↓
Captured audio frames
      ↓
Packetization / transport
      ↓
Participant jitter buffer
      ↓
Native scheduled audio output
```

The old file-selection and file-distribution model must not be reintroduced as the MVP architecture.

---

# 16. DEC-011 — Continuous Audio Streaming

**Status:** SUPERSEDED by DEC-085

### Historical Decision

Continuous decoded host-to-participant audio streaming was previously rejected.

### Current Authority

Live audio transport is now a **required architectural component** for the external-audio-capture model.

The rejection of streaming in the original decision was based on a different product architecture.

The current implementation must therefore evaluate:

* packetization
* transport
* jitter
* packet loss
* buffering
* backpressure
* latency
* synchronization
* CPU usage
* network reliability

The exact transport and audio representation remain subject to the current experimental decisions.

---

# 17. DEC-012 — QR-Based Joining

**Status:** DECIDED

QR scanning is the preferred MVP room-joining mechanism.

### Desired flow

```text
Host:

Create Room
   ↓
Show QR

Participant:

Join Room
   ↓
Scan QR
   ↓
Connect
```

---

# 18. DEC-013 — QR Payload

**Status:** PREFERRED

A QR payload should contain temporary room bootstrap information rather than permanent credentials.

Conceptual structure:

```text
soundmesh://join
?room=<room-id>
&host=<bootstrap-address>
&port=<bootstrap-port>
&version=<protocol-version>
&token=<short-lived-join-token>
```

The exact serialization remains implementation-dependent.

### QR must NOT contain

* permanent passwords
* long-lived secrets
* private keys
* audio files
* permanent account credentials

---

# 19. DEC-014 — IP Address Is Not Device Identity

**Status:** DECIDED

An IP address must not be treated as a permanent device identity.

Device identity must be represented independently.

Reasons include:

* DHCP changes
* hotspot behavior
* network transitions
* reconnection
* multiple interfaces

---

# 20. DEC-015 — Audio Integrity

**Status:** SUPERSEDED by DEC-085

### Historical Decision

Transferred audio assets were to be verified using content hashes before playback.

### Current Authority

The MVP does not distribute complete audio files as its primary audio path.

Live captured audio is transported as timestamped frames.

Integrity of live transport should instead be handled through:

* sequence numbers
* framing
* packet validation
* session generation
* format validation
* loss/gap detection
* transport-level integrity mechanisms where applicable

Content-hash verification of an entire media asset is not a required MVP playback mechanism.

---

# 21. DEC-016 — Scheduled Playback

**Status:** DECIDED

SoundMesh must use scheduled playback as the primary synchronization mechanism.

The system must not depend on simultaneous arrival of commands or audio packets.

Preferred concept:

```text
Current synchronized time
        +
Future playback target
        ↓
Schedule output
```

### Important clarification

For live audio, packets may arrive at different times.

Participants therefore buffer incoming audio and schedule output against the shared synchronized timeline.

---

# 22. DEC-017 — Shared Playback Timeline

**Status:** DECIDED

SoundMesh uses a shared logical audio timeline.

Participants map their local monotonic/native timing systems to the shared timeline.

The shared timeline is not equivalent to wall-clock time.

For live audio, captured frames must carry timing information sufficient for participants to place them on this shared timeline.

---

# 23. DEC-018 — Monotonic Timing

**Status:** DECIDED

Synchronization calculations should use monotonic timing sources where available.

Wall clocks must not be used as the sole source of realtime playback synchronization.

---

# 24. DEC-019 — Clock Offset Measurement

**Status:** DECIDED

SoundMesh will estimate relationships between host and participant monotonic clocks through timestamp exchanges.

A conceptual exchange:

```text
Participant sends t1
Host receives t2
Host sends t3
Participant receives t4
```

Offset estimation must account for the applicable network-delay assumptions.

---

# 25. DEC-020 — RTT Measurement

**Status:** DECIDED

Round-trip time must be measured independently from clock offset.

Conceptually:

```text
RTT = (t4 - t1) - (t3 - t2)
```

RTT is a network measurement.

It is not equivalent to:

* clock offset
* audio latency
* speaker latency

---

# 26. DEC-021 — Synchronization Is Measured

**Status:** DECIDED

SoundMesh must measure synchronization quality rather than assuming that scheduled output worked.

Important measurements include:

* startup spread
* steady-state spread
* timing uncertainty
* clock offset
* drift
* RTT
* calibration duration
* recovery behavior
* capture-to-output latency

---

# 27. DEC-022 — Perceptual Synchronization Target

**Status:** DECIDED

The product goal is **perceptually coherent synchronization**, not mathematically identical hardware output.

### Initial engineering targets

```text
≤ 20 ms
```

Preferred stretch:

```text
≤ 10 ms
```

These are engineering targets, not guaranteed specifications.

Actual performance must be experimentally measured.

---

# 28. DEC-023 — External Synchronization Validation

**Status:** DECIDED

Software logs alone are insufficient to prove audible synchronization quality.

External validation should eventually use appropriate measurement methods such as:

* microphones
* waveform analysis
* controlled test signals
* simultaneous recording
* physical measurement setups

The actual sound produced by different phone speakers can differ from the timing predicted by software.

---

# 29. DEC-024 — Drift Correction

**Status:** DECIDED

SoundMesh must monitor synchronization after output begins.

If drift is detected, the system should attempt correction.

Preferred correction hierarchy:

```text
Monitor
   ↓
Tiny playback-rate correction
   ↓
Small position correction
   ↓
Controlled resynchronization
   ↓
Recovery/rejoin if necessary
```

Corrections should prioritize inaudibility.

---

# 30. DEC-025 — “Play Now” Rejection

**Status:** REJECTED

Sending an immediate play command independently to every device is not an acceptable primary synchronization mechanism.

Network arrival times differ.

Therefore:

```text
Command received ≠ identical playback time
```

---

# 31. DEC-026 — Native Audio Engine Strategy

**Status:** EXPERIMENTAL

The exact native audio implementation remains subject to device testing.

### Android candidates

* Oboe
* AAudio
* AudioTrack

### iOS candidates

* AVAudioEngine
* AVAudioPlayerNode
* AVAudioTime
* AVAudioSession

The final implementation must be selected based on:

* scheduling accuracy
* latency
* device compatibility
* stability
* background behavior
* CPU usage
* battery usage

For the Android MVP, capture and synchronized output must be validated on physical Android devices.

---

# 32. DEC-027 — Bluetooth

**Status:** EXPERIMENTAL

Bluetooth audio routes are not guaranteed to provide the same synchronization behavior as local device speakers.

Bluetooth support must therefore be tested separately.

Synchronization results obtained through built-in speakers must not automatically be generalized to Bluetooth.

---

# 33. DEC-028 — Wi-Fi Direct / P2P

**Status:** EXPERIMENTAL

Direct peer-to-peer networking is interesting but is not the required MVP networking foundation.

MVP preference:

```text
Local Wi-Fi / hotspot
```

Future experiments may investigate:

* Android Wi-Fi Direct
* iOS peer-to-peer mechanisms
* Wi-Fi Aware
* other platform-supported local transports

---

# 34. DEC-029 — Reliable Control Transport

**Status:** DECIDED for MVP baseline

Reliable control traffic should use a reliable ordered transport such as TCP unless platform experiments demonstrate a specific requirement for another approach.

Appropriate uses include:

* room messages
* handshake
* device information
* session state
* synchronization control
* recovery messages
* diagnostics/control metadata

### Important clarification

This decision no longer implies that live audio frames must use TCP.

Live audio transport is a separate engineering concern and remains subject to transport experiments.

---

# 35. DEC-030 — UDP / Realtime Audio Transport

**Status:** EXPERIMENTAL

UDP and other realtime-capable transports may be investigated for live audio transport and specialized timing measurements.

A realtime transport must not be introduced merely because it sounds more “realtime.”

Any selected transport must demonstrate measurable benefit considering:

* packet loss
* jitter
* latency
* buffering
* recovery
* CPU cost
* implementation complexity
* device/network compatibility

---

# 36. DEC-031 — Control / Audio / Timing Plane Separation

**Status:** DECIDED

SoundMesh conceptually separates three logical planes.

### Control plane

Handles:

* room state
* device state
* session lifecycle
* joining
* recovery
* configuration
* non-realtime commands

### Audio data plane

Handles:

* captured audio frames
* packetization
* transport
* sequence numbers
* buffering
* loss/gap handling
* stream statistics

### Timing plane

Handles:

* timestamp exchanges
* clock relationships
* timing measurements
* synchronization
* drift estimation

This separation prevents ordinary control traffic from being confused with realtime audio and timing requirements.

---

# 37. DEC-032 — Flutter Realtime Boundary

**Status:** DECIDED

High-frequency synchronization, capture, networking, and audio callbacks must remain outside Flutter where possible.

Preferred:

```text
Native realtime system
        ↓
Aggregated measurements/state
        ↓
Flutter
        ↓
UI
```

The UI does not need every internal timing event or audio frame.

---

# 38. DEC-033 — Audio Representation Strategy

**Status:** UNDECIDED

The exact live-audio representation remains to be determined through implementation and compatibility testing.

Possible considerations include:

* PCM transport
* compressed transport
* packet size
* encoding/decoding cost
* bandwidth
* quality
* latency
* licensing
* device compatibility

The system must not prematurely assume a final representation.

---

# 39. DEC-034 — Sample Rate

**Status:** UNDECIDED

SoundMesh has not permanently selected:

* capture sample rate
* output sample rate
* resampling strategy

These decisions require real-device testing.

---

# 40. DEC-035 — Channel Configuration

**Status:** UNDECIDED

Channel handling requires explicit testing.

The application must not assume that every device has identical:

* sample rates
* channel counts
* hardware characteristics
* output latency

---

# 41. DEC-036 — Host Failure

**Status:** DECIDED for MVP

The MVP does not require seamless host migration.

If the host fails, the application may perform controlled recovery.

Future seamless host migration would require a separate architectural decision.

---

# 42. DEC-037 — Late Joining

**Status:** DECIDED

Late-joining devices must synchronize with the **current live session** before producing synchronized output.

They do not receive an old media file and prepare it locally.

Conceptually:

```text
Join current session
       ↓
Receive current stream metadata
       ↓
Synchronize clock
       ↓
Fill bounded jitter buffer
       ↓
Schedule future audio output
       ↓
Join active synchronized output
```

---

# 43. DEC-038 — Session Generation Numbers

**Status:** DECIDED

Session- and audio-stream-affecting messages must include a generation/version mechanism where appropriate.

Purpose:

Prevent stale state, packets, commands, or recovery events from affecting the current session.

Example:

```text
Generation 12
Audio session active

Generation 13
New audio session

Old Generation 12
packet / state update
```

The stale data must not affect Generation 13.

---

# 44. DEC-039 — UI Technical Complexity

**Status:** DECIDED

Normal users should not be exposed to technical implementation details.

Normal UI should say:

> Getting everyone in sync…

not:

> Measuring clock offset using timestamp exchange.

Diagnostics may intentionally expose technical information.

---

# 45. DEC-040 — UI Theme

**Status:** DECIDED

SoundMesh uses a dark-first visual design.

Primary background:

```text
#0B0D10
```

Primary accent:

```text
#5B8CFF
```

The UI specification is the authority for all visual tokens.

---

# 46. DEC-041 — SoundMesh Blue

**Status:** DECIDED

Primary brand accent:

```text
#5B8CFF
```

Accent variants:

```text
Light: #7DA5FF
Dark:  #3D6FE0
```

Other saturated colors must not become competing brand colors without a documented decision.

---

# 47. DEC-042 — Mesh Visual Language

**Status:** DECIDED

Connected devices are represented conceptually through a mesh/node visual language.

The mesh represents:

* connection
* participation
* coordination
* synchronization

It should remain subtle and performant.

---

# 48. DEC-043 — Premium Visual Direction

**Status:** DECIDED

SoundMesh's visual direction is:

> **Dark, minimal, premium, calm, technical, audio-focused.**

It should avoid:

* gamer RGB aesthetics
* excessive neon
* excessive gradients
* generic AI-dashboard styling
* excessive glassmorphism
* excessive animation

---

# 49. DEC-044 — Typography

**Status:** DECIDED

The MVP should prioritize high-quality platform-native typography.

Preferred:

* SF Pro/system UI on iOS
* Roboto/system UI on Android

A custom font requires a documented reason.

Typography hierarchy must follow `ui-ux.md`.

---

# 50. DEC-045 — Accessibility

**Status:** DECIDED

Accessibility is a required product property.

Requirements include:

* adequate contrast
* sufficiently large touch targets
* screen-reader semantics
* dynamic text support
* reduced motion
* non-color-only status communication
* accessible error messages

Accessibility is not a post-MVP decoration.

---

# 51. DEC-046 — Performance Priority

**Status:** DECIDED

Priority order:

```text
Audio stability
      ↓
Synchronization
      ↓
Network reliability
      ↓
Application responsiveness
      ↓
Visual effects
```

Visual effects must never compromise realtime audio.

---

# 52. DEC-047 — No Premature Backend

**Status:** REJECTED for MVP

Do not create:

* microservices
* cloud APIs
* cloud databases
* user-account systems
* authentication infrastructure
* remote media servers

unless an actual MVP requirement requires them.

---

# 53. DEC-048 — No Feature Creep

**Status:** DECIDED

Features should not be added simply because they are common in music applications.

Potential non-MVP features include:

* playlists
* social profiles
* music discovery
* streaming-service integrations
* cloud libraries
* advanced equalizers
* accounts
* remote rooms
* social sharing systems

The MVP must prove the core synchronization experience first.

---

# 54. DEC-049 — Device Scaling Strategy

**Status:** DECIDED

Testing progression:

```text
2 devices
   ↓
3 devices
   ↓
5 devices
   ↓
larger groups
```

Do not optimize for an arbitrary huge device count before proving reliable synchronization with a small group.

---

# 55. DEC-050 — Real Devices Over Simulators

**Status:** DECIDED

Synchronization quality must ultimately be validated on physical devices.

Simulators/emulators may be used for:

* UI development
* application logic
* basic flows

but cannot be considered sufficient proof of real-world synchronization quality.

---

# 56. DEC-051 — Measurement Before Optimization

**Status:** DECIDED

Do not optimize synchronization based solely on subjective assumptions.

Measure:

* RTT
* timing offset
* jitter/uncertainty
* startup spread
* steady-state spread
* drift
* recovery time
* capture latency
* network latency
* output latency
* CPU
* memory
* battery

before deciding which subsystem requires optimization.

---

# 57. DEC-052 — AI Agent Documentation

**Status:** DECIDED

AI coding agents are expected to use repository documentation as engineering context.

Important documentation includes:

```text
DOCS/blueprint.md
DOCS/architecture.md
DOCS/networking.md
DOCS/synchronization.md
DOCS/audio.md
DOCS/ui-ux.md
DOCS/decisions.md
DOCS/testing.md
DOCS/roadmap.md
DOCS/AI/*
AGENTS.md
```

Agents must not rely exclusively on the current prompt.

---

# 58. DEC-053 — AI Must Respect Decision States

**Status:** DECIDED

AI agents must distinguish:

```text
DECIDED
PREFERRED
EXPERIMENTAL
UNDECIDED
REJECTED
SUPERSEDED
```

An AI agent must not interpret `UNDECIDED` as permission to permanently choose an implementation.

---

# 59. DEC-054 — AI Must Not Rewrite Architecture Without Evidence

**Status:** DECIDED

An AI agent encountering an implementation difficulty must first determine whether:

1. the implementation is incorrect
2. the documented architecture is being violated
3. a platform limitation exists
4. a smaller workaround exists
5. an architectural decision genuinely needs revision

The agent must not immediately replace the architecture.

---

# 60. DEC-055 — Test Before Claiming Completion

**Status:** DECIDED

An AI agent must not claim:

> “Implemented successfully”

without performing applicable verification.

The exact verification process is defined in:

```text
DOCS/testing.md
DOCS/AI/task-protocol.md
```

---

# 61. DEC-056 — Source of Truth Hierarchy

**Status:** DECIDED

When information conflicts, use the following hierarchy:

```text
1. Explicit current engineering decision
2. Relevant detailed specification
3. Architecture specification
4. Experimental evidence
5. Repository implementation
6. General assumptions
```

However, implementation may reveal that documentation is outdated.

In that situation, the discrepancy must be documented rather than silently ignored.

---

# 62. DEC-057 — Documentation Consistency

**Status:** DECIDED

When a major architectural decision changes, all affected documentation must be reviewed.

For the external-audio-capture architecture, affected documentation includes:

```text
architecture.md
networking.md
synchronization.md
audio.md
playback-api.md
ui-ux.md
roadmap.md
AI/ai-context.md
testing.md
```

---

# 63. DEC-058 — Experimental Code Must Be Identifiable

**Status:** DECIDED

Experimental implementations should be clearly identifiable in code and documentation.

An experiment must not silently become the permanent architecture merely because it exists in the repository.

---

# 64. DEC-059 — Prototype Before Overengineering

**Status:** DECIDED

The team should prove the hardest technical assumption as early as possible.

The most important technical risk is:

> **Can multiple heterogeneous phones actually produce sufficiently coherent synchronized audio from a live external-audio source using the chosen local networking and native audio architecture?**

Therefore early prototypes should prioritize:

```text
2 phones
   ↓
external audio capture
   ↓
local connection
   ↓
live audio transport
   ↓
clock measurement
   ↓
jitter buffering
   ↓
scheduled output
   ↓
actual synchronization measurement
```

---

# 65. DEC-060 — The Core Technical Risk

**Status:** DECIDED

SoundMesh's largest technical risk is achieving reliable perceptual synchronization across different physical devices.

This must guide prioritization.

A beautiful interface cannot compensate for poor synchronization.

---

# 66. DEC-061 — UX Must Hide Engineering Complexity

**Status:** DECIDED

The user experience should make the complex distributed system feel simple.

Desired experience:

```text
Create
   ↓
Join
   ↓
Connect
   ↓
Allow Capture
   ↓
Open Media App
   ↓
Play Normally
   ↓
Everyone Hears Together
```

The application may perform:

```text
Discovery
Handshake
Capture
Clock measurement
Calibration
Packetization
Buffering
Scheduling
Monitoring
Drift correction
Recovery
```

without requiring the user to understand these operations.

---

# 67. DEC-062 — Reliability Over Feature Count

**Status:** DECIDED

For the competition MVP, a small number of highly reliable features is preferable to a large feature set with unreliable synchronization.

Priority:

```text
Reliable synchronization
      >
Reliable joining
      >
Reliable audio capture
      >
Reliable audio output
      >
Recovery
      >
Polish
      >
Additional features
```

---

# 68. DEC-063 — Competitive Differentiation

**Status:** DECIDED

SoundMesh should not rely on the claim:

> “Phones can become a speaker.”

The differentiation should come from execution quality, especially:

* synchronization quality
* calibration
* drift correction
* reliability
* ease of joining
* local-first operation
* heterogeneous-device handling
* measurable performance
* diagnostics

---

# 69. DEC-064 — Do Not Claim Perfect Synchronization

**Status:** DECIDED

SoundMesh must never claim:

> Perfect synchronization

unless objective testing can justify such a claim.

Preferred language:

> Synchronized playback

or:

> Designed for perceptually coherent synchronized playback.

---

# 70. DEC-065 — Engineering Targets Are Not Guarantees

**Status:** DECIDED

Values such as:

```text
≤20 ms startup spread
≤20 ms steady-state spread
≤10 ms preferred stretch
```

are engineering targets.

They must not be represented as universally guaranteed performance.

---

# 71. DEC-066 — Failure Is a First-Class Design Concern

**Status:** DECIDED

The system must explicitly design for:

* device disconnect
* host disconnect
* network changes
* packet loss
* high latency
* jitter
* capture failure
* source-app capture refusal
* capture interruption
* MediaProjection revocation
* buffer underrun
* audio route changes
* interruption
* backgrounding
* device sleep
* battery/thermal pressure
* late joining

Failure behavior must be specified rather than improvised.

---

# 72. DEC-067 — State Machines

**Status:** DECIDED

Important systems should use explicit state machines rather than scattered boolean flags.

The room/session lifecycle is conceptually:

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

Actual implementation may refine these states while preserving their semantics.

---

# 73. DEC-068 — Explicit Unknowns

**Status:** DECIDED

Unknown technical behavior must be documented explicitly.

Preferred:

```text
UNDECIDED — requires device testing.
```

or:

```text
EXPERIMENTAL — current implementation is provisional.
```

Do not hide uncertainty behind confident language.

---

# 74. DEC-069 — Security by Standard Mechanisms

**Status:** DECIDED

SoundMesh should prefer standard cryptographic and platform security mechanisms rather than custom cryptography.

The application should avoid:

* custom encryption algorithms
* permanent secrets inside QR codes
* unnecessary credential persistence

Security details remain primarily defined in `networking.md`.

---

# 75. DEC-070 — Repository Simplicity

**Status:** DECIDED

The repository should remain understandable.

Do not introduce:

* unnecessary abstraction layers
* duplicate networking systems
* duplicate state-management systems
* unused packages
* speculative infrastructure

Every major dependency should have a reason.

---

# 76. Decision Change Procedure

When proposing a change to a `DECIDED` item:

### Step 1

Identify the decision.

### Step 2

Explain the problem with the current decision.

### Step 3

Provide evidence.

Examples:

* benchmark
* device test
* official platform documentation
* reproducible failure
* measured performance

### Step 4

Describe alternatives.

### Step 5

Describe consequences.

### Step 6

Update this document.

### Step 7

Update affected specifications.

### Step 8

Only then modify implementation architecture.

---

# 77. AI Decision-Safety Rule

When an AI agent encounters an architectural uncertainty, it should classify it before acting:

```text
Is this DECIDED?
      ↓
Yes → Follow it.

No
 ↓
Is it PREFERRED?
 ↓
Yes → Follow unless evidence contradicts it.

No
 ↓
Is it EXPERIMENTAL?
 ↓
Yes → Preserve experimental status.

No
 ↓
Is it UNDECIDED?
 ↓
Yes → Do not silently finalize it.

No
 ↓
Check whether it is REJECTED/SUPERSEDED.
```

---

# 78. Decision Log Maintenance

Every major architectural decision should receive a unique ID.

IDs must never be reused.

If a decision changes:

```text
DEC-012
Status → SUPERSEDED
```

and a new decision receives a new ID.

Historical decisions should remain available for context.

---

# 79. Current High-Confidence Decisions

The following areas are currently strongly established:

```text
Product:
SoundMesh

MVP platform:
Android

Broader participation:
iOS may participate as a synchronized receiver,
but cannot act as an external-audio-capture host

Framework:
Flutter

Architecture:
Flutter UI/application layer + native timing-critical systems

Core audio model:
Live external-audio capture

External media:
External media application remains the source of truth

Audio capture:
Android AudioPlaybackCapture on supported Android versions/devices

Audio distribution:
Live captured-audio transport

Networking:
Local-first

Network planes:
Control + audio data + timing

Joining:
QR-first

Room:
Host + participants

Synchronization:
Shared timeline + clock measurement + scheduled output

Buffering:
Bounded participant jitter buffers

Drift:
Monitor + correct

Playback:
SoundMesh does not own external-media playback controls

UI:
Dark-first + premium minimal design

Brand accent:
#5B8CFF

Accessibility:
Required

Performance:
Audio/synchronization before visual effects

Testing:
Real devices required

External validation:
Physical/audio measurement required
```

---

# 80. Current Experimental / Open Areas

The following areas must remain explicitly open until evidence is available:

```text
Exact Android native audio engine
Exact participant output implementation
Live audio representation
Audio transport protocol
TCP vs UDP/other realtime transport
Packet size
Buffer depth
Jitter-buffer strategy
Sample-rate strategy
Resampling strategy
Channel strategy
Capture format normalization
Exact audio latency measurement
Host direct-output latency compensation
Bluetooth behavior
Wi-Fi Direct/P2P
Background capture behavior across Android versions/devices
Interruption behavior
Audio route changes
Maximum practical device count
Exact synchronization algorithm refinements
Drift-correction parameters
Host recovery strategy beyond MVP
```

---

# 81. Current Rejected / Superseded MVP Directions

The following must not be reintroduced as the MVP architecture:

```text
Mandatory cloud backend
Mandatory Internet connectivity
In-app media library
SoundMesh-owned file picker
SoundMesh-owned media playback controls
Selecting a song inside SoundMesh as the primary audio model
Whole-file audio distribution as the primary playback architecture
preparePlayback(audioId)-style file preparation
Content-hash-based whole-file synchronization as the primary audio mechanism
“Play Now” as the synchronization mechanism
Manual IP-address-based onboarding
Large social/music-streaming feature set
Premature microservices
Premature authentication infrastructure
Arbitrary synchronization claims
Feature expansion before core synchronization reliability
```

### Important distinction

**Live audio streaming is NOT rejected.**

It is required by the current capture architecture.

What remains undecided is the exact implementation of the live audio transport.

---

# 82. DEC-084 — Room / Participant / Session Identity Format

**Status:** DECIDED

**Category:** Architecture / Networking

**Date:** 2026-09-12

### Decision

* `roomId`: UUID v4 string, generated by the host on room creation.
* `participantId`: UUID v4 string, generated locally by each device when it joins a room.
* `participantId` is not persisted across app restarts or different rooms.
* `sessionId`: UUID v4 string, generated by the host, representing the room's active session.

`participantId` remains distinct from any permanent user identity.

### Rationale

UUID v4 provides globally unique identifiers without coordination.

Regenerating `participantId` per room join avoids persistent tracking and keeps the identity scoped to the relevant room session.

### Alternatives Considered

* Custom string formats — rejected; no advantage over UUID v4.
* Persistent device ID — rejected; conflicts with local-first/no-account principles and room identity requirements.
* Numeric IDs — rejected; requires collision coordination.

### Consequences

* All three IDs are represented as standard UUID v4 strings.
* `participantId` is generated fresh for each room join.
* No persistent identity storage is required for MVP.

### Affected Documents

* `DOCS/interfaces/room-api.md`
* `DOCS/networking.md`
* this decision log

---

# 83. DEC-085 — Audio Source Model: Background Capture, Android-Only Host

**Status:** DECIDED

**Category:** Audio / Platform / Product

**Date:** 2026-09-12

## Decision

SoundMesh's MVP audio source model is **background external-audio capture**, not in-app file/media selection.

The host device captures eligible system/other-app audio currently playing on that device and distributes the resulting live audio stream to participant devices for synchronized output.

Examples include audio produced by:

* a video player
* a browser
* a downloaded movie player
* another eligible Android media application

SoundMesh does **not** act as its own media player with a file picker or media library.

## Platform Scope

This capture capability is **Android-only**.

Android 10+ / API 29+ provides the intended `AudioPlaybackCapture` mechanism, subject to:

* MediaProjection permission
* session-specific capture authorization
* foreground-service requirements
* source-application capture policy
* device/platform compatibility

Source applications can prevent capture.

SoundMesh cannot override a source application's capture policy.

Therefore SoundMesh must explicitly represent capture incompatibility rather than pretending all external media applications are supported.

## iOS Scope

iOS cannot act as an external-audio-capture host for this MVP architecture.

iOS remains a potential synchronized participant/receiver platform for the broader SoundMesh architecture, but it is not the host platform for arbitrary background capture of another application's audio.

## External Media Source of Truth

The external media application remains responsible for:

* media selection
* play/pause
* seeking
* playback speed
* subtitles
* track selection
* media format handling
* media library
* application-specific controls

SoundMesh synchronizes the resulting audio.

SoundMesh does not attempt to reproduce the external application's media-player functionality.

## Authoritative Audio Pipeline

```text
External media app
      ↓
Android AudioPlaybackCapture
      ↓
Captured audio frames
      ↓
Timestamp + sequence number
      ↓
Packetization / transport
      ↓
Participant jitter buffer
      ↓
Native scheduled audio output
      ↓
Speakers
```

## Rationale

The capture model represents the intended real-world product more accurately than the previous file-distribution model.

The core use case is:

```text
Open SoundMesh
      ↓
Create / Join room
      ↓
Connect devices
      ↓
Allow audio capture
      ↓
Open external media app
      ↓
Play normally
      ↓
SoundMesh distributes the live audio
      ↓
Everyone hears together
```

## Consequences

The following architectural assumptions are authoritative:

* live audio transport is required
* capture and output are native timing-critical systems
* audio frames require sequence/timing information
* participant buffering is required
* synchronization occurs against a shared timeline
* capture source compatibility must be surfaced
* background capture lifecycle must be handled
* capture interruptions must be recoverable
* host direct-output latency versus participant output latency must be measured
* the exact transport remains experimental
* the exact audio representation remains undecided

The following old assumptions are invalid:

* selecting a local song inside SoundMesh
* transferring an entire audio file before playback
* preparing an `audioId`
* SoundMesh owning playback controls
* SoundMesh maintaining a media library
* treating all external applications as universally captureable

## Affected Documents

The following documents must reflect DEC-085:

```text
DOCS/blueprint.md
DOCS/architecture.md
DOCS/audio.md
DOCS/networking.md
DOCS/playback-api.md
DOCS/ui-ux.md
DOCS/roadmap.md
DOCS/AI/ai-context.md
DOCS/testing.md
```

---

# 84. Final Engineering Principle

SoundMesh should be engineered according to one fundamental rule:

> **Make the simplest system capable of delivering genuinely synchronized multi-device audio, measure whether it works, and only add complexity when evidence requires it.**

The goal is not to create the most complicated architecture.

The goal is to create an architecture that makes the complicated problem **reliably solvable**.

---

# 85. Final Product Principle

The user should experience:

> **“We didn't have a speaker, so we made one out of our phones.”**

The engineering team should experience:

> **“We built a distributed synchronization system that makes independent audio devices behave like one.”**

Both statements describe the same product from different sides.

---

# 86. DEC-086 — Join Payload Formalization and Join Code Lifetime

**Status:** DECIDED

**Date:** 2026-09-19 (Phase 7 bootstrap task)

### Context

Phase 6 built raw connection mechanics; the 6-digit code + UDP discovery join
flow was added as a shortcut during UI integration. Formalizing the bootstrap
payload against the contract revealed gaps: codes never expired, code
generation used timestamp-derived randomness (identical codes within the same
millisecond, predictable values), the announcement advertised a roomId that
never matched the room ID the host assigned at handshake, and participant
validation produced no structured errors.

### Decision

1. The bootstrap payload is a transport-independent `JoinPayload` structure
   (`roomId`, `hostAddress`, `hostPort`, `protocolVersion`, `code`,
   `issuedAt`, `expiresAt`) shared by both transports: the UDP discovery
   announcement and the QR `soundmesh://join` URI (per DEC-013, with the
   credential transmitted in the `token` parameter). Swapping or adding a
   transport changes only transmission, not the data structure.
2. Join credential lifetime is 10 minutes from issuance, with a 60-second
   clock-skew allowance on validation. The effective lifetime is also bounded
   by the host session (broadcasting stops when the room closes, and the host
   stops broadcasting automatically when the credential expires).
3. Room code generation uses cryptographically secure randomness
   (`Random.secure()`), keeping the 6-digit format.
4. The host pre-assigns the room ID at room creation and uses it for both the
   discovery announcement and the WELCOME handshake, so the advertised and
   actual room identities agree.
5. Participant-side bootstrap failures raise structured errors
   (`INVALID_PAYLOAD`, `CODE_EXPIRED`, `PROTOCOL_VERSION_UNSUPPORTED`,
   `CODE_NOT_FOUND`, `ROOM_NOT_FOUND` — reserved).

### Alternatives considered

* Code lifetime tied only to host session lifetime (no explicit expiry) —
  rejected: a code seen or overheard could be reused much later.
* Keeping timestamp-derived code randomness — rejected: same bug class as the
  UUID collision defect already fixed in the protocol layer.
* Leaving the announcement roomId as a discovery-time value — rejected: it
  contradicts the payload contract and would break QR room verification.

### Consequences

* A participant who waits longer than 10 minutes after room creation cannot
  join with the original code (CODE_NOT_FOUND); the host must recreate the
  room or re-broadcast a fresh credential in a future iteration.
* QR payloads (Mahin's Phase 7) can be built against the documented format
  without backend changes; any adjustment after syncing with Mahin is a
  payload-level change only.

### Evidence

* 144 automated tests pass (including 17 pre-existing discovery tests
  unchanged, plus new payload/expiration/validation tests).
* `flutter analyze` clean.
* Two-real-device end-to-end validation: NOT TESTED (manual test for the
  developer).

### Affected Documents

```text
DOCS/networking.md (sections 14.1, 14.2, 59.1)
DOCS/interfaces/room-api.md (section 17 cross-reference)
```
