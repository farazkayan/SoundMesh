\# SoundMesh Device API Contract



\*\*File:\*\* `DOCS/interfaces/device-api.md`

\*\*Status:\*\* EXPERIMENTAL

\*\*Owner:\*\* Faraz

\*\*Primary Consumers:\*\* Core API, Room API, UI/Application Layer, Sync System, Playback System, Integration Tests



\---



\# 1. Purpose



The Device API defines the authoritative interface for representing and querying devices participating in a SoundMesh session.



It establishes a stable boundary between the rest of the application and device-level information such as:



\* device identity

\* device role

\* device capabilities

\* audio output capabilities

\* connection/presence state

\* readiness state

\* synchronization status

\* device availability

\* device lifecycle

\* device-level errors



The Device API exists so that other subsystems do not need to know how device information is discovered, stored, transported, or updated.



The core principle is:



> \*\*Consumers interact with devices through the Device API, not through implementation-specific device objects, network sockets, platform APIs, or UI state.\*\*



\---



\# 2. Scope



The Device API owns the representation and lifecycle of device-level information.



It does \*\*not\*\* own:



\* room membership rules

\* network transport

\* QR-code rendering

\* network discovery

\* audio decoding

\* audio playback implementation

\* clock synchronization algorithms

\* drift correction algorithms

\* UI rendering

\* platform-specific audio APIs

\* persistent user identity

\* authentication policy



Those responsibilities belong to their respective systems.



\---



\# 3. Authority



The Device API must follow the SoundMesh authority hierarchy.



When conflicting information exists, use:



1\. Approved architectural decisions

2\. Interface contracts

3\. Core architecture specification

4\. Synchronization/networking/audio specifications

5\. Approved integration tests

6\. Existing implementation

7\. AI assumptions



AI agents must never treat an existing implementation as automatically authoritative when it conflicts with the documented contract.



\---



\# 4. Device Identity Model



Device identity must be explicitly separated from other forms of identity.



SoundMesh has several distinct concepts:



```text

Device Identity

&#x20;       │

&#x20;       ├── Participant Identity

&#x20;       │

&#x20;       ├── Network Address

&#x20;       │

&#x20;       └── Human/User Identity

```



These are not interchangeable.



\## 4.1 Device ID



A `deviceId` identifies a device within the SoundMesh system.



The exact format is:



\*\*UNDECIDED\*\*



The ID must not depend on:



\* current IP address

\* network interface address

\* temporary socket

\* UI display name

\* human-readable device name



A device may change network addresses without necessarily becoming a different device.



\---



\## 4.2 Participant ID



A participant ID represents the device's membership identity within a specific SoundMesh room.



Participant identity and device identity must not be assumed to be identical.



The relationship between them is:



\*\*UNDECIDED\*\*



The Room API owns room membership.



The Device API may expose participant information when required by consumers but must not redefine room membership semantics.



\---



\## 4.3 Network Address



Network addresses are connection information, not identity.



Examples include:



\* IPv4 address

\* IPv6 address

\* port

\* transport endpoint



The exact representation is:



\*\*UNDECIDED\*\*



Consumers must never use an IP address as the permanent device identifier.



\---



\# 5. Device Roles



The initial SoundMesh system defines two conceptual roles:



```text

HOST

PARTICIPANT

```



A device's room role is contextual.



A device may be a host in one room and a participant in another.



The Device API must therefore avoid treating `HOST` or `PARTICIPANT` as permanent device identity.



The authoritative room-level role is defined by the Room API.



\---



\# 6. Device Model



The conceptual device representation is:



```text

Device

├── identity

│   ├── deviceId

│   └── displayName

│

├── room context

│   └── participantId

│

├── capabilities

│   ├── audioOutput

│   ├── supportedFormats

│   └── platformCapabilities

│

├── connection

│   ├── state

│   └── transport information

│

├── readiness

│   └── state

│

└── synchronization

&#x20;   └── status

```



This is a conceptual model.



Exact field names, types, serialization formats, and required fields remain subject to this contract and future implementation decisions.



\---



\# 7. Device Display Name



A device may expose a human-readable display name.



Example:



```text

"Faraz's Phone"

```



The display name is for presentation only.



It must not be used as:



\* a unique identifier

\* an authentication credential

\* a membership identifier

\* a network identifier



Two devices may have identical display names.



\---



\# 8. Device Capabilities



The Device API may expose capabilities that affect whether the device can participate correctly in playback.



Potential capability categories include:



```text

Audio Output

Supported Audio Formats

Sample Rates

Channel Configuration

Platform Audio Features

Low-Latency Audio Support

Background Playback Capability

```



Exact capability fields are:



\*\*EXPERIMENTAL / UNDECIDED\*\*



Capabilities must represent actual device/platform capabilities.



AI agents must not fabricate capabilities based on assumptions about a device model.



\---



\# 9. Audio Output Capability



A device must be able to communicate whether it has a usable audio output for SoundMesh playback.



Conceptual state:



```text

AVAILABLE

UNAVAILABLE

UNKNOWN

```



Exact state model:



\*\*UNDECIDED\*\*



Examples of potentially relevant conditions:



\* speaker available

\* headphones connected

\* Bluetooth output active

\* audio route unavailable

\* platform audio session unavailable

\* another application currently controlling audio



The Device API reports the condition.



It does not decide how the Playback System handles it.



\---



\# 10. Connection State



Connection state describes the device's current communication relationship with the SoundMesh session.



Conceptual states:



```text

DISCONNECTED

CONNECTING

CONNECTED

DEGRADED

RECONNECTING

FAILED

```



These states are:



\*\*EXPERIMENTAL\*\*



Connection state must not be confused with room membership.



For example:



```text

Membership: ACTIVE

Connection: DEGRADED

```



may be valid.



A temporary network failure does not automatically mean that room membership has been terminated.



The exact reconnection and membership behavior is governed by the Room and Networking contracts.



\---



\# 11. Presence



Presence describes whether the system currently has evidence that the device is reachable or active.



Presence and connection are related but not necessarily identical.



Potential conceptual states:



```text

PRESENT

UNKNOWN

ABSENT

```



The exact model is:



\*\*UNDECIDED\*\*



The implementation must not claim that a device is present merely because an old record exists.



Presence must be based on observable system evidence.



\---



\# 12. Readiness State



A device may be connected but not ready for synchronized playback.



Conceptual states:



```text

NOT\_READY

PREPARING

READY

FAILED

```



A device should only report `READY` when all required local preparation for the current playback generation has completed.



Possible preparation requirements include:



\* audio available locally

\* audio decoded or prepared

\* playback engine initialized

\* required audio route available

\* synchronization calibration available

\* scheduled playback accepted



The exact readiness requirements are:



\*\*UNDECIDED\*\*



The Playback and Synchronization contracts may define additional conditions.



\---



\# 13. Synchronization Status



The Device API may expose the current synchronization status of a device.



It must not calculate synchronization metrics itself.



Synchronization calculations belong to the Synchronization System.



Conceptual representation:



```json

{

&#x20; "state": "SYNCHRONIZED",

&#x20; "offsetMs": 4.2,

&#x20; "driftMsPerSecond": 0.3,

&#x20; "confidence": 0.94

}

```



These fields are illustrative.



Their exact schema is:



\*\*UNDECIDED\*\*



Possible synchronization states include:



```text

UNKNOWN

CALIBRATING

SYNCHRONIZED

DEGRADED

FAILED

```



The Device API exposes synchronization information provided by the Sync System.



It must never invent values such as:



```text

offsetMs: 0

confidence: 1.0

```



simply because no measurement is available.



Unknown measurements must remain unknown.



\---



\# 14. Device Status



A consumer may need a summarized device status.



Conceptual representation:



```text

DeviceStatus

├── connectionState

├── presence

├── readiness

├── audioOutput

└── synchronization

```



The status object is intended for consumers such as:



\* Core API

\* UI

\* Diagnostics

\* Integration tests



The Device API must preserve the distinction between these states.



For example:



```text

Connected

≠

Ready

≠

Synchronized

```



A connected device may still be preparing audio.



A ready device may still have synchronization problems.



\---



\# 15. Operations



The initial Device API is conceptual and EXPERIMENTAL.



The following operations define the intended boundary.



\---



\## 15.1 `getDevice()`



Returns information about a specific device.



Conceptual input:



```text

deviceId

```



Conceptual result:



```text

Device

```



Failure conditions may include:



```text

DEVICE\_NOT\_FOUND

INVALID\_DEVICE\_ID

INTERNAL\_ERROR

```



Exact request and response types are:



\*\*UNDECIDED\*\*



\---



\## 15.2 `getDevices()`



Returns devices currently known to the relevant SoundMesh session.



Conceptual result:



```text

Device\[]

```



Room membership filtering is governed by the Room context.



The Device API must not silently invent room membership rules.



Possible result:



```text

\[

&#x20;   Device,

&#x20;   Device,

&#x20;   Device

]

```



An empty list is valid.



\---



\## 15.3 `getDeviceStatus()`



Returns the current observable status of a device.



Conceptual result:



```text

DeviceStatus

```



The result may include:



```text

connection

presence

readiness

audio output

synchronization

```



Exact fields remain:



\*\*UNDECIDED\*\*



\---



\## 15.4 `getCapabilities()`



Returns the capabilities known for a device.



Conceptual result:



```text

DeviceCapabilities

```



Capabilities must reflect actual observed or platform-reported capabilities.



\---



\## 15.5 `registerDevice()`



Registers a device with the appropriate SoundMesh subsystem.



Exact ownership and lifecycle semantics are:



\*\*UNDECIDED\*\*



Registration must not be confused with room membership.



A device may exist before joining a room.



\---



\## 15.6 `unregisterDevice()`



Removes a device from the relevant device registry or lifecycle.



Exact semantics are:



\*\*UNDECIDED\*\*



An implementation must not automatically interpret unregistering as:



```text

leaveRoom()

```



unless explicitly defined by the Room contract.



\---



\## 15.7 `updateDeviceStatus()`



Updates observable device-level state.



This operation may be internal rather than publicly exposed.



Exact visibility is:



\*\*UNDECIDED\*\*



The implementation must prevent arbitrary consumers from writing false device status.



For example, the UI must not be able to declare:



```text

synchronized = true

```



without authoritative evidence from the Sync System.



\---



\# 16. Device Events



The Device API may expose asynchronous device events.



Potential events include:



```text

DEVICE\_ADDED

DEVICE\_REMOVED

DEVICE\_UPDATED

CONNECTION\_CHANGED

READINESS\_CHANGED

AUDIO\_ROUTE\_CHANGED

SYNC\_STATUS\_CHANGED

```



Exact event architecture is:



\*\*UNDECIDED\*\*



If events are implemented, event payloads must be contract-defined.



AI agents must not invent event names or payload structures.



\---



\# 17. Device Lifecycle



The conceptual lifecycle is:



```text

UNKNOWN

&#x20;  ↓

DISCOVERED

&#x20;  ↓

REGISTERED

&#x20;  ↓

CONNECTED

&#x20;  ↓

READY

&#x20;  ↓

ACTIVE

&#x20;  ↓

DISCONNECTED / DEGRADED

&#x20;  ↓

REMOVED

```



This is a conceptual model, not yet a finalized state machine.



The exact legal transitions are:



\*\*UNDECIDED\*\*



No implementation may assume transitions not defined by the finalized contract.



\---



\# 18. Device vs Room Responsibilities



This distinction is critical.



\### Device API owns:



```text

"What is this device?"

"What can this device do?"

"What is its current device-level status?"

"Is its audio output available?"

"Is it currently ready?"

"What synchronization status is reported for it?"

```



\### Room API owns:



```text

"Is this device a member of the room?"

"Who is the host?"

"Who joined?"

"Who left?"

"What is the room state?"

```



\### Networking owns:



```text

"How do these devices communicate?"

"Which transport is being used?"

"How is the connection established?"

```



\### Sync API owns:



```text

"How synchronized is this device?"

"How is clock offset measured?"

"How is drift estimated?"

"How is resynchronization performed?"

```



\### Playback API owns:



```text

"What should play?"

"When should playback happen?"

"Is playback running?"

"How is playback scheduled?"

```



No subsystem should silently absorb another subsystem's responsibility.



\---



\# 19. Network Address Isolation



The Device API must not expose network implementation details as device identity.



For example:



```text

deviceId = "device-abc"

IP = "192.168.1.42"

```



If the device changes to:



```text

IP = "192.168.1.73"

```



it should not automatically become:



```text

deviceId = "device-xyz"

```



Network addresses are ephemeral infrastructure information.



Identity must remain conceptually separate.



\---



\# 20. State Truthfulness



All device status exposed to consumers must represent actual known state.



The following are prohibited:



```text

Fake synchronization percentages

Fake latency values

Fake connection states

Fake battery values

Fake readiness

Fake capability detection

```



If a value has not been measured or established:



```text

UNKNOWN

UNAVAILABLE

UNDECIDED

```



must be used according to the appropriate contract.



A visually impressive UI must never take priority over truthful system state.



\---



\# 21. Concurrency



Multiple subsystems may request device information simultaneously.



The exact concurrency model is:



\*\*UNDECIDED\*\*



However, implementations must avoid:



\* race conditions

\* stale state overwriting newer state

\* duplicate registration

\* contradictory status updates

\* unsafe mutation from multiple asynchronous operations



If device state changes asynchronously, state updates must have an authoritative ordering mechanism.



The exact mechanism is:



\*\*UNDECIDED\*\*



\---



\# 22. Generation Awareness



SoundMesh uses generation numbers for playback-related lifecycle changes.



Examples include:



```text

generation 1 → first playback

generation 2 → new audio

generation 3 → seek

generation 4 → recovery

```



Device status associated with playback or synchronization must not accidentally apply information from an obsolete generation to a newer generation.



Exact generation ownership and propagation are defined by the Playback, Sync, and Networking contracts.



\---



\# 23. Error Model



Device errors should be structured rather than represented only by human-readable strings.



Conceptual examples:



```text

DEVICE\_NOT\_FOUND

INVALID\_DEVICE\_ID

DEVICE\_UNAVAILABLE

DEVICE\_NOT\_READY

AUDIO\_OUTPUT\_UNAVAILABLE

CAPABILITY\_UNAVAILABLE

DEVICE\_REGISTRATION\_FAILED

DEVICE\_UNREGISTRATION\_FAILED

STATUS\_UNAVAILABLE

INTERNAL\_ERROR

```



These are candidate error codes.



Their final names and semantics are:



\*\*UNDECIDED\*\*



AI agents must not silently create competing error taxonomies.



\---



\# 24. Platform Independence



The Device API must remain platform-independent.



Flutter/application code should not need to know whether device information came from:



```text

Android

iOS

Wi-Fi

Network Framework

Android networking APIs

native audio APIs

platform-specific device services

```



Platform-specific implementations belong behind the appropriate abstraction boundary.



\---



\# 25. Native Integration



Timing-critical information may originate from native platform implementations.



Examples:



```text

native clock

audio route

audio capability

actual playback position

native connection state

```



The Device API may expose normalized information to higher-level consumers.



The normalization layer must not destroy information required for synchronization or diagnostics.



Exact platform bridge implementation is governed by:



\* `architecture.md`

\* `networking.md`

\* `audio.md`

\* `synchronization.md`



\---



\# 26. UI Consumption



The UI may consume Device API information to display:



```text

Phone name

Connection status

Ready/not ready

Audio output availability

Synchronization status

Device list

Diagnostics

```



The UI must not directly:



\* mutate synchronization state

\* change network state

\* modify native audio state

\* fabricate device capabilities

\* assign device identity

\* declare a device synchronized



The UI is a consumer of authoritative device state.



\---



\# 27. Contract Testing



The Device API must have contract tests covering at minimum:



\### Identity



```text

deviceId is present

deviceId is stable within its defined scope

deviceId is not derived from display name

deviceId is not equivalent to IP address

```



\### Capabilities



```text

reported capabilities are structurally valid

unknown capabilities remain unknown

```



\### Connection



```text

connection states are valid

connection changes are observable when required

```



\### Readiness



```text

device cannot report READY without required preparation

```



\### Synchronization



```text

sync state comes from authoritative synchronization logic

missing measurements are not fabricated

```



\### Lifecycle



```text

registration behaves according to contract

unregistration behaves according to contract

invalid lifecycle transitions are rejected

```



\### Isolation



```text

room membership is not silently modified by Device API operations

network address is not used as permanent identity

```



\---



\# 28. Integration Testing



Unit tests are insufficient.



Device behavior must eventually be tested using real devices.



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



Testing should validate:



\* device registration

\* device discovery/visibility

\* connection changes

\* readiness

\* audio availability

\* synchronization status propagation

\* disconnect/reconnect behavior

\* stale state handling

\* real network changes

\* real playback preparation



The final authority for timing and real-world device behavior is physical validation.



\---



\# 29. AI Implementation Rules



AI agents implementing Device API functionality MUST:



1\. Read this contract before modifying Device API code.

2\. Read relevant architecture documentation.

3\. Read the Room, Networking, Audio, Playback, and Sync contracts when their boundaries are involved.

4\. Preserve device identity semantics.

5\. Never use IP address as permanent identity.

6\. Never invent device capabilities.

7\. Never fabricate synchronization measurements.

8\. Never silently redefine membership.

9\. Never silently redefine connection semantics.

10\. Preserve structured error behavior.

11\. Add or update contract tests when behavior changes.

12\. Document any newly introduced behavior.

13\. Stop when the contract is insufficient.



\---



\# 30. AI Stop Conditions



The agent MUST STOP and report a blocker when:



1\. Device identity format is required but undefined.

2\. Participant identity mapping is required but undefined.

3\. Capability fields are required but undefined.

4\. Connection state semantics conflict between documents.

5\. Device lifecycle behavior is undefined.

6\. A requested change requires modifying Room membership semantics.

7\. A requested change requires modifying network transport behavior.

8\. A requested change requires modifying synchronization algorithms.

9\. A device status cannot be determined truthfully.

10\. Multiple valid interpretations of a device state exist.

11\. Existing implementation contradicts this contract.

12\. Another subsystem expects an incompatible Device API.

13\. A new public operation is required but not specified.

14\. The agent would need to invent an error code.

15\. The agent would need to fabricate a capability or metric.



The agent must not resolve these conditions by guessing.



\---



\# 31. Contract Change Procedure



A Device API change must follow the contract-change process.



Before implementation, document:



```text

Current Contract:

<existing behavior>



Proposed Change:

<new behavior>



Reason:

<why it is required>



Affected Systems:

<systems that depend on it>



Compatibility Impact:

<breaking or non-breaking>



Required Updates:

<code/tests/docs>



Decision:

UNDECIDED

```



The decision must be approved before implementation when the change affects another subsystem.



\---



\# 32. Dependency Map



```text

&#x20;                   ┌──────────────┐

&#x20;                   │   Core API   │

&#x20;                   └──────┬───────┘

&#x20;                          │

&#x20;                          ▼

&#x20;                   ┌──────────────┐

&#x20;                   │  Device API  │

&#x20;                   └──────┬───────┘

&#x20;                          │

&#x20;         ┌────────────────┼────────────────┐

&#x20;         ▼                ▼                ▼

&#x20;     Room API         Sync API        Playback API

&#x20;         │                │                │

&#x20;         └────────────────┼────────────────┘

&#x20;                          ▼

&#x20;                    Integration

&#x20;                      Testing

```



The Device API is an information and state boundary.



It does not become the central owner of every subsystem merely because other systems need device information.



\---



\# 33. Relationship to Other Contracts



This contract must remain consistent with:



```text

DOCS/interfaces/core-api.md

DOCS/interfaces/room-api.md

DOCS/interfaces/audio-api.md

DOCS/interfaces/playback-api.md

DOCS/interfaces/sync-api.md

DOCS/interfaces/README.md

DOCS/networking.md

DOCS/audio.md

DOCS/synchronization.md

DOCS/architecture.md

DOCS/testing.md

DOCS/contract-testing.md

DOCS/AI/rules.md

DOCS/AI/task-protocol.md

DOCS/AI/integration-protocol.md

```



If these documents conflict, the authority hierarchy applies.



\---



\# 34. Current Open Questions



The following remain intentionally unresolved:



```text

1\. Exact deviceId format

2\. Device ID persistence scope

3\. Participant ID ↔ device ID relationship

4\. Exact Device model schema

5\. Capability schema

6\. Audio output state model

7\. Connection state machine

8\. Presence semantics

9\. Readiness requirements

10\. Event architecture

11\. Device registry ownership

12\. Registration lifecycle

13\. Unregistration lifecycle

14\. Device discovery ownership

15\. Reconnection semantics

16\. Generation propagation

17\. Exact error taxonomy

18\. Device state versioning

19\. Serialization format

20\. Flutter/native representation

```



These questions are intentionally visible.



They must not be silently converted into implementation decisions.



\---



\# 35. Definition of Done



Device API implementation is considered complete only when:



```text

□ Device identity semantics are implemented correctly

□ Device and network identity are separated

□ Device capabilities are represented truthfully

□ Connection state follows the contract

□ Readiness follows the contract

□ Synchronization status is sourced from Sync

□ Room membership is not silently redefined

□ Structured errors are implemented

□ Contract tests exist

□ Integration tests exist where applicable

□ Real-device behavior has been validated

□ Documentation matches implementation

□ No undocumented public behavior exists

□ No fake metrics or capabilities exist

□ Git diff has been reviewed

```



\---



\# 36. Final Principle



The Device API answers:



> \*\*“What is this device, what can it currently do, and what is its authoritative device-level state?”\*\*



It does not answer:



> “How does the network work?”



> “Does this device belong to the room?”



> “How do we synchronize its clock?”



> “How do we play audio?”



Those responsibilities remain with their respective contracts.



\*\*A device is an entity.

A room defines membership.

The network defines communication.

Sync defines timing.

Playback defines execution.\*\*



No subsystem may silently collapse those boundaries.



