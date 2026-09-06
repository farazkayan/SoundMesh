\# SoundMesh — Faraz Work Plan



\*\*Document Status:\*\* ACTIVE

\*\*Document Type:\*\* Developer Workstream Specification

\*\*Owner:\*\* Faraz

\*\*Primary AI Consumer:\*\* Faraz's AI development agent

\*\*Project:\*\* SoundMesh

\*\*Last Updated:\*\* 2026-09-06



\---



\# 1. Purpose



This document defines the complete technical workstream owned by Faraz.



Faraz owns the core technical systems that make SoundMesh function as a synchronized multi-device audio system.



This document does NOT replace the shared SoundMesh architecture, subsystem specifications, or interface contracts.



It answers a different question:



> \*\*"What is Faraz responsible for building, in what order, and what does completion mean?"\*\*



All work described here MUST remain consistent with:



1\. `AGENTS.md`

2\. `CONTRIBUTING.md`

3\. `DOCS/blueprint.md`

4\. `DOCS/architecture.md`

5\. `DOCS/roadmap.md`

6\. `DOCS/networking.md`

7\. `DOCS/synchronization.md`

8\. `DOCS/audio.md`

9\. `DOCS/testing.md`

10\. `DOCS/contract-testing.md`

11\. `DOCS/interfaces/\*`

12\. `DOCS/AI/rules.md`

13\. `DOCS/AI/task-protocol.md`

14\. `DOCS/AI/integration-protocol.md`



Higher-authority documents override this document.



\---



\# 2. Faraz's Ownership



Faraz is primarily responsible for:



\* Core application coordination

\* Room management implementation

\* Device management implementation

\* Local networking

\* Room discovery/bootstrap

\* Connection lifecycle

\* Protocol implementation

\* Audio distribution

\* Audio preparation infrastructure

\* Playback infrastructure

\* Synchronization

\* Clock synchronization

\* Timing measurement

\* Latency estimation

\* Calibration

\* Shared playback timeline

\* Drift detection

\* Drift correction

\* Synchronization recovery

\* Native Android timing/audio infrastructure

\* Native iOS timing/audio infrastructure

\* Flutter-to-native integration

\* Pigeon/platform-channel boundaries where required

\* Backend/core state machines

\* Integration infrastructure

\* Core contract implementations

\* Contract tests for Faraz-owned interfaces

\* Technical diagnostics

\* Performance instrumentation

\* Real-device synchronization validation

\* Technical bug fixing

\* Cross-subsystem integration



Faraz is NOT the primary owner of:



\* Flutter visual design

\* UI screen implementation

\* UI animations

\* UI component styling

\* User-facing navigation design

\* UI-only state presentation



Those areas are primarily owned by Mahin.



However, Faraz MUST provide the technical interfaces required by the UI.



\---



\# 3. Fundamental Rule



Faraz does NOT build isolated backend systems.



Every subsystem MUST be implemented as part of the complete SoundMesh architecture.



The goal is not:



> "Make the backend work."



The goal is:



> \*\*"Make the complete SoundMesh system work reliably across multiple real devices."\*\*



A subsystem is not considered complete merely because its unit tests pass.



Subsystem completion ultimately requires integration evidence.



\---



\# 4. Development Strategy



Faraz's work MUST follow this general progression:



```text

Foundation

&#x20;   ↓

Project Architecture

&#x20;   ↓

Native/Flutter Boundaries

&#x20;   ↓

Core Interfaces

&#x20;   ↓

Room System

&#x20;   ↓

Device System

&#x20;   ↓

Networking

&#x20;   ↓

Two-Device Connection

&#x20;   ↓

Audio Infrastructure

&#x20;   ↓

Playback Infrastructure

&#x20;   ↓

Clock Synchronization

&#x20;   ↓

Two-Device Synchronization

&#x20;   ↓

Calibration

&#x20;   ↓

Drift Detection

&#x20;   ↓

Drift Correction

&#x20;   ↓

Room-Level Synchronization

&#x20;   ↓

3–5 Device Scaling

&#x20;   ↓

Failure Recovery

&#x20;   ↓

Diagnostics

&#x20;   ↓

Performance Optimization

&#x20;   ↓

Real-Device Validation

&#x20;   ↓

Competition Hardening

```



The exact order may change if an approved architectural decision requires it.



\---



\# 5. Phase 0 — Repository and Development Foundation



\## Objective



Establish a safe technical foundation before implementing SoundMesh functionality.



\## Responsibilities



Faraz MUST:



\* Verify Flutter project structure.

\* Establish package/module boundaries.

\* Establish native Android structure.

\* Establish native iOS structure when available.

\* Establish shared models/types.

\* Establish error representation.

\* Establish logging infrastructure.

\* Establish configuration handling.

\* Establish environment separation.

\* Establish test structure.

\* Establish linting/formatting.

\* Establish dependency management.

\* Establish platform abstraction boundaries.



\## Required principles



Flutter MUST NOT directly implement timing-critical functionality.



Timing-sensitive functionality belongs behind native interfaces.



\## Completion criteria



\* Project builds.

\* Tests execute.

\* Android project builds.

\* iOS project structure is valid where development environment permits.

\* Native boundaries are documented.

\* No subsystem has bypassed the architecture.



\---



\# 6. Phase 1 — Contract Implementation Foundation



\## Objective



Turn the documented interfaces into implementation-ready contracts.



\## Primary interfaces



\* Core API

\* Room API

\* Device API

\* Audio API

\* Playback API

\* Sync API



\## Responsibilities



Faraz MUST:



\* Define implementation-side types corresponding to contracts.

\* Define shared request/result models.

\* Define structured errors.

\* Define state representations.

\* Define lifecycle representations.

\* Define generation identifiers where required.

\* Implement contract validation.

\* Create mocks/fakes where useful for testing.

\* Create contract tests.



\## Critical rule



The documented interface is authoritative.



Faraz's implementation MUST NOT silently redefine the interface.



If implementation reveals an inadequate contract:



```text

Implementation discovers problem

&#x20;       ↓

STOP

&#x20;       ↓

Propose contract change

&#x20;       ↓

Update documentation

&#x20;       ↓

Update interface

&#x20;       ↓

Update implementation

&#x20;       ↓

Update dependent consumers

&#x20;       ↓

Run integration tests

```



\---



\# 7. Phase 2 — Core Coordinator



\## Objective



Implement the Core system that coordinates SoundMesh subsystems.



Core MUST coordinate:



\* Room

\* Device

\* Audio

\* Playback

\* Sync



Core MUST NOT secretly become responsible for the internal algorithms of those systems.



\## Responsibilities



Implement the conceptual Core operations:



\* `getState()`

\* `createRoom()`

\* `joinRoom()`

\* `leaveRoom()`

\* `getRoomState()`

\* `selectAudio()`

\* `preparePlayback()`

\* `play()`

\* `pause()`

\* `resume()`

\* `seek()`

\* `stop()`

\* `getDevices()`

\* `getPlaybackState()`

\* `getSyncStatus()`

\* `resynchronize()`



Exact signatures MUST follow the current Core API contract.



\## Completion criteria



Core can coordinate a complete high-level flow without requiring UI code to directly manipulate internal subsystems.



\---



\# 8. Phase 3 — Room System



\## Objective



Implement authoritative room lifecycle and membership management.



\## Responsibilities



Implement:



\* Room creation

\* Room identity

\* Host role

\* Participant role

\* Join lifecycle

\* Leave lifecycle

\* Membership registration

\* Room state

\* Room membership state

\* Join validation

\* Room-level errors

\* Room state transitions



\## Must preserve



Room membership MUST remain distinct from:



\* Network connection

\* IP address

\* Socket identity

\* Device identity

\* Human identity



A connected socket does not automatically mean a valid room member.



\## Completion criteria



Two real devices can:



1\. Create a room.

2\. Obtain valid join information.

3\. Join the room.

4\. Become registered participants.

5\. Observe consistent membership state.

6\. Leave the room cleanly.



\---



\# 9. Phase 4 — Device System



\## Objective



Implement device identity, capabilities, readiness, presence, and device state.



\## Responsibilities



Implement:



\* Device identity

\* Device registration

\* Device lifecycle

\* Device capabilities

\* Connection state

\* Presence state

\* Readiness state

\* Audio route information where supported

\* Synchronization status exposure

\* Device errors

\* Device status updates



\## Critical distinctions



Faraz MUST NOT merge:



```text

Device Identity

Room Membership

Network Connection

Playback State

Synchronization State

```



These are separate concepts.



\## Completion criteria



The system can reliably determine:



\* Which device is present.

\* Which device belongs to the room.

\* Whether it is connected.

\* Whether it is ready.

\* Whether it is capable of required playback.

\* What synchronization state it reports.



No fabricated capability or status values are permitted.



\---



\# 10. Phase 5 — Networking Foundation



\## Objective



Build reliable local networking for SoundMesh.



\## Initial target



Local Wi-Fi and phone hotspot environments.



Internet connectivity MUST NOT be required for the core SoundMesh experience.



\## Responsibilities



Implement:



\* Host networking

\* Participant networking

\* Connection establishment

\* Handshake

\* Room bootstrap

\* Message envelopes

\* Protocol versioning

\* Session identifiers

\* Participant identifiers

\* Heartbeats

\* Connection lifecycle

\* Reconnection foundations

\* Structured network errors

\* Control-plane messaging

\* Timing-plane support where required

\* Audio-transfer transport



\## Message envelope



Messages MUST follow the documented networking contract.



Conceptual fields include:



\* `protocolVersion`

\* `messageType`

\* `messageId`

\* `sessionId`

\* `senderId`

\* `generation`

\* `timestamp`

\* `payload`



Fields MUST NOT be changed casually.



\## Completion criteria



Two real devices can establish a stable local connection and exchange validated protocol messages.



\---



\# 11. Phase 6 — QR / Room Bootstrap



\## Objective



Make joining a room simple and reliable.



\## Responsibilities



Implement the technical side of:



\* Join payload generation

\* Join payload parsing

\* Room identification

\* Bootstrap information

\* Short-lived join tokens

\* Protocol version information

\* Validation

\* Expiration handling



Conceptual format:



```text

soundmesh://join?

room=<room-id>\&

host=<bootstrap-address>\&

port=<bootstrap-port>\&

version=<protocol-version>\&

token=<short-lived-join-token>

```



The exact format is governed by `networking.md`.



QR rendering itself is primarily UI-owned.



Faraz owns the underlying join data and validation.



\## Security requirements



QR payloads MUST NOT contain permanent credentials.



\---



\# 12. Phase 7 — Audio Distribution



\## Objective



Make audio available locally on participating devices.



\## Architecture



Preferred model:



```text

Host

&#x20;│

&#x20;├── Audio file

&#x20;│

&#x20;├── distribute

&#x20;│

&#x20;↓

Participants

&#x20;│

&#x20;├── local copy

&#x20;│

&#x20;└── local playback

```



SoundMesh SHOULD NOT continuously stream the audio from the host during normal playback unless an approved experiment requires it.



\## Responsibilities



Implement:



\* Audio selection infrastructure

\* Audio metadata

\* Audio resource identity

\* File transfer

\* Transfer progress infrastructure

\* Integrity verification

\* Local availability

\* Audio preparation

\* Audio caching where appropriate

\* Failure handling



\## Integrity



Transferred audio MUST be verifiable.



The exact hash algorithm remains governed by the Audio contract.



\## Completion criteria



Two or more devices possess verified local copies of the same audio resource and can independently prepare it for synchronized playback.



\---



\# 13. Phase 8 — Native Playback Engine



\## Objective



Build the timing-capable local playback layer.



\## Android



Evaluate/use the appropriate native audio infrastructure according to the architecture.



Candidate technologies include:



\* Oboe

\* AAudio

\* AudioTrack



The final choice MUST be evidence-based.



\## iOS



Evaluate/use:



\* AVAudioEngine

\* AVAudioPlayerNode

\* AVAudioTime

\* AVAudioSession



The final implementation MUST preserve access to accurate playback timing.



\## Responsibilities



Implement:



\* Audio preparation

\* Playback scheduling

\* Start

\* Pause

\* Resume

\* Seek

\* Stop

\* Actual playback position

\* Playback generation

\* Native playback state

\* Audio-route awareness

\* Interruption handling where supported



\## Critical rule



Do NOT implement the system as:



```text

audio.play()

```



and assume devices start together.



SoundMesh requires scheduled playback.



\---



\# 14. Phase 9 — Playback Scheduler



\## Objective



Make playback occur at a shared future logical time.



\## Responsibilities



Implement:



\* Target playback time

\* Target audio position

\* Scheduling margin

\* Preparation barrier

\* Generation validation

\* Start scheduling

\* Cancellation

\* Pause scheduling

\* Resume scheduling

\* Seek scheduling

\* Stop cancellation



Conceptual schedule:



```text

Prepare

&#x20;  ↓

Ready

&#x20;  ↓

Synchronize timing

&#x20;  ↓

Choose future target

&#x20;  ↓

Schedule locally

&#x20;  ↓

Wait

&#x20;  ↓

Start at target

```



\## Critical requirement



The system MUST use monotonic timing for scheduling.



Wall-clock time MUST NOT be used as the primary synchronization clock.



\---



\# 15. Phase 10 — Clock Synchronization



\## Objective



Allow devices to estimate their timing relationship.



\## Responsibilities



Implement:



\* Monotonic clock abstraction

\* Timestamp exchange

\* Clock offset estimation

\* RTT measurement

\* Uncertainty estimation

\* Clock model

\* Timing observation storage

\* Outlier handling foundations



Use the documented timestamp exchange model.



Conceptual exchange:



```text

Participant → Host

&#x20;     t1



Host receives

&#x20;     t2



Host → Participant

&#x20;     t3



Participant receives

&#x20;     t4

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



\---



\# 16. Phase 11 — Synchronization Calibration



\## Objective



Determine how each device should compensate for timing differences.



\## Responsibilities



Implement:



\* Calibration measurements

\* Network timing analysis

\* Estimated offset

\* Estimated uncertainty

\* Playback/output latency considerations

\* Calibration state

\* Calibration result

\* Confidence calculation

\* Calibration failure handling



Conceptual states:



```text

UNKNOWN

CALIBRATING

SYNCHRONIZED

DEGRADED

FAILED

```



The exact thresholds MUST be evidence-based and documented.



\## Critical rule



Confidence values MUST represent actual model confidence.



Never generate decorative or arbitrary confidence percentages.



\---



\# 17. Phase 12 — Shared Playback Timeline



\## Objective



Create a common logical timeline for all participating devices.



\## Responsibilities



Implement:



\* Shared timeline

\* Target start time

\* Target playback position

\* Timeline generation

\* Pause timeline

\* Resume timeline

\* Seek timeline

\* Stop timeline

\* Late-join timeline



All devices MUST reason from the same logical playback event.



Example:



```text

Shared Timeline

&#x20;     │

&#x20;     ├── PLAY at T = 10,000 ms

&#x20;     │

&#x20;     ├── PAUSE at T = 40,000 ms

&#x20;     │

&#x20;     ├── SEEK → 90,000 ms

&#x20;     │

&#x20;     └── PLAY at T = 45,000 ms

```



The exact timeline model MUST follow the Sync and Playback contracts.



\---



\# 18. Phase 13 — Two-Device Synchronization Milestone



\## Objective



Achieve the first real SoundMesh synchronization milestone.



\## Required test



Two physical phones.



Not:



\* two simulators

\* mocked clocks

\* theoretical calculations

\* unit tests alone



\## Required flow



```text

Phone A

Create Room

&#x20;   ↓

Phone B

Join

&#x20;   ↓

Audio distributed

&#x20;   ↓

Audio prepared

&#x20;   ↓

Clock synchronization

&#x20;   ↓

Calibration

&#x20;   ↓

Shared playback schedule

&#x20;   ↓

PLAY

&#x20;   ↓

Measure physical output

```



\## Target



Initial engineering target:



\*\*≤20 ms group playback spread\*\*



Preferred:



\*\*≤10 ms\*\*



These are targets, not guarantees.



\## Completion requires



\* Repeatable tests

\* Multiple runs

\* Real devices

\* Recorded measurements

\* Documented environment

\* Documented failures

\* No fake metrics



This is the most important early technical milestone.



\---



\# 19. Phase 14 — Drift Detection



\## Objective



Detect devices gradually moving out of synchronization during playback.



\## Responsibilities



Implement:



\* Playback position observation

\* Timing error estimation

\* Drift estimation

\* Drift rate estimation

\* Confidence/uncertainty

\* Drift thresholds

\* Monitoring loop



Conceptual model:



```text

error(t) =

&#x20;   offset +

&#x20;   driftRate × elapsedTime

```



The exact estimator remains experimental until validated.



\---



\# 20. Phase 15 — Drift Correction



\## Objective



Keep devices synchronized during long playback.



\## Responsibilities



Implement and evaluate correction strategies.



Potential hierarchy:



```text

Small error

&#x20;   ↓

Subtle correction



Medium error

&#x20;   ↓

Controlled correction



Large error

&#x20;   ↓

Resynchronization



Severe failure

&#x20;   ↓

Recovery procedure

```



Corrections MUST NOT introduce unacceptable:



\* clicks

\* pops

\* pitch artifacts

\* audible speed changes

\* discontinuities

\* playback jumps



Every correction strategy MUST be tested physically.



\---



\# 21. Phase 16 — Multi-Device Scaling



\## Objective



Move beyond the two-device proof of concept.



\## Test progression



```text

2 devices

&#x20;  ↓

3 devices

&#x20;  ↓

5 devices

&#x20;  ↓

10 devices

```



Do not skip directly to large-scale testing.



\## Variables



Test across:



\* Different phone models

\* Different Android versions

\* Different iOS versions where available

\* Different audio hardware

\* Different network conditions

\* Different distances

\* Network congestion

\* CPU load

\* Battery conditions

\* Background activity



\## Measure



\* Join success rate

\* Connection stability

\* Audio transfer success

\* Preparation time

\* Startup spread

\* Steady-state spread

\* Drift

\* Recovery time

\* CPU

\* Memory

\* Battery impact



\---



\# 22. Phase 17 — Failure and Recovery



\## Objective



Make SoundMesh robust when real-world conditions become bad.



\## Responsibilities



Handle and test:



\* Participant disconnect

\* Temporary network loss

\* Host disconnect

\* Audio transfer failure

\* Invalid audio

\* Playback failure

\* Sync degradation

\* Calibration failure

\* Late join

\* Pause during degraded connection

\* Seek during degraded connection

\* Device interruption

\* Audio-route changes

\* App interruption

\* Stale commands

\* Duplicate commands

\* Out-of-order messages



\## Critical rule



Never invent host migration behavior.



Host migration remains UNDECIDED unless explicitly approved and documented.



\---



\# 23. Phase 18 — Generation and Stale-State Protection



\## Objective



Prevent old asynchronous operations from corrupting current state.



Generation identifiers MUST be used wherever required by the architecture.



Example:



```text

Generation 1

Audio A

&#x20;  ↓

Preparation begins



Generation 2

Audio B selected

&#x20;  ↓

Preparation begins



Generation 1 finishes late

&#x20;  ↓

MUST NOT overwrite Generation 2

```



Apply the same principle to:



\* Audio

\* Playback

\* Synchronization

\* Room transitions

\* Async network operations

\* Scheduled playback



\---



\# 24. Phase 19 — Diagnostics and Observability



\## Objective



Make synchronization failures measurable and debuggable.



\## Responsibilities



Provide technical diagnostics for:



\* Device

\* Room

\* Network

\* Audio

\* Playback

\* Sync



Useful metrics include:



\* RTT

\* Estimated offset

\* Estimated drift

\* Uncertainty

\* Calibration state

\* Playback position

\* Scheduled target time

\* Actual start time

\* Connection state

\* Audio readiness

\* Sync state

\* Recovery events



\## Critical rule



Diagnostics MUST expose real measurements.



Never fabricate metrics to make the UI appear healthy.



\---



\# 25. Phase 20 — Flutter / Native Integration



\## Objective



Connect the technical core to the Flutter application safely.



\## Responsibilities



Implement:



\* Flutter-facing interfaces

\* Pigeon/platform-channel definitions where appropriate

\* Native method exposure

\* Native event exposure

\* Serialization

\* Error propagation

\* State propagation

\* Lifecycle handling



\## Critical rule



Do not send high-frequency timing data through Flutter unnecessarily.



Timing-critical loops MUST remain native where appropriate.



Flutter should receive meaningful state/results rather than every low-level timing event.



\---



\# 26. Phase 21 — Integration With Mahin's UI



\## Objective



Make the technical systems consumable by Mahin's UI without exposing internal implementation details.



Mahin's UI MUST interact through documented contracts.



Faraz MUST provide:



\* Core API

\* Room API

\* Device API

\* Audio API

\* Playback API

\* Sync API

\* Structured errors

\* Meaningful state

\* Events where required

\* Accurate status



\## Example



The UI should be able to ask:



```text

getSyncStatus()

```



and receive a contract-defined result.



The UI should NOT need to know:



\* clock synchronization algorithms

\* network packet timing

\* native audio engine internals

\* drift estimator implementation

\* calibration mathematics



\## Integration rule



If Mahin's UI requires information not represented by the contract:



```text

Identify missing contract

&#x20;       ↓

Do NOT invent it

&#x20;       ↓

Propose contract change

&#x20;       ↓

Approve

&#x20;       ↓

Implement

&#x20;       ↓

Test

```



\---



\# 27. Phase 22 — Contract Testing



\## Objective



Ensure independently developed systems remain compatible.



Every Faraz-owned interface MUST have contract tests.



Tests SHOULD verify:



\* Input validity

\* Output shape

\* State transitions

\* Error behavior

\* Required fields

\* Generation behavior

\* Lifecycle behavior

\* Timing semantics

\* Ordering requirements

\* Cancellation behavior



The contract is the shared agreement between Faraz's implementation and Mahin's consumer code.



\---



\# 28. Phase 23 — End-to-End Integration



\## Objective



Validate SoundMesh as one complete system.



\## Required path



```text

Create Room

&#x20;   ↓

Generate Join Information

&#x20;   ↓

Join From Another Device

&#x20;   ↓

Register Participant

&#x20;   ↓

Distribute Audio

&#x20;   ↓

Verify Audio

&#x20;   ↓

Prepare Playback

&#x20;   ↓

Synchronize Clocks

&#x20;   ↓

Calibrate

&#x20;   ↓

Schedule Playback

&#x20;   ↓

Play

&#x20;   ↓

Monitor

&#x20;   ↓

Detect Drift

&#x20;   ↓

Correct

&#x20;   ↓

Pause / Resume

&#x20;   ↓

Seek

&#x20;   ↓

Stop

&#x20;   ↓

Leave

```



The complete path MUST be tested on real devices.



\---



\# 29. Phase 24 — Performance and Reliability



\## Objective



Optimize only after correctness has been established.



Measure:



\* Startup latency

\* Room creation time

\* Join time

\* Audio transfer speed

\* Preparation time

\* Synchronization convergence

\* CPU usage

\* Memory usage

\* Battery impact

\* Network traffic

\* Long-session drift

\* Recovery time



\## Rule



```text

Measure

&#x20;   ↓

Identify bottleneck

&#x20;   ↓

Form hypothesis

&#x20;   ↓

Optimize

&#x20;   ↓

Measure again

```



Never optimize based only on intuition.



\---



\# 30. Phase 25 — Competition Hardening



\## Objective



Prepare the technical system for the Shipaton submission.



Faraz MUST verify:



\* Core demo path is reliable.

\* Real-device synchronization is repeatable.

\* No critical crashes remain.

\* Major failure cases are handled.

\* Architecture documentation matches implementation.

\* Interfaces match actual behavior.

\* README accurately describes the system.

\* No fake technical claims exist.

\* Performance claims are backed by measurements.

\* Open-source requirements are satisfied where applicable.

\* Demo build is reproducible.

\* Critical setup instructions are documented.



\---



\# 31. Definition of Done for Faraz



A Faraz-owned feature is NOT DONE merely because:



\* The code compiles.

\* The AI says it works.

\* A unit test passes.

\* A mock works.

\* A simulator works.



A feature is DONE when applicable:



```text

Implementation

&#x20;     +

Contract compliance

&#x20;     +

Unit tests

&#x20;     +

Integration tests

&#x20;     +

Documentation

&#x20;     +

Real-device validation

&#x20;     +

Evidence

```



The required level depends on the feature.



Timing-critical features require physical validation.



\---



\# 32. Faraz AI Task Selection Rules



When assigning work to Faraz's AI, tasks SHOULD be narrow and explicit.



Good:



```text

Implement Room API createRoom() according to

DOCS/interfaces/room-api.md.



Do not modify the public contract.

Add contract tests.

```



Bad:



```text

Build the backend.

```



The AI MUST know:



\* What subsystem it owns.

\* What contract applies.

\* What files it may modify.

\* What tests are expected.

\* What is explicitly out of scope.



\---



\# 33. Faraz AI Must Not Modify Mahin-Owned Work Without Coordination



Faraz's AI MUST NOT casually modify:



\* Mahin's UI implementation

\* UI layout

\* UI styling

\* UI navigation

\* UI components

\* UI interaction logic



unless the task explicitly requires coordinated integration work.



If an integration issue appears:



```text

Identify issue

&#x20;   ↓

Determine ownership

&#x20;   ↓

Fix only the Faraz-owned side if possible

&#x20;   ↓

Otherwise report dependency/blocker

```



\---



\# 34. Faraz AI Stop Conditions



The AI MUST STOP and report a blocker when:



1\. An interface is undefined.

2\. Two authoritative documents conflict.

3\. Existing code contradicts the contract.

4\. A required architectural decision is missing.

5\. Mahin's subsystem requires an undocumented behavior.

6\. A contract needs to change.

7\. The AI would need to modify another owner's subsystem.

8\. A synchronization algorithm requires an unapproved assumption.

9\. Timing behavior cannot be measured reliably.

10\. The AI cannot determine which state is authoritative.

11\. A dependency is unclear.

12\. A proposed solution changes system architecture.

13\. A test contradicts the expected behavior.

14\. A platform-specific behavior is unknown and affects correctness.

15\. The AI is tempted to "just make it work" through an undocumented workaround.



The AI MUST NOT silently resolve these situations by guessing.



\---



\# 35. Faraz's Primary Milestones



The most important milestones are:



\## M1 — Foundation



Project architecture and native boundaries established.



\## M2 — Contracts Implemented



Core/Room/Device/Audio/Playback/Sync interfaces exist and are tested.



\## M3 — Two Devices Connected



Two physical phones can create/join a room and communicate.



\## M4 — Audio Distributed



Both phones have verified local audio.



\## M5 — Scheduled Playback



Both phones can schedule local playback.



\## M6 — Two-Device Synchronization



Two physical devices achieve repeatable synchronization within the engineering target.



\## M7 — Drift Correction



Devices remain acceptably synchronized during extended playback.



\## M8 — Multi-Device



3–5+ physical devices operate together.



\## M9 — Recovery



Common failures do not destroy the session unnecessarily.



\## M10 — Full Integration



Mahin's UI controls the real technical system through documented contracts.



\## M11 — Competition Ready



The complete demo path is stable, measurable, documented, and reproducible.



\---



\# 36. Priority Order



When deciding what to build first, use:



```text

1\. Correctness

2\. Architecture

3\. Contract stability

4\. Real-device functionality

5\. Synchronization accuracy

6\. Reliability

7\. Failure recovery

8\. Performance

9\. Diagnostics

10\. UI integration

11\. Polish

```



Do not sacrifice synchronization correctness for visual polish.



Do not sacrifice architecture for speed.



Do not sacrifice contract integrity to satisfy a short-term UI requirement.



\---



\# 37. The Two-Phone Rule



At every major technical milestone, prefer proving the system with two real phones before scaling.



```text

One phone

&#x20;   ↓

Two phones

&#x20;   ↓

Stable two-phone system

&#x20;   ↓

Three phones

&#x20;   ↓

Five phones

&#x20;   ↓

Larger groups

```



A feature that cannot reliably work with two real devices is not ready for scaling.



\---



\# 38. Evidence Rule



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



Technical claims MUST be measurable whenever practical.



\---



\# 39. Final Responsibility



Faraz's responsibility is not merely to build a backend.



Faraz owns the technical foundation that allows:



```text

Phone A

&#x20;    │

&#x20;    │

&#x20;    ├──── Room ────┐

&#x20;    │              │

&#x20;    ├──── Audio ───┤

&#x20;    │              │

&#x20;    ├──── Playback ┤

&#x20;    │              │

&#x20;    ├──── Sync ────┤

&#x20;    │              │

&#x20;    └──── Network ─┘

&#x20;                   │

&#x20;                Phone B

&#x20;                   │

&#x20;                Phone C

&#x20;                   │

&#x20;                Phone D

```



to behave as \*\*one coordinated audio system\*\*.



The ultimate technical objective is:



> \*\*Multiple independent phones must behave like one synchronized speaker system using local networking and coordinated playback.\*\*



Everything Faraz builds should serve that objective.



\---



\# 40. Final Principle



Faraz's work is the technical foundation of SoundMesh.



The implementation MUST remain:



\* contract-driven

\* local-first

\* timing-aware

\* measurable

\* testable

\* platform-conscious

\* failure-aware

\* integration-safe

\* AI-safe

\* honest about uncertainty



The final standard is not:



> "The code works on my machine."



The final standard is:



> \*\*"The complete SoundMesh system works predictably across real devices, and we have evidence to prove it."\*\*



