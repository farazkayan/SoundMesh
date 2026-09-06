\# SoundMesh — Mahin Work Plan



\*\*Document Status:\*\* ACTIVE

\*\*Document Type:\*\* Developer Workstream Specification

\*\*Owner:\*\* Mahin

\*\*Primary AI Consumer:\*\* Mahin's AI development agent

\*\*Project:\*\* SoundMesh

\*\*Related Workstream:\*\* `DOCS/AI/farazwork.md`



\---



\# 1. Purpose



This document defines the complete application/UI workstream owned by Mahin.



Mahin owns the user-facing Flutter application layer and the presentation of SoundMesh functionality to the user.



This document does NOT replace the shared SoundMesh architecture, subsystem specifications, or interface contracts.



It answers:



> \*\*"What is Mahin responsible for building, in what order, and how must his work integrate with Faraz's technical systems?"\*\*



All work described here MUST remain consistent with:



1\. `AGENTS.md`

2\. `CONTRIBUTING.md`

3\. `DOCS/blueprint.md`

4\. `DOCS/architecture.md`

5\. `DOCS/roadmap.md`

6\. `DOCS/networking.md`

7\. `DOCS/synchronization.md`

8\. `DOCS/audio.md`

9\. `DOCS/ui-ux.md`

10\. `DOCS/testing.md`

11\. `DOCS/contract-testing.md`

12\. `DOCS/interfaces/\*`

13\. `DOCS/AI/rules.md`

14\. `DOCS/AI/task-protocol.md`

15\. `DOCS/AI/integration-protocol.md`

16\. `DOCS/AI/farazwork.md`



Higher-authority documents override this document.



\---



\# 2. Mahin's Ownership



Mahin is primarily responsible for:



\* Flutter application UI

\* Navigation

\* Screens

\* User interaction

\* UI state presentation

\* UI components

\* Visual design implementation

\* Room screens

\* Create Room UI

\* Join Room UI

\* QR scanning UI

\* Device list UI

\* Audio selection UI

\* Playback controls

\* Synchronization status presentation

\* Diagnostics presentation

\* Loading/preparation states

\* Error presentation

\* Empty states

\* Connection states

\* Accessibility

\* Responsive layouts

\* UI animations

\* UI-level state management

\* Mock UI development

\* UI tests

\* Integration of the UI with Core APIs

\* User-facing documentation where appropriate



Mahin is NOT the primary owner of:



\* Networking implementation

\* Room lifecycle implementation

\* Audio transport

\* Audio decoding

\* Native audio timing

\* Clock synchronization

\* Calibration algorithms

\* Drift estimation

\* Drift correction

\* Playback scheduling internals

\* Native Android timing systems

\* Native iOS timing systems

\* Core technical state machines



Those systems are primarily owned by Faraz.



\---



\# 3. Fundamental Rule



Mahin's UI MUST consume SoundMesh functionality through documented interfaces.



The UI MUST NOT depend directly on internal implementation details.



The desired architecture is:



```text

User

&#x20; ↓

Flutter UI

&#x20; ↓

Core API

&#x20; ↓

Room / Device / Audio / Playback / Sync

&#x20; ↓

Native / Networking Systems

&#x20; ↓

Real Devices

```



Mahin's UI should not bypass Core to directly manipulate:



\* sockets

\* network packets

\* native audio engines

\* synchronization clocks

\* drift algorithms

\* calibration internals



\---



\# 4. Shared Source of Truth



Mahin MUST use the same SoundMesh documentation as Faraz.



The following are shared:



\* Architecture

\* Networking specification

\* Audio specification

\* Synchronization specification

\* UI/UX specification

\* Testing specification

\* Interface contracts

\* AI rules

\* Task protocol

\* Integration protocol



Mahin MUST NOT create alternative interpretations of these systems inside UI code.



If the contract says:



```text

getSyncStatus()

```



the UI consumes the documented result.



It MUST NOT invent:



```text

getSyncError()

getSyncQuality()

getPerfectSync()

```



unless those are formally added to the relevant contract.



\---



\# 5. Development Strategy



Mahin's work SHOULD progress approximately as follows:



```text

UI Foundation

&#x20;   ↓

Design System

&#x20;   ↓

Navigation

&#x20;   ↓

Application State

&#x20;   ↓

Core API Adapter

&#x20;   ↓

Create Room

&#x20;   ↓

Join Room

&#x20;   ↓

QR Flow

&#x20;   ↓

Room Screen

&#x20;   ↓

Device List

&#x20;   ↓

Audio Selection

&#x20;   ↓

Preparation UI

&#x20;   ↓

Playback UI

&#x20;   ↓

Synchronization UI

&#x20;   ↓

Error / Recovery UI

&#x20;   ↓

Diagnostics

&#x20;   ↓

Real Backend Integration

&#x20;   ↓

Multi-Device UX

&#x20;   ↓

Accessibility

&#x20;   ↓

Performance

&#x20;   ↓

Competition Polish

```



The exact sequence may change based on integration requirements.



\---



\# 6. Phase 0 — UI Foundation



\## Objective



Establish a clean Flutter application foundation.



\## Responsibilities



Mahin MUST establish:



\* Flutter project structure

\* UI folder/module structure

\* Navigation foundation

\* Theme system

\* Typography system

\* Spacing system

\* Reusable components

\* Icon system

\* Button system

\* Cards/surfaces

\* Input components

\* Loading indicators

\* Error components

\* State presentation components



The implementation MUST follow `DOCS/ui-ux.md`.



\---



\# 7. Phase 1 — SoundMesh Design System



\## Objective



Create the reusable visual language for the application.



\## Required direction



SoundMesh should feel:



\* modern

\* calm

\* premium

\* audio-focused

\* minimal

\* technically trustworthy



The UI MUST NOT become visually noisy.



\## Design system



Use the shared UI specification.



Primary concepts include:



\* Dark-first interface

\* System-native typography

\* 8pt spacing system

\* Touch targets ≥44px

\* Consistent corner radii

\* Subtle borders

\* Controlled elevation

\* Purposeful animation

\* Accessible contrast



The documented SoundMesh palette is authoritative.



Mahin MUST NOT create a separate color system without updating `ui-ux.md`.



\---



\# 8. Phase 2 — Navigation Architecture



\## Objective



Create predictable application navigation.



Conceptual flow:



```text

Home

&#x20;├── Create Room

&#x20;│      ↓

&#x20;│   Room

&#x20;│

&#x20;└── Join Room

&#x20;       ↓

&#x20;     Scan QR

&#x20;       ↓

&#x20;     Joining

&#x20;       ↓

&#x20;     Room

```



Room flow:



```text

Room

&#x20;├── Devices

&#x20;├── Audio

&#x20;├── Preparation

&#x20;├── Playback

&#x20;├── Sync Status

&#x20;└── Diagnostics

```



Exact navigation structure may evolve.



Navigation MUST represent actual application state.



\---



\# 9. Phase 3 — Application State Presentation



\## Objective



Build a UI state model that accurately represents the Core API.



Potential high-level states include:



```text

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



These correspond conceptually to the Core contract.



Mahin MUST NOT invent contradictory state meanings.



For example:



```text

Core = PREPARING

```



The UI MUST NOT display:



```text

READY

```



unless the contract actually permits that state.



\---



\# 10. Phase 4 — Core API Integration Layer



\## Objective



Create the Flutter-side adapter to the Core API.



The UI should interact with a clean application-facing interface.



Conceptually:



```text

Flutter UI

&#x20;    ↓

CoreController / CoreService

&#x20;    ↓

Core API

```



The exact implementation is governed by the architecture.



\## Responsibilities



Mahin MUST implement the UI-side handling of:



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



Exact signatures MUST come from `core-api.md`.



\---



\# 11. Phase 5 — Create Room Experience



\## Objective



Make room creation extremely simple.



Conceptual flow:



```text

Home

&#x20;↓

Create Room

&#x20;↓

Creating

&#x20;↓

Room Created

&#x20;↓

Display Join Information

&#x20;↓

Wait for Participants

```



The UI should clearly communicate:



\* Room exists

\* User is host

\* Other devices can join

\* Current participants

\* Connection/readiness status



Mahin MUST NOT fabricate room IDs, join codes, or participant counts.



All values MUST come from the Core/Room contracts.



\---



\# 12. Phase 6 — Join Room Experience



\## Objective



Make joining another device simple.



Conceptual flow:



```text

Home

&#x20;↓

Join Room

&#x20;↓

Scan QR

&#x20;↓

Validate

&#x20;↓

Connect

&#x20;↓

Register

&#x20;↓

Room

```



UI MUST distinguish:



\* scanning

\* validating

\* connecting

\* joining

\* registered participant



A successful network connection MUST NOT automatically be presented as successful room membership unless the Room/Core API confirms it.



\---



\# 13. Phase 7 — QR User Experience



\## Objective



Provide a fast QR-first onboarding experience.



Mahin owns:



\* QR scanner UI

\* Camera permission UX

\* Scan feedback

\* Invalid QR state

\* Expired QR state

\* Unsupported version state

\* Connection progress

\* Join success/failure presentation



Faraz owns the underlying:



\* join payload

\* validation

\* room identity

\* token handling

\* networking



Mahin MUST NOT implement an alternative join protocol.



\---



\# 14. Phase 8 — Room Screen



\## Objective



Create the central SoundMesh control surface.



The room screen should make it immediately clear:



\* Which room the user is in

\* Whether the user is host or participant

\* Which devices are present

\* Whether devices are ready

\* What audio is selected

\* Whether playback is active

\* Whether synchronization is healthy



The room screen MUST use real application state.



\---



\# 15. Phase 9 — Device UI



\## Objective



Present participating devices clearly.



The UI may show information such as:



\* Device name

\* Device role

\* Connection state

\* Presence

\* Readiness

\* Sync state

\* Audio route where available



Example conceptual display:



```text

Devices



Faraz's Phone

● Ready

● Synchronized



Mahin's Phone

● Ready

● Synchronized



Phone 3

● Preparing

```



The exact fields must follow `device-api.md`.



Mahin MUST NOT infer technical states from unrelated information.



\---



\# 16. Phase 10 — Audio Selection UI



\## Objective



Allow the user to select audio for the SoundMesh session.



The UI may provide:



\* File picker

\* Selected audio display

\* Metadata

\* Duration

\* Format

\* Preparation status

\* Availability

\* Integrity failure state



Mahin consumes Audio API results.



The UI MUST NOT implement:



\* audio decoding

\* audio distribution

\* integrity algorithms

\* audio preparation internals



\---



\# 17. Phase 11 — Preparation Experience



\## Objective



Clearly communicate when SoundMesh is preparing devices for playback.



Conceptual flow:



```text

Audio Selected

&#x20;    ↓

Preparing Audio

&#x20;    ↓

Checking Devices

&#x20;    ↓

Synchronizing

&#x20;    ↓

Ready

```



The UI MUST distinguish:



```text

Audio Ready

Device Ready

Sync Ready

Playback Ready

```



These are not automatically equivalent.



Mahin MUST display the actual state reported by the relevant contract.



\---



\# 18. Phase 12 — Playback UI



\## Objective



Create intuitive controls for synchronized playback.



Controls may include:



\* Play

\* Pause

\* Resume

\* Seek

\* Stop



The UI sends high-level commands.



It MUST NOT determine synchronization timing itself.



For example, the UI should call:



```text

play()

```



rather than attempting to calculate:



```text

startAt = currentTime + 3000

```



The Playback/Sync systems determine the correct timing.



\---



\# 19. Phase 13 — Synchronization UI



\## Objective



Make the technical synchronization system understandable to normal users.



The UI should communicate meaningful states such as:



```text

Synchronized

Calibrating

Preparing

Degraded

Resynchronizing

Connection Lost

```



Where appropriate, technical diagnostics may expose:



\* estimated offset

\* drift

\* confidence

\* timing state



However:



\*\*No synchronization value may be fabricated.\*\*



If the Sync API reports:



```text

offsetMs: 4.2

```



the UI may display it.



If the API does not provide a value:



```text

DO NOT invent one.

```



\---



\# 20. Phase 14 — Sync Quality Presentation



\## Objective



Translate technical synchronization information into truthful user-facing feedback.



Potential user-facing representation:



```text

● Synchronized

```



or:



```text

● Syncing...

```



or:



```text

⚠ Sync degraded

```



The UI MUST NOT claim:



> "Perfect synchronization"



unless the project has explicitly defined and justified such a claim.



The preferred terminology is:



> \*\*Synchronized\*\*



not:



> \*\*Perfectly synchronized\*\*



\---



\# 21. Phase 15 — Resynchronization UI



\## Objective



Allow the user to recover from synchronization degradation.



If the Core API provides:



```text

resynchronize()

```



Mahin may expose an appropriate control.



Possible flow:



```text

Sync degraded

&#x20;     ↓

Resynchronize

&#x20;     ↓

Calibrating

&#x20;     ↓

Scheduling

&#x20;     ↓

Synchronized

```



The UI MUST show the actual state.



It MUST NOT pretend synchronization succeeded before the Core/Sync systems confirm success.



\---



\# 22. Phase 16 — Error Handling



\## Objective



Make failures understandable instead of exposing raw technical errors.



Potential error categories:



```text

Room unavailable

Invalid join information

Connection failed

Audio unavailable

Audio invalid

Device unavailable

Playback failed

Synchronization failed

Unsupported version

Timeout

Unknown error

```



The UI MUST:



\* Present meaningful explanations.

\* Provide recovery actions where supported.

\* Preserve the actual error semantics.

\* Avoid hiding serious failures.



Mahin MUST NOT reinterpret an error into a success state.



\---



\# 23. Phase 17 — Connection and Recovery UX



\## Objective



Handle temporary failures gracefully.



Possible states:



```text

Connected

&#x20;    ↓

Connection degraded

&#x20;    ↓

Reconnecting

&#x20;    ↓

Connected

```



The UI should communicate this transition.



If the backend does not support a specific recovery mechanism, the UI MUST NOT pretend it does.



For example:



> "Reconnecting..."



is valid only if reconnection is actually occurring.



\---



\# 24. Phase 18 — Late Join UX



\## Objective



Allow participants to understand what happens when joining an active room.



Potential flow:



```text

Join

&#x20;↓

Room Active

&#x20;↓

Downloading Audio

&#x20;↓

Preparing

&#x20;↓

Synchronizing

&#x20;↓

Scheduled

&#x20;↓

Join Playback

```



Exact late-join behavior is governed by Playback/Sync contracts.



Mahin MUST NOT invent synchronization behavior.



\---



\# 25. Phase 19 — Diagnostics UI



\## Objective



Provide an optional technical view for debugging and demonstration.



Diagnostics may show:



\* Room state

\* Device count

\* Connection states

\* Audio state

\* Playback state

\* Sync state

\* Offset

\* Drift

\* Confidence

\* RTT

\* Recovery events



Diagnostics MUST clearly distinguish:



```text

Measured

Estimated

Unknown

Unavailable

```



No diagnostic metric may be generated merely for visual effect.



\---



\# 26. Phase 20 — UI Mocking



\## Objective



Allow Mahin to build UI before Faraz's backend is complete.



Mocks MAY be used.



However:



\*\*Mocks MUST conform to the real interface contracts.\*\*



Example:



```text

Real Core API

&#x20;     │

&#x20;     ├── createRoom()

&#x20;     ├── getDevices()

&#x20;     └── getSyncStatus()



Mock Core API

&#x20;     │

&#x20;     ├── createRoom()

&#x20;     ├── getDevices()

&#x20;     └── getSyncStatus()

```



The mock MUST NOT invent a different API.



All mock behavior MUST be clearly identifiable as mock behavior.



Mocks MUST eventually be replaced or supplemented with real integration tests.



\---



\# 27. Phase 21 — Real Backend Integration



\## Objective



Replace mock functionality with Faraz's actual technical implementation.



Integration MUST follow:



```text

Contract

&#x20;  ↓

Adapter

&#x20;  ↓

Real Core

&#x20;  ↓

Real Subsystems

&#x20;  ↓

Real Device

```



Mahin MUST verify that:



\* request shapes match

\* response shapes match

\* states match

\* errors match

\* lifecycle behavior matches

\* asynchronous behavior matches



If they do not match:



\*\*STOP and report the contract/integration mismatch.\*\*



Do not patch around the mismatch with undocumented assumptions.



\---



\# 28. Phase 22 — Two-Device UI Integration



\## Objective



Connect Mahin's UI to the first real two-device SoundMesh system.



Required flow:



```text

Phone A

Create Room

&#x20;   ↓

UI displays room

&#x20;   ↓

Phone B

Scan QR

&#x20;   ↓

UI displays joining

&#x20;   ↓

Participant registered

&#x20;   ↓

Both UI instances display room

&#x20;   ↓

Audio selected

&#x20;   ↓

Preparation

&#x20;   ↓

Synchronization

&#x20;   ↓

Playback

```



This is the first major UI/backend integration milestone.



\---



\# 29. Phase 23 — Real-Device Validation



\## Objective



Ensure the UI represents real system behavior.



Test on physical devices.



Verify:



\* permissions

\* QR scanning

\* joining

\* room state

\* device state

\* audio state

\* preparation state

\* playback state

\* sync state

\* errors

\* reconnect behavior

\* orientation/layout behavior

\* app lifecycle behavior



The UI MUST NOT be validated only with mocked data.



\---



\# 30. Phase 24 — Multi-Device UI



\## Objective



Support rooms containing multiple participants.



Target progression:



```text

2 devices

&#x20;↓

3 devices

&#x20;↓

5 devices

&#x20;↓

10 devices

```



The UI must remain understandable as device count increases.



Consider:



\* device lists

\* grouped statuses

\* synchronization summaries

\* readiness summaries

\* connection warnings

\* participant identity



The UI MUST NOT become dependent on a fixed device count.



\---



\# 31. Phase 25 — Accessibility



\## Objective



Make SoundMesh usable by as many users as practical.



Mahin MUST consider:



\* minimum touch target sizes

\* readable typography

\* contrast

\* semantic labels

\* screen-reader support

\* keyboard navigation where applicable

\* clear error messaging

\* non-color-only status indicators

\* reduced-motion preferences where applicable



Accessibility MUST be considered during implementation rather than added only at the end.



\---



\# 32. Phase 26 — UI Performance



\## Objective



Keep the Flutter application responsive while the technical system operates in real time.



The UI MUST NOT:



\* rebuild unnecessarily at high frequency

\* receive raw timing events unnecessarily

\* perform expensive work on the UI thread

\* continuously render low-level synchronization data



The technical architecture should expose meaningful state to Flutter.



Mahin MUST coordinate with Faraz if an API produces excessive update frequency.



\---



\# 33. Phase 27 — Competition Polish



\## Objective



Prepare the user-facing application for the final demonstration.



Focus on:



\* onboarding clarity

\* fast room creation

\* fast joining

\* clear audio selection

\* understandable preparation

\* satisfying playback controls

\* trustworthy sync feedback

\* polished error handling

\* visual consistency

\* accessibility

\* animation polish

\* responsive layouts

\* removal of placeholder content



The final UI MUST reflect the actual capabilities of SoundMesh.



\---



\# 34. Mahin AI Task Rules



Mahin's AI MUST receive narrow, contract-aware tasks.



Good:



```text

Implement the Room screen.



Consume room state through the Core API.

Use DOCS/ui-ux.md for visual requirements.

Do not modify Room API.

Use mock data only if the Core implementation is unavailable.

```



Bad:



```text

Build the entire SoundMesh frontend and make whatever backend calls you need.

```



Tasks MUST specify:



\* feature

\* applicable contract

\* files/scope

\* expected states

\* expected errors

\* tests

\* dependencies

\* out-of-scope areas



\---



\# 35. Mahin AI Must Not Invent Backend APIs



The AI MUST NOT decide:



> "The backend probably has a `getRoomDevices()` function."



It MUST inspect the documented contract.



If the required function does not exist:



```text

STOP

↓

Identify missing capability

↓

Propose contract change

↓

Coordinate with Faraz

```



No invented APIs.



\---



\# 36. Mahin AI Must Not Implement Technical Internals



Mahin's AI MUST NOT independently implement:



\* synchronization algorithms

\* clock offset calculations

\* drift estimation

\* drift correction

\* network protocols

\* audio transfer

\* native audio scheduling

\* native timing systems

\* room membership internals



unless explicitly assigned a coordinated task.



The UI consumes these systems.



It does not redefine them.



\---



\# 37. Contract Change Procedure



If Mahin discovers that the UI requires information not available through an existing contract:



Mahin MUST create a contract change proposal containing:



```text

Current contract:

<existing behavior>



Requested change:

<proposed behavior>



Reason:

<why UI requires it>



Affected systems:

<Core / Room / Device / Audio / Playback / Sync>



Affected UI:

<screens/components>



Compatibility impact:

<impact>



Testing required:

<tests>

```



The change MUST NOT be silently implemented.



\---



\# 38. Mahin AI Stop Conditions



Mahin's AI MUST STOP and report a blocker when:



1\. A required API is undefined.

2\. Two contracts conflict.

3\. UI behavior requires undocumented backend behavior.

4\. A backend response differs from the documented contract.

5\. A state has ambiguous meaning.

6\. An error has ambiguous semantics.

7\. The UI needs a new backend capability.

8\. The AI would need to modify Faraz-owned technical systems.

9\. A synchronization value is unavailable but the UI is being asked to display it.

10\. A mock requires behavior not defined by the contract.

11\. The AI is tempted to infer backend behavior.

12\. A platform-specific technical issue affects UI correctness.

13\. A proposed workaround would bypass a contract.

14\. Existing integration tests fail.

15\. The AI cannot determine which source of truth is authoritative.



The AI MUST NOT resolve these situations by guessing.



\---



\# 39. UI Truthfulness Rule



The UI is a representation of the real SoundMesh system.



Therefore:



```text

Backend State

&#x20;     ↓

Contract

&#x20;     ↓

UI State

&#x20;     ↓

User

```



NOT:



```text

Desired UI

&#x20;     ↓

Fake State

&#x20;     ↓

User

```



Examples:



If audio is still downloading:



```text

Preparing audio...

```



If synchronization is uncertain:



```text

Calibrating...

```



If a device disconnected:



```text

Device disconnected

```



Do not display:



```text

Ready

Synchronized

Connected

```



unless the underlying system actually reports those states.



\---



\# 40. UI/Backend Ownership Boundary



The boundary between Mahin and Faraz is:



```text

&#x20;                FARAZ

&#x20;                  │

&#x20;           Technical Systems

&#x20;                  │

&#x20;            Core API

&#x20;                  │

═══════════════════╪═══════════════════

&#x20;            CONTRACT BOUNDARY

═══════════════════╪═══════════════════

&#x20;                  │

&#x20;            Flutter Adapter

&#x20;                  │

&#x20;                 MAHIN

&#x20;                  │

&#x20;            UI / UX / State

&#x20;                  │

&#x20;                USER

```



The contract boundary is intentional.



Neither side should casually cross it.



\---



\# 41. Integration With Faraz



When Faraz completes a backend feature, Mahin should consume it through its documented contract.



When Mahin discovers a UI requirement, he should communicate it as a contract requirement rather than modifying backend code himself.



Example:



```text

Mahin:

"I need to show whether each device is ready."



&#x20;       ↓



Check Device API



&#x20;       ↓



If supported:

Consume readiness state.



If not supported:

Submit contract change.



&#x20;       ↓



Faraz implements.



&#x20;       ↓



Mahin integrates.



&#x20;       ↓



Integration test.

```



\---



\# 42. Integration Milestones



\## M1 — UI Foundation



Flutter architecture and design system complete.



\## M2 — Navigation



Core application flow exists.



\## M3 — Mock Core



UI can operate against contract-compliant mocks.



\## M4 — Create/Join UI



Room creation and QR joining flows complete.



\## M5 — Room UI



Participants and room state displayed.



\## M6 — Audio UI



Audio selection and preparation represented.



\## M7 — Playback UI



Playback controls connected to the Playback contract.



\## M8 — Sync UI



Synchronization state accurately represented.



\## M9 — Real Backend



UI operates against Faraz's actual implementation.



\## M10 — Two-Device Integration



Complete UI flow works on two physical phones.



\## M11 — Multi-Device UI



3–5+ devices represented correctly.



\## M12 — Competition Ready



Polished, accessible, truthful, stable application.



\---



\# 43. Definition of Done for Mahin



A UI feature is NOT DONE merely because:



\* It looks good.

\* It works with mock data.

\* The screen renders.

\* Buttons animate.

\* The AI reports success.



A feature is DONE when applicable:



```text

UI implementation

&#x20;     +

Contract compliance

&#x20;     +

Correct state handling

&#x20;     +

Error handling

&#x20;     +

UI tests

&#x20;     +

Real API integration

&#x20;     +

Real-device validation

```



\---



\# 44. Final Responsibility



Mahin's responsibility is to turn the SoundMesh technical system into a simple, understandable, and polished user experience.



The user should not need to understand:



\* clock offsets

\* network timing

\* drift rates

\* calibration algorithms

\* native audio engines

\* packet protocols



The user should be able to understand:



```text

Create

&#x20;  ↓

Join

&#x20;  ↓

Choose

&#x20;  ↓

Prepare

&#x20;  ↓

Play

```



while SoundMesh handles the complexity underneath.



\---



\# 45. Final Principle



Mahin does not build a separate version of SoundMesh.



Mahin builds the \*\*user-facing layer of the same SoundMesh system\*\*.



The UI MUST:



\* consume shared contracts

\* represent real state

\* respect architecture

\* avoid invented APIs

\* avoid fabricated metrics

\* handle errors honestly

\* remain accessible

\* remain performant

\* integrate with Faraz's systems

\* validate on real devices



The final standard is not:



> "The UI looks finished."



The final standard is:



> \*\*"A real user can create, join, prepare, play, and understand the state of a real SoundMesh session through a polished UI connected to the real technical system."\*\*



