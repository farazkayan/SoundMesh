\# SoundMesh Playback API Contract



\*\*File:\*\* `DOCS/interfaces/playback-api.md`

\*\*Status:\*\* EXPERIMENTAL

\*\*Owner:\*\* Faraz

\*\*Primary Consumers:\*\* Core API, Audio API, Synchronization System, Device API, Room API, UI/Application Layer, Integration Tests



\---



\# 1. Purpose



The Playback API defines the authoritative interface for controlling playback of prepared audio within a SoundMesh session.



It establishes the boundary between:



\* prepared audio

\* synchronized timing

\* playback execution

\* device playback state

\* room-level playback state

\* UI controls



The Playback API is responsible for answering:



> \*\*“What should be playing, what is its playback state, and how should playback execution be controlled?”\*\*



It does not independently determine synchronization.



The core principle is:



> \*\*Playback executes against a shared timeline supplied by the synchronization system. It must never replace synchronized scheduling with immediate local playback.\*\*



\---



\# 2. Scope



The Playback API owns:



\* playback state

\* playback commands

\* playback position

\* playback generation

\* scheduling requests

\* pause/resume behavior

\* seek behavior

\* stop behavior

\* playback readiness

\* playback lifecycle

\* playback-related errors

\* reporting actual playback state



The Playback API does \*\*not\*\* own:



\* audio decoding

\* audio distribution

\* room membership

\* network transport

\* clock synchronization algorithms

\* latency estimation

\* drift estimation

\* synchronization correction algorithms

\* QR joining

\* UI rendering



Those responsibilities belong to their respective contracts.



\---



\# 3. Authority



The Playback API follows the SoundMesh authority hierarchy:



1\. Approved architectural decisions

2\. Interface contracts

3\. Core architecture specification

4\. Audio / Networking / Synchronization specifications

5\. Approved integration tests

6\. Existing implementation

7\. AI assumptions



If implementation and documentation disagree, AI agents must not silently choose one.



\---



\# 4. Playback Mental Model



SoundMesh playback is fundamentally different from ordinary single-device playback.



A normal application might perform:



```text

&#x20;id="p1"

User presses Play

&#x20;       ↓

audio.play()

&#x20;       ↓

Audio starts immediately

```



SoundMesh must instead use:



```text

&#x20;id="p2"

User presses Play

&#x20;       ↓

Core requests playback

&#x20;       ↓

Playback checks readiness

&#x20;       ↓

Sync determines shared target time

&#x20;       ↓

Playback schedules local execution

&#x20;       ↓

Each device reaches the target timeline

&#x20;       ↓

Playback begins

```



This distinction is mandatory.



\---



\# 5. Scheduled Playback



Playback MUST support scheduled execution.



A command equivalent to:



```text

play()

```



must not necessarily mean:



```text

start immediately

```



Instead, playback should use a target timeline.



Conceptually:



```text

T\_target = T\_now + M

```



where:



\* `T\_now` = current local monotonic time

\* `M` = preparation/scheduling margin

\* `T\_target` = future playback target



The exact scheduling algorithm is owned by Synchronization.



The Playback API consumes the scheduling decision.



\---



\# 6. Playback State Model



The conceptual playback states are:



```text

IDLE

PREPARING

READY

SCHEDULED

PLAYING

PAUSED

SEEKING

STOPPING

STOPPED

ERROR

```



These states are:



\*\*EXPERIMENTAL\*\*



Exact legal transitions remain subject to further implementation decisions.



An implementation must not invent additional externally visible states without updating this contract.



\---



\# 7. Playback Lifecycle



Conceptual lifecycle:



```text

&#x20;id="p3"

IDLE

&#x20; ↓

AUDIO\_READY

&#x20; ↓

READY

&#x20; ↓

SCHEDULED

&#x20; ↓

PLAYING

&#x20; ↓

PAUSED

&#x20; ↓

PLAYING

&#x20; ↓

STOPPING

&#x20; ↓

STOPPED

```



Alternative failure paths:



```text

&#x20;id="p4"

PREPARING → ERROR

SCHEDULED → ERROR

PLAYING → ERROR

```



Exact state transitions are:



\*\*UNDECIDED\*\*



\---



\# 8. Playback Resource



Playback must reference an Audio API resource.



Conceptual:



```text

PlaybackResource

├── audioId

├── generation

└── duration

```



Exact schema:



\*\*UNDECIDED\*\*



Playback must not independently redefine audio identity.



\---



\# 9. Playback Generation



Every playback lifecycle that can invalidate previous timing or state should be associated with a generation.



Conceptual:



```text

&#x20;id="p5"

Generation 1

&#x20;   ↓

Song A



Generation 2

&#x20;   ↓

Song B

```



A generation may change because of:



\* new audio

\* seek

\* restart

\* synchronization recovery

\* major playback lifecycle change



Exact generation semantics remain:



\*\*UNDECIDED\*\*



The purpose is to prevent stale asynchronous operations from modifying newer playback state.



\---



\# 10. `getPlaybackState()`



Returns the current playback state.



Conceptual result:



```json id="p6"

{

&#x20; "state": "PLAYING",

&#x20; "audioId": "example-audio",

&#x20; "generation": 3,

&#x20; "positionMs": 12450

}

```



This is illustrative only.



Exact fields and types:



\*\*UNDECIDED\*\*



The result must represent actual known state.



\---



\# 11. `preparePlayback()`



Prepares playback without starting it.



Conceptual:



```text id="p7"

preparePlayback(audioId)

```



Preparation may require:



\* audio resource availability

\* audio validation

\* local audio preparation

\* playback engine readiness

\* synchronization readiness

\* required device readiness



Exact prerequisites:



\*\*UNDECIDED\*\*



The operation must not start playback as a side effect.



\---



\# 12. `play()`



Requests synchronized playback.



Conceptual:



```text id="p8"

play()

```



The command should result in a scheduled playback operation rather than an immediate local start.



Conceptual flow:



```text

play()

&#x20; ↓

Validate state

&#x20; ↓

Check audio readiness

&#x20; ↓

Check device readiness

&#x20; ↓

Obtain synchronization timing

&#x20; ↓

Create scheduled playback

&#x20; ↓

Wait for target time

&#x20; ↓

Start playback

```



The exact API request shape is:



\*\*UNDECIDED\*\*



\---



\# 13. Play Preconditions



Playback must not begin unless required preconditions are satisfied.



Potential prerequisites:



```text id="p9"

Audio is available

Audio is prepared

Playback engine is ready

Required device is available

Synchronization is sufficiently calibrated

Target timeline is valid

Current generation is valid

```



The exact readiness policy is:



\*\*UNDECIDED\*\*



If a required condition cannot be established, playback should fail safely rather than pretending the condition is satisfied.



\---



\# 14. `pause()`



Requests a synchronized pause.



Conceptual:



```text id="p10"

pause()

```



Pause behavior must account for the fact that multiple devices are playing against a shared timeline.



A device must not simply pause independently and assume the group remains synchronized.



The exact pause protocol is:



\*\*UNDECIDED\*\*



Synchronization may need to coordinate a future pause point.



\---



\# 15. `resume()`



Requests synchronized continuation of playback.



Conceptual:



```text id="p11"

resume()

```



Resume must not simply call the platform's immediate `resume()` method if doing so would create cross-device timing divergence.



Conceptually:



```text

Resume request

&#x20;     ↓

Determine shared timeline

&#x20;     ↓

Schedule future continuation

&#x20;     ↓

Resume playback

```



Exact behavior:



\*\*UNDECIDED\*\*



\---



\# 16. `seek()`



Requests movement to a new playback position.



Conceptual:



```text id="p12"

seek(positionMs)

```



Seeking is a synchronization event.



All participating devices must eventually converge on the same intended playback position.



A local seek must not silently create a new timeline while other devices remain on the previous one.



A seek should therefore create or use an appropriate playback generation.



Exact semantics:



\*\*UNDECIDED\*\*



\---



\# 17. Seek Preconditions



A seek request must validate:



```text

position >= 0

position <= audio duration

```



unless the implementation explicitly supports another behavior.



Invalid seek requests must be rejected.



The exact position type and precision are:



\*\*UNDECIDED\*\*



\---



\# 18. `stop()`



Stops playback.



Conceptual:



```text

stop()

```



Stopping must terminate the active playback generation according to the defined lifecycle.



Potential resulting state:



```text

STOPPED

```



Exact state transition:



\*\*UNDECIDED\*\*



Stopping must not leave an old scheduled playback task capable of starting later.



\---



\# 19. Scheduled Playback Cancellation



If playback has been scheduled but not yet started, cancellation must be possible.



Example:



```text

&#x20;id="p13"

Schedule playback

&#x20;      ↓

User presses Stop

&#x20;      ↓

Scheduled operation cancelled

&#x20;      ↓

Audio does NOT start later

```



This is mandatory for correctness.



Stale scheduled operations must be invalidated using the appropriate generation/lifecycle mechanism.



\---



\# 20. Playback Position



Playback position represents the actual or authoritative playback position.



Conceptual:



```text

positionMs

```



The exact precision is:



\*\*UNDECIDED\*\*



The system must distinguish between:



```text

Requested Position

```



and:



```text

Actual Playback Position

```



They are not necessarily identical.



\---



\# 21. Actual Playback Position



Actual playback position should ultimately be derived from the native playback engine where available.



The Playback API must not simply calculate:



```text

position = elapsedTimeSincePlay

```



and assume it is exact.



Actual playback may differ because of:



\* scheduling latency

\* buffering

\* audio engine behavior

\* clock differences

\* interruptions

\* device-specific timing



Native timing information should be used where required.



\---



\# 22. Playback Drift



Playback drift is the divergence between intended playback position and actual playback behavior.



Conceptually:



```text

Expected Position

&#x20;      │

&#x20;      ▼

Actual Position

&#x20;      │

&#x20;      ▼

Playback Error

```



The Playback API reports observable playback state.



The Synchronization System owns drift estimation and correction decisions.



Playback must not independently invent drift correction algorithms.



\---



\# 23. Playback and Synchronization Boundary



This distinction is critical.



\### Synchronization answers:



```text

When should this device play?

How far is this device from the shared timeline?

How much drift exists?

How should timing be corrected?

```



\### Playback answers:



```text

Can I schedule playback?

Did playback start?

What is the actual playback position?

Is playback paused?

Did playback stop?

```



Neither system should silently become the other.



\---



\# 24. Playback Scheduling Contract



The Synchronization System may provide a scheduling instruction.



Conceptual:



```text

PlaybackSchedule

├── generation

├── targetTime

├── targetPosition

└── timingConfidence

```



Exact schema:



\*\*UNDECIDED\*\*



Playback executes this instruction using the appropriate native timing mechanism.



\---



\# 25. Scheduling Margin



Playback may require a future scheduling margin.



Conceptually:



```text

T\_target = T\_now + M

```



The margin must be large enough for participating devices to prepare.



However, it should not introduce unnecessary startup latency.



The exact margin:



\*\*UNDECIDED\*\*



It must be determined through measurement and real-device testing rather than arbitrary assumptions.



\---



\# 26. Monotonic Time



Timing-critical scheduling must use a monotonic time source.



Wall-clock time must not be used for playback synchronization.



Examples of suitable platform concepts include:



```text

Android:

SystemClock.elapsedRealtime()



iOS:

AVAudioTime / monotonic timing facilities

```



Exact implementation belongs to the platform-specific timing layer.



\---



\# 27. Playback Readiness



Playback readiness is different from:



```text

Audio readiness

Device readiness

Sync readiness

Room readiness

```



Conceptually:



```text

Audio READY

&#x20;     +

Device READY

&#x20;     +

Sync READY

&#x20;     +

Playback READY

&#x20;     =

Eligible for playback

```



The exact readiness composition is:



\*\*UNDECIDED\*\*



The system must not claim that the entire room is ready when only one subsystem is ready.



\---



\# 28. Room Playback State



Room-level playback state may be represented by Core/Room.



Potential states:



```text

STOPPED

PREPARING

READY

PLAYING

PAUSED

STOPPING

ERROR

```



The exact room state remains governed by the Room API.



Playback must not independently redefine the room's lifecycle.



\---



\# 29. Device Playback State



Each participating device may have local playback state.



Example:



```text

Device A → PLAYING

Device B → PLAYING

Device C → PREPARING

```



The system must detect when the room is not uniformly ready or playing.



The exact aggregation policy is:



\*\*UNDECIDED\*\*



\---



\# 30. Playback Events



Potential events include:



```text id="p14"

PLAYBACK\_READY

PLAYBACK\_SCHEDULED

PLAYBACK\_STARTED

PLAYBACK\_PAUSED

PLAYBACK\_RESUMED

PLAYBACK\_SEEKED

PLAYBACK\_STOPPED

PLAYBACK\_COMPLETED

PLAYBACK\_FAILED

PLAYBACK\_POSITION\_CHANGED

PLAYBACK\_ROUTE\_CHANGED

```



The event architecture is:



\*\*UNDECIDED\*\*



Event payloads must be contract-defined before implementation.



\---



\# 31. Playback Completion



When audio reaches its end, playback should report completion.



Potential event:



```text

PLAYBACK\_COMPLETED

```



Completion behavior for the room is:



\*\*UNDECIDED\*\*



Possible future policies include:



\* stop

\* pause

\* replay

\* wait

\* return to ready state



AI agents must not select a policy without an explicit decision.



\---



\# 32. Audio Completion vs Room Completion



A device completing playback does not automatically mean that the entire room has completed playback.



For example:



```text

Device A → completed

Device B → playing

Device C → playing

```



The system must not immediately declare:



```text

Room → completed

```



without an authoritative aggregation rule.



\---



\# 33. Interruption Handling



Playback may be interrupted by:



\* phone calls

\* system audio interruptions

\* application suspension

\* audio route changes

\* Bluetooth changes

\* operating-system behavior



The Playback API must expose the interruption when observable.



Recovery behavior is:



\*\*UNDECIDED\*\*



Potential recovery may involve:



```text

pause

resynchronize

resume

```



but this must be explicitly defined before implementation.



\---



\# 34. Audio Route Changes



If a device switches from:



```text

Built-in Speaker

```



to:



```text

Bluetooth

```



the playback system may experience a new latency profile.



The Audio API reports the route.



The Playback/Sync systems determine whether recalibration is required.



No subsystem may assume that a route change has zero timing impact.



\---



\# 35. Failure Handling



Playback failures must be explicit.



Potential errors:



```text id="p15"

PLAYBACK\_NOT\_READY

AUDIO\_NOT\_READY

DEVICE\_NOT\_READY

SCHEDULE\_FAILED

PLAYBACK\_ENGINE\_FAILED

INVALID\_POSITION

INVALID\_GENERATION

PLAYBACK\_INTERRUPTED

AUDIO\_OUTPUT\_UNAVAILABLE

PLAYBACK\_CANCELLED

INTERNAL\_ERROR

```



These are candidate errors.



Final taxonomy:



\*\*UNDECIDED\*\*



Errors should contain enough structured information for Core/UI to present an appropriate state without parsing arbitrary strings.



\---



\# 36. Stale Command Protection



Commands must not accidentally affect a newer playback generation.



Example:



```text

Generation 4

Song A scheduled



Generation 5

Song B selected



Old Song A schedule fires

```



The system must reject the stale operation.



Conceptually:



```text

if command.generation != activeGeneration:

&#x20;   reject / ignore

```



Exact mechanism is:



\*\*UNDECIDED\*\*



\---



\# 37. Concurrent Commands



The user or system may issue commands quickly:



```text

Play

Pause

Resume

Seek

Stop

```



The implementation must define ordering behavior.



For example:



```text

Play

↓

Seek

↓

Stop

```



must not result in an old Play command starting after Stop.



The exact concurrency model:



\*\*UNDECIDED\*\*



Generation and cancellation mechanisms should be used to prevent stale asynchronous operations.



\---



\# 38. Idempotency



Some playback operations may need idempotent behavior.



Potential examples:



```text

stop()

stop()

```



or:



```text

pause()

pause()

```



The exact idempotency policy is:



\*\*UNDECIDED\*\*



AI agents must not assume idempotency unless documented.



\---



\# 39. Native Playback Boundary



Timing-critical playback should be implemented using native platform audio facilities where required.



\### Android



Potential technologies:



```text

Oboe

AAudio

AudioTrack

```



\### iOS



Potential technologies:



```text

AVAudioEngine

AVAudioPlayerNode

AVAudioTime

AVAudioSession

```



These are implementation options.



They are not themselves part of the public Playback API.



\---



\# 40. Flutter Boundary



Flutter should interact with playback through the defined abstraction.



Conceptually:



```text

Flutter UI

&#x20;    │

&#x20;    ▼

Core API

&#x20;    │

&#x20;    ▼

Playback API

&#x20;    │

&#x20;    ▼

Platform Abstraction

&#x20;    │

&#x20;┌───┴───────────┐

&#x20;▼               ▼

Android         iOS

Native          Native

Playback        Playback

```



High-frequency timing-sensitive communication should remain out of ordinary Flutter UI state management where possible.



\---



\# 41. UI Consumption



The UI may display:



```text

Play / Pause

Current position

Duration

Playback state

Preparation state

Error state

Device playback state

```



The UI must not directly:



\* call native audio APIs

\* manipulate playback buffers

\* calculate synchronization offsets

\* schedule independent playback

\* fabricate playback state



The UI is a consumer of authoritative playback state.



\---



\# 42. Contract Testing



The Playback API must have contract tests covering at minimum:



\### Preparation



```text

Playback cannot begin before required preparation

Preparation does not automatically start playback

```



\### Scheduling



```text

Play creates scheduled execution

Scheduled playback can be cancelled

Cancelled playback cannot start later

```



\### State



```text

State transitions follow the contract

Actual state is reported truthfully

```



\### Position



```text

Position remains within valid bounds

Actual position is not confused with requested position

```



\### Generation



```text

Stale commands cannot affect newer generations

```



\### Seek



```text

Invalid seek positions are rejected

Seek invalidates or updates timing appropriately

```



\### Stop



```text

Stop prevents pending playback

Stop produces the correct state

```



\### Synchronization



```text

Playback consumes Sync timing

Playback does not independently invent synchronization

```



\---



\# 43. Integration Testing



Playback must eventually be tested with real devices.



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



\* synchronized start

\* pause

\* resume

\* seek

\* stop

\* repeated play/stop

\* long-duration playback

\* route changes

\* interruptions

\* reconnect scenarios

\* late preparation

\* stale command protection

\* generation changes



\---



\# 44. Timing Validation



Playback correctness must ultimately be measured physically.



The project target from the synchronization specification is:



```text

Target:

≤ 20 ms group spread



Preferred:

≤ 10 ms

```



These are system-level targets, not guarantees.



The Playback API must not report successful synchronization merely because a command was scheduled.



Measured synchronization evidence must come from actual timing validation.



\---



\# 45. AI Implementation Rules



AI agents implementing Playback functionality MUST:



1\. Read this contract before modifying Playback code.

2\. Read `audio.md`.

3\. Read `synchronization.md`.

4\. Read `architecture.md`.

5\. Read `audio-api.md`.

6\. Read `sync-api.md`.

7\. Preserve scheduled playback.

8\. Never replace synchronized scheduling with immediate local playback.

9\. Preserve playback generation semantics.

10\. Prevent stale asynchronous commands.

11\. Never fabricate playback position.

12\. Never fabricate synchronization metrics.

13\. Never independently implement synchronization logic inside Playback.

14\. Add or update contract tests.

15\. Validate timing behavior on real devices where applicable.

16\. Document newly introduced behavior.



\---



\# 46. AI Stop Conditions



The agent MUST STOP and report a blocker when:



1\. Scheduling semantics are required but undefined.

2\. Playback readiness requirements are undefined.

3\. Generation behavior is unclear.

4\. Pause/resume synchronization behavior is unclear.

5\. Seek semantics conflict with Sync behavior.

6\. Playback state transitions conflict with Room state.

7\. Actual playback position cannot be obtained reliably.

8\. A requested feature requires changing synchronization behavior.

9\. A requested feature requires changing Audio API semantics.

10\. A requested feature requires changing Room semantics.

11\. Existing implementation contradicts this contract.

12\. A new public playback operation is required but unspecified.

13\. The agent would need to invent timing behavior.

14\. The agent would need to fabricate playback state.

15\. The agent would need to bypass scheduled playback.



The agent must not resolve these conditions by guessing.



\---



\# 47. Contract Change Procedure



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



\---



\# 48. Dependency Map



```text

&#x20;                        ┌──────────────┐

&#x20;                        │   Core API   │

&#x20;                        └──────┬───────┘

&#x20;                               │

&#x20;                               ▼

&#x20;                      ┌────────────────┐

&#x20;                      │  Playback API  │

&#x20;                      └───────┬────────┘

&#x20;                              │

&#x20;               ┌──────────────┼──────────────┐

&#x20;               ▼              ▼              ▼

&#x20;          Audio API       Sync API       Device API

&#x20;               │              │

&#x20;               └──────┬───────┘

&#x20;                      ▼

&#x20;                Native Playback

&#x20;                      │

&#x20;                      ▼

&#x20;               Physical Devices

```



Playback is the execution boundary.



It coordinates with Audio and Sync but does not absorb their responsibilities.



\---



\# 49. Relationship to Other Contracts



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



\---



\# 50. Current Open Questions



The following remain intentionally unresolved:



```text

1\. Exact PlaybackState schema

2\. Exact PlaybackResource schema

3\. Exact generation semantics

4\. Exact scheduling request schema

5\. Scheduling margin

6\. Playback readiness requirements

7\. Pause synchronization behavior

8\. Resume synchronization behavior

9\. Seek synchronization behavior

10\. Completion behavior

11\. Room playback aggregation

12\. Device playback aggregation

13\. Interruption recovery

14\. Audio route recovery

15\. Exact position precision

16\. Native playback abstraction

17\. Flutter/native communication model

18\. Concurrency semantics

19\. Idempotency semantics

20\. Exact error taxonomy

21\. Playback event architecture

22\. Background playback behavior

23\. Bluetooth playback behavior

24\. Recovery behavior after synchronization failure

```



These questions must remain explicit until resolved.



\---



\# 51. Definition of Done



Playback API implementation is complete only when:



```text

□ Playback resource contract is defined

□ Playback states are defined

□ Playback generation is implemented

□ Scheduled playback is implemented

□ Playback cannot bypass synchronization

□ Preparation is separate from playback

□ Pause is implemented according to contract

□ Resume is implemented according to contract

□ Seek is implemented according to contract

□ Stop cancels stale scheduled operations

□ Actual playback state is observable

□ Actual playback position is represented truthfully

□ Stale commands are prevented

□ Structured errors are implemented

□ Contract tests exist

□ Integration tests exist

□ Real-device playback has been validated

□ Timing behavior has been measured

□ Documentation matches implementation

□ No undocumented public behavior exists

□ No fake timing metrics exist

□ Git diff has been reviewed

```



\---



\# 52. Final Principle



The Playback API answers:



> \*\*“What should play, what is its current playback state, and how should playback execution be controlled?”\*\*



It does not answer:



> \*\*“How do we synchronize clocks?”\*\*



That belongs to Sync.



It does not answer:



> \*\*“How do we decode or prepare audio?”\*\*



That belongs to Audio.



It does not answer:



> \*\*“How do devices communicate?”\*\*



That belongs to Networking.



It does not answer:



> \*\*“Who belongs to the room?”\*\*



That belongs to Room.



\*\*Audio provides the content.

Sync provides the timing.

Playback executes the timing.

Room provides the participants.

Networking connects them.\*\*



The Playback API is the execution boundary that turns a synchronized plan into actual sound.



