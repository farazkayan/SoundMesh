\# SoundMesh Room API Contract



\## 1. Purpose



The Room API defines the authoritative contract for creating, joining, managing, and leaving a SoundMesh room.



A SoundMesh room represents a local group of devices that cooperate to produce synchronized audio playback.



The Room API owns the logical concept of:



\* room identity

\* room lifecycle

\* host role

\* participant membership

\* join state

\* room-level state

\* room membership changes



The Room API does NOT own:



\* network transport implementation

\* audio decoding

\* audio playback

\* clock synchronization algorithms

\* UI rendering

\* QR rendering

\* native audio implementation



Those responsibilities belong to their respective subsystems.



\---



\# 2. Core Principle



> \*\*The Room API defines what a room is, not how the network creates it.\*\*



A consumer should be able to create or join a room without knowing:



\* socket implementation

\* Wi-Fi implementation

\* TCP/UDP implementation

\* platform networking APIs

\* QR encoding internals

\* native discovery mechanisms



The Room API provides a stable logical boundary over those implementations.



\---



\# 3. Contract Status



Status:



```text

EXPERIMENTAL

```



The logical room model is established, but some exact data structures and implementation details remain unresolved.



Any item explicitly marked:



```text

UNDECIDED

```



MUST NOT be silently decided by an AI agent.



\---



\# 4. Ownership



```text

Owner:

Faraz



Primary Consumers:

\- Core API

\- UI

\- Device API

\- Networking implementation

\- Integration tests

```



The owner is responsible for maintaining the contract.



Consumers may propose changes.



Consumers MUST NOT silently modify the contract.



\---



\# 5. Room Mental Model



A room consists of:



```text

Room

├── Room identity

├── Host

├── Participants

├── Join information

├── Room state

└── Membership state

```



Conceptually:



```text

&#x20;                 SOUND MESH ROOM

&#x20;                       │

&#x20;               ┌───────┴───────┐

&#x20;               │               │

&#x20;             HOST         PARTICIPANTS

&#x20;               │          ┌────┼────┐

&#x20;               │          ▼    ▼    ▼

&#x20;               │         P1   P2   P3

&#x20;               │

&#x20;               └──── coordinates

&#x20;                  room lifecycle

```



A room may contain multiple participant devices.



The exact maximum supported room size is:



```text

UNDECIDED

```



The initial engineering target is multiple real devices, with early validation focused on:



```text

2 devices

→ 3 devices

→ 5 devices

→ larger groups

```



Scaling requirements are defined further by the networking and roadmap documentation.



\---



\# 6. Room Identity



Every room MUST have a unique logical room identifier.



Conceptual model:



```text

roomId

```



Requirements:



\* MUST uniquely identify the room within the relevant system/session.

\* MUST NOT depend on the device's IP address.

\* MUST NOT be treated as a permanent user identity.

\* MUST NOT expose unnecessary personal information.

\* MUST remain stable for the lifetime of the room session.



Exact format:



```text

UNDECIDED

```



Possible implementation formats such as UUIDs MUST NOT be treated as final until explicitly decided.



\---



\# 7. Participant Identity



Every participating device MUST have a logical participant identifier.



Conceptual model:



```text

participantId

```



Requirements:



\* identifies a participant within the room

\* MUST be distinct from the device's IP address

\* MUST be distinct from a network socket

\* MUST be distinct from a permanent user account

\* MUST remain stable for the relevant room session



Exact generation and persistence behavior:



```text

UNDECIDED

```



\---



\# 8. Host



The host is the device that initially creates the room.



Conceptually:



```text

Host

&#x20;├── creates room

&#x20;├── coordinates room membership

&#x20;├── provides room bootstrap information

&#x20;└── participates in synchronized playback

```



The host is also a playback participant unless explicitly excluded by a future architecture decision.



The host MUST NOT be assumed to be a permanently trusted server.



The host is a role within a room session.



\---



\# 9. Participant



A participant is a device that has successfully joined a room.



A participant:



\* has a participant ID

\* has room membership

\* maintains a room connection

\* prepares audio

\* synchronizes timing

\* participates in playback



A participant MUST NOT be considered fully joined merely because a network connection exists.



Successful membership requires completion of the Room API's defined join lifecycle.



\---



\# 10. Room Roles



Initial roles:



```text

HOST

PARTICIPANT

```



The exact role model:



```text

EXPERIMENTAL

```



Future roles such as:



```text

CO\_HOST

OBSERVER

MODERATOR

```



MUST NOT be introduced unless the architecture requires them.



\---



\# 11. Room State



The room state represents the logical lifecycle of the room.



Initial conceptual states:



```text

CREATING

OPEN

PREPARING

READY

PLAYING

PAUSED

STOPPING

CLOSING

CLOSED

ERROR

```



Status:



```text

EXPERIMENTAL

```



The exact final room state machine MUST be defined consistently with:



\* Core API

\* Playback API

\* Sync API

\* Networking specification



Agents MUST NOT introduce new states without considering the complete state machine.



\---



\# 12. Room State Semantics



\## CREATING



The host is establishing a new room.



The room is not yet available for normal participant joining.



\---



\## OPEN



The room exists and can accept participants.



The host may wait for additional devices.



\---



\## PREPARING



The room is preparing a synchronized playback session.



This may involve:



\* audio distribution

\* audio verification

\* device readiness

\* synchronization calibration

\* playback preparation



\---



\## READY



The room has completed the required preparation for playback.



All required readiness conditions MUST be satisfied according to the Playback and Sync contracts.



\---



\## PLAYING



The room is actively participating in coordinated playback.



\---



\## PAUSED



Playback is paused while room membership remains active.



\---



\## STOPPING



The room is transitioning out of active playback.



\---



\## CLOSING



The room is being terminated.



\---



\## CLOSED



The room is no longer active.



Participants MUST NOT continue normal room operations after the room reaches CLOSED.



\---



\## ERROR



The room has encountered a condition requiring recovery or termination.



Exact recovery behavior:



```text

UNDECIDED

```



\---



\# 13. Room State Transition Model



Conceptually:



```text

CREATING

&#x20;   │

&#x20;   ▼

&#x20;  OPEN

&#x20;   │

&#x20;   ├───────────────┐

&#x20;   │               │

&#x20;   ▼               │

PREPARING           │

&#x20;   │               │

&#x20;   ▼               │

&#x20; READY             │

&#x20;   │               │

&#x20;   ▼               │

&#x20;PLAYING            │

&#x20;   │               │

&#x20;   ├──────┐        │

&#x20;   ▼      ▼        │

&#x20;PAUSED  STOPPING   │

&#x20;   │      │        │

&#x20;   └──► READY      │

&#x20;          │        │

&#x20;          └────────┘

&#x20;               │

&#x20;               ▼

&#x20;            CLOSING

&#x20;               │

&#x20;               ▼

&#x20;             CLOSED

```



This is a conceptual model.



The final transition guards and exact allowed transitions are:



```text

UNDECIDED

```



\---



\# 14. Room Creation



\## Operation



```text

createRoom()

```



\## Purpose



Creates a new room and makes the current device its host.



\---



\## Input



Conceptual request:



```text

CreateRoomRequest



displayName:

&#x20;   optional

```



Exact fields:



```text

UNDECIDED

```



\---



\## Output



Conceptual result:



```text

CreateRoomResult



roomId

joinCode

hostStatus

roomState

```



Exact field types:



```text

UNDECIDED

```



\---



\## Successful Creation Requirements



A successful room creation MUST establish:



1\. a valid room ID

2\. a host participant

3\. a room lifecycle state

4\. participant membership for the host

5\. join information

6\. the necessary networking bootstrap process



The exact ordering between these operations is implementation-dependent unless otherwise specified.



\---



\# 15. Join Code



A room MAY expose a human-friendly join code.



Example:



```text

482731

```



The exact format is:



```text

UNDECIDED

```



A join code:



\* MUST NOT be treated as permanent identity

\* SHOULD have limited lifetime

\* SHOULD be scoped to the relevant room session

\* MUST NOT contain sensitive information

\* SHOULD be difficult enough to guess within the practical threat model



The networking specification defines additional join security requirements.



\---



\# 16. QR Joining



SoundMesh is designed around QR-first joining.



Conceptually:



```text

Host

&#x20; │

&#x20; │ generates join information

&#x20; ▼

QR code

&#x20; │

&#x20; │ scan

&#x20; ▼

Participant

&#x20; │

&#x20; ▼

joinRoom()

```



The QR code is a transport mechanism for join information.



The Room API SHOULD expose the logical join information required by the UI without requiring the UI to understand networking internals.



\---



\# 17. QR Payload



The current conceptual payload is:



```text

soundmesh://join?room=<room-id>\&host=<bootstrap-address>\&port=<bootstrap-port>\&version=<protocol-version>\&token=<short-lived-join-token>

```



This format originates from the networking architecture.



The exact final encoding, fields, escaping rules, and security behavior are governed by:



`DOCS/networking.md`



The Room API MUST NOT independently redefine the networking payload.



\---



\# 18. Join Lifecycle



A participant joining a room conceptually follows:



```text

Join Request

&#x20;    │

&#x20;    ▼

Validate join information

&#x20;    │

&#x20;    ▼

Establish network connection

&#x20;    │

&#x20;    ▼

HELLO / WELCOME handshake

&#x20;    │

&#x20;    ▼

Validate room/session

&#x20;    │

&#x20;    ▼

Register participant

&#x20;    │

&#x20;    ▼

Synchronize room state

&#x20;    │

&#x20;    ▼

JOINED

```



The detailed networking handshake is defined by:



`DOCS/networking.md`



The Room API owns the logical membership result.



\---



\# 19. joinRoom()



\## Purpose



Joins an existing room.



\### Input



```text

JoinRoomRequest

```



Conceptual fields may include:



```text

roomId

joinCode

bootstrap information

join token

protocol version

```



Exact field structure:



```text

UNDECIDED

```



Networking-specific fields SHOULD remain behind the networking boundary where practical.



\---



\## Output



```text

JoinRoomResult

```



Conceptual fields:



```text

roomId

participantId

role

roomState

connectionState

```



Exact structure:



```text

UNDECIDED

```



\---



\# 20. Successful Join



A participant is considered successfully joined only after:



\* room identity is validated

\* participant identity is established

\* required handshake succeeds

\* membership is registered

\* required room state is synchronized



A network socket alone does NOT constitute successful room membership.



\---



\# 21. Join Failure



Join failure MUST return a structured error.



Possible categories:



```text

ROOM\_NOT\_FOUND

INVALID\_JOIN\_CODE

JOIN\_TOKEN\_INVALID

PROTOCOL\_VERSION\_UNSUPPORTED

ROOM\_FULL

HOST\_UNAVAILABLE

CONNECTION\_FAILED

JOIN\_TIMEOUT

MEMBERSHIP\_REJECTED

INTERNAL\_ERROR

```



This list is preliminary.



Final error taxonomy:



```text

UNDECIDED

```



\---



\# 22. leaveRoom()



\## Purpose



Terminates the current participant's membership in the room.



\### Input



None.



\### Output



Conceptual:



```text

LeaveRoomResult

```



Exact structure:



```text

UNDECIDED

```



\---



\# 23. Leaving Requirements



When a participant leaves:



1\. its room membership becomes inactive

2\. relevant network resources are released

3\. room-specific synchronization state is released

4\. room-specific playback state is handled according to the Playback contract

5\. the participant no longer appears as active



The exact cleanup ordering:



```text

UNDECIDED

```



\---



\# 24. Host Leaving



Host departure is a special case.



The current architecture MUST account for host failure or departure.



Possible strategies include:



```text

controlled room shutdown

host migration

temporary recovery

```



Final host-departure strategy:



```text

UNDECIDED

```



An AI agent MUST NOT invent host migration behavior.



Until explicitly decided, implementations MUST NOT assume automatic host migration exists.



\---



\# 25. Room Membership



The Room API SHOULD expose the current membership list.



Conceptual model:



```text

RoomMembers



host

participants\[]

```



Each participant SHOULD expose:



```text

participantId

role

connectionState

membershipState

```



Device-specific details belong to the Device API.



\---



\# 26. Membership States



Possible conceptual membership states:



```text

JOINING

ACTIVE

LEAVING

LEFT

REJECTED

```



Final state model:



```text

UNDECIDED

```



Membership state and network connection state MUST remain conceptually distinct.



For example:



```text

membership = ACTIVE

connection = DEGRADED

```



may be valid.



\---



\# 27. Connection vs Membership



These concepts MUST NOT be treated as identical.



```text

Membership:

"Is this device logically part of the room?"



Connection:

"Can this device currently communicate with the room?"

```



A participant may remain logically known to the room while temporarily disconnected, depending on the recovery policy.



The exact behavior:



```text

UNDECIDED

```



\---



\# 28. getRoomState()



\## Purpose



Returns the current logical room state.



\### Output



```text

RoomState

```



Conceptual information:



```text

roomId

state

host

participants

```



Exact schema:



```text

UNDECIDED

```



\---



\# 29. getMembers()



\## Purpose



Returns active room members.



\### Output



```text

Participant\[]

```



The Participant model is defined by the Device API where applicable.



The Room API SHOULD avoid duplicating device-specific fields.



\---



\# 30. Room Events



The Room API may expose room-level events.



Potential events:



```text

roomCreated

roomOpened

roomClosed



participantJoining

participantJoined

participantLeaving

participantLeft



hostChanged



roomStateChanged



joinFailed

participantConnectionChanged

```



Final event mechanism:



```text

UNDECIDED

```



Events MUST represent meaningful state changes.



They MUST NOT be emitted merely because an internal implementation detail changed.



\---



\# 31. Room Events and UI



The UI may use room events to update:



```text

participant list

room status

join status

host status

connection indicators

```



The UI MUST NOT infer room membership from:



\* animations

\* local timers

\* network socket assumptions

\* QR scan completion alone



The Room API is authoritative for logical room membership.



\---



\# 32. Room Capacity



The final maximum room capacity is:



```text

UNDECIDED

```



Capacity MUST eventually be established through:



\* networking limits

\* synchronization performance

\* audio performance

\* device diversity

\* physical testing



The project MUST NOT claim a maximum number of devices without evidence.



\---



\# 33. Room Closure



A room may be closed because:



\* host intentionally ends it

\* unrecoverable host failure occurs

\* fatal room error occurs

\* session expires

\* application terminates



The final closure policy:



```text

UNDECIDED

```



When a room closes, participants MUST receive an appropriate room-level state/error where communication remains possible.



\---



\# 34. Room Expiration



Rooms are expected to represent temporary local sessions rather than permanent cloud accounts.



A room SHOULD have a bounded session lifetime.



Exact expiration rules:



```text

UNDECIDED

```



No permanent room identity should be assumed.



\---



\# 35. Networking Boundary



The Room API depends on networking but MUST NOT implement networking directly.



Conceptually:



```text

Room API

&#x20;  │

&#x20;  ▼

Networking abstraction

&#x20;  │

&#x20;  ├── Android implementation

&#x20;  └── iOS implementation

```



The Room API should request operations such as:



```text

create local room endpoint

accept participant

connect to host

send room control messages

receive room control messages

close room connection

```



without depending on raw platform APIs.



Exact networking interface boundaries are defined by:



`DOCS/networking.md`



\---



\# 36. Room and Audio



The Room API establishes the group.



It does NOT own audio preparation.



Conceptually:



```text

Room

&#x20;↓

Participants established

&#x20;↓

Audio API

&#x20;↓

Playback API

&#x20;↓

Sync API

```



Creating or joining a room MUST NOT automatically select or play audio.



\---



\# 37. Room and Synchronization



The Room API provides the group membership that synchronization operates over.



The Sync subsystem determines synchronization quality.



The Room API MUST NOT calculate:



\* clock offsets

\* drift rates

\* latency

\* synchronization confidence

\* playback correction



Those belong to the Sync API.



\---



\# 38. Room and Playback



Room membership determines which devices are eligible to participate in coordinated playback.



Playback determines what those devices actually do.



Therefore:



```text

Room:

"Who is participating?"



Playback:

"What are they playing?"



Sync:

"When should they play it?"

```



These responsibilities MUST remain distinct.



\---



\# 39. Concurrency



Room operations may conflict.



Examples:



```text

createRoom()

joinRoom()



joinRoom()

leaveRoom()



leaveRoom()

preparePlayback()

```



The implementation MUST prevent invalid concurrent operations from corrupting room state.



Final concurrency semantics:



```text

UNDECIDED

```



Until finalized, agents MUST NOT assume that every operation is safely concurrent.



\---



\# 40. Idempotency



The final idempotency behavior of Room operations is:



```text

UNDECIDED

```



Operations such as:



```text

leaveRoom()

```



may eventually be defined as idempotent.



Operations such as:



```text

createRoom()

joinRoom()

```



may have different semantics.



Agents MUST NOT invent idempotency guarantees.



\---



\# 41. Reconnection



Participants may temporarily lose network connectivity.



The Room API MUST eventually support a defined relationship between:



```text

temporary network loss

&#x20;       ↓

participant membership

&#x20;       ↓

reconnection

&#x20;       ↓

room state recovery

```



Final reconnection policy:



```text

UNDECIDED

```



The networking specification contains related requirements.



\---



\# 42. Security



Room joining MUST follow the security model defined by `DOCS/networking.md`.



Important principles:



\* room IDs are not secrets

\* IP addresses are not identity

\* join tokens should be temporary

\* join credentials should have limited scope

\* permanent credentials MUST NOT be embedded in QR codes

\* sensitive information MUST NOT be unnecessarily displayed

\* room membership MUST be validated by the host/session authority



The exact authentication/authorization model:



```text

UNDECIDED

```



\---



\# 43. Privacy



SoundMesh is local-first.



Room information SHOULD remain local to the room session unless the architecture explicitly introduces an external service.



The Room API MUST NOT require a cloud account for basic local room functionality.



No permanent personal profile is required for the MVP room model.



\---



\# 44. Error Contract



Room errors SHOULD be structured.



Conceptual model:



```text

RoomError



code

message

recoverability

operation

```



Possible codes:



```text

ROOM\_NOT\_FOUND

ROOM\_CLOSED

INVALID\_JOIN\_CODE

INVALID\_JOIN\_TOKEN

ROOM\_FULL

HOST\_UNAVAILABLE

CONNECTION\_FAILED

JOIN\_TIMEOUT

MEMBERSHIP\_REJECTED

ALREADY\_IN\_ROOM

NOT\_IN\_ROOM

HOST\_REQUIRED

PROTOCOL\_VERSION\_UNSUPPORTED

INTERNAL\_ERROR

```



Final taxonomy:



```text

UNDECIDED

```



\---



\# 45. Error Propagation



Platform/network errors SHOULD be translated into Room-level errors.



Example:



```text

Socket failure

&#x20;     ↓

Networking layer

&#x20;     ↓

Room connection failure

&#x20;     ↓

Room API error

&#x20;     ↓

Core API error

&#x20;     ↓

UI

```



The UI SHOULD NOT need to understand:



```text

SocketException

NSError

Network framework errors

Android networking exceptions

```



for normal room operations.



\---



\# 46. Data Requirements



Public Room API data structures MUST eventually define:



\* exact field names

\* types

\* required/optional status

\* nullability

\* allowed values

\* validation

\* lifecycle meaning



No public field should have ambiguous semantics.



For example:



```text

joinCode

```



must eventually specify:



\* type

\* format

\* lifetime

\* uniqueness

\* validation

\* whether it may be reused



\---



\# 47. Platform Independence



The Room API MUST remain platform-independent at the logical level.



Android and iOS may implement networking differently.



For example:



```text

Android

&#x20;   ↓

native networking

&#x20;   ↓

Room implementation



iOS

&#x20;   ↓

native networking

&#x20;   ↓

Room implementation

```



Both MUST satisfy the same logical Room API contract.



Platform-specific differences MUST be documented when externally observable.



\---



\# 48. Testing Requirements



The Room API MUST eventually have automated tests covering:



\## Creation



```text

createRoom()

```



Verify:



\* room exists

\* room ID exists

\* host is registered

\* join information exists

\* initial room state is correct



\---



\## Joining



```text

joinRoom()

```



Verify:



\* valid join succeeds

\* participant is registered

\* room state is received

\* invalid join information fails correctly

\* unsupported protocol versions fail correctly



\---



\## Leaving



```text

leaveRoom()

```



Verify:



\* participant membership ends

\* room state updates

\* resources are released

\* participant is no longer active



\---



\## Membership



Verify:



```text

participantJoined

participantLeft

connection changes

room state changes

```



\---



\## Failure



Test:



\* host unavailable

\* invalid room

\* invalid join code

\* timeout

\* duplicate join

\* network failure

\* room closed

\* room full

\* protocol mismatch



Exact test matrix is defined further in:



`DOCS/contract-testing.md`



\---



\# 49. Real-Device Testing



Room behavior MUST eventually be tested on real devices.



At minimum:



```text

Device A

&#x20;   ↓

creates room

&#x20;   ↓

Device B

&#x20;   ↓

joins room

```



Then:



```text

Device A

Device B

Device C

...

```



The project MUST test:



\* different devices

\* different network conditions

\* hotspot mode

\* local Wi-Fi

\* disconnect/reconnect

\* late joining

\* host departure

\* room closure



Simulated networking is not sufficient evidence for final real-world behavior.



\---



\# 50. Integration Requirements



The Room API MUST integrate with:



```text

Core API

Device API

Networking implementation

Audio API

Playback API

Sync API

```



Integration tests MUST verify that room membership correctly feeds the other subsystems.



For example:



```text

joinRoom()

&#x20;   ↓

Device registered

&#x20;   ↓

Audio preparation knows participant exists

&#x20;   ↓

Sync knows participant exists

&#x20;   ↓

Playback knows participant is eligible

```



No subsystem should independently maintain a conflicting definition of room membership.



\---



\# 51. AI Implementation Rules



An AI agent implementing the Room API MUST:



1\. Read `DOCS/interfaces/README.md`.

2\. Read this document completely.

3\. Read `DOCS/blueprint.md`.

4\. Read `DOCS/architecture.md`.

5\. Read `DOCS/networking.md`.

6\. Read `DOCS/interfaces/device-api.md` when working with participant/device data.

7\. Read `DOCS/AI/rules.md`.

8\. Read `DOCS/AI/task-protocol.md`.

9\. Inspect the repository.

10\. Check Git state.

11\. Identify unresolved decisions.

12\. Preserve existing contracts.

13\. Add contract tests.

14\. Report all assumptions.

15\. Stop when required behavior is undefined.



The agent MUST NOT:



\* invent host migration

\* invent final room states

\* invent authentication semantics

\* invent permanent user identity

\* treat IP addresses as identity

\* silently change join payloads

\* bypass the networking contract

\* directly expose platform networking APIs

\* automatically start playback after joining

\* silently modify another subsystem's contract



\---



\# 52. Stop Conditions



The agent MUST STOP and report a blocker if:



```text

The networking contract conflicts with the Room API.



OR



The Device API defines incompatible participant identity.



OR



The Core API expects a different room lifecycle.



OR



A required room state is undefined.



OR



Host failure behavior is required but undefined.



OR



Join authentication behavior is required but undefined.



OR



A consumer requires room information that this contract does not define.



OR



Implementation requires changing another interface.



OR



Contract tests reveal incompatible assumptions.

```



Do not silently resolve these conflicts.



\---



\# 53. Current Open Questions



The following remain:



```text

UNDECIDED:



\- Exact room ID format.

\- Exact participant ID format.

\- Exact join-code format.

\- Exact join-code lifetime.

\- Final RoomState enum.

\- Final membership state machine.

\- Final connection/membership recovery relationship.

\- Maximum supported room size.

\- Host departure behavior.

\- Host migration support.

\- Room expiration rules.

\- Final authentication model.

\- Final authorization model.

\- Exact Room API request/response types.

\- Final event mechanism.

\- Final concurrency rules.

\- Final idempotency rules.

\- Final reconnection semantics.

```



These MUST be resolved through explicit architecture/contract decisions before dependent implementation relies on them.



\---



\# 54. Final Principle



The Room API answers one fundamental question:



> \*\*Which devices belong to this SoundMesh session?\*\*



It establishes the group that the other subsystems operate on.



```text

Room API

&#x20;   │

&#x20;   │ Who is here?

&#x20;   ▼

Device API

&#x20;   │

&#x20;   │ What can they do?

&#x20;   ▼

Audio API

&#x20;   │

&#x20;   │ What are they playing?

&#x20;   ▼

Playback API

&#x20;   │

&#x20;   │ How should playback behave?

&#x20;   ▼

Sync API

&#x20;   │

&#x20;   │ When should each device play?

&#x20;   ▼

Synchronized sound

```



The Room API MUST remain focused on room membership and lifecycle.



It should coordinate the group without becoming responsible for every other subsystem.



> \*\*A room is the group. The other APIs determine what the group does.\*\*



