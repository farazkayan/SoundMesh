\# SoundMesh Interface Contract System



\## 1. Purpose



This directory contains the authoritative interface contracts that define how independently developed SoundMesh subsystems communicate.



These contracts exist to prevent incompatible implementations, undocumented assumptions, and AI-generated interface drift.



SoundMesh may be developed by multiple humans and AI agents simultaneously. Different agents may work on different layers of the system and may otherwise make locally reasonable decisions that become globally incompatible.



The interface contracts are the boundary that prevents this.



An implementation MUST conform to the applicable interface contract.



The contract is authoritative over any individual implementation.



\---



\# 2. Core Principle



> \*\*Build against contracts, not assumptions.\*\*



An agent working on one subsystem MUST NOT infer the behavior of another subsystem from:



\* variable names

\* existing implementation details

\* temporary code

\* UI assumptions

\* undocumented behavior

\* previous AI-generated code

\* guessed return values

\* guessed state meanings

\* guessed error behavior



If behavior is not defined by the applicable contract or higher-level architecture documentation, it is \*\*UNDECIDED\*\*.



Agents MUST NOT silently invent a solution for an UNDECIDED contract decision.



\---



\# 3. What Is an Interface Contract?



An interface contract defines the agreement between two or more subsystems.



A contract may define:



\* operations/functions

\* inputs

\* outputs

\* data types

\* state values

\* state transitions

\* events

\* errors

\* lifecycle behavior

\* timing requirements

\* ordering requirements

\* concurrency requirements

\* guarantees

\* constraints

\* ownership

\* versioning

\* compatibility requirements

\* testing requirements



A contract describes \*\*what a subsystem promises to provide\*\*, not necessarily how it internally implements that behavior.



\---



\# 4. Contract vs Implementation



The contract defines externally observable behavior.



The implementation defines how that behavior is achieved.



For example:



```text

Contract:



createRoom()

&#x20;   → returns RoomCreationResult

&#x20;   → result contains roomId

&#x20;   → result contains joinCode

&#x20;   → host becomes registered in the room



Implementation:



&#x20;   generate UUID

&#x20;   create local room object

&#x20;   open network listener

&#x20;   register host

&#x20;   generate join code

```



The implementation may change.



The contract MUST remain stable unless an explicit contract change is approved.



\---



\# 5. Interface Hierarchy



SoundMesh interfaces are layered.



```text

&#x20;                   ┌──────────────────────┐

&#x20;                   │      Core API        │

&#x20;                   │ System coordination  │

&#x20;                   └──────────┬───────────┘

&#x20;                              │

&#x20;            ┌─────────────────┼─────────────────┐

&#x20;            │                 │                 │

&#x20;            ▼                 ▼                 ▼

&#x20;     ┌────────────┐    ┌────────────┐    ┌────────────┐

&#x20;     │  Room API  │    │ Device API │    │ Audio API  │

&#x20;     └────────────┘    └────────────┘    └────────────┘

&#x20;            │                 │                 │

&#x20;            └─────────────────┼─────────────────┘

&#x20;                              ▼

&#x20;                    ┌──────────────────┐

&#x20;                    │   Playback API   │

&#x20;                    └────────┬─────────┘

&#x20;                             │

&#x20;                             ▼

&#x20;                    ┌──────────────────┐

&#x20;                    │     Sync API     │

&#x20;                    └──────────────────┘

```



The exact dependency relationships remain subject to the authoritative architecture documentation and individual interface contracts.



Agents MUST NOT create new cross-layer dependencies without documenting and approving them.



\---



\# 6. Interface Documents



The following documents define the current SoundMesh interface boundaries.



\## 6.1 `core-api.md`



Defines the high-level coordination boundary of SoundMesh.



Responsible for coordinating major subsystems without exposing unnecessary implementation details.



Examples of responsibilities:



\* application lifecycle

\* subsystem coordination

\* high-level room lifecycle

\* high-level playback lifecycle

\* high-level system state

\* cross-subsystem orchestration



\---



\## 6.2 `room-api.md`



Defines the contract for room lifecycle and room state.



Expected responsibilities include:



\* creating rooms

\* joining rooms

\* leaving rooms

\* room identity

\* join information

\* room membership

\* room lifecycle

\* room state

\* host/participant roles



The Room API MUST NOT require consumers to understand low-level networking implementation.



\---



\## 6.3 `device-api.md`



Defines the contract for participating devices.



Expected responsibilities include:



\* device identity

\* device registration

\* device presence

\* connection state

\* device capabilities

\* device status

\* device synchronization status

\* device lifecycle



Device identity MUST NOT be treated as equivalent to a network address.



\---



\## 6.4 `audio-api.md`



Defines the contract for audio preparation and audio availability.



Expected responsibilities include:



\* audio selection

\* audio metadata

\* audio preparation

\* audio availability

\* audio integrity

\* audio readiness

\* audio lifecycle



The Audio API MUST NOT expose unnecessary platform-specific audio implementation details to higher layers.



\---



\## 6.5 `playback-api.md`



Defines the contract for synchronized playback control.



Expected responsibilities include:



\* prepare

\* schedule

\* play

\* pause

\* resume

\* seek

\* stop

\* playback state

\* playback position

\* playback generation

\* playback readiness



Playback scheduling MUST be compatible with the synchronization model defined by `DOCS/synchronization.md`.



\---



\## 6.6 `sync-api.md`



Defines the contract for synchronization.



Expected responsibilities include:



\* clock synchronization

\* offset estimation

\* latency estimation

\* uncertainty

\* calibration

\* synchronization state

\* drift measurement

\* synchronization correction

\* resynchronization

\* synchronization diagnostics



The Sync API MUST preserve the distinction between:



```text

clock time

network timing

audio playback position

synchronization error

drift

uncertainty

```



These concepts MUST NOT be treated as interchangeable.



\---



\# 7. Ownership



Every interface MUST have an explicit owner.



Initial ownership:



| Interface    | Owner | Primary Consumer |

| ------------ | ----- | ---------------- |

| Core API     | Faraz | Mahin / UI       |

| Room API     | Faraz | Mahin / UI       |

| Device API   | Faraz | Mahin / UI       |

| Audio API    | Faraz | Mahin / UI       |

| Playback API | Faraz | Mahin / UI       |

| Sync API     | Faraz | Mahin / UI       |



This ownership describes responsibility for maintaining the contract.



Ownership does NOT mean that only the owner may inspect, test, or implement the interface.



Consumers may propose changes.



Only an explicitly approved contract change may modify an established interface.



\---



\# 8. Consumer Responsibility



A consumer MUST:



1\. Read the complete applicable contract.

2\. Use only documented operations.

3\. Respect documented input and output types.

4\. Respect documented states.

5\. Handle documented errors.

6\. Respect lifecycle rules.

7\. Avoid depending on undocumented implementation details.

8\. Report missing requirements instead of guessing.

9\. Report incompatible behavior discovered during integration.

10\. Keep mocks and test doubles compatible with the same contract.



A consumer MUST NOT create an unofficial alternative interface because the official interface is inconvenient.



\---



\# 9. Contract Authority



The authority hierarchy for interfaces is:



```text

1\. Explicit approved architectural decisions

2\. Interface contract documents

3\. Core architecture documentation

4\. Synchronization/networking/audio specifications

5\. Existing approved integration tests

6\. Existing implementation

7\. AI assumptions

```



Existing code is NOT automatically authoritative.



If code conflicts with a documented contract, the conflict MUST be reported.



An agent MUST NOT silently rewrite the contract merely to match existing code.



\---



\# 10. UNDECIDED Is a Valid State



An interface document MUST explicitly mark unresolved decisions as:



```text

UNDECIDED

```



Examples:



```text

UNDECIDED:

\- exact serialization format

\- exact error enum

\- exact implementation language boundary

\- whether a particular operation is synchronous or asynchronous

```



UNDECIDED means:



> The project has intentionally not made this decision yet.



It does NOT mean:



> The AI should choose something reasonable.



Agents MUST stop and report a blocker when an unresolved decision is required to safely continue implementation.



\---



\# 11. Contract Stability



Once an interface is implemented and consumed by another subsystem, changes become controlled changes.



The following are considered contract changes:



\* renaming an operation

\* removing an operation

\* changing parameters

\* adding required parameters

\* changing parameter types

\* changing return types

\* changing state meanings

\* changing error semantics

\* changing lifecycle behavior

\* changing timing guarantees

\* changing ordering guarantees

\* changing required fields

\* changing required events

\* changing guarantees relied upon by consumers



These changes MUST NOT be made silently.



\---



\# 12. Adding New Interface Behavior



New behavior MUST be documented before dependent implementation begins.



The change process is:



```text

Identify requirement

&#x20;       ↓

Check existing contract

&#x20;       ↓

Determine whether existing contract is sufficient

&#x20;       ↓

If insufficient → propose contract change

&#x20;       ↓

Document affected interfaces

&#x20;       ↓

Identify affected consumers

&#x20;       ↓

Update contract tests

&#x20;       ↓

Implement

&#x20;       ↓

Run integration tests

```



The agent MUST NOT implement an undocumented public interface simply because it appears useful.



\---



\# 13. Contract Change Proposal



When an interface needs to change, the proposal MUST include:



```text

Change ID:

Interface:

Owner:

Requester:



Current Contract:

<existing behavior>



Proposed Contract:

<new behavior>



Reason:

<why the change is necessary>



Affected Systems:

<systems that may need changes>



Compatibility Impact:

<breaking / non-breaking / unknown>



Required Tests:

<tests that must change or be added>



Migration Plan:

<how existing consumers will adapt>

```



If compatibility cannot be determined, mark it:



```text

UNKNOWN

```



Do not guess.



\---



\# 14. Versioning



Interface versioning MUST be used when compatibility requires it.



The exact versioning strategy is defined by the individual contracts and networking specification.



Agents MUST NOT independently invent incompatible versioning schemes.



Where protocol versions are required, version information MUST be explicit rather than inferred.



\---



\# 15. Contract Tests



Every important interface SHOULD have automated contract tests.



Contract tests verify that:



```text

Producer implementation

&#x20;       ↓

conforms to

&#x20;       ↓

Interface contract

&#x20;       ↑

consumed by

&#x20;       ↑

Consumer implementation

```



Contract tests SHOULD verify:



\* valid inputs

\* invalid inputs

\* expected outputs

\* required fields

\* state transitions

\* errors

\* lifecycle behavior

\* ordering

\* timing guarantees where applicable

\* compatibility requirements



See:



`DOCS/contract-testing.md`



for the project-wide contract-testing policy.



\---



\# 16. Mock Implementations



Consumers may use mock implementations while the real subsystem is under development.



However:



> \*\*A mock is a contract implementation, not an alternative contract.\*\*



A mock MUST conform to the same interface contract as the real implementation.



A mock MUST NOT introduce behavior that the real implementation is not required to provide.



Mock-specific behavior MUST be clearly identified as test-only behavior.



\---



\# 17. AI Agent Rules



AI agents working on SoundMesh MUST follow these rules.



\### MUST



\* Read the relevant interface contract before implementation.

\* Treat the contract as authoritative.

\* Preserve existing interfaces.

\* Use documented types and states.

\* Respect ownership.

\* Report ambiguity.

\* Mark unknown behavior as UNDECIDED.

\* Update contract documentation when an approved contract changes.

\* Update affected tests.

\* Report contract-related changes explicitly.



\### MUST NOT



\* invent undocumented interfaces

\* silently change interfaces

\* rename public operations

\* remove public operations

\* change state meanings

\* invent error semantics

\* add required parameters without approval

\* depend on internal implementation details

\* create duplicate unofficial APIs

\* assume another subsystem's behavior

\* silently resolve architectural ambiguity



\---



\# 18. Stop Conditions



An AI agent MUST STOP implementation and report a blocker if:



1\. A required interface is undefined.

2\. Two authoritative documents conflict.

3\. Existing code contradicts the contract.

4\. The task requires changing another subsystem's interface.

5\. An architectural decision is required but undocumented.

6\. A dependency between subsystems is unclear.

7\. The authoritative behavior cannot be determined.

8\. A contract test fails because of incompatible behavior.

9\. Another subsystem expects incompatible behavior.

10\. Multiple valid architectural solutions exist and no decision has been made.



The agent MUST NOT resolve these situations by silently choosing an option.



\---



\# 19. Implementation Boundary



Interfaces SHOULD expose behavior rather than implementation details.



For example, a consumer SHOULD depend on:



```text

getSyncStatus()

```



rather than:



```text

readInternalClockModel()

calculateNtpOffsetInternally()

inspectNativeAudioBuffer()

```



The consumer should know:



```text

what synchronization state exists

```



not:



```text

how synchronization is internally calculated

```



This separation allows the implementation to evolve without breaking consumers.



\---



\# 20. Platform Independence



SoundMesh targets multiple platforms.



Flutter and platform-native implementations may differ internally.



The interface contract SHOULD define the common observable behavior.



For example:



```text

Flutter/UI

&#x20;     │

&#x20;     ▼

Common interface

&#x20;     │

&#x20;┌────┴────┐

&#x20;▼         ▼

Android    iOS

native     native

implementation implementation

```



Platform-specific behavior MUST be documented when it produces externally observable differences.



An agent MUST NOT assume Android and iOS behave identically merely because they implement the same interface.



\---



\# 21. Timing-Critical Interfaces



Interfaces involving synchronization and playback require additional caution.



The following MUST remain explicit:



\* time source

\* clock domain

\* timestamps

\* units

\* precision

\* scheduling semantics

\* playback generation

\* drift behavior

\* correction behavior

\* uncertainty

\* failure behavior



Timing values MUST include explicit units.



For example:



```text

offsetMs

driftMsPerSecond

```



is preferable to:



```text

offset

drift

```



because the unit is unambiguous.



Timing-critical operations SHOULD remain close to the native timing boundary where required by the architecture.



See:



\* `DOCS/synchronization.md`

\* `DOCS/audio.md`

\* `DOCS/architecture.md`



\---



\# 22. Data Type Requirements



Public interface data structures MUST define:



\* field names

\* field types

\* required/optional status

\* allowed values

\* units

\* nullability

\* validation rules

\* lifecycle meaning



Example:



```text

SyncStatus



state:

&#x20;   type: SyncState

&#x20;   required: YES



offsetMs:

&#x20;   type: number

&#x20;   required: YES

&#x20;   unit: milliseconds



confidence:

&#x20;   type: number

&#x20;   required: YES

&#x20;   range: 0.0–1.0

```



The exact types and fields belong in the relevant interface document.



\---



\# 23. Error Contract



Errors are part of the interface.



A subsystem MUST NOT simply expose arbitrary implementation errors to consumers when the contract defines structured errors.



Errors SHOULD define:



```text

error code

message

recoverability

affected operation

recommended consumer behavior

```



Example:



```text

ROOM\_NOT\_FOUND

Recoverable: NO

Operation: joinRoom

Consumer behavior: show room unavailable

```



The exact error taxonomy is defined by the applicable interface.



\---



\# 24. State Contract



State values are part of the interface and MUST have precise meanings.



For example:



```text

CONNECTING

CONNECTED

DISCONNECTED

```



MUST NOT be used interchangeably with:



```text

PREPARING

READY

PLAYING

PAUSED

```



Different state machines MUST remain conceptually separate unless the contract explicitly defines their relationship.



Every externally visible state SHOULD define:



\* meaning

\* entry conditions

\* exit conditions

\* allowed transitions

\* invalid transitions

\* consumer behavior



\---



\# 25. Integration Principle



A subsystem is not considered complete merely because its own tests pass.



It is complete only when:



```text

Implementation

&#x20;     ↓

matches contract

&#x20;     ↓

contract tests pass

&#x20;     ↓

consumer integration works

&#x20;     ↓

system integration works

```



For SoundMesh, real-device validation is required for timing-critical behavior.



A mocked or simulated success MUST NOT be presented as evidence of real synchronization quality.



\---



\# 26. Source of Truth



When implementing an interface, the agent SHOULD follow this order:



```text

Applicable interface document

&#x20;       ↓

Referenced architecture specification

&#x20;       ↓

Referenced synchronization/networking/audio specification

&#x20;       ↓

Approved decisions

&#x20;       ↓

Contract tests

&#x20;       ↓

Implementation

```



If these sources disagree:



\*\*STOP.\*\*



Do not silently select one.



Report the conflict and identify the exact documents or code involved.



\---



\# 27. Cross-References



Interface contracts depend on broader SoundMesh specifications.



Relevant documents:



\* `DOCS/blueprint.md`

\* `DOCS/architecture.md`

\* `DOCS/networking.md`

\* `DOCS/audio.md`

\* `DOCS/synchronization.md`

\* `DOCS/testing.md`

\* `DOCS/contract-testing.md`

\* `DOCS/AI/rules.md`

\* `DOCS/AI/task-protocol.md`

\* `DOCS/AI/integration-protocol.md`



The interface documents MUST remain consistent with these authoritative specifications.



\---



\# 28. Current Contract Status



The interface system is being established incrementally.



Unless explicitly marked otherwise, individual interface details that have not yet been formally specified are:



```text

UNDECIDED

```



Agents MUST NOT infer final API signatures, data models, state machines, or error taxonomies from this README alone.



The individual interface documents are authoritative for their respective interfaces.



\---



\# 29. Final Principle



SoundMesh is being built by humans and AI agents working on different parts of the same distributed system.



Local correctness is not enough.



The system must also be \*\*compatible\*\*.



Therefore:



> \*\*No subsystem may silently redefine the boundary between itself and another subsystem.\*\*



When the contract is clear:



\*\*Implement it.\*\*



When the contract is missing:



\*\*Stop and document the gap.\*\*



When the contract is wrong:



\*\*Propose a change.\*\*



When the contract conflicts with another source:



\*\*Stop and escalate.\*\*



When implementation and contract disagree:



\*\*Do not hide the disagreement.\*\*



The goal is not merely to make individual AI agents productive.



The goal is to make their work \*\*composable, testable, and safe to integrate into one SoundMesh system.\*\*



