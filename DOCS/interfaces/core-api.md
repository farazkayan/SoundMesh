\# SoundMesh Core API Contract



\## 1. Purpose



The Core API is the high-level coordination boundary of SoundMesh.



It provides a stable interface through which the application layer, UI layer, and other high-level consumers interact with SoundMesh without depending directly on low-level implementation details.



The Core API coordinates the major SoundMesh subsystems:



```text

UI / Application Layer

&#x20;       │

&#x20;       ▼

&#x20;    Core API

&#x20;       │

&#x20;┌──────┼────────┬────────┬────────┐

&#x20;▼      ▼        ▼        ▼        ▼

Room   Device   Audio   Playback   Sync

&#x20;API    API      API      API       API

```



The Core API is an orchestration boundary.



It MUST NOT become a replacement for the individual subsystem contracts.



\---



\# 2. Responsibilities



The Core API is responsible for:



\* application-level SoundMesh coordination

\* high-level room lifecycle

\* high-level device lifecycle

\* high-level audio workflow

\* high-level playback workflow

\* high-level synchronization workflow

\* exposing combined application state

\* coordinating subsystem transitions

\* exposing structured errors

\* coordinating recovery where multiple subsystems are involved



The Core API is NOT responsible for:



\* implementing audio decoding

\* implementing network transport

\* implementing clock synchronization

\* implementing drift correction

\* implementing platform-native audio engines

\* implementing QR generation internally

\* implementing UI rendering

\* exposing raw platform APIs to consumers



Those responsibilities belong to their respective subsystem implementations and contracts.



\---



\# 3. Contract Status



Status:



```text

EXPERIMENTAL

```



The Core API is being established before the final implementation architecture is complete.



Any field, operation, state, or behavior explicitly marked `UNDECIDED` MUST NOT be treated as finalized.



Agents MUST NOT invent final behavior for unresolved items.



\---



\# 4. Ownership



```text

Owner:

Faraz



Primary Consumers:

\- UI

\- Application layer

\- Mahin's UI implementation

\- Integration tests

```



The owner is responsible for maintaining the contract.



Consumers may propose changes.



Consumers MUST NOT silently modify the contract.



\---



\# 5. Design Principles



\## 5.1 Stable Boundary



Consumers SHOULD depend on the Core API rather than internal subsystem implementations.



For example:



```text

GOOD:



UI

&#x20;│

&#x20;▼

Core API

&#x20;│

&#x20;▼

Room API

```



Instead of:



```text

BAD:



UI

&#x20;│

&#x20;├── direct network calls

&#x20;├── direct room database access

&#x20;├── direct audio engine access

&#x20;├── direct clock synchronization

&#x20;└── direct native platform APIs

```



\---



\## 5.2 Explicit Behavior



Every public operation MUST have clearly defined:



\* inputs

\* outputs

\* state effects

\* errors

\* lifecycle behavior

\* ownership

\* asynchronous behavior

\* cancellation behavior where applicable



If any of these are not yet defined, the contract MUST say:



```text

UNDECIDED

```



\---



\## 5.3 No Hidden Side Effects



A Core API operation MUST NOT perform major undocumented side effects.



For example:



```text

joinRoom()

```



MUST NOT silently:



\* start playback

\* select audio

\* modify unrelated application state

\* begin synchronization

\* change user preferences



unless the contract explicitly defines that behavior.



\---



\# 6. Core Lifecycle



The high-level application lifecycle is conceptually:



```text

IDLE

&#x20; │

&#x20; ├── create room ──► ROOM\_CREATED

&#x20; │

&#x20; └── join room ────► ROOM\_JOINED

&#x20;                          │

&#x20;                          ▼

&#x20;                   ROOM\_PREPARING

&#x20;                          │

&#x20;                          ▼

&#x20;                      READY

&#x20;                          │

&#x20;                          ▼

&#x20;                      PLAYING

&#x20;                          │

&#x20;                   ┌──────┴──────┐

&#x20;                   ▼             ▼

&#x20;                 PAUSED       STOPPED

&#x20;                   │             │

&#x20;                   └──────┬──────┘

&#x20;                          ▼

&#x20;                        READY

```



This is a high-level conceptual lifecycle.



The authoritative state machines for individual subsystems are defined in their respective contracts.



The exact final Core state model is:



```text

UNDECIDED

```



until formally specified.



\---



\# 7. Core State



The Core API SHOULD expose a high-level application state.



Proposed model:



```text

CoreState



IDLE

CREATING\_ROOM

JOINING\_ROOM

ROOM\_READY

PREPARING

READY

PLAYING

PAUSED

STOPPING

ERROR

```



Status:



```text

EXPERIMENTAL

```



The exact final states, transitions, and transition guards remain subject to implementation and integration testing.



Agents MUST NOT add states merely because an implementation finds them convenient.



\---



\# 8. Core Operations



The following operations define the initial Core API surface.



```text

getState()

createRoom()

joinRoom()

leaveRoom()



getRoomState()



selectAudio()

preparePlayback()



play()

pause()

resume()

seek()

stop()



getDevices()

getPlaybackState()

getSyncStatus()



resynchronize()

```



The exact programming-language syntax is implementation-dependent.



The logical contract is authoritative.



\---



\# 9. getState()



\## Purpose



Returns the current high-level SoundMesh application state.



\### Input



```text

None

```



\### Output



```text

CoreState

```



\### Side Effects



None.



\### Errors



Normally none.



\### Requirements



The returned state MUST represent the current high-level application state.



It MUST NOT expose a stale cached state when the implementation knows that the underlying state has changed.



Exact update/event semantics:



```text

UNDECIDED

```



\---



\# 10. createRoom()



\## Purpose



Creates a new SoundMesh room and establishes the current device as the host.



\### Input



```text

CreateRoomRequest

```



Initial request:



```text

CreateRoomRequest



displayName:

&#x20;   optional

```



Exact fields:



```text

UNDECIDED

```



\### Output



```text

CreateRoomResult

```



Minimum expected conceptual information:



```text

roomId

joinCode

hostStatus

```



Exact data type and field definitions:



```text

UNDECIDED

```



\### Expected Behavior



On success:



1\. A new room exists.

2\. The current device becomes the host.

3\. The room becomes available for participants.

4\. Join information becomes available.

5\. Core state reflects the new room lifecycle.



\### Failure



The operation MUST return a structured error.



Possible categories include:



```text

ROOM\_CREATION\_FAILED

NETWORK\_UNAVAILABLE

ALREADY\_IN\_ROOM

INTERNAL\_ERROR

```



Final error taxonomy:



```text

UNDECIDED

```



\---



\# 11. joinRoom()



\## Purpose



Joins an existing SoundMesh room as a participant.



\### Input



```text

JoinRoomRequest

```



Conceptual information may include:



```text

roomId

joinCode

bootstrap information

join token

```



The exact request structure is defined by the Room and Networking contracts.



The Core API MUST NOT duplicate networking-specific fields unnecessarily.



\### Output



```text

JoinRoomResult

```



Conceptual result:



```text

roomId

participantId

connectionState

```



Exact structure:



```text

UNDECIDED

```



\### Expected Behavior



On success:



1\. The device becomes a room participant.

2\. The device is registered.

3\. Room state becomes available.

4\. Device state becomes available.

5\. Core state reflects successful room participation.



The operation MUST NOT automatically start playback unless explicitly requested by the playback workflow.



\---



\# 12. leaveRoom()



\## Purpose



Leaves the current room.



\### Input



```text

None

```



\### Output



```text

LeaveRoomResult

```



Exact result:



```text

UNDECIDED

```



\### Expected Behavior



On success:



1\. Room participation ends.

2\. Room-specific state is cleared or transitioned appropriately.

3\. Playback associated with the room is stopped or released according to the Playback contract.

4\. Synchronization state is released.

5\. Core returns to an appropriate non-room state.



The exact ordering of subsystem cleanup:



```text

UNDECIDED

```



\---



\# 13. getRoomState()



\## Purpose



Returns the current high-level room state.



\### Input



None.



\### Output



```text

RoomState

```



The detailed Room API is authoritative for room-specific fields.



The Core API SHOULD return either:



\* a stable room-state representation, or

\* a reference/view of the Room API state.



The final representation:



```text

UNDECIDED

```



\---



\# 14. selectAudio()



\## Purpose



Selects the audio that will be prepared for synchronized playback.



\### Input



```text

AudioSelectionRequest

```



The Audio API is authoritative for audio-specific fields.



\### Output



```text

AudioSelectionResult

```



Exact fields:



```text

UNDECIDED

```



\### Requirements



Selecting audio MUST NOT imply that playback has started.



The expected workflow is:



```text

selectAudio()

&#x20;     ↓

preparePlayback()

&#x20;     ↓

play()

```



\---



\# 15. preparePlayback()



\## Purpose



Prepares all required subsystems for synchronized playback.



Preparation may involve:



```text

Audio

&#x20; ↓

Distribution

&#x20; ↓

Audio readiness

&#x20; ↓

Synchronization

&#x20; ↓

Playback readiness

```



\### Input



```text

PreparePlaybackRequest

```



Exact fields:



```text

UNDECIDED

```



\### Output



```text

PreparePlaybackResult

```



Conceptual result:



```text

ready

audioReady

devicesReady

syncReady

```



Exact structure:



```text

UNDECIDED

```



\### Requirement



`preparePlayback()` MUST NOT begin audible playback unless explicitly defined by the Playback contract.



Preparation and playback MUST remain separate concepts.



\---



\# 16. play()



\## Purpose



Starts synchronized playback according to the Playback and Synchronization contracts.



\### Input



```text

PlayRequest

```



Conceptual information:



```text

scheduledStartTime

```



The exact scheduling model is defined by the Playback and Sync contracts.



\### Output



```text

PlayResult

```



Conceptual result:



```text

scheduled

targetTime

generation

```



Exact structure:



```text

UNDECIDED

```



\### Requirements



Playback MUST use scheduled playback.



Immediate local execution such as:



```text

play()

→ play immediately

```



MUST NOT be assumed to produce synchronized playback.



The Core API is responsible for initiating the coordinated workflow, while timing-critical scheduling belongs to the Playback/Sync implementation.



\---



\# 17. pause()



\## Purpose



Pauses coordinated playback.



\### Input



None or a pause request.



Exact input:



```text

UNDECIDED

```



\### Output



```text

PauseResult

```



Exact structure:



```text

UNDECIDED

```



\### Requirements



Pause behavior MUST remain consistent across participating devices.



The exact synchronization behavior during pause is defined by the Playback and Sync contracts.



\---



\# 18. resume()



\## Purpose



Resumes coordinated playback.



\### Input



```text

ResumeRequest

```



Exact structure:



```text

UNDECIDED

```



\### Output



```text

ResumeResult

```



Exact structure:



```text

UNDECIDED

```



Resume MUST NOT simply invoke independent immediate playback on every device.



It MUST use the synchronized playback model.



\---



\# 19. seek()



\## Purpose



Changes the playback position for the synchronized group.



\### Input



```text

SeekRequest



positionMs

```



`positionMs` represents the desired playback position in milliseconds.



\### Output



```text

SeekResult

```



Exact structure:



```text

UNDECIDED

```



\### Requirements



Seeking MUST preserve synchronized playback behavior.



The Core API MUST NOT implement device-level seeking independently.



\---



\# 20. stop()



\## Purpose



Stops coordinated playback.



\### Input



None.



\### Output



```text

StopResult

```



Exact structure:



```text

UNDECIDED

```



\### Requirements



Stopping playback MUST update the high-level Core state and relevant Playback/Sync state.



\---



\# 21. getDevices()



\## Purpose



Returns participating devices in the current room.



\### Input



None.



\### Output



```text

Device\[]

```



The Device API is authoritative for the device model.



\### Requirements



The Core API MUST NOT expose raw network connection objects as the device model.



A device identity and a network address are different concepts.



\---



\# 22. getPlaybackState()



\## Purpose



Returns high-level playback information.



\### Output



Conceptual structure:



```text

PlaybackState



state

positionMs

generation

```



Exact fields and semantics:



```text

UNDECIDED

```



Playback-specific behavior is defined by:



`DOCS/interfaces/playback-api.md`



\---



\# 23. getSyncStatus()



\## Purpose



Returns synchronization information suitable for application-level display and diagnostics.



\### Output



Conceptual structure:



```text

SyncStatus



state

offsetMs

driftMsPerSecond

confidence

```



Example:



```json

{

&#x20; "state": "SYNCHRONIZED",

&#x20; "offsetMs": 4.2,

&#x20; "driftMsPerSecond": 0.3,

&#x20; "confidence": 0.94

}

```



This example is illustrative.



The final schema is defined by:



`DOCS/interfaces/sync-api.md`



The Core API MUST NOT calculate synchronization metrics itself.



It consumes the Sync API.



\---



\# 24. resynchronize()



\## Purpose



Requests recovery synchronization when the group is no longer sufficiently synchronized.



\### Input



```text

ResynchronizeRequest

```



Exact fields:



```text

UNDECIDED

```



\### Output



```text

ResynchronizeResult

```



Exact structure:



```text

UNDECIDED

```



\### Requirements



The Core API requests synchronization recovery.



The actual synchronization algorithm belongs to the Sync subsystem.



The Core API MUST NOT duplicate the synchronization algorithm.



\---



\# 25. Events



The Core API may expose high-level events.



Potential events include:



```text

roomCreated

roomJoined

roomLeft



deviceJoined

deviceLeft

deviceConnectionChanged



audioChanged

audioReady



playbackPreparing

playbackReady

playbackStarted

playbackPaused

playbackStopped

playbackPositionChanged



syncStateChanged

syncDegraded

syncRecovered



error

```



Final event model:



```text

UNDECIDED

```



Events MUST NOT be added merely because an implementation finds them convenient.



\---



\# 26. Asynchronous Behavior



Many Core API operations involve networking, audio preparation, synchronization, or multiple devices.



These operations SHOULD therefore be treated as asynchronous at the application boundary.



Examples:



```text

createRoom()

joinRoom()

leaveRoom()

selectAudio()

preparePlayback()

play()

pause()

resume()

seek()

stop()

resynchronize()

```



The exact language-level representation:



```text

Future

Promise

Stream

Callback

Reactive state

```



is implementation-dependent.



The logical behavior MUST remain consistent with this contract.



\---



\# 27. Cancellation



Operations that may take significant time MAY support cancellation.



Examples:



```text

joinRoom()

preparePlayback()

resynchronize()

```



Final cancellation semantics:



```text

UNDECIDED

```



An agent MUST NOT invent cancellation behavior without documenting it.



\---



\# 28. Concurrency



The Core API MUST prevent conflicting high-level operations from corrupting application state.



Examples of potentially conflicting operations:



```text

createRoom()

joinRoom()



play()

stop()



seek()

stop()



preparePlayback()

leaveRoom()

```



The exact concurrency policy:



```text

UNDECIDED

```



However, implementations MUST NOT silently allow concurrent operations to create invalid state.



If an operation is invalid in the current state, it MUST produce a defined structured error once the error contract is finalized.



\---



\# 29. State Consistency



The Core API acts as a coordinator.



Therefore:



> A successful Core API operation MUST leave the system in a state consistent with all affected subsystem contracts.



For example, successful playback MUST NOT mean:



```text

Core = PLAYING

Audio = NOT\_READY

Playback = STOPPED

Sync = FAILED

```



unless the contract explicitly defines such a transitional or degraded state.



Cross-subsystem state relationships MUST be documented as they become finalized.



\---



\# 30. Error Handling



Core-level errors SHOULD represent application-level failures rather than leaking implementation details.



Examples:



```text

NOT\_IN\_ROOM

ALREADY\_IN\_ROOM

ROOM\_UNAVAILABLE

NO\_AUDIO\_SELECTED

AUDIO\_NOT\_READY

DEVICES\_NOT\_READY

SYNC\_NOT\_READY

PLAYBACK\_NOT\_READY

INVALID\_STATE

OPERATION\_IN\_PROGRESS

SYNC\_FAILED

NETWORK\_FAILED

INTERNAL\_ERROR

```



This list is preliminary.



Final error taxonomy:



```text

UNDECIDED

```



Errors MUST provide enough information for the consumer to decide what action to take.



\---



\# 31. Error Propagation



Subsystem errors MUST be translated into appropriate Core-level errors where necessary.



Example:



```text

Native network error

&#x20;       ↓

Networking subsystem

&#x20;       ↓

Room API error

&#x20;       ↓

Core API error

&#x20;       ↓

UI

```



The UI SHOULD NOT need to understand platform-native exceptions such as:



```text

NSError

IOException

SocketException

AVAudioError

```



unless the contract explicitly exposes such information for diagnostics.



\---



\# 32. Timing Boundary



The Core API is NOT the timing engine.



The Core API may initiate:



```text

prepare

schedule

play

pause

resume

seek

resynchronize

```



but timing-critical execution MUST remain inside the appropriate Playback and Synchronization implementations.



The Core layer MUST NOT use UI timing mechanisms such as:



```text

Flutter frame callbacks

UI timers

wall-clock time

animation timing

```



as the authoritative synchronization clock.



The synchronization architecture is defined by:



`DOCS/synchronization.md`



\---



\# 33. UI Boundary



The UI SHOULD interact with SoundMesh through stable Core API behavior.



The UI SHOULD NOT:



\* directly manipulate synchronization state

\* calculate playback offsets

\* calculate drift

\* perform network handshakes

\* access native audio buffers

\* directly modify room membership

\* fabricate device status

\* fabricate synchronization metrics



The UI displays information supplied by the underlying contracts.



\---



\# 34. Example High-Level Workflow



A typical host workflow:



```text

createRoom()

&#x20;     ↓

room created

&#x20;     ↓

wait for participants

&#x20;     ↓

selectAudio()

&#x20;     ↓

preparePlayback()

&#x20;     ↓

verify readiness

&#x20;     ↓

play()

&#x20;     ↓

monitor playback/synchronization

&#x20;     ↓

pause / resume / seek / stop

```



A typical participant workflow:



```text

joinRoom()

&#x20;     ↓

room state available

&#x20;     ↓

receive/prepare audio

&#x20;     ↓

synchronization calibration

&#x20;     ↓

ready

&#x20;     ↓

receive playback schedule

&#x20;     ↓

play locally at scheduled target

&#x20;     ↓

monitor drift

&#x20;     ↓

apply synchronization corrections

```



The detailed behavior of each step belongs to the appropriate subsystem contract.



\---



\# 35. Contract Dependencies



The Core API depends on the following contracts:



```text

Core API

&#x20;  │

&#x20;  ├── Room API

&#x20;  ├── Device API

&#x20;  ├── Audio API

&#x20;  ├── Playback API

&#x20;  └── Sync API

```



Dependency direction SHOULD remain one-way where practical.



Subsystems SHOULD NOT depend on UI implementation details.



The exact dependency graph remains subject to:



\* `DOCS/architecture.md`

\* individual interface contracts

\* approved architecture decisions



\---



\# 36. Contract Change Rules



Changes to this document are controlled.



A change is required when:



\* an operation is added

\* an operation is removed

\* an input changes

\* an output changes

\* state semantics change

\* error semantics change

\* lifecycle behavior changes

\* timing guarantees change

\* consumer-visible behavior changes



Before changing the contract:



1\. Identify the reason.

2\. Identify affected interfaces.

3\. Identify affected consumers.

4\. Identify compatibility impact.

5\. Update contract tests.

6\. Document the change.

7\. Coordinate implementation.



Do not silently change the Core API to make one implementation easier.



\---



\# 37. Contract Test Requirements



The Core API MUST eventually have contract tests covering at least:



\### Room lifecycle



```text

createRoom()

joinRoom()

leaveRoom()

```



\### Audio lifecycle



```text

selectAudio()

preparePlayback()

```



\### Playback lifecycle



```text

play()

pause()

resume()

seek()

stop()

```



\### State



```text

getState()

getRoomState()

getPlaybackState()

getSyncStatus()

```



\### Failure behavior



Tests MUST eventually cover:



\* invalid state

\* unavailable room

\* network failure

\* unavailable audio

\* synchronization failure

\* device failure

\* conflicting operations



Exact test cases are defined in:



`DOCS/contract-testing.md`



\---



\# 38. Integration Requirements



Core API tests are not sufficient by themselves.



The Core API MUST eventually be tested against real subsystem implementations.



Required integration chain:



```text

UI

&#x20;↓

Core API

&#x20;↓

Subsystem APIs

&#x20;↓

Native/platform implementations

&#x20;↓

Real device

```



For synchronization and playback, real-device testing is mandatory.



A passing mock test MUST NOT be interpreted as proof that synchronized physical playback works.



\---



\# 39. Security Requirements



The Core API MUST NOT expose sensitive networking credentials unnecessarily.



Room join information, temporary tokens, and network bootstrap information MUST follow the security rules defined by:



`DOCS/networking.md`



The Core API SHOULD expose only the information required by its consumer.



Temporary credentials MUST NOT become permanent application identity.



\---



\# 40. Observability



The Core API SHOULD provide enough structured state for diagnostics without exposing unnecessary internal implementation details.



Useful high-level information includes:



```text

current state

room state

device count

audio readiness

playback state

sync state

last error

```



The exact diagnostics model:



```text

UNDECIDED

```



Logging MUST NOT fabricate successful states or synchronization measurements.



\---



\# 41. Non-Goals



The Core API is NOT intended to:



\* replace subsystem APIs

\* contain synchronization algorithms

\* contain audio processing algorithms

\* contain network transport logic

\* become a global dumping ground for unrelated functionality

\* expose every internal implementation detail

\* provide UI-specific convenience functions

\* hide architectural problems through excessive abstraction



If functionality belongs naturally to a subsystem, it SHOULD remain in that subsystem.



\---



\# 42. AI Implementation Rules



An AI agent implementing the Core API MUST:



1\. Read this document completely.

2\. Read `DOCS/interfaces/README.md`.

3\. Read the relevant subsystem contracts.

4\. Read `DOCS/architecture.md`.

5\. Read `DOCS/blueprint.md`.

6\. Read `DOCS/AI/rules.md`.

7\. Read `DOCS/AI/task-protocol.md`.

8\. Inspect the existing repository.

9\. Check the current Git state.

10\. Identify any unresolved contract decisions.

11\. Avoid inventing unspecified behavior.

12\. Preserve existing contracts.

13\. Add tests for implemented behavior.

14\. Report all contract assumptions.

15\. Stop when a required decision is UNDECIDED.



The agent MUST NOT:



\* invent API signatures and treat them as final

\* bypass subsystem contracts

\* directly access another subsystem's internals

\* change another subsystem's contract silently

\* add undocumented state

\* invent undocumented errors

\* fabricate synchronization metrics

\* use UI timing as a synchronization mechanism

\* expand scope without authorization



\---



\# 43. Stop Conditions



The agent MUST STOP and report a blocker if:



```text

A required subsystem contract is missing.



OR



Two contracts disagree.



OR



The architecture contradicts the Core API.



OR



An implementation requires an undocumented architectural decision.



OR



A required state transition is undefined.



OR



An error behavior is required but undefined.



OR



A consumer requires behavior that the contract does not provide.



OR



A proposed implementation requires changing another interface.



OR



Contract tests reveal incompatible assumptions.

```



The agent MUST NOT resolve these silently.



\---



\# 44. Current Open Questions



The following are intentionally unresolved until explicitly decided:



```text

UNDECIDED:

\- Final programming-language representation of async operations.

\- Final CoreState enum.

\- Final event model.

\- Final request/response data structures.

\- Final error taxonomy.

\- Final cancellation semantics.

\- Final concurrency policy.

\- Final cross-subsystem state synchronization mechanism.

\- Final dependency injection strategy.

\- Final Core API implementation location in the Flutter/native architecture.

```



These MUST be resolved before they become required implementation assumptions.



\---



\# 45. Final Principle



The Core API exists to make SoundMesh composable.



It should allow one part of the system to say:



```text

"Create a room."

"Join this room."

"Prepare playback."

"Play at the coordinated time."

"Show me the current sync status."

```



without needing to know:



```text

how packets are transmitted

how clocks are synchronized

how audio buffers are managed

how native audio is scheduled

how drift is corrected

how QR data is encoded

```



That separation is intentional.



> \*\*The Core API coordinates the system. It does not secretly become the system.\*\*



The objective is a stable, testable boundary that allows independently developed SoundMesh components—and AI agents—to work together without silently inventing incompatible assumptions.



