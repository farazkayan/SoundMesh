# SoundMesh — Faraz Work Plan

**Document Status:** ACTIVE
**Document Type:** Developer Workstream Specification
**Owner:** Faraz
**Primary AI Consumer:** Faraz's AI development agent
**Project:** SoundMesh
**Last Updated:** 2026-09-15

---

# 1. Purpose

This document defines the complete technical workstream owned by Faraz.

Faraz owns the core technical systems that make SoundMesh function as a synchronized multi-device audio system.

This document does NOT replace the shared SoundMesh architecture, subsystem specifications, or interface contracts.

It answers a different question:

> **"What is Faraz responsible for building, in what order, and what does completion mean?"**

All work described here MUST remain consistent with:

1. `AGENTS.md`
2. `CONTRIBUTING.md`
3. `DOCS/blueprint.md`
4. `DOCS/architecture.md`
5. `DOCS/roadmap.md`
6. `DOCS/networking.md`
7. `DOCS/synchronization.md`
8. `DOCS/audio.md`
9. `DOCS/testing.md`
10. `DOCS/contract-testing.md`
11. `DOCS/interfaces/*`
12. `DOCS/AI/rules.md`
13. `DOCS/AI/task-protocol.md`
14. `DOCS/AI/integration-protocol.md`

Higher-authority documents override this document.

---

# 2. Faraz's Ownership

Faraz is primarily responsible for:

* Core application coordination
* Room management implementation
* Device management implementation
* Local networking
* Room discovery/bootstrap
* Connection lifecycle
* Protocol implementation
* External audio capture infrastructure
* Android AudioPlaybackCapture integration
* Captured audio transport
* Live audio buffering infrastructure
* Native audio output infrastructure
* Synchronization
* Clock synchronization
* Timing measurement
* Latency estimation
* Capture/output latency investigation
* Calibration
* Shared audio timeline
* Drift detection
* Drift correction
* Synchronization recovery
* Native Android timing/audio infrastructure
* Android foreground-service lifecycle where required
* MediaProjection lifecycle where required
* Flutter-to-native integration
* Pigeon/platform-channel boundaries where required
* Backend/core state machines
* Integration infrastructure
* Core contract implementations
* Contract tests for Faraz-owned interfaces
* Technical diagnostics
* Performance instrumentation
* Real-device synchronization validation
* Technical bug fixing
* Cross-subsystem integration

SoundMesh's MVP is Android-first.

iOS native timing/audio implementation is NOT part of the current MVP workstream.

Faraz is NOT the primary owner of:

* Flutter visual design
* UI screen implementation
* UI animations
* UI component styling
* User-facing navigation design
* UI-only state presentation

Those areas are primarily owned by Mahin.

However, Faraz MUST provide the technical interfaces required by the UI.

---

# 3. Fundamental Rule

Faraz does NOT build isolated backend systems.

Every subsystem MUST be implemented as part of the complete SoundMesh architecture.

The goal is not:

> "Make the backend work."

The goal is:

> **"Make the complete SoundMesh system work reliably across multiple real Android devices."**

A subsystem is not considered complete merely because its unit tests pass.

Subsystem completion ultimately requires integration evidence.

---

# 4. Development Strategy

Faraz's work follows this general progression:

```text
Completed Foundation
        ↓
External Audio Capture Feasibility
        ↓
Local Networking Foundation
        ↓
Room Bootstrap / Connection
        ↓
Live Captured-Audio Transport
        ↓
Native Audio Output
        ↓
Capture → Network → Output Pipeline
        ↓
Clock Synchronization
        ↓
Latency / Calibration
        ↓
Two-Device External-Audio Sync
        ↓
Drift Detection
        ↓
Drift Correction
        ↓
Multi-Device Scaling
        ↓
Failure / Recovery
        ↓
Generation / Stale-State Protection
        ↓
Diagnostics
        ↓
Flutter / Native Integration
        ↓
Mahin UI Integration
        ↓
Contract / End-to-End Validation
        ↓
Performance / Reliability
        ↓
Competition Hardening
```

The exact order may change if an approved architectural decision requires it.

The critical path MUST prioritize the highest-risk technical assumptions early.

---

# 5. Phase 0 — Repository and Development Foundation

## Objective

Establish a safe technical foundation before implementing SoundMesh functionality.

## Responsibilities

Faraz MUST:

* Verify Flutter project structure.
* Establish package/module boundaries.
* Establish native Android structure.
* Establish native iOS structure when available.
* Establish shared models/types.
* Establish error representation.
* Establish logging infrastructure.
* Establish configuration handling.
* Establish environment separation.
* Establish test structure.
* Establish linting/formatting.
* Establish dependency management.
* Establish platform abstraction boundaries.

## Required principles

Flutter MUST NOT directly implement timing-critical functionality.

Timing-sensitive functionality belongs behind native interfaces.

## Completion criteria

* Project builds.
* Tests execute.
* Android project builds.
* iOS project structure is valid where development environment permits.
* Native boundaries are documented.
* No subsystem has bypassed the architecture.

---

# 6. Phase 1 — Contract Implementation Foundation

## Objective

Turn the documented interfaces into implementation-ready contracts.

## Primary interfaces

* Core API
* Room API
* Device API
* Audio API
* Playback API
* Sync API

## Responsibilities

Faraz MUST:

* Define implementation-side types corresponding to contracts.
* Define shared request/result models.
* Define structured errors.
* Define state representations.
* Define lifecycle representations.
* Define generation identifiers where required.
* Implement contract validation.
* Create mocks/fakes where useful for testing.
* Create contract tests.

## Critical rule

The documented interface is authoritative.

Faraz's implementation MUST NOT silently redefine the interface.

If implementation reveals an inadequate contract:

```text
Implementation discovers problem
        ↓
STOP
        ↓
Propose contract change
        ↓
Update documentation
        ↓
Update interface
        ↓
Update implementation
        ↓
Update dependent consumers
        ↓
Run integration tests
```

---

# 7. Phase 2 — Core Coordinator

## Objective

Implement the Core system that coordinates SoundMesh subsystems.

Core MUST coordinate:

* Room
* Device
* Audio
* Playback
* Sync

Core MUST NOT secretly become responsible for the internal algorithms of those systems.

## Responsibilities

Implement the conceptual Core operations:

* `getState()`
* `createRoom()`
* `joinRoom()`
* `leaveRoom()`
* `getRoomState()`
* `selectAudio()`
* `preparePlayback()`
* `play()`
* `pause()`
* `resume()`
* `seek()`
* `stop()`
* `getDevices()`
* `getPlaybackState()`
* `getSyncStatus()`
* `resynchronize()`

Exact signatures MUST follow the current Core API contract.

## Completion criteria

Core can coordinate a complete high-level flow without requiring UI code to directly manipulate internal subsystems.

---

# 8. Phase 3 — Room System

## Objective

Implement authoritative room lifecycle and membership management.

## Responsibilities

Implement:

* Room creation
* Room identity
* Host role
* Participant role
* Join lifecycle
* Leave lifecycle
* Membership registration
* Room state
* Room membership state
* Join validation
* Room-level errors
* Room state transitions

## Must preserve

Room membership MUST remain distinct from:

* Network connection
* IP address
* Socket identity
* Device identity
* Human identity

A connected socket does not automatically mean a valid room member.

## Completion criteria

Two real devices can:

1. Create a room.
2. Obtain valid join information.
3. Join the room.
4. Become registered participants.
5. Observe consistent membership state.
6. Leave the room cleanly.

---

# 9. Phase 4 — Device System

## Objective

Implement device identity, capabilities, readiness, presence, and device state.

## Responsibilities

Implement:

* Device identity
* Device registration
* Device lifecycle
* Device capabilities
* Connection state
* Presence state
* Readiness state
* Audio route information where supported
* Synchronization status exposure
* Device errors
* Device status updates

## Critical distinctions

Faraz MUST NOT merge:

```text
Device Identity

Room Membership

Network Connection

Playback State

Synchronization State
```

These are separate concepts.

## Completion criteria

The system can reliably determine:

* Which device is present.
* Which device belongs to the room.
* Whether it is connected.
* Whether it is ready.
* Whether it is capable of required playback.
* What synchronization state it reports.

No fabricated capability or status values are permitted.

---

# 10. Phase 5 — Android External-Audio Capture Feasibility

## Objective

Prove that SoundMesh can capture eligible audio produced by another Android application using the platform's supported audio playback capture mechanisms.

This is the highest-risk technical assumption in the new SoundMesh architecture and MUST be validated before building the complete live-audio transport pipeline.

## Product model

SoundMesh does NOT own media playback.

The host uses an external application such as:

* YouTube
* VLC
* Spotify
* Browser-based media
* A video player
* Another eligible media application

The intended architecture is:

```text
External Media App
        ↓
Android System Audio
        ↓
AudioPlaybackCapture
        ↓
SoundMesh
```

SoundMesh MUST NOT become a replacement media player.

## Responsibilities

Faraz MUST investigate and implement the minimum technical proof for:

* Android `AudioPlaybackCapture`
* `MediaProjection` permission flow
* Capture configuration
* Capturable audio usages
* Source application capture policy
* Audio format discovery
* Sample rate
* Channel configuration
* PCM frame acquisition
* Capture lifecycle
* Capture start
* Capture stop
* Capture failure
* Permission denial
* Source application incompatibility
* Capture interruption
* Android version compatibility

## Critical platform requirements

The implementation MUST follow current Android platform requirements for:

* MediaProjection
* AudioPlaybackCapture
* Runtime permissions
* Foreground-service requirements
* Android background execution restrictions

The implementation MUST NOT assume that arbitrary applications permit capture.

## Required experiment

At minimum, test multiple real Android source applications.

Record:

* Android version
* Device model
* Source application
* Whether capture permission was granted
* Whether audio was captured
* Captured format
* Sample rate
* Channel count
* Observed capture latency
* Failure reason where applicable

## Completion criteria

Phase 5 is complete only when:

1. SoundMesh can obtain user-approved capture access.
2. SoundMesh can capture eligible external application audio.
3. Captured PCM data can be observed reliably.
4. Capture lifecycle can be started and stopped safely.
5. At least one real external media application has been successfully captured on a physical Android device.
6. Unsupported/blocked source applications are detected or reported honestly.
7. Platform restrictions and known limitations are documented.

No large networking/audio-streaming implementation should be built solely on an unverified capture assumption.

---

# 11. Phase 6 — Local Networking Foundation

## Objective

Build reliable local networking for SoundMesh.

## Initial target

Local Wi-Fi and phone hotspot environments.

Internet connectivity MUST NOT be required for the core SoundMesh experience.

## Responsibilities

Implement:

* Host networking
* Participant networking
* Connection establishment
* Handshake
* Room bootstrap
* Message envelopes
* Protocol versioning
* Session identifiers
* Participant identifiers
* Heartbeats
* Connection lifecycle
* Reconnection foundations
* Structured network errors
* Control-plane messaging
* Timing-plane support where required
* Live audio transport foundation

## Message envelope

Messages MUST follow the documented networking contract.

Conceptual fields include:

* `protocolVersion`
* `messageType`
* `messageId`
* `sessionId`
* `senderId`
* `generation`
* `timestamp`
* `payload`

Fields MUST NOT be changed casually.

## Role validation

The implementation MUST be tested in both directions where applicable:

```text
Android Host → Android Participant
Android Participant → Android Host
```

Role changes MUST NOT corrupt room state or connection lifecycle.

## Completion criteria

Two real devices can establish a stable local connection and exchange validated protocol messages.

---

# 12. Phase 7 — QR / Room Bootstrap

## Objective

Make joining a room simple and reliable.

## Responsibilities

Implement the technical side of:

* Join payload generation
* Join payload parsing
* Room identification
* Bootstrap information
* Short-lived join tokens
* Protocol version information
* Validation
* Expiration handling

Conceptual format:

```text
soundmesh://join?
room=<room-id>&
host=<bootstrap-address>&
port=<bootstrap-port>&
version=<protocol-version>&
token=<short-lived-join-token>
```

The exact format is governed by `networking.md`.

QR rendering itself is primarily UI-owned.

Faraz owns the underlying join data and validation.

## Security requirements

QR payloads MUST NOT contain permanent credentials.

## Completion criteria

A participant can obtain join information, connect to the host, validate the room/session, and become a registered participant.

---

# 13. Phase 8 — Live Captured-Audio Transport

## Objective

Transport captured external application audio from the host to participating devices in real time.

The old file-distribution model is NOT used.

## Architecture

The intended model is:

```text
Host External App
        ↓
Android AudioPlaybackCapture
        ↓
Captured PCM
        ↓
Audio Buffer / Packetizer
        ↓
Local Network
        ↓
Participants
        ↓
Jitter / Receive Buffer
        ↓
Native Audio Output
```

## Responsibilities

Implement and evaluate:

* Captured audio stream abstraction
* PCM frame handling
* Packetization
* Sequence numbering
* Audio timestamps
* Stream/session identity
* Packet ordering
* Packet loss detection
* Receive buffering
* Jitter buffering
* Buffer underrun detection
* Buffer overrun handling
* Stream start/stop
* Stream reset
* Format propagation
* Sample-rate handling
* Channel configuration
* Backpressure
* Network failure handling

## Critical distinction

SoundMesh is transporting a **live audio stream**, not distributing a media file.

Therefore SoundMesh MUST NOT require:

* A complete audio file
* A media library
* Media metadata such as title/artist
* Subtitle data
* Video data
* Media seeking infrastructure
* Media decoding for arbitrary file formats

The external application owns those concerns.

## Transport decision

The exact transport mechanism and encoding MUST be selected based on evidence from:

* Latency
* CPU usage
* Packet overhead
* Reliability
* Audio quality
* Network conditions
* Device capability

Do not prematurely commit to a transport or codec without validation.

## Completion criteria

A host can capture live external-app audio and deliver an ordered, validated audio stream to at least one participant over the local network.

---

# 14. Phase 9 — Native Synchronized Audio Output

## Objective

Build the native Android audio output layer required to render the received live audio stream with precise timing.

This is an audio output engine, NOT a media player.

## Android

Evaluate/use appropriate native audio infrastructure according to the architecture.

Candidate technologies may include:

* Oboe
* AAudio
* AudioTrack

The final choice MUST be evidence-based.

## Responsibilities

Implement:

* Audio output initialization
* Audio buffer submission
* Low-latency output where supported
* Output scheduling
* Start
* Pause where architecturally required
* Resume where architecturally required
* Stop
* Output position observation
* Output timing observation
* Audio-route awareness
* Output failure handling
* Underrun detection
* Stream generation handling

## Critical rule

The native output engine MUST NOT become a general media player.

It MUST NOT assume responsibility for:

* Opening arbitrary media files
* Video playback
* Subtitles
* Media browsing
* Media metadata
* Media seeking based on external media APIs

It receives audio data and renders it according to SoundMesh's synchronization model.

---

# 15. Phase 10 — Capture-to-Output Pipeline

## Objective

Connect the major technical components into one real-time audio pipeline.

## Required pipeline

```text
External Media App
        ↓
AudioPlaybackCapture
        ↓
Captured PCM
        ↓
Buffer
        ↓
Packetize
        ↓
Network
        ↓
Receive Buffer
        ↓
Jitter Buffer
        ↓
Native Audio Output
```

## Responsibilities

Integrate:

* Capture
* Audio buffering
* Packetization
* Networking
* Receive buffering
* Jitter management
* Native output
* Stream lifecycle
* Error propagation
* Generation handling

## Critical investigation: host latency

The system MUST explicitly investigate the difference between:

```text
External App
      ↓
Host's audible output
```

and:

```text
External App
      ↓
Audio Capture
      ↓
Network
      ↓
Participant Buffer
      ↓
Participant Output
```

The capture path may introduce latency relative to the host's original audio output.

SoundMesh MUST NOT assume these paths are naturally synchronized.

Possible approaches MAY include:

* Measured latency compensation
* Delayed host reference/output
* Host output through SoundMesh where technically feasible
* Participant compensation
* Another evidence-based architecture

No solution may be treated as final until physically validated.

## Completion criteria

A real external media application can produce audio that travels through the complete SoundMesh pipeline and emerges from another physical Android device.

---

# 16. Phase 11 — Monotonic Clock and Clock Synchronization

## Objective

Allow devices to estimate their timing relationship for synchronized audio output.

## Responsibilities

Implement:

* Monotonic clock abstraction
* Timestamp exchange
* Clock offset estimation
* RTT measurement
* Uncertainty estimation
* Clock model
* Timing observation storage
* Outlier handling foundations

Use the documented timestamp exchange model.

Conceptual exchange:

```text
Participant → Host

     t1

Host receives

     t2

Host → Participant

     t3

Participant receives

     t4
```

Offset estimate:

```text
offset ≈ ((t2 - t1) + (t3 - t4)) / 2
```

RTT:

```text
RTT = (t4 - t1) - (t3 - t2)
```

The implementation MUST NOT assume network delay is perfectly symmetric.

Uncertainty MUST be represented.

## Critical rule

Monotonic timestamps MUST NOT be treated as inherently synchronized between devices.

Clock calibration establishes the relationship between independent clock domains.

---

# 17. Phase 12 — Audio Timing and Calibration

## Objective

Determine how each device should compensate for timing differences across capture, network, buffering, and output.

## Responsibilities

Implement and measure:

* Clock offset
* Network latency
* Network jitter
* Capture latency
* Buffer latency
* Output latency
* Estimated end-to-end latency
* Device-specific timing differences
* Calibration state
* Calibration result
* Confidence
* Calibration failure handling

Conceptual states:

```text
UNKNOWN
    ↓
CALIBRATING
    ↓
SYNCHRONIZED
    ↓
DEGRADED
    ↓
FAILED
```

The exact thresholds MUST be evidence-based and documented.

## Critical rule

Calibration MUST consider the complete audio path where measurable:

```text
Capture
  ↓
Transport
  ↓
Receive Buffer
  ↓
Output
```

Clock synchronization alone is not sufficient to prove audible synchronization.

## Confidence

Confidence values MUST represent actual model confidence.

Never generate decorative or arbitrary percentages.

---

# 18. Phase 13 — Shared Live-Audio Timeline

## Objective

Create a common logical timeline for live captured audio.

Unlike the previous file-based architecture, the timeline MUST represent a continuously arriving audio stream.

## Responsibilities

Implement:

* Stream timeline
* Audio sequence position
* Target output time
* Buffer readiness
* Stream generation
* Start scheduling
* Pause/stop semantics where applicable
* Stream reset
* Late participant synchronization
* Resynchronization

Conceptual model:

```text
Capture Timeline
       ↓
Network Timeline
       ↓
Output Timeline
       ↓
Shared Logical Audio Position
```

All devices MUST reason from the same logical audio event.

## Critical rule

Do not reintroduce a media-player timeline merely because the system needs synchronized audio positions.

The timeline belongs to the synchronized audio stream, not to media ownership.

---

# 19. Phase 14 — Two-Device External-Audio Synchronization Milestone

## Objective

Achieve the first complete real SoundMesh milestone.

## Required test

At least two physical Android phones.

Not:

* Two simulators
* Mocked clocks
* Theoretical calculations
* Unit tests alone

## Required flow

```text
Phone A
Create Room
    ↓
Phone B
Join
    ↓
User grants capture permission
    ↓
Host opens external media app
    ↓
SoundMesh captures audio
    ↓
Audio transported
    ↓
Both devices prepare output
    ↓
Clock synchronization
    ↓
Calibration
    ↓
Shared output schedule
    ↓
Audio output
    ↓
Measure physical output
```

## Target

Initial engineering target:

**≤20 ms group playback spread**

Preferred:

**≤10 ms**

These are engineering targets, not guarantees.

## Required evidence

* Repeatable tests
* Multiple runs
* Real devices
* Recorded measurements
* Documented environment
* Documented source application
* Documented Android versions
* Documented failures
* No fake metrics

## Completion criteria

Two physical Android devices can repeatedly reproduce synchronized output from a real external media application within the defined engineering target under documented conditions.

This is the most important technical milestone.

---

# 20. Phase 15 — Drift Detection

## Objective

Detect devices gradually moving out of synchronization during continuous live audio.

## Responsibilities

Implement:

* Output timing observation
* Audio position observation
* Timing error estimation
* Drift estimation
* Drift rate estimation
* Confidence/uncertainty
* Drift thresholds
* Monitoring loop

Conceptual model:

```text
error(t) =
    offset +
    driftRate × elapsedTime
```

The exact estimator remains experimental until validated.

---

# 21. Phase 16 — Drift Correction

## Objective

Keep devices synchronized during extended live audio playback.

## Responsibilities

Implement and evaluate correction strategies.

Potential hierarchy:

```text
Small error
    ↓
Subtle timing correction

Medium error
    ↓
Controlled correction

Large error
    ↓
Resynchronization

Severe failure
    ↓
Recovery procedure
```

Corrections MUST NOT introduce unacceptable:

* Clicks
* Pops
* Pitch artifacts
* Audible speed changes
* Discontinuities
* Audible jumps

Every correction strategy MUST be tested physically.

## Critical rule

Do not introduce arbitrary audio manipulation merely to force synchronization.

Correction strategies must be technically justified and measurable.

---

# 22. Phase 17 — Multi-Device Scaling

## Objective

Move beyond the two-device proof of concept.

## Test progression

```text
2 devices
   ↓
3 devices
   ↓
5 devices
```

Larger groups may be tested if hardware and time permit.

Do not skip directly to large-scale testing.

## Variables

Test across:

* Different Android phone models
* Different Android versions
* Different audio hardware
* Different network conditions
* Different distances
* Network congestion
* CPU load
* Battery conditions
* Background activity
* Different external source applications where supported

## Measure

* Join success rate
* Connection stability
* Capture success rate
* Capture interruption rate
* Audio transport success
* Buffer underruns
* Buffer overruns
* Startup spread
* Steady-state spread
* Drift
* Recovery time
* CPU
* Memory
* Battery impact
* Network traffic

---

# 23. Phase 18 — Failure and Recovery

## Objective

Make SoundMesh robust when real-world conditions become bad.

## Responsibilities

Handle and test:

* Participant disconnect
* Temporary network loss
* Host disconnect
* Audio capture failure
* MediaProjection termination
* Source application refusing capture
* Audio stream interruption
* Invalid audio format
* Audio output failure
* Buffer underrun
* Buffer overrun
* Sync degradation
* Calibration failure
* Late join
* Device interruption
* Audio-route changes
* App interruption
* Foreground-service interruption
* Stale commands
* Duplicate commands
* Out-of-order messages
* Network congestion

## Critical rule

Never invent host migration behavior.

Host migration remains UNDECIDED unless explicitly approved and documented.

---

# 24. Phase 19 — Generation and Stale-State Protection

## Objective

Prevent old asynchronous operations from corrupting current state.

Generation identifiers MUST be used wherever required by the architecture.

Example:

```text
Generation 1

Audio Stream A
    ↓
Capture begins

Generation 2

Audio Stream B
    ↓
New stream begins

Generation 1 finishes late
    ↓
MUST NOT overwrite Generation 2
```

Apply the same principle to:

* Room transitions
* Audio capture
* Audio streams
* Network sessions
* Playback/output
* Synchronization
* Calibration
* Scheduled output
* Async network operations
* Recovery operations

---

# 25. Phase 20 — Diagnostics and Observability

## Objective

Make synchronization and audio failures measurable and debuggable.

## Responsibilities

Provide technical diagnostics for:

* Device
* Room
* Network
* Capture
* Audio stream
* Output
* Synchronization

Useful measurements include:

* RTT
* Estimated clock offset
* Estimated drift
* Uncertainty
* Capture state
* Capture source compatibility
* Capture latency
* Buffer depth
* Jitter
* Packet loss
* Packet reordering
* Underruns
* Overruns
* Calibration state
* Output position
* Scheduled target time
* Actual output timing where measurable
* Connection state
* Audio readiness
* Sync state
* Recovery events

## Critical rule

Diagnostics MUST expose real measurements.

Never fabricate metrics to make the UI appear healthy.

---

# 26. Phase 21 — Flutter / Native Integration

## Objective

Connect the technical core to the Flutter application safely.

## Responsibilities

Implement:

* Flutter-facing interfaces
* Pigeon/platform-channel definitions where appropriate
* Native method exposure
* Native event exposure
* Serialization
* Error propagation
* State propagation
* Lifecycle handling
* Capture permission state
* Capture-service state
* Audio synchronization state

## Critical rule

Do not send high-frequency timing or audio data through Flutter unnecessarily.

Timing-critical loops and high-frequency audio processing MUST remain native where appropriate.

Flutter should receive meaningful state/results rather than raw audio frames or every low-level timing event.

---

# 27. Phase 22 — Integration With Mahin's UI

## Objective

Make the technical systems consumable by Mahin's UI without exposing internal implementation details.

Mahin's UI MUST interact through documented contracts.

Faraz MUST provide accurate interfaces for:

* Core API
* Room API
* Device API
* Audio API
* Playback/output API
* Sync API
* Capture state
* Structured errors
* Meaningful state
* Events where required
* Accurate status

## Important product distinction

The UI MUST NOT imply that SoundMesh is a media player.

UI state should communicate concepts such as:

* Room connected
* Devices connected
* Capture permission required
* Audio capture active
* Audio synchronization active
* Waiting for audio
* Synchronization degraded
* Capture unsupported
* Connection lost

It should NOT expose unnecessary media-player concepts such as:

* SoundMesh media library
* Subtitle system
* Internal media browsing
* Arbitrary file playback
* SoundMesh-owned video playback

## Integration rule

If Mahin's UI requires information not represented by the contract:

```text
Identify missing contract
        ↓
Do NOT invent it
        ↓
Propose contract change
        ↓
Approve
        ↓
Implement
        ↓
Test
```

---

# 28. Phase 23 — Contract Testing

## Objective

Ensure independently developed systems remain compatible.

Every Faraz-owned interface MUST have contract tests.

Tests SHOULD verify:

* Input validity
* Output shape
* State transitions
* Error behavior
* Required fields
* Generation behavior
* Lifecycle behavior
* Timing semantics
* Ordering requirements
* Cancellation behavior
* Capture lifecycle
* Audio stream lifecycle
* Synchronization state
* Recovery semantics

The contract is the shared agreement between Faraz's implementation and Mahin's consumer code.

---

# 29. Phase 24 — End-to-End Real-Device Integration

## Objective

Validate SoundMesh as one complete Android system.

## Required path

```text
Create Room
    ↓
Generate Join Information
    ↓
Join From Another Device
    ↓
Register Participant
    ↓
Grant Capture Permission
    ↓
Start Capture
    ↓
Open External Media App
    ↓
Capture External Audio
    ↓
Transport Live Audio
    ↓
Prepare Native Output
    ↓
Synchronize Clocks
    ↓
Calibrate
    ↓
Schedule Synchronized Output
    ↓
Play Synchronized Audio
    ↓
Monitor
    ↓
Detect Drift
    ↓
Correct
    ↓
Handle Interruptions
    ↓
Resynchronize
    ↓
Stop
    ↓
Leave
```

The complete path MUST be tested on real Android devices.

## Critical rule

The external media application remains the media owner.

SoundMesh only captures, transports, synchronizes, and outputs audio.

---

# 30. Phase 25 — Performance and Reliability

## Objective

Optimize only after correctness has been established.

Measure:

* Room creation time
* Join time
* Capture startup time
* Capture latency
* Audio pipeline latency
* Buffer latency
* Network traffic
* Packet loss
* Buffer underruns
* Synchronization convergence
* Startup spread
* Steady-state spread
* Long-session drift
* CPU usage
* Memory usage
* Battery impact
* Recovery time

## Rule

```text
Measure
    ↓
Identify bottleneck
    ↓
Form hypothesis
    ↓
Optimize
    ↓
Measure again
```

Never optimize based only on intuition.

---

# 31. Phase 26 — Competition Hardening

## Objective

Prepare the technical system for the Shipaton submission.

Faraz MUST verify:

* Core demo path is reliable.
* External audio capture works on the supported test configuration.
* Real-device synchronization is repeatable.
* No critical crashes remain.
* Major failure cases are handled.
* Architecture documentation matches implementation.
* Interfaces match actual behavior.
* README accurately describes the system.
* No fake technical claims exist.
* Performance claims are backed by measurements.
* Android platform limitations are documented.
* Unsupported capture sources are handled honestly.
* Open-source requirements are satisfied where applicable.
* Demo build is reproducible.
* Critical setup instructions are documented.
* Required permissions and Android restrictions are documented.

---

# 32. Definition of Done for Faraz

A Faraz-owned feature is NOT DONE merely because:

* The code compiles.
* The AI says it works.
* A unit test passes.
* A mock works.
* A simulator works.

A feature is DONE when applicable:

```text
Implementation
      +
Contract compliance
      +
Unit tests
      +
Integration tests
      +
Documentation
      +
Real-device validation
      +
Evidence
```

The required level depends on the feature.

Timing-critical features require physical validation.

Audio capture, networking, buffering, output timing, and synchronization MUST receive real-device validation.

---

# 33. Faraz AI Task Selection Rules

When assigning work to Faraz's AI, tasks SHOULD be narrow and explicit.

Good:

```text
Implement the Android audio capture abstraction according to
DOCS/interfaces/audio-api.md and the current audio architecture.

Use Android AudioPlaybackCapture.

Do not implement a media player.

Add tests for lifecycle and error handling.

Document platform limitations.
```

Bad:

```text
Build the audio system.
```

The AI MUST know:

* What subsystem it owns.
* What contract applies.
* What files it may modify.
* What tests are expected.
* What is explicitly out of scope.
* What platform constraints apply.

---

# 34. Faraz AI Must Not Modify Mahin-Owned Work Without Coordination

Faraz's AI MUST NOT casually modify:

* Mahin's UI implementation
* UI layout
* UI styling
* UI navigation
* UI components
* UI interaction logic

unless the task explicitly requires coordinated integration work.

If an integration issue appears:

```text
Identify issue
    ↓
Determine ownership
    ↓
Fix only the Faraz-owned side if possible
    ↓
Otherwise report dependency/blocker
```

---

# 35. Faraz AI Stop Conditions

The AI MUST STOP and report a blocker when:

1. An interface is undefined.
2. Two authoritative documents conflict.
3. Existing code contradicts the contract.
4. A required architectural decision is missing.
5. Mahin's subsystem requires an undocumented behavior.
6. A contract needs to change.
7. The AI would need to modify another owner's subsystem.
8. A synchronization algorithm requires an unapproved assumption.
9. Timing behavior cannot be measured reliably.
10. The AI cannot determine which state is authoritative.
11. A dependency is unclear.
12. A proposed solution changes system architecture.
13. A test contradicts the expected behavior.
14. A platform-specific behavior is unknown and affects correctness.
15. The AI is tempted to "just make it work" through an undocumented workaround.
16. Android prevents or restricts the required audio capture behavior.
17. The external application refuses audio capture and the architecture has no approved fallback.
18. Capture/output latency cannot be characterized sufficiently for synchronization.
19. The AI would need to turn SoundMesh into a media player to satisfy a requirement.
20. A proposed audio transport or encoding choice has not been sufficiently validated for the required latency/reliability target.

The AI MUST NOT silently resolve these situations by guessing.

---

# 36. Faraz's Primary Milestones

The most important milestones are:

## M1 — Foundation

Repository, architecture, contracts, and native boundaries established.

## M2 — Core Systems

Core, Room, and Device systems implemented and tested.

## M3 — External Audio Capture Proven

A physical Android device can capture eligible external application audio through the supported Android capture mechanism.

## M4 — Two Devices Connected

Two physical Android phones can create/join a room and communicate.

## M5 — Live Audio Transport

Captured host audio can reach another physical device as a validated live stream.

## M6 — Native Audio Output

A received live audio stream can be rendered through the native Android audio output layer.

## M7 — End-to-End Audio Pipeline

External application audio can travel:

```text
External App
    ↓
Capture
    ↓
Network
    ↓
Receive Buffer
    ↓
Native Output
```

on real devices.

## M8 — Two-Device Synchronization

Two physical devices achieve repeatable synchronized output within the engineering target.

## M9 — Drift Control

Devices remain acceptably synchronized during extended live audio.

## M10 — Multi-Device

3–5 physical devices operate together.

## M11 — Recovery

Common failures do not unnecessarily destroy the session.

## M12 — Full Integration

Mahin's UI controls the real technical system through documented contracts.

## M13 — Competition Ready

The complete demo path is stable, measurable, documented, and reproducible.

---

# 37. Priority Order

When deciding what to build first, use:

```text
1. Feasibility
2. Correctness
3. Architecture
4. Contract stability
5. Real-device functionality
6. Audio latency
7. Synchronization accuracy
8. Reliability
9. Failure recovery
10. Diagnostics
11. Performance
12. UI integration
13. Polish
```

The first priority is proving that the fundamental external-audio architecture actually works.

Do not build large systems around an unverified platform assumption.

Do not sacrifice synchronization correctness for visual polish.

Do not sacrifice architecture for speed.

Do not sacrifice contract integrity to satisfy a short-term UI requirement.

---

# 38. The Two-Phone Rule

At every major technical milestone, prefer proving the system with two real Android phones before scaling.

```text
One phone
    ↓
Capture proof
    ↓
Two phones
    ↓
Stable two-phone system
    ↓
Three phones
    ↓
Five phones
```

A feature that cannot reliably work with two real devices is not ready for scaling.

---

# 39. Evidence Rule

Every important technical claim MUST be supported by evidence.

Examples:

Instead of:

> "Sync is perfect."

Use:

> "Across X physical test runs on Y devices under Z network conditions, measured startup spread was between A–B ms."

Instead of:

> "The network is reliable."

Use:

> "Under the defined test conditions, connection success was X/Y."

Instead of:

> "YouTube works."

Use:

> "On device X running Android version Y, the tested source application successfully produced capturable audio under configuration Z."

Technical claims MUST be measurable whenever practical.

---

# 40. Final Responsibility

Faraz's responsibility is not merely to build a backend.

Faraz owns the technical foundation that allows:

```text
External Media App
        │
        │
        ↓
Android System Audio
        │
        ↓
Audio Capture
        │
        ↓
SoundMesh Host
        │
        ├──── Room ────────┐
        │                  │
        ├──── Network ─────┤
        │                  │
        ├──── Audio ───────┤
        │                  │
        ├──── Timing ──────┤
        │                  │
        └──── Sync ────────┤
                           │
                     Phone B
                           │
                     Phone C
                           │
                     Phone D
```

to behave as **one coordinated audio system**.

The ultimate technical objective is:

> **Multiple independent Android phones must behave like one synchronized speaker system by capturing eligible audio from the host's existing media application, distributing that live audio locally, and coordinating its output across devices.**

SoundMesh does NOT own the media itself.

SoundMesh does NOT replace the external media player.

SoundMesh owns the synchronization layer.

Everything Faraz builds should serve that objective.

---

# 41. Final Principle

Faraz's work is the technical foundation of SoundMesh.

The implementation MUST remain:

* contract-driven
* local-first
* timing-aware
* measurable
* testable
* platform-conscious
* failure-aware
* integration-safe
* AI-safe
* honest about uncertainty

The final standard is not:

> "The code works on my machine."

The final standard is:

> **"The complete SoundMesh system works predictably across real Android devices, and we have evidence to prove it."**
