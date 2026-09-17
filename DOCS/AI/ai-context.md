# SoundMesh — AI Engineering Context

**Document Status:** REQUIRED
**Document Type:** AI Developer Context / Project Context
**Audience:** AI coding agents, AI-assisted developers, maintainers
**Primary Authority:** High-level project context and AI orientation
**Detailed Specifications:** See `DOCS/*.md`
**Repository Instructions:** See `AGENTS.md`

---

# 1. Purpose

This document provides the minimum high-level context an AI coding agent must understand before modifying SoundMesh.

It exists because technically valid code can still be architecturally incorrect.

An agent must understand:

* what SoundMesh is
* what problem it solves
* what the MVP actually does
* what is already decided
* what remains experimental
* where responsibilities belong
* what must not be built
* how success is measured

This document does not replace the detailed specifications.

It provides the mental model required to interpret them correctly.

---

# 2. What Is SoundMesh?

SoundMesh is an Android-first local application that allows multiple nearby phones to behave as a synchronized distributed speaker system.

The core product idea is:

> **Turn nearby phones into one synchronized speaker.**

SoundMesh does not provide a media library or replace the user's media applications.

Instead, the user's normal media application remains responsible for playing media.

SoundMesh captures eligible audio from the host device, distributes that live audio to participating devices, and coordinates their audio output.

---

# 3. The Actual Product Model

The intended user experience is:

```text
Open SoundMesh
      ↓
Create or join a room
      ↓
Connect nearby devices
      ↓
Allow audio capture
      ↓
Open a normal media app
      ↓
Play media normally
      ↓
SoundMesh captures the host's audio
      ↓
SoundMesh distributes the live audio
      ↓
Participant phones output it together
```

The external media application remains the source of truth for media playback.

SoundMesh does not become the media player.

---

# 4. What SoundMesh Is NOT

AI agents must understand these boundaries.

SoundMesh is **not**:

* a music player
* a video player
* a media library
* a playlist manager
* a file-sharing application
* an audio downloader
* a cloud music service
* a media synchronization service based on shared files

SoundMesh does not own:

* song selection
* video selection
* media metadata
* subtitles
* seeking
* playback position inside the external media application
* play/pause controls for the external application
* media decoding as a general-purpose player

The user's external media application owns those responsibilities.

---

# 5. Core Technical Problem

Playing audio on one phone is easy.

Streaming audio between phones is also possible.

The difficult problem is:

> **Making independent physical devices produce sufficiently synchronized audio.**

Each device has its own:

* processor
* operating-system scheduling
* monotonic clock
* audio hardware
* output pipeline
* speaker
* network conditions
* audio latency

SoundMesh must coordinate these independent systems.

The goal is not merely to synchronize application state.

The goal is to synchronize **actual sound output**.

---

# 6. Primary Engineering Challenge

The highest-priority technical question is:

> **Can SoundMesh capture eligible external-app audio on Android, transport it live over a local network, and produce sufficiently synchronized physical audio across multiple heterogeneous phones?**

Everything else is secondary until this is proven.

A beautiful interface does not compensate for broken audio synchronization.

A successful network connection does not prove synchronized sound.

A reported clock offset does not prove synchronized speakers.

A successful demo on one pair of devices does not prove scalability.

---

# 7. Core Engineering Principle

SoundMesh follows:

> **Prove the hardest technical assumption first, then build the product around measured evidence.**

Development should prioritize:

```text
Capture feasibility
        ↓
Live audio transport
        ↓
Native audio output
        ↓
End-to-end pipeline
        ↓
Clock synchronization
        ↓
Audio timing calibration
        ↓
Two-device synchronization
        ↓
Drift correction
        ↓
Multi-device scaling
        ↓
Recovery
        ↓
Product UX
        ↓
Polish
```

Do not spend the majority of development time on secondary features before the core audio system works.

---

# 8. Platform Strategy

The MVP is:

> **Android-only.**

The primary application framework is:

> **Flutter.**

Android is required because the MVP depends on Android platform capabilities for capturing eligible external application audio.

iOS is not an active MVP platform requirement.

Future iOS support may be investigated separately if a technically valid architecture becomes available.

AI agents must not introduce iOS-specific MVP abstractions merely to preserve theoretical cross-platform parity.

---

# 9. Android External Audio Capture

The host captures eligible audio from another Android application using Android's supported audio playback capture mechanisms.

Conceptually:

```text
External Media App
        ↓
Android Audio Playback Capture
        ↓
Captured Audio Frames
        ↓
SoundMesh
```

Capture may require:

* user-granted MediaProjection permission
* appropriate Android permissions
* a compatible foreground-service lifecycle
* a source application that permits capture

Not every external application is guaranteed to be captureable.

Source applications may explicitly prevent audio playback capture.

Therefore capture compatibility is a runtime condition, not a universal assumption.

---

# 10. Capture Is a First-Class Subsystem

Capture has explicit states.

Conceptually:

```text
UNAVAILABLE
     ↓
PERMISSION_REQUIRED
     ↓
CAPTURING
     ↓
STREAMING
```

It may also transition to:

```text
INTERRUPTED
DEGRADED
ERROR
STOPPED
```

Important failure cases include:

* permission denied
* MediaProjection revoked
* source application refuses capture
* capture becomes unavailable
* capture is interrupted
* unsupported capture format
* audio route changes
* operating-system restrictions
* foreground-service failure

AI agents must represent these conditions honestly.

---

# 11. Live Audio Pipeline

The authoritative audio architecture is:

```text
External Media App
        ↓
Android AudioPlaybackCapture
        ↓
Captured Audio Frames
        ↓
Timestamp + Sequence Number
        ↓
Packetization
        ↓
Local Audio Transport
        ↓
Participant Jitter Buffer
        ↓
Shared Timeline
        ↓
Scheduled Native Audio Output
        ↓
Participant Speaker
```

The host's external media application continues playing its own audio.

This creates a critical distinction between:

```text
Host external-app output
```

and:

```text
Captured host audio
        ↓
Network
        ↓
Participant output
```

Their latency paths may differ.

This must be measured.

---

# 12. Host Output Latency

The host's direct external-app output and a participant's replayed output do not necessarily have identical latency.

Conceptually:

```text
Host:

External App
    ↓
Host Audio Output


Participant:

External App
    ↓
Capture
    ↓
Network
    ↓
Jitter Buffer
    ↓
Scheduled Output
    ↓
Participant Speaker
```

The host therefore cannot automatically be treated as having the same acoustic timing as participants.

SoundMesh must measure or otherwise account for the relevant capture, transport, buffering, and output timing.

The exact host-output strategy remains an engineering question until validated experimentally.

An AI agent must not silently assume that host direct output and participant output have identical latency.

---

# 13. Host and Participant Model

SoundMesh uses a host-participant room model.

```text
                    Host
                     │
          ┌──────────┼──────────┐
          ↓          ↓          ↓
     Participant  Participant  Participant
```

The host coordinates:

* room state
* session state
* stream configuration
* session generation
* synchronization targets
* participant coordination

The host is authoritative for room/session coordination.

The host is **not automatically assumed to be the physical audio timing reference**.

Physical output timing must be measured.

---

# 14. Flutter / Native Boundary

The architecture is:

```text
Flutter
   │
   │ Typed platform interface
   ↓
Native Android
   │
   ├── Audio Capture
   ├── Audio Transport
   ├── Jitter Buffer
   ├── Audio Output
   ├── Timing
   └── Realtime Networking
```

Flutter owns:

* UI
* navigation
* high-level application state
* room/session presentation
* user interaction
* aggregated diagnostics

Native Android owns timing-sensitive operations including:

* MediaProjection
* AudioPlaybackCapture
* foreground service
* capture buffers
* audio packetization
* high-frequency audio transport
* jitter buffering
* native audio output
* output scheduling
* timing measurements
* realtime audio processing

Pigeon or another strongly typed platform interface may be used where appropriate.

---

# 15. Realtime Boundary Rule

Do not send every audio frame through Flutter.

Bad:

```text
Native Audio Callback
        ↓
Flutter
        ↓
Dart
        ↓
Widget
        ↓
Native Audio
```

Preferred:

```text
Native Realtime Subsystem
        ↓
Internal Processing
        ↓
Aggregated State / Measurements
        ↓
Flutter
        ↓
UI
```

Flutter should observe the realtime subsystem rather than participate in every audio operation.

High-frequency audio data must remain in native/realtime infrastructure.

---

# 16. Local-First Networking

SoundMesh is:

> **Local-first.**

Normal MVP operation should not require Internet access.

Expected environments include:

* local Wi-Fi
* phone hotspot
* other suitable local networks

The Internet must not become a hidden runtime dependency.

---

# 17. Networking Planes

Networking is logically divided into three planes.

### Control Plane

Responsible for:

* room state
* device state
* session state
* capture state
* permissions
* commands
* errors
* heartbeats
* recovery

### Audio Data Plane

Responsible for:

* live captured audio frames
* sequence numbers
* timestamps
* buffering
* reordering
* packet loss handling
* backpressure
* stream statistics

### Timing Plane

Responsible for:

* timestamp exchange
* RTT measurements
* clock relationship estimation
* timing telemetry
* synchronization inputs

These planes may share physical connections initially.

They must remain logically distinct.

---

# 18. Live Audio Is Not File Transfer

The active audio architecture is live streaming.

The old architecture of:

```text
Select File
    ↓
Transfer File
    ↓
Verify Hash
    ↓
Store File
    ↓
Prepare File
    ↓
Play File
```

is not the MVP architecture.

The active architecture is:

```text
Capture
    ↓
Frame
    ↓
Timestamp
    ↓
Transmit
    ↓
Buffer
    ↓
Schedule
    ↓
Output
```

AI agents must not reintroduce audio asset distribution unless a new architectural decision explicitly requires it.

---

# 19. Audio Frames

The exact wire format remains implementation-dependent.

Conceptually an audio frame contains:

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

The actual serialization, packet size, codec/PCM representation, and transport must be determined through implementation and measurement.

Sequence numbers are required for detecting:

* loss
* duplication
* reordering
* gaps

Timestamps are required for:

* timing
* buffering
* scheduling
* synchronization
* diagnostics

---

# 20. Transport Is an Engineering Decision

Do not assume that one transport is automatically correct.

Reliable ordered transport may be appropriate for:

* control messages
* room state
* configuration

Live audio transport must be evaluated for:

* latency
* jitter
* packet loss
* reordering
* head-of-line blocking
* implementation complexity
* CPU usage
* bandwidth

TCP, UDP, QUIC, WebSocket, or another mechanism must not be treated as permanently decided unless `decisions.md` explicitly says so.

Choose based on evidence.

Do not introduce UDP merely because it is associated with realtime systems.

---

# 21. QR-First Joining

The intended onboarding flow is:

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

Users should not normally need to enter:

* IP addresses
* ports
* protocol parameters

manually.

The QR payload may contain temporary bootstrap information.

---

# 22. QR Security

QR payloads must not contain:

* permanent credentials
* long-lived secrets
* private keys
* unnecessary personal information
* audio data

Prefer:

* room identifiers
* endpoint/bootstrap information
* protocol version
* short-lived join authorization

Use established authentication/encryption mechanisms.

Do not invent custom cryptography.

---

# 23. Identity

An IP address is a network location, not a permanent device identity.

Use explicit identifiers for:

* room
* session
* device
* participant

Network addresses may change.

Logical identity must survive ordinary network changes where appropriate.

---

# 24. Synchronization Mental Model

The most important synchronization concept is:

> **SoundMesh is a distributed timing system.**

There is no magically shared perfect clock.

Each device has its own clock.

SoundMesh estimates relationships between clocks and coordinates output against a shared logical timeline.

The objective is:

```text
Independent clocks
       ↓
Measured relationship
       ↓
Shared timeline
       ↓
Scheduled output
```

---

# 25. Monotonic Time

Synchronization calculations should use monotonic timing sources where available.

Do not rely exclusively on wall-clock time.

Wall clocks may change because of:

* system synchronization
* user adjustments
* timezone changes
* operating-system corrections

Elapsed-time synchronization requires stable timing references.

---

# 26. Timestamp Exchange

A conceptual exchange is:

```text
Participant → Host: t1
Host receives:      t2
Host → Participant: t3
Participant receives: t4
```

These measurements can provide inputs for estimating:

* RTT
* clock relationships
* timing uncertainty

The exact algorithm must follow `synchronization.md`.

---

# 27. RTT Is Not Audio Latency

These are different measurements:

```text
Network RTT
Clock Offset
Network One-Way Delay
Capture Latency
Network Latency
Jitter Buffer Delay
Audio Output Latency
Speaker Latency
```

Never substitute one for another.

For example:

> Low RTT does not automatically mean low physical speaker latency.

---

# 28. Capture-to-Output Timing

For synchronized live audio, the system must understand the complete timing path.

Conceptually:

```text
Capture
  ↓
Timestamp
  ↓
Network
  ↓
Buffer
  ↓
Schedule
  ↓
Native Output
  ↓
Speaker
```

The system should expose enough timing information to determine where delay exists.

Important measurements may include:

* capture-to-network delay
* network-to-buffer delay
* buffer depth
* network-to-output delay
* output timestamp
* host output timing
* participant output timing

---

# 29. Calibration

Before synchronized output, devices should establish the timing relationships required by the session.

Conceptually:

```text
Connect
   ↓
Measure
   ↓
Estimate
   ↓
Reject outliers
   ↓
Estimate uncertainty
   ↓
Calibrated
```

Calibration should produce a quality/confidence assessment where practical.

Calibration is not the same thing as network connection.

---

# 30. Shared Live-Audio Timeline

SoundMesh uses a shared logical timeline for live audio.

Participants receive audio frames before their intended output time whenever possible.

Conceptually:

```text
Current Timeline
       +
Future Output Target
       ↓
Jitter Buffer
       ↓
Native Scheduled Output
```

This provides room for network variation while maintaining coordinated output.

---

# 31. Scheduled Output

Avoid:

```text
PLAY NOW
```

as the primary synchronization mechanism.

Commands received at different times cannot guarantee simultaneous physical output.

Prefer:

```text
Current synchronized timeline
        +
Future target timestamp
        ↓
Native scheduled output
```

The exact scheduler implementation must be determined experimentally.

---

# 32. Preparation and Buffering

A participant joining a live session must not immediately emit audio merely because it has connected.

Expected flow:

```text
Join
 ↓
Receive current stream information
 ↓
Establish timing
 ↓
Fill bounded jitter buffer
 ↓
Determine future output target
 ↓
Schedule native output
 ↓
Join synchronized output
```

Unlike a file-based architecture, a late participant cannot simply download the complete media asset and seek to a known position.

It joins the current live stream.

---

# 33. Late Joining

Late joiners need:

* current session generation
* current stream configuration
* current timeline information
* current capture state
* timing calibration
* enough live audio buffering
* a future synchronization target

The participant may need to wait briefly before becoming active.

This is preferable to producing unsynchronized audio immediately.

---

# 34. Drift

Even devices that start synchronized can gradually diverge.

Possible causes include:

* oscillator differences
* audio hardware differences
* resampling
* operating-system behavior
* output-clock differences

SoundMesh must monitor timing over the lifetime of the session.

---

# 35. Drift Correction

A conceptual correction hierarchy is:

```text
Measure
   ↓
Estimate drift
   ↓
Apply tiny correction
   ↓
Re-measure
   ↓
Apply small position correction if required
   ↓
Controlled resynchronization if necessary
```

Corrections should prioritize:

* stability
* inaudibility
* avoiding oscillation
* avoiding unnecessary disruption

Do not build an unstable feedback loop.

---

# 36. Generations

Session generation numbers remain important.

They prevent stale session state from affecting a newer session.

For example:

```text
Generation 10
       ↓
Old stream/session state

Generation 11
       ↓
Current stream/session state
```

A packet or command belonging to an older generation should not corrupt the current session.

Generations are for session/state freshness.

They must not be used to recreate old media-player `PLAY`, `PAUSE`, or `SEEK` semantics.

---

# 37. External Media Playback Ownership

The external media application controls:

* play
* pause
* seek
* next
* previous
* media position
* playback speed
* media selection

SoundMesh controls:

* room
* connection
* capture session
* live audio stream
* synchronization
* participant output
* recovery

This separation is fundamental.

---

# 38. Capture and External-App Handoff

The user should be able to:

```text
Allow audio capture
        ↓
Open media app
        ↓
Play normally
        ↓
SoundMesh captures eligible audio
```

SoundMesh may remain active in the background when Android permits it and when the required foreground-service lifecycle is correctly implemented.

A persistent notification may be required.

The UI must clearly communicate when capture is active, stopped, interrupted, or unavailable.

---

# 39. Source-App Compatibility

Not every external application is guaranteed to allow capture.

The system must distinguish:

```text
SoundMesh capture unavailable
```

from:

```text
This particular source application does not permit capture
```

where the platform can determine the difference.

Do not claim universal compatibility with:

* YouTube
* Spotify
* VLC
* browsers
* games
* other applications

without testing the specific source and Android configuration.

---

# 40. Background and Lifecycle Behavior

Background operation is a real engineering requirement.

The system must consider:

* foreground-service restrictions
* MediaProjection lifecycle
* persistent notification requirements
* application backgrounding
* device locking
* audio route changes
* interruptions
* network changes
* process death
* permission revocation

Do not assume that a background Dart process can safely maintain realtime audio.

Native Android lifecycle handling is required.

---

# 41. Failure Handling

SoundMesh must explicitly handle:

* participant disconnect
* host disconnect
* network interruption
* network change
* capture permission denial
* source capture refusal
* MediaProjection revocation
* capture interruption
* unsupported capture format
* audio route changes
* output failure
* stream underrun
* packet loss
* packet reordering
* jitter
* calibration failure
* synchronization degradation
* background lifecycle interruption

Failure behavior should be deterministic and observable.

---

# 42. Host Failure

MVP does not require seamless host migration.

If the host disappears, the system may:

* terminate the room
* enter controlled recovery
* require participants to reconnect

Do not introduce host election or migration architecture unless a documented requirement justifies it.

---

# 43. Network Recovery

A disconnected participant should not automatically invalidate the entire room.

Expected recovery may be:

```text
Disconnect
   ↓
Reconnect
   ↓
Rejoin current session
   ↓
Refresh timing
   ↓
Refill jitter buffer
   ↓
Schedule future output
   ↓
Return to active state
```

Do not assume that a disconnected participant can resume by retrieving an old audio file.

The active source is a live stream.

---

# 44. Bounded Buffers

Audio buffers must remain bounded.

Unbounded buffering can turn network degradation into increasing latency.

When a participant falls behind significantly, the system may need to:

* drop stale frames
* refill from a newer live point
* resynchronize
* temporarily suppress output

The exact policy is an engineering decision.

The host should not block every participant because one device is slow.

---

# 45. State Machines

Important subsystems should use explicit state machines.

Room/session states may conceptually include:

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

Error states may occur from any appropriate point.

Avoid replacing explicit state with large collections of unrelated booleans.

Do not use `PAUSED` as a generic SoundMesh media state because SoundMesh does not own external media playback.

---

# 46. UI Philosophy

SoundMesh should feel:

* dark
* minimal
* premium
* calm
* audio-focused
* technically sophisticated without being visually noisy

The UI should hide implementation complexity.

Users should not need to understand:

* clock offsets
* RTT
* jitter buffers
* packet sequence numbers
* transport protocols
* calibration algorithms

unless they enter diagnostics.

---

# 47. Primary User Journey

The correct product mental model is:

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

The old mental model:

```text
Create
Join
Choose Audio
Prepare
Play
```

is obsolete.

There is no SoundMesh audio picker or SoundMesh-owned media player in the MVP.

---

# 48. UI Anti-Patterns

AI agents must not create:

* song selection screens
* local audio libraries
* track lists
* track artwork
* media progress bars
* SoundMesh play/pause controls
* SoundMesh seek controls
* next/previous controls
* audio asset transfer progress
* audio download states
* fake media metadata
* fake playback position
* fake universal source compatibility

SoundMesh may show:

* capture status
* streaming status
* connected devices
* synchronization quality
* buffering state
* recovery state
* source compatibility state
* diagnostics

---

# 49. Visual Direction

The primary visual system is defined in `ui-ux.md`.

Current core palette:

```text
Background:       #0B0D10
Surface:          #181D23
Primary Text:     #F5F7FA
Secondary Text:   #A7AFB9
Accent:           #5B8CFF
Success:          #39D98A
Warning:          #FFB84D
Error:            #FF5C6C
```

Avoid:

* excessive neon
* gamer RGB styling
* arbitrary gradients
* excessive glassmorphism
* excessive animation
* emoji as primary icons
* fake technical dashboards

---

# 50. Accessibility

Accessibility is required.

Consider:

* sufficient contrast
* touch targets
* dynamic text
* screen-reader semantics
* reduced motion
* status information that does not rely solely on color

---

# 51. Performance Priority

The priority order is:

```text
Audio Stability
      ↓
Synchronization
      ↓
Realtime Networking
      ↓
Application Responsiveness
      ↓
Visual Effects
```

Visual polish must never compromise realtime audio.

---

# 52. Testing Philosophy

Launching the application is not proof of correctness.

Testing must progressively validate:

```text
Unit
 ↓
Component
 ↓
Integration
 ↓
Real Android Devices
 ↓
Live Audio Pipeline
 ↓
Synchronization
 ↓
Stress
 ↓
Physical Acoustic Output
```

Core synchronization claims require real hardware.

---

# 53. Real Devices Are Required

Emulators are useful for:

* UI
* application logic
* navigation
* basic protocol tests

They cannot prove:

* real speaker timing
* physical output latency
* real capture behavior
* real Wi-Fi behavior
* device-specific audio processing
* acoustic synchronization

Core audio synchronization must be validated on physical Android devices.

---

# 54. Device Scaling

Initial progression:

```text
2 devices
   ↓
3 devices
   ↓
5 devices
   ↓
larger groups
```

Two-device success does not automatically prove larger-scale success.

---

# 55. Physical Synchronization Validation

Software metrics are not sufficient proof of physical synchronization.

Strong validation should use external measurement.

Conceptually:

```text
Phone A ─┐
Phone B ─┤
Phone C ─┼──→ External recording / measurement
Phone D ─┤
Phone E ─┘
```

Controlled signals should be used where possible.

Measure actual waveform onset or equivalent acoustic timing differences.

---

# 56. Engineering Targets

Initial engineering targets may include:

```text
Startup group spread:
≤ 20 ms

Steady-state group spread:
≤ 20 ms
```

These are engineering targets, not guarantees.

They must never be presented as achieved until measured on real hardware.

A software-reported metric must not be confused with measured acoustic output.

---

# 57. Do Not Fake Metrics

AI agents must never invent:

* synchronization measurements
* latency
* jitter
* packet-loss results
* device compatibility
* benchmark results
* battery measurements
* thermal results
* acoustic measurements

If something has not been measured:

```text
NOT MEASURED
```

is the correct result.

---

# 58. Existing Documentation

Before modifying SoundMesh, agents should understand the relevant specifications.

```text
DOCS/blueprint.md
```

Product definition and scope.

```text
DOCS/architecture.md
```

System architecture and platform boundaries.

```text
DOCS/networking.md
```

Local networking, protocol, and live audio transport.

```text
DOCS/synchronization.md
```

Clock synchronization, timing, calibration, scheduling, and drift.

```text
DOCS/audio.md
```

External audio capture, live audio pipeline, native output, and audio lifecycle.

```text
DOCS/ui-ux.md
```

Visual and interaction system.

```text
DOCS/decisions.md
```

Settled and open engineering decisions.

```text
DOCS/testing.md
```

Testing and validation requirements.

```text
DOCS/roadmap.md
```

Development order and milestones.

```text
DOCS/AI/rules.md
```

Rules for AI-assisted development.

```text
DOCS/AI/task-protocol.md
```

How AI agents should execute tasks.

```text
AGENTS.md
```

Repository-wide agent instructions.

---

# 59. Documentation Hierarchy

Think of the documentation as layers:

```text
Product
   ↓
Blueprint
   ↓
Architecture
   ↓
Subsystem Specifications
   ↓
Decisions
   ↓
Testing
   ↓
Roadmap
   ↓
AI Execution Rules
```

Each document answers a different question.

An AI agent should read the smallest relevant set of documents before making a change.

---

# 60. Decision Awareness

Before making an architectural change, inspect:

```text
DOCS/decisions.md
```

Look for statuses such as:

* `DECIDED`
* `PREFERRED`
* `EXPERIMENTAL`
* `UNDECIDED`
* `REJECTED`
* `SUPERSEDED`

Do not silently turn an `UNDECIDED` item into a permanent architecture decision.

If a decision must be made, document the evidence and update the appropriate decision record.

---

# 61. Important Decided Constraints

The current high-level constraints are:

```text
Flutter is the primary application framework.

Android is the MVP platform.

SoundMesh is local-first.

The external media application remains the source of truth for media playback.

SoundMesh captures eligible host external audio.

Live captured audio is the active audio distribution mechanism.

The host coordinates the room.

QR is the preferred joining mechanism.

Flutter owns UI and high-level orchestration.

Native Android owns timing-critical audio and networking.

High-frequency audio data stays outside Flutter.

Synchronization uses monotonic timing.

Playback/output is scheduled against future timing targets.

Synchronization must be measured.

Drift must be monitored.

Physical synchronization must eventually be validated.

Real devices are required for synchronization testing.

SoundMesh does not own external media playback.

File-based audio distribution is not the MVP architecture.
```

---

# 62. Important Experimental Areas

The following remain evidence-driven:

```text
Exact live audio transport
Codec vs PCM
Audio packet format
Packet size
Sample-rate strategy
Channel strategy
Resampling strategy
Jitter-buffer policy
Packet-loss recovery policy
Exact clock synchronization algorithm
Exact audio latency measurement method
Host direct-output synchronization strategy
Background-service implementation details
Maximum practical device count
Automatic discovery
Wi-Fi Direct / P2P
Advanced host recovery
Source-application compatibility
```

An AI agent must not present these as settled facts unless the decision has been documented.

---

# 63. Rejected or Out-of-Scope MVP Directions

Do not introduce these without a new architectural decision:

```text
Mandatory cloud backend
Mandatory Internet connectivity
SoundMesh-owned media player
SoundMesh-owned media library
Audio file distribution as the primary session architecture
Manual IP onboarding
PLAY NOW as the primary synchronization mechanism
Premature microservices
Premature account systems
Music discovery
Social features unrelated to the core problem
Unnecessary infrastructure
Mandatory iOS MVP support
```

---

# 64. Repository Philosophy

SoundMesh should remain understandable.

Avoid:

* speculative abstractions
* duplicate systems
* unnecessary dependencies
* unused infrastructure
* premature generalization
* compatibility layers for unsupported platforms without a requirement

Prefer the smallest architecture that satisfies measured requirements.

---

# 65. AI Implementation Philosophy

AI-generated code is not automatically correct.

An agent should:

1. read the relevant specification
2. identify the applicable decision state
3. understand existing code
4. identify the smallest required change
5. implement it
6. test it
7. inspect failures
8. verify behavior
9. update documentation when necessary
10. report limitations honestly

---

# 66. Small Changes Are Preferred

Do not combine unrelated changes.

Bad:

```text
Implement networking
+
Redesign UI
+
Rewrite audio architecture
+
Refactor state management
```

Good:

```text
Implement participant handshake.
```

Then test it independently.

---

# 67. Avoid Architecture by Vibes

Do not choose technology because:

* it is popular
* another project uses it
* an AI model recommends it
* it seems modern
* it has a convenient API

Choose technology because:

* it satisfies the requirement
* it works on the target platform
* testing supports it
* it fits the architecture
* it has acceptable maintenance cost

---

# 68. When Documentation and Code Conflict

If implementation differs from documentation:

1. do not silently assume either is correct
2. identify the discrepancy
3. determine which reflects the intended architecture
4. inspect `decisions.md`
5. test if necessary
6. update documentation or implementation accordingly

Documentation drift is a defect.

---

# 69. When an AI Agent Gets Blocked

Classify the blocker.

### Missing dependency

Investigate project configuration and dependency requirements.

### Platform limitation

Document the limitation and evaluate alternatives.

### Architectural contradiction

Consult `decisions.md` and the relevant subsystem specification.

### Undefined behavior

Find the corresponding `UNDECIDED` item.

Do not silently invent a permanent behavior.

### Test failure

Investigate the actual failure before changing architecture.

### Capture failure

Determine whether the problem is:

* permission
* MediaProjection lifecycle
* source-app capture restriction
* unsupported format
* foreground-service lifecycle
* route/interruption issue
* implementation defect

Do not immediately redesign the system.

---

# 70. What an AI Agent Must Never Do

Never:

* fabricate test results
* claim untested compatibility
* silently change architecture
* delete requirements to make implementation easier
* weaken tests merely to make them pass
* introduce cloud infrastructure without justification
* introduce iOS MVP requirements without evidence
* expose unnecessary technical internals in UX
* treat experimental code as production truth
* treat an IP address as device identity
* use wall-clock time as the only synchronization mechanism
* use `PLAY NOW` as the primary sync mechanism
* claim perfect synchronization
* assume two-device success proves large-scale success
* assume low RTT proves synchronized speakers
* assume host output latency equals participant output latency
* assume every Android source application allows capture
* route every audio frame through Flutter
* rebuild the old audio-file distribution architecture
* create a SoundMesh media player
* add SoundMesh-owned play/pause/seek controls for external media
* invent acoustic measurements

---

# 71. Core Terminology

Use these terms consistently.

### Host

The device coordinating a SoundMesh room.

### Participant

A device participating in synchronized audio output.

### Room

The logical collection of devices participating together.

### Session

A specific active audio-session instance within a room.

### Device ID

Stable logical identity for a participating device.

### Participant ID

Identity of a device within a particular room/session.

### Capture Session

The host-side external-audio capture lifecycle.

### Audio Stream

The live sequence of captured audio frames distributed to participants.

### Audio Frame

A timestamped, sequenced unit of captured audio data.

### Shared Timeline

The logical timing reference used to coordinate output.

### Clock Offset

Estimated timing relationship between clocks.

### RTT

Round-trip network time.

### Jitter

Variation in packet arrival timing.

### Buffer Fill

The amount of audio currently available in a participant's jitter buffer.

### Drift

Gradual divergence in audio timing between devices.

### Calibration

The process of estimating timing and latency relationships.

### Startup Spread

Difference between actual output start times across devices.

### Steady-State Spread

Difference between device output positions over continued playback.

### Session Generation

Version identifier used to reject stale session state.

---

# 72. Product Vocabulary

Prefer simple user-facing language such as:

```text
Connecting…

Allow audio capture

Open your media app

SoundMesh is listening

Streaming

Getting everyone in sync…

Everyone is ready

Synchronized

Audio capture unavailable

This app doesn't allow audio capture

Reconnecting…

Resynchronizing…
```

Avoid exposing technical language such as:

```text
Clock offset calibration phase 2
TCP handshake failure 104
RTT variance exceeded
Jitter buffer underrun
```

unless the user is viewing diagnostics.

---

# 73. Technical Vocabulary Rules

Engineers may use technical terminology in:

* code
* logs
* diagnostics
* engineering documentation
* protocol definitions

User-facing UI should translate technical state into understandable language.

---

# 74. Core User Journey

The authoritative journey is:

```text
Open SoundMesh
      ↓
Create Room
      ↓
Display QR
      ↓
Friends Scan QR
      ↓
Devices Connect
      ↓
Allow Audio Capture
      ↓
Open External Media App
      ↓
Play Normally
      ↓
SoundMesh Captures Audio
      ↓
Live Audio Streams
      ↓
Devices Synchronize
      ↓
Everyone Hears Together
```

The complexity underneath this flow should remain mostly invisible.

---

# 75. MVP Definition

The MVP fundamentally consists of:

```text
Android application
+
Local room creation
+
QR-based joining
+
Local device networking
+
External-app audio capture
+
Live audio transport
+
Native participant audio output
+
Clock synchronization
+
Timing calibration
+
Future-target scheduling
+
Two-device synchronization
+
Basic drift handling
+
Basic recovery
+
Diagnostics
```

The MVP does not fundamentally require:

```text
Audio file distribution
+
Media library
+
SoundMesh media player
+
Cloud backend
+
Internet access
+
iOS
```

---

# 76. First Technical Milestone

The first major technical milestone is:

> **Two real Android phones receive the same live external-app audio through SoundMesh and produce measured, repeatable, perceptually coherent synchronized output.**

This milestone is more important than completing a large feature set.

---

# 77. Scaling Milestone

After two-device synchronization works:

```text
2 devices
   ↓
3 devices
   ↓
5 devices
```

Synchronization quality must be measured at each stage.

Do not infer scalability from two-device success.

---

# 78. Competition-Readiness Milestone

SoundMesh approaches competition readiness when:

* the core room flow is reliable
* external audio capture works on tested sources
* live audio transport is stable
* synchronization is repeatable
* drift is controlled
* recovery is predictable
* multiple devices work
* physical measurements support synchronization claims
* UI is polished
* diagnostics exist
* documentation is coherent
* builds are stable
* the demonstration is repeatable

---

# 79. AI Mental Model

Before changing code, an AI agent should be able to answer:

### What are we building?

A synchronized multi-phone speaker system.

### What is the hardest part?

Synchronizing actual physical audio output across heterogeneous Android devices.

### What platform?

Android for the MVP.

### What framework?

Flutter plus native Android integrations.

### Does it require cloud?

No.

### Does it require Internet?

No for normal MVP operation.

### How do devices join?

QR-first.

### Where does the audio come from?

The host's eligible external media application.

### Does SoundMesh own media playback?

No.

### How does audio reach participants?

Live capture → timestamped frames → local network → jitter buffer → scheduled native output.

### How is synchronization achieved?

Measured clock relationships + timing calibration + shared timeline + future scheduled output + drift monitoring/correction.

### Does the host's speaker automatically have the same latency as participants?

No assumption may be made. It must be measured or otherwise accounted for.

### How do we know synchronization works?

Measure it on real physical devices, including acoustic output where possible.

### What happens if an external app refuses capture?

Surface the incompatibility clearly. Do not pretend capture succeeded.

### What happens if a decision is unclear?

Read `decisions.md` and the relevant specification. Do not silently decide.

---

# 80. The Most Important Mental Model

Think of SoundMesh as:

```text
                 EXTERNAL MEDIA APP
                         │
                         ▼
                AUDIOPLAYBACKCAPTURE
                         │
                         ▼
                  CAPTURED AUDIO
                         │
                Timestamp + Sequence
                         │
                         ▼
                  LIVE AUDIO STREAM
                         │
             ┌───────────┼───────────┐
             ▼           ▼           ▼
         Phone A      Phone B      Phone C
             │           │           │
       Jitter Buffer Jitter Buffer Jitter Buffer
             │           │           │
        Shared Timeline / Timing Model
             │           │           │
      Scheduled Native Audio Output
             │           │           │
          Speaker      Speaker      Speaker
```

Above this realtime path is:

```text
Room Control
Device State
Capture State
Session State
Diagnostics
Recovery
```

The central engineering problem is coordinating independent clocks, network paths, capture timing, buffering, and audio output well enough that the resulting physical sound behaves like one system.

---

# 81. Evidence-Driven Development

SoundMesh development should follow:

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

An AI agent should not jump directly from:

```text
Unknown
   ↓
Implementation
```

especially for timing-critical architecture.

---

# 82. Final AI Principle

The AI developer's job is not simply:

> **Write code that works.**

It is:

> **Write code that fits the architecture, satisfies documented requirements, survives testing, and produces measurable evidence that the system behaves as intended.**

When uncertain:

> **Measure.**

When architecture is unclear:

> **Read the decisions.**

When requirements are unclear:

> **Read the specifications.**

When a feature is unnecessary:

> **Do not build it.**

When something has not been tested:

> **Do not claim that it works.**

When an external application may reject capture:

> **Handle the failure explicitly.**

When a timing assumption has not been measured:

> **Do not assume it.**

---

# 83. Final SoundMesh Principle

SoundMesh should feel extremely simple to the person using it:

```text
Create
Join
Connect
Allow Capture
Open Media App
Play
Everyone Hears Together
```

Underneath that simplicity, the system must carefully coordinate:

```text
External Audio Capture
+
Networking
+
Identity
+
Live Audio Transport
+
Buffering
+
Clock Relationships
+
Scheduling
+
Drift
+
Recovery
+
Physical Hardware
```

The user should not have to understand that complexity.

The engineering must.

> **Complexity belongs underneath the product, not inside the user's head.**

---

**End of AI Engineering Context.**
