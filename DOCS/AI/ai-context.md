\# SoundMesh — AI Engineering Context



\*\*Document Status:\*\* REQUIRED

\*\*Document Type:\*\* AI Developer Context / Project Context

\*\*Audience:\*\* AI coding agents, AI-assisted developers, maintainers

\*\*Primary Authority:\*\* High-level project context and AI orientation

\*\*Detailed Specifications:\*\* See `DOCS/\*.md`

\*\*Repository Instructions:\*\* See `AGENTS.md`



\---



\# 1. Purpose



This document provides the minimum high-level context an AI coding agent should understand before modifying SoundMesh.



It exists because AI agents can produce technically valid code that is nevertheless incorrect for the project's architecture.



An agent must understand:



\* what SoundMesh is

\* what problem it solves

\* what matters most

\* how the system is structured

\* which decisions are already settled

\* which areas are experimental

\* which areas are unknown

\* where different responsibilities belong

\* how success is measured



This document does not replace the detailed specifications.



It provides the mental model required to use them correctly.



\---



\# 2. What Is SoundMesh?



SoundMesh is a mobile application that allows multiple nearby phones to coordinate audio playback so that they behave like one synchronized speaker system.



The core idea is:



> \*\*Turn nearby phones into one synchronized speaker.\*\*



The application is designed for situations where people have multiple phones but do not have a physical speaker available.



\---



\# 3. The Core Problem



Playing audio on one phone is easy.



Playing the same audio on multiple phones is also easy.



The difficult problem is:



> \*\*Making independent physical devices produce sufficiently synchronized audio.\*\*



Each phone has its own:



\* processor

\* operating system

\* clock

\* audio hardware

\* audio pipeline

\* speaker

\* network behavior

\* latency characteristics



SoundMesh exists to coordinate those independent systems.



\---



\# 4. What Makes SoundMesh Technically Interesting?



The basic product concept is not new.



Similar products have existed.



Therefore SoundMesh must not depend on novelty of the statement:



> “Multiple phones can play audio together.”



The engineering differentiation is execution quality.



Important areas include:



\* automatic calibration

\* accurate timing

\* scheduled playback

\* clock relationship estimation

\* drift detection

\* drift correction

\* heterogeneous-device support

\* local-first operation

\* resilient joining

\* recovery

\* synchronization diagnostics

\* measurable performance



\---



\# 5. Primary Engineering Challenge



The most important technical question is:



> \*\*Can SoundMesh reliably synchronize audio across multiple heterogeneous physical phones to a perceptually coherent level?\*\*



Everything else is secondary to proving this.



A beautiful UI does not compensate for poor synchronization.



A successful network connection does not prove synchronization.



A low reported timing error does not automatically prove low physical acoustic error.



\---



\# 6. Core Engineering Principle



The project follows:



> \*\*Prove the hardest technical assumption first, then build the product around what the evidence shows.\*\*



Do not spend the majority of development time on:



\* animations

\* settings

\* social features

\* cloud systems

\* playlists

\* accounts



before the core synchronization system works.



\---



\# 7. Product Model



The application uses a room-based model.



Conceptually:



```text

Host

&#x20;├── Participant

&#x20;├── Participant

&#x20;├── Participant

&#x20;└── Participant

```



The host coordinates the room.



Participants join the room and synchronize with the session.



The host is not necessarily a continuous audio-streaming server.



\---



\# 8. Platform Strategy



SoundMesh targets:



\* Android

\* iOS



The primary application framework is:



> \*\*Flutter\*\*



Flutter provides:



\* UI

\* navigation

\* high-level application state

\* user interaction

\* cross-platform presentation



Native Android/iOS code provides platform-specific realtime capabilities.



\---



\# 9. Flutter / Native Boundary



The architecture is:



```text

Flutter

&#x20;  │

&#x20;  │ typed platform interface

&#x20;  ↓

Native Android / iOS

&#x20;  │

&#x20;  ├── Audio

&#x20;  ├── Timing

&#x20;  └── Networking

```



Flutter should not be treated as the realtime audio engine.



Timing-critical operations should remain as close to the native platform APIs as practical.



Pigeon is the preferred mechanism for strongly typed platform APIs where appropriate.



\---



\# 10. Realtime Boundary Rule



Do not send high-frequency realtime audio events through Flutter unless there is a compelling technical reason.



Bad conceptual architecture:



```text

Native audio callback

&#x20;↓

Flutter

&#x20;↓

Dart

&#x20;↓

Widget rebuild

&#x20;↓

Native audio

```



Preferred:



```text

Native realtime subsystem

&#x20;↓

Internal processing

&#x20;↓

Aggregated state/measurements

&#x20;↓

Flutter

&#x20;↓

UI

```



Flutter should observe the system rather than control every realtime event.



\---



\# 11. Networking Model



SoundMesh is:



> \*\*Local-first.\*\*



Normal playback should not require Internet access.



Preferred MVP environments:



\* local Wi-Fi

\* phone hotspot/local network



The Internet should not become a hidden dependency.



\---



\# 12. Preferred Networking Architecture



Conceptually:



```text

&#x20;            Local Network



Host ─────────────────── Participant

&#x20; │                           │

&#x20; ├────────────────────────── Participant

&#x20; │                           │

&#x20; └────────────────────────── Participant

```



The exact physical network topology may vary.



The application should abstract the transport from the higher-level room protocol.



\---



\# 13. QR-First Joining



The intended onboarding path is:



```text

Host:

Create Room

&#x20;↓

Display QR



Participant:

Join Room

&#x20;↓

Scan QR

&#x20;↓

Connect

```



Users should not normally need to enter:



\* IP addresses

\* ports

\* technical connection parameters



manually.



\---



\# 14. QR Security Principle



QR payloads may contain temporary bootstrap information.



They must not contain:



\* permanent credentials

\* long-lived secrets

\* private keys

\* unnecessary personal information

\* audio data



Short-lived join authorization is preferred.



\---



\# 15. IP Address Is Not Identity



An IP address represents a network location.



It must not be treated as a permanent device identity.



SoundMesh should use explicit identifiers for:



\* room

\* session

\* participant/device



\---



\# 16. Audio Architecture



The preferred architecture is:



```text

Host selects audio

&#x20;      ↓

Audio distributed to participants

&#x20;      ↓

Each device stores/prepares local copy

&#x20;      ↓

Each device schedules local playback

&#x20;      ↓

Synchronization maintained

```



This is preferred over continuously streaming decoded audio from the host.



\---



\# 17. Why Audio Is Distributed First



If every device already has the audio asset, the network does not need to continuously deliver the audio during playback.



The system instead needs to coordinate:



\* when playback starts

\* where playback is

\* how devices drift

\* how devices recover



This reduces the synchronization system's dependence on continuous network streaming.



\---



\# 18. Audio Integrity



A participant must not assume that a received audio file is correct.



The asset should be verified using a content hash or equivalent integrity mechanism.



Conceptually:



```text

Transfer

&#x20;↓

Hash verification

&#x20;↓

Valid

&#x20;↓

Prepare

```



If verification fails:



```text

Transfer

&#x20;↓

Hash mismatch

&#x20;↓

Reject / recover

```



\---



\# 19. Audio Preparation



A device is not READY merely because it possesses an audio file.



Preparation should include:



\* asset validation

\* integrity verification

\* decoder availability

\* audio engine initialization

\* required buffering

\* playback readiness

\* synchronization readiness



\---



\# 20. Local Playback



Each participant should ideally play its local audio asset through its native audio system.



The native layer is responsible for timing-sensitive playback operations.



Flutter is responsible for presenting the resulting state.



\---



\# 21. Synchronization Mental Model



The most important concept an AI agent must understand is:



> \*\*SoundMesh is a distributed timing system.\*\*



There is no single magical global clock that every phone automatically shares with perfect accuracy.



Each phone has its own timing system.



SoundMesh estimates relationships between them.



\---



\# 22. Shared Logical Timeline



SoundMesh creates a shared logical playback timeline.



Each participant maps its local timing system to that timeline.



Conceptually:



```text

Host clock

&#x20;    │

&#x20;    ├── shared timeline

&#x20;    │

Participant A clock

&#x20;    │

Participant B clock

&#x20;    │

Participant C clock

```



The goal is not to make physical clocks identical.



The goal is to coordinate playback events.



\---



\# 23. Monotonic Time



Synchronization calculations should use monotonic timing sources where available.



Do not rely exclusively on wall-clock time.



Wall clocks may change because of:



\* system synchronization

\* user adjustments

\* timezone changes

\* operating-system corrections



Elapsed-time synchronization requires stable timing references.



\---



\# 24. Timestamp Exchange



A conceptual exchange is:



```text

Participant → Host: t1

Host receives:    t2

Host → Participant: t3

Participant receives: t4

```



The system can estimate clock relationship and RTT from these measurements under the documented assumptions.



The exact implementation must follow `synchronization.md`.



\---



\# 25. RTT Is Not Audio Latency



This distinction is critical.



These are different concepts:



```text

Network RTT

Clock offset

Network one-way delay

Audio preparation latency

Audio output latency

Speaker latency

```



Do not substitute one measurement for another.



For example:



> Low RTT does not automatically mean low speaker latency.



\---



\# 26. Calibration



Before synchronized playback, participants should measure the timing relationship.



Conceptual lifecycle:



```text

Connect

&#x20;↓

Measure

&#x20;↓

Estimate

&#x20;↓

Reject outliers

&#x20;↓

Determine uncertainty

&#x20;↓

Calibrated

```



Calibration must provide a confidence/quality assessment.



\---



\# 27. Scheduled Playback



SoundMesh must schedule playback against a future target.



Bad:



```text

PLAY NOW

```



Why?



Because different devices receive the command at different times.



Preferred:



```text

Current synchronized timeline

&#x20;         +

Future target

&#x20;         ↓

Native scheduled playback

```



\---



\# 28. Preparation Barrier



A synchronized start requires participants to be ready before the playback target.



The host should not schedule a synchronized start while participants are still:



\* downloading audio

\* decoding

\* initializing playback

\* calibrating



unless the protocol explicitly supports that condition.



\---



\# 29. Synchronization Measurement



The system must measure actual synchronization quality.



A useful group metric is:



```text

groupSpread =

maximum playback position

\-

minimum playback position

```



This represents how far apart the devices are according to the available playback measurements.



\---



\# 30. Physical Synchronization



Software measurements are not sufficient proof of audible synchronization.



Actual acoustic output can differ because of:



\* speaker hardware

\* operating-system audio processing

\* output latency

\* Bluetooth

\* device-specific behavior



Therefore physical measurement is required for strong validation.



\---



\# 31. Initial Synchronization Targets



Initial engineering targets are:



```text

Startup group spread:

≤ 20 ms



Steady-state group spread:

≤ 20 ms



Preferred correction stretch:

≤ 10 ms

```



These are:



> \*\*Engineering targets, not universal guarantees.\*\*



Do not represent them as guaranteed performance.



\---



\# 32. Drift



Even if devices start together, their playback timing may diverge.



Conceptually:



```text

Device A

───────────────



Device B

──────────────

&#x20;             ↘

&#x20;              increasingly different

```



SoundMesh must monitor for this.



\---



\# 33. Drift Correction



Preferred correction hierarchy:



```text

Monitor

&#x20;↓

Estimate drift

&#x20;↓

Tiny playback-rate correction

&#x20;↓

Re-measure

&#x20;↓

Small position correction

&#x20;↓

Controlled resynchronization

```



Corrections should prioritize:



\* stability

\* inaudibility

\* avoiding oscillation



\---



\# 34. Do Not Build a Fragile Feedback Loop



Synchronization correction must not continuously overreact.



Bad behavior:



```text

Device too early

&#x20;↓

Huge correction

&#x20;↓

Device too late

&#x20;↓

Huge correction

&#x20;↓

Device too early

&#x20;↓

...

```



The system should use measured error, uncertainty, thresholds, and controlled correction.



\---



\# 35. Playback Generations



Playback commands should support a generation/version mechanism where appropriate.



Purpose:



Prevent stale commands from affecting current playback.



Example:



```text

Generation 10 → PLAY

Generation 11 → PAUSE

Generation 10 → PLAY

```



The final command is stale and should not override the newer state.



\---



\# 36. Late Joining



A participant joining an active room must not immediately begin playback.



Expected flow:



```text

Join

&#x20;↓

Receive audio

&#x20;↓

Prepare

&#x20;↓

Calibrate

&#x20;↓

Determine timeline position

&#x20;↓

Schedule

&#x20;↓

Join playback

```



\---



\# 37. Failure Handling



SoundMesh must explicitly handle:



\* participant disconnect

\* host disconnect

\* network interruption

\* network change

\* transfer failure

\* calibration failure

\* audio preparation failure

\* playback failure

\* audio route changes

\* interruption

\* backgrounding

\* device lock

\* thermal pressure



Failure behavior should be deterministic.



\---



\# 38. Host Failure



MVP does not require seamless host migration.



If the host disappears, the system may perform controlled recovery.



Do not introduce complex host-election architecture unless a documented requirement justifies it.



\---



\# 39. Network Architecture



The network should conceptually contain:



\### Control plane



Responsible for:



\* room state

\* participant state

\* audio transfer

\* commands

\* recovery



\### Timing plane



Responsible for:



\* timestamp exchange

\* clock measurements

\* synchronization calculations

\* timing health



This distinction prevents control traffic from being confused with realtime timing.



\---



\# 40. Transport Principle



Reliable transport should be the MVP baseline for:



\* control

\* room state

\* file transfer



UDP is experimental.



Do not introduce UDP merely because it is associated with realtime systems.



It must demonstrate measurable benefit.



\---



\# 41. State Machines



Important subsystems should use explicit state machines.



Room state conceptually:



```text

CREATED

&#x20;↓

DISCOVERABLE

&#x20;↓

JOINING

&#x20;↓

CALIBRATING

&#x20;↓

READY

&#x20;↓

PLAYING

&#x20;↓

PAUSED / RECOVERING

&#x20;↓

PLAYING

&#x20;↓

ENDING

&#x20;↓

CLOSED

```



Avoid replacing explicit state with large collections of unrelated booleans.



\---



\# 42. UI Philosophy



SoundMesh should feel:



\* dark

\* minimal

\* premium

\* calm

\* audio-focused

\* technically sophisticated without being visually noisy



The UI should hide implementation complexity.



\---



\# 43. Primary User Actions



The primary mental model should be:



```text

Create

Join

Choose

Play

```



Users should not need to understand:



\* clock offsets

\* RTT

\* protocol versions

\* transport layers

\* calibration algorithms



unless they enter diagnostics.



\---



\# 44. Visual Direction



Primary background:



```text

\#0B0D10

```



Primary surface:



```text

\#181D23

```



Primary text:



```text

\#F5F7FA

```



Secondary text:



```text

\#A7AFB9

```



Primary accent:



```text

\#5B8CFF

```



Success:



```text

\#39D98A

```



Warning:



```text

\#FFB84D

```



Error:



```text

\#FF5C6C

```



The detailed visual system is defined in `ui-ux.md`.



\---



\# 45. Visual Anti-Patterns



Avoid:



\* excessive neon

\* gamer RGB styling

\* arbitrary gradients

\* excessive glassmorphism

\* excessive animation

\* emoji as primary icons

\* random colors

\* giant typography

\* fake technical dashboards



SoundMesh should look like a serious modern product.



\---



\# 46. Accessibility



Accessibility is a required part of the product.



Important requirements:



\* sufficient contrast

\* touch targets

\* dynamic text

\* screen-reader semantics

\* reduced motion

\* status information that does not rely solely on color



\---



\# 47. Performance Priority



The priority order is:



```text

Audio stability

&#x20;↓

Synchronization

&#x20;↓

Networking

&#x20;↓

Application responsiveness

&#x20;↓

Visual effects

```



A visual optimization must never compromise realtime audio.



\---



\# 48. Testing Philosophy



The project does not consider:



> “The app launched.”



to be proof of correctness.



Testing must progressively validate:



```text

Unit

&#x20;↓

Component

&#x20;↓

Integration

&#x20;↓

Physical devices

&#x20;↓

System

&#x20;↓

Synchronization

&#x20;↓

Stress

&#x20;↓

Physical acoustic output

```



\---



\# 49. Real Devices Are Required



Emulators and simulators are useful for:



\* UI

\* application logic

\* basic flows



They cannot prove:



\* real speaker timing

\* real audio latency

\* Wi-Fi behavior

\* device-specific audio behavior

\* physical synchronization



Core synchronization must be tested on real hardware.



\---



\# 50. Device Scaling



Initial testing progression:



```text

2 devices

&#x20;↓

3 devices

&#x20;↓

5 devices

&#x20;↓

larger groups

```



Do not assume success with two devices automatically means success with ten.



\---



\# 51. Device Heterogeneity



The system must eventually be tested across:



\* different Android devices

\* different iOS devices

\* different manufacturers

\* different OS versions

\* different speaker hardware



Android + iOS testing is particularly important.



\---



\# 52. Physical Synchronization Validation



Strong synchronization validation should use external measurement.



Conceptually:



```text

Phone A ─┐

Phone B ─┤

Phone C ─┼──→ simultaneous recording

Phone D ─┤

Phone E ─┘

```



Use controlled signals where possible.



Measure actual waveform onset differences.



\---



\# 53. Do Not Fake Metrics



AI agents must never invent:



\* synchronization numbers

\* benchmark results

\* device compatibility

\* test results

\* battery measurements

\* latency measurements



If something has not been measured:



```text

NOT MEASURED

```



is the correct result.



\---



\# 54. Existing Documentation



Before modifying SoundMesh, AI agents should understand the following:



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



Local networking and protocol design.



```text

DOCS/synchronization.md

```



Timing and synchronization system.



```text

DOCS/audio.md

```



Audio architecture and playback behavior.



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



\---



\# 55. Documentation Hierarchy



An AI agent should think of the documentation as layers:



```text

Product

&#x20; ↓

Blueprint

&#x20; ↓

Architecture

&#x20; ↓

Subsystem specifications

&#x20; ↓

Decisions

&#x20; ↓

Testing

&#x20; ↓

Roadmap

&#x20; ↓

AI execution rules

```



Each document answers a different question.



\---



\# 56. Decision Awareness



Before making an architectural change, inspect:



```text

DOCS/decisions.md

```



Look for:



\* `DECIDED`

\* `PREFERRED`

\* `EXPERIMENTAL`

\* `UNDECIDED`

\* `REJECTED`

\* `SUPERSEDED`



Do not silently turn an `UNDECIDED` item into a permanent decision.



\---



\# 57. Important Decided Constraints



The following are currently strong project constraints:



```text

Flutter is the primary application framework.



Android and iOS are the target mobile platforms.



Flutter owns UI and high-level orchestration.



Native layers own timing-critical audio/network functionality.



SoundMesh is local-first.



QR is the preferred joining mechanism.



The host coordinates the room.



Audio should preferably be distributed before synchronized playback.



Playback should be scheduled against a future target.



Monotonic timing should be used for synchronization calculations.



Synchronization must be measured.



Drift must be monitored.



Physical synchronization must eventually be validated.



Real devices are required for synchronization testing.

```



\---



\# 58. Important Experimental Areas



The following must remain open to evidence:



```text

Exact Android audio engine

Exact iOS audio engine

Supported audio formats

Sample-rate strategy

Channel strategy

Resampling

Bluetooth behavior

Wi-Fi Direct/P2P

UDP timing transport

Exact buffering strategy

Exact audio latency measurement

Background playback behavior

Maximum practical device count

Advanced host recovery

```



An AI agent must not present these as settled facts.



\---



\# 59. Rejected MVP Directions



Do not introduce the following without a new architectural decision:



```text

Mandatory cloud backend

Mandatory Internet connectivity

Continuous host audio streaming

Manual IP onboarding

PLAY NOW as primary synchronization

Premature microservices

Premature account systems

Large social features

Music-discovery features

Unnecessary infrastructure

```



\---



\# 60. Repository Philosophy



SoundMesh should remain understandable.



Avoid:



\* speculative abstractions

\* duplicate systems

\* unnecessary dependencies

\* unused infrastructure

\* premature generalization



Prefer the smallest architecture that satisfies measured requirements.



\---



\# 61. AI Implementation Philosophy



AI-generated code is not automatically correct.



An agent should:



1\. understand the relevant specification

2\. identify the smallest required change

3\. implement it

4\. test it

5\. inspect failures

6\. verify behavior

7\. update documentation when necessary

8\. report limitations



\---



\# 62. Small Changes Are Preferred



Do not combine unrelated changes.



Bad:



```text

Implement networking

\+

Redesign UI

\+

Change audio architecture

\+

Refactor state management

```



Good:



```text

Implement participant handshake.

```



Then test it independently.



\---



\# 63. Avoid Architecture by Vibes



Do not choose technology because:



\* it is popular

\* another project uses it

\* an AI model recommends it

\* it seems modern

\* it has a nice API



Choose it because:



\* it satisfies the requirement

\* it works on target platforms

\* testing supports it

\* it fits the architecture

\* it has acceptable maintenance cost



\---



\# 64. When Documentation and Code Conflict



If implementation differs from documentation:



1\. do not silently assume either is correct

2\. identify the discrepancy

3\. determine which reflects the intended architecture

4\. test if necessary

5\. update documentation or implementation accordingly



Documentation drift is a defect.



\---



\# 65. When an AI Agent Gets Blocked



An AI agent should classify the blocker.



Examples:



\### Missing dependency



Investigate dependency and project configuration.



\### Platform limitation



Document the limitation and evaluate alternatives.



\### Architectural contradiction



Consult `decisions.md`.



\### Undefined behavior



Consult `UNDECIDED` items and avoid silently deciding.



\### Test failure



Investigate the actual failure before changing architecture.



\---



\# 66. What an AI Agent Must Never Do



Never:



\* fabricate test results

\* claim untested compatibility

\* silently change architecture

\* delete requirements to make implementation easier

\* weaken tests merely to make them pass

\* introduce cloud infrastructure without justification

\* expose technical internals unnecessarily in UX

\* treat experimental code as production truth

\* treat an IP address as device identity

\* use wall-clock time as the only synchronization mechanism

\* use “PLAY NOW” as the primary sync mechanism

\* claim perfect synchronization

\* assume two-device success proves large-scale success



\---



\# 67. Core Terminology



Use these terms consistently.



\### Host



The device coordinating a SoundMesh room.



\### Participant



A device participating in playback.



\### Room



The logical collection of devices participating in a session.



\### Session



A specific active room instance.



\### Participant ID



Logical identity assigned to a device within the session.



\### Shared Timeline



The logical time reference used to coordinate playback.



\### Clock Offset



Estimated timing relationship between two clocks.



\### RTT



Round-trip network time.



\### Drift



Gradual timing divergence between devices.



\### Calibration



The process of estimating timing relationships.



\### Startup Spread



Difference between actual playback start times across devices.



\### Steady-State Spread



Difference between playback positions during continued playback.



\### Playback Generation



Version identifier used to prevent stale playback commands from affecting current state.



\---



\# 68. Preferred Product Vocabulary



User-facing language should prefer:



```text

Getting everyone in sync…

Everyone is ready.

Synchronized

Connecting…

Preparing audio…

Recovering…

```



Avoid exposing:



```text

Clock offset calibration phase 2

TCP handshake failure 104

RTT variance exceeded

```



unless inside diagnostics.



\---



\# 69. Technical Vocabulary Rules



Engineers may use technical terminology in:



\* code

\* logs

\* diagnostics

\* engineering documentation



User-facing UI should translate technical state into understandable language.



\---



\# 70. Core User Journey



The intended experience is:



```text

Open SoundMesh

&#x20;     ↓

Create Room

&#x20;     ↓

Show QR

&#x20;     ↓

Friends scan QR

&#x20;     ↓

Devices connect

&#x20;     ↓

Choose audio

&#x20;     ↓

Prepare

&#x20;     ↓

Synchronize

&#x20;     ↓

Play

```



The complexity beneath this flow should remain mostly invisible.



\---



\# 71. MVP Definition



The MVP is fundamentally:



```text

Local room

\+

Device joining

\+

Audio distribution

\+

Audio preparation

\+

Clock calibration

\+

Scheduled playback

\+

Synchronized playback

\+

Monitoring

\+

Basic recovery

```



Everything else should be evaluated against this core.



\---



\# 72. First Technical Milestone



The first major technical milestone is:



> \*\*Two real phones successfully playing the same local audio through a shared future timeline with measured synchronization.\*\*



This is more important than completing a large feature set.



\---



\# 73. Second Technical Milestone



After two-device synchronization works:



```text

2 devices

&#x20;↓

3 devices

&#x20;↓

5 devices

```



The system should demonstrate that synchronization quality remains acceptable as participant count increases.



\---



\# 74. Final Product Milestone



The product is approaching competition readiness when:



\* the core room flow is reliable

\* synchronization is repeatable

\* drift is controlled

\* failures recover predictably

\* multiple devices work

\* physical measurements support synchronization claims

\* UI is polished

\* diagnostics exist

\* documentation is complete

\* builds are stable

\* the demonstration is reliable



\---



\# 75. AI Mental Model



Before changing code, an AI agent should be able to answer:



\### What are we building?



A synchronized multi-phone speaker system.



\### What is the hardest part?



Reliable synchronization across heterogeneous physical devices.



\### What platform?



Android and iOS.



\### What framework?



Flutter plus native platform integrations.



\### Does it require cloud?



No for normal MVP playback.



\### How do devices join?



QR-first.



\### Does the host continuously stream audio?



Preferably no.



\### How does synchronized playback work?



Local audio + shared timeline + measured clock relationship + future scheduled playback.



\### How do we know it works?



Measure it on real devices.



\### What happens if a decision is unclear?



Do not silently decide; consult the documented decision state.



\---



\# 76. The Most Important Mental Model



Think of SoundMesh as:



```text

&#x20;            CONTROL

&#x20;               │

&#x20;               ▼

&#x20;       ┌───────────────┐

&#x20;       │  SoundMesh    │

&#x20;       │     Room      │

&#x20;       └───────┬───────┘

&#x20;               │

&#x20;       Shared timeline

&#x20;               │

&#x20;      ┌────────┼────────┐

&#x20;      ▼        ▼        ▼

&#x20;    Phone A  Phone B  Phone C

&#x20;      │        │        │

&#x20;    Clock    Clock    Clock

&#x20;      │        │        │

&#x20;    Audio    Audio    Audio

&#x20;      │        │        │

&#x20;    Speaker  Speaker  Speaker

```



The central engineering problem is coordinating those independent clocks and audio systems well enough that the resulting physical sound behaves like one system.



\---



\# 77. Final AI Principle



The AI developer's job is not simply:



> \*\*Write code that works.\*\*



It is:



> \*\*Write code that fits the architecture, satisfies the documented requirements, survives testing, and produces measurable evidence that the system behaves as intended.\*\*



When uncertain:



> \*\*Measure.\*\*



When architecture is unclear:



> \*\*Read the decisions.\*\*



When requirements are unclear:



> \*\*Read the specifications.\*\*



When a feature is not necessary:



> \*\*Do not build it.\*\*



When something has not been tested:



> \*\*Do not claim that it works.\*\*



\---



\# 78. Final SoundMesh Principle



SoundMesh should feel extremely simple to the person using it:



```text

Create

Join

Choose

Play

```



But underneath that simplicity, the system must carefully coordinate:



```text

Networking

\+

Identity

\+

Audio

\+

Clock relationships

\+

Scheduling

\+

Drift

\+

Recovery

\+

Physical hardware

```



The user's experience should hide the complexity.



The engineering must solve it.



> \*\*Complexity belongs underneath the product, not inside the user's head.\*\*



\*\*End of AI Engineering Context.\*\*



