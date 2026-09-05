\# SoundMesh — Networking Specification



\*\*Document status:\*\* Living engineering specification

\*\*Document role:\*\* Defines how SoundMesh devices discover one another, establish communication, exchange control data, transfer audio, maintain sessions, and recover from network failures.



\*\*Primary authority:\*\* This document defines networking behavior and networking architecture.

\*\*Related specifications:\*\*



\* `DOCS/blueprint.md` — product-level requirements and boundaries

\* `DOCS/architecture.md` — system architecture and platform boundaries

\* `DOCS/synchronization.md` — timing, clock synchronization, scheduled playback, drift correction

\* `DOCS/audio.md` — audio preparation, decoding, buffering, and playback

\* `DOCS/testing.md` — validation and acceptance testing

\* `DOCS/decisions.md` — records major architectural decisions



\---



\# 1. Purpose



SoundMesh requires multiple independent smartphones to communicate reliably enough that they can behave as one coordinated speaker system.



The networking layer is responsible for:



1\. discovering nearby SoundMesh devices;

2\. creating and joining rooms;

3\. establishing device-to-device connections;

4\. identifying participants;

5\. exchanging room and session state;

6\. distributing audio when required;

7\. exchanging synchronization measurements;

8\. sending playback commands;

9\. reporting playback and device state;

10\. detecting connection failures;

11\. reconnecting when possible;

12\. handling device joins and departures;

13\. handling network changes;

14\. protecting room communication from unauthorized participants;

15\. providing deterministic behavior to the synchronization layer.



Networking is \*\*not\*\* responsible for determining whether audio is synchronized correctly.



That responsibility belongs to the synchronization system defined in `synchronization.md`.



Networking must instead provide the communication primitives and timing measurements required by synchronization.



\---



\# 2. Core Networking Principles



SoundMesh networking MUST follow these principles.



\## 2.1 Local-first



Normal SoundMesh playback MUST NOT require Internet access.



The intended path is:



```text

Phone A ─┐

Phone B ─┼── Local network ── Phone C

Phone D ─┘

```



The Internet should not be a dependency for:



\* room creation;

\* room joining;

\* device discovery;

\* audio transfer;

\* synchronization;

\* playback control;

\* synchronization monitoring;

\* recovery.



Internet connectivity may exist, but SoundMesh should not depend on it for ordinary playback.



\---



\## 2.2 Networking must support heterogeneous devices



SoundMesh cannot assume that every device has:



\* the same OS;

\* the same CPU;

\* the same Wi-Fi chipset;

\* the same network stack;

\* the same clock behavior;

\* the same IP address;

\* the same network latency;

\* the same audio subsystem;

\* the same permissions;

\* the same network capabilities.



The protocol MUST therefore be platform-independent.



A device running Android and a device running iOS should communicate using the same SoundMesh application protocol.



Platform-specific implementation details MUST remain behind the platform networking abstraction.



\---



\## 2.3 Networking must be measurable



The networking layer MUST expose enough information for synchronization to measure:



\* round-trip time;

\* packet/message timing;

\* connection state;

\* connection establishment duration;

\* transfer progress;

\* transfer failures;

\* reconnect attempts;

\* network changes;

\* message ordering;

\* message loss where applicable.



A connection that "seems connected" is insufficient.



SoundMesh synchronization depends on measured behavior.



\---



\## 2.4 Control traffic and bulk data are different



SoundMesh MUST distinguish between:



\### Control traffic



Examples:



\* room information;

\* participant information;

\* readiness;

\* playback commands;

\* pause;

\* resume;

\* seek;

\* stop;

\* synchronization probes;

\* playback reports;

\* heartbeat;

\* error reports.



\### Bulk data



Examples:



\* audio files;

\* large metadata;

\* future diagnostic exports.



These traffic classes should not be treated identically.



Control messages require reliability and ordering.



Bulk transfer requires throughput, progress reporting, integrity verification, and resumability where practical.



\---



\# 3. Initial Network Architecture



The initial SoundMesh architecture SHOULD use a \*\*host-and-participant topology\*\*.



```text

&#x20;                   ┌───────────────┐

&#x20;                   │     HOST      │

&#x20;                   │               │

&#x20;                   │ Room authority│

&#x20;                   │ Session state │

&#x20;                   │ Coordination  │

&#x20;                   └───────┬───────┘

&#x20;                           │

&#x20;            ┌──────────────┼──────────────┐

&#x20;            │              │              │

&#x20;            ▼              ▼              ▼

&#x20;       Participant     Participant    Participant

&#x20;            A              B              C

```



The host is responsible for room coordination.



Participants connect to the host.



The host SHOULD NOT be treated as a continuous audio relay unless experiments prove that this architecture is necessary.



The preferred model is:



```text

Host

&#x20;│

&#x20;├── audio transfer ──> Participant A

&#x20;├── audio transfer ──> Participant B

&#x20;└── audio transfer ──> Participant C

```



followed by:



```text

Host ── playback schedule ──> all participants

```



Each participant then plays its local copy.



This minimizes continuous network dependence during playback.



\---



\# 4. Why Audio Should Prefer Local Distribution



Streaming the audio continuously from the host to every participant creates unnecessary network sensitivity.



A continuous stream would make playback dependent on:



\* packet delivery;

\* network jitter;

\* bandwidth;

\* buffering;

\* host CPU;

\* host upload capacity;

\* temporary congestion.



Instead, SoundMesh SHOULD preferably use:



```text

SELECT AUDIO

&#x20;     ↓

PREPARE AUDIO

&#x20;     ↓

TRANSFER AUDIO

&#x20;     ↓

VERIFY AUDIO

&#x20;     ↓

LOCAL BUFFER

&#x20;     ↓

CALIBRATE

&#x20;     ↓

SCHEDULE PLAYBACK

&#x20;     ↓

LOCAL PLAYBACK

```



The network is then primarily responsible for \*\*coordination\*\*, rather than transporting every audio sample in real time.



This architecture is a design preference and must be validated experimentally.



\---



\# 5. Network Topology



SoundMesh MUST support a topology in which all participating devices can establish direct local connections to the host.



The first implementation SHOULD prioritize:



1\. devices connected to the same Wi-Fi network;

2\. a phone hotspot providing the local network;

3\. later investigation of direct peer-to-peer networking.



The architecture MUST NOT assume that an Internet router is available.



\---



\# 6. Local Wi-Fi



The primary MVP networking environment SHOULD be ordinary local Wi-Fi.



Example:



```text

&#x20;              Wi-Fi Router

&#x20;             /     |      \\

&#x20;            /      |       \\

&#x20;         Host    Phone A  Phone B

```



The router does not need Internet access.



It only needs to provide local connectivity.



A completely offline Wi-Fi network is therefore valid.



\---



\# 7. Phone Hotspot



Phone hotspot support is an important target scenario.



Example:



```text

&#x20;          Host Phone

&#x20;       Wi-Fi Hotspot

&#x20;         /       \\

&#x20;        /         \\

&#x20;  Phone A       Phone B

```



The host may simultaneously:



\* provide the local network;

\* run the SoundMesh host session;

\* participate in playback.



This scenario MUST be tested separately from ordinary Wi-Fi.



Hotspot behavior can differ between devices and operating systems.



SoundMesh MUST NOT assume that all phones expose identical hotspot behavior.



\---



\# 8. Wi-Fi Direct / Peer-to-Peer



Direct peer-to-peer networking SHOULD be treated as a future or experimental capability rather than an MVP dependency.



Android currently provides Wi-Fi Direct service discovery that can operate without an existing network or hotspot, but it has platform-specific permission requirements, including `NEARBY\_WIFI\_DEVICES` for Android 13/API 33+ scenarios.



Therefore:



```text

MVP:

Local Wi-Fi

&#x20;  +

Phone hotspot



Future / Experimental:

Wi-Fi Direct

Other platform-specific P2P mechanisms

```



The application architecture MUST allow future transports without rewriting the SoundMesh application protocol.



\---



\# 9. Cross-Platform Networking



The on-wire protocol MUST be platform-neutral.



The following should communicate identically:



```text

Android Host → Android Participant

Android Host → iOS Participant

iOS Host → Android Participant

iOS Host → iOS Participant

```



Platform-specific networking implementations may differ.



For example:



```text

Flutter

&#x20;  │

&#x20;  ├── Android implementation

&#x20;  │      └── Kotlin networking

&#x20;  │

&#x20;  └── iOS implementation

&#x20;         └── Swift networking

```



Both implementations must expose the same logical SoundMesh networking API.



\---



\# 10. Flutter Networking Boundary



Flutter SHOULD own:



\* networking state presentation;

\* room UI;

\* participant list;

\* connection status;

\* transfer progress UI;

\* user actions;

\* error presentation;

\* application-level orchestration.



Native platform code SHOULD own functionality that depends heavily on platform networking APIs or timing-sensitive behavior.



Flutter's platform-channel architecture explicitly supports calling native Kotlin/Swift APIs, and Flutter recommends Pigeon when type-safe generated interfaces are appropriate.



The preferred architecture is therefore:



```text

┌───────────────────────────────────────────────┐

│                   Flutter                     │

│                                               │

│ UI                                            │

│ Room state                                    │

│ User actions                                  │

│ Application orchestration                     │

└──────────────────────┬────────────────────────┘

&#x20;                      │

&#x20;                Typed interface

&#x20;                   / Pigeon

&#x20;                      │

&#x20;       ┌──────────────┴──────────────┐

&#x20;       │                             │

┌───────▼────────┐            ┌───────▼────────┐

│ Android Native │            │   iOS Native   │

│    Kotlin      │            │     Swift      │

│                │            │                │

│ Networking     │            │ Networking     │

│ Discovery      │            │ Discovery      │

│ Sockets        │            │ Network        │

│ Platform APIs  │            │ framework      │

└────────────────┘            └────────────────┘

```



High-frequency synchronization or timing traffic MUST NOT depend on repeatedly crossing the Flutter/native boundary.



\---



\# 11. iOS Networking



On iOS, the preferred native networking foundation SHOULD be Apple's Network framework.



SoundMesh should avoid making Multipeer Connectivity the architectural foundation.



Apple's current networking guidance favors Network framework for custom networking, while local-network operations are governed by iOS local-network privacy rules.



\---



\# 12. iOS Local Network Permission



An iOS SoundMesh application that communicates with devices on the local network MUST correctly implement Apple's local-network privacy requirements.



The application must provide:



```text

NSLocalNetworkUsageDescription

```



in `Info.plist`.



If Bonjour service discovery is used, the required Bonjour service types must also be declared through:



```text

NSBonjourServices

```



Apple explicitly documents that Bonjour registration, browsing, and resolution require local-network access.



The application MUST provide a clear user-facing explanation for why local-network access is required.



Example concept:



> SoundMesh needs local network access to find and connect to nearby phones in your speaker group.



The exact wording is a product/UI decision.



\---



\# 13. Android Networking



Android networking SHOULD use standard platform networking APIs where practical.



Android-specific discovery mechanisms may be implemented behind the networking abstraction.



Android Wi-Fi Direct can provide service discovery without an existing local network, but its permissions and device behavior make it unsuitable as an assumed universal transport for the MVP.



Android implementation MUST explicitly account for:



\* Android API level;

\* Wi-Fi state;

\* nearby-device permissions;

\* local network availability;

\* hotspot behavior;

\* background restrictions;

\* connection changes.



\---



\# 14. Device Discovery



Discovery answers:



> "Which SoundMesh devices are available to join?"



Discovery is separate from connection establishment.



The preferred user flow is:



```text

Host creates room

&#x20;       ↓

Room receives identity

&#x20;       ↓

Host displays QR code

&#x20;       ↓

Participant scans QR

&#x20;       ↓

Participant obtains bootstrap information

&#x20;       ↓

Participant connects to host

```



Discovery therefore does not necessarily require automatic scanning.



\---



\# 15. QR Code Joining



QR joining SHOULD be the primary MVP onboarding mechanism.



The QR code should contain only the information necessary to bootstrap the connection.



Conceptual structure:



```text

soundmesh://join?

&#x20;   room=<room-id>

&#x20;   host=<bootstrap-address>

&#x20;   port=<bootstrap-port>

&#x20;   version=<protocol-version>

&#x20;   token=<short-lived-join-token>

```



The exact encoding is intentionally implementation-defined.



The QR code MUST NOT contain:



\* permanent credentials;

\* user passwords;

\* long-lived secrets;

\* unnecessary personal information;

\* audio data.



\---



\# 16. QR Code Security



A QR code should be considered visible to nearby people.



Therefore, the QR payload MUST NOT be treated as a permanent authentication credential.



Room joining SHOULD use a short-lived, room-specific join credential.



Example:



```text

Room ID

\+

Protocol version

\+

Short-lived join token

```



The token SHOULD:



\* expire;

\* be scoped to the current room;

\* become invalid when the room closes;

\* preferably become invalid after successful use or after a defined lifetime.



\---



\# 17. Room Identity



Every active room MUST have a unique room identifier.



Example conceptual format:



```text

roomId = random opaque identifier

```



The room ID must not be based solely on:



\* device name;

\* IP address;

\* username;

\* timestamp;

\* phone model.



Room IDs exist at the application protocol level.



\---



\# 18. Device Identity



Every participant MUST have a unique identity within the current room.



A participant identity should be generated locally.



Example:



```text

participantId

displayName

deviceCapabilities

protocolVersion

```



A participant ID is scoped to the room/session unless a future feature explicitly requires persistent identity.



SoundMesh SHOULD avoid unnecessary persistent tracking.



\---



\# 19. Host Identity



The host must also have a participant/device identity.



Conceptually:



```text

Room

&#x20;├── Host

&#x20;│    └── participantId

&#x20;│

&#x20;├── Participant

&#x20;│    └── participantId

&#x20;│

&#x20;└── Participant

&#x20;     └── participantId

```



The host additionally has room-authority responsibilities.



\---



\# 20. Transport Selection



The initial networking architecture SHOULD use:



\### TCP



For:



\* room control;

\* participant management;

\* session setup;

\* audio transfer;

\* metadata;

\* reliable commands;

\* configuration;

\* state synchronization.



\### UDP



UDP SHOULD NOT be required for the initial implementation unless experiments demonstrate a measurable advantage.



Potential future uses include:



\* high-frequency timing probes;

\* low-latency telemetry;

\* specialized synchronization measurements.



The synchronization system must determine whether UDP provides meaningful improvement.



Do not introduce UDP merely because it is theoretically faster.



\---



\# 21. Why TCP Is Preferred Initially



SoundMesh's primary network messages require:



\* reliable delivery;

\* ordering;

\* connection state;

\* simplicity;

\* debugging;

\* cross-platform implementation.



TCP provides these properties.



For the MVP, adding a custom reliability layer over UDP would create unnecessary complexity unless measurement proves it is required.



The system can later introduce a specialized datagram channel without changing the logical application protocol.



\---



\# 22. Protocol Independence



The SoundMesh protocol MUST NOT depend on a specific transport.



Conceptually:



```text

SoundMesh Protocol

&#x20;      │

&#x20;      ▼

Transport Interface

&#x20;      │

&#x20;  ┌───┴────┐

&#x20;  │        │

&#x20; TCP      UDP

```



This allows future experimentation.



The application should think in terms of:



```text

send(message)

receive(message)

```



rather than:



```text

sendTCP(...)

```



where practical.



\---



\# 23. Connection Lifecycle



A participant connection SHOULD follow this state machine:



```text

DISCONNECTED

&#x20;    ↓

CONNECTING

&#x20;    ↓

CONNECTED

&#x20;    ↓

AUTHENTICATING

&#x20;    ↓

READY

&#x20;    ↓

ACTIVE

&#x20;    ↓

DEGRADED

&#x20;    ↓

RECONNECTING

&#x20;    ↓

CONNECTED

```



Failure states may transition to:



```text

FAILED

```



or:



```text

REMOVED

```



depending on the reason.



\---



\# 24. Connection Establishment



A participant connection SHOULD follow:



```text

QR scanned

&#x20;   ↓

Bootstrap information validated

&#x20;   ↓

Host address resolved

&#x20;   ↓

TCP connection established

&#x20;   ↓

Protocol handshake

&#x20;   ↓

Version compatibility checked

&#x20;   ↓

Join token validated

&#x20;   ↓

Participant registered

&#x20;   ↓

Room state received

&#x20;   ↓

Connection READY

```



The participant MUST NOT be considered fully joined merely because the TCP socket opened.



\---



\# 25. Protocol Handshake



Every connection MUST begin with a protocol handshake.



The handshake should establish:



\* protocol version;

\* participant ID;

\* device role;

\* supported capabilities;

\* session/room identity;

\* authentication/join authorization;

\* optional transport capabilities.



Conceptually:



```text

Participant → Host:

HELLO



Host → Participant:

WELCOME

```



\---



\# 26. Protocol Versioning



Every protocol implementation MUST declare a protocol version.



Example:



```text

protocolMajor

protocolMinor

```



Major-version incompatibility SHOULD result in rejection.



Minor-version differences MAY be supported when compatibility is explicitly defined.



The application MUST NOT silently assume compatibility.



Example:



```text

Host:      1.2

Participant: 1.1



→ compatibility rules determine whether joining is allowed

```



\---



\# 27. Message Envelope



All SoundMesh protocol messages SHOULD use a common envelope.



Conceptual structure:



```text

Message {

&#x20;   protocolVersion

&#x20;   messageType

&#x20;   messageId

&#x20;   sessionId

&#x20;   senderId

&#x20;   generation

&#x20;   timestamp

&#x20;   payload

}

```



Not every field must be transmitted in exactly this form.



The final wire format is an implementation decision.



The protocol MUST, however, provide equivalent semantics.



\---



\# 28. Message IDs



Messages that require acknowledgement SHOULD have unique message IDs.



Example:



```text

messageId = random/monotonic unique identifier

```



This allows the receiver to detect:



\* duplicates;

\* retries;

\* acknowledgements;

\* stale commands.



\---



\# 29. Generation Numbers



Playback-related commands MUST include a generation or equivalent ordering mechanism.



Example:



```text

generation = 42

```



A participant receiving:



```text

generation 42

```



after already processing:



```text

generation 43

```



MUST NOT execute the stale command.



This prevents delayed network messages from accidentally modifying current playback state.



\---



\# 30. Core Message Categories



The protocol SHOULD support message categories such as:



\### Session



\* `HELLO`

\* `WELCOME`

\* `JOIN\_REQUEST`

\* `JOIN\_ACCEPTED`

\* `JOIN\_REJECTED`

\* `LEAVE`

\* `ROOM\_STATE`



\### Device



\* `DEVICE\_INFO`

\* `DEVICE\_CAPABILITIES`

\* `DEVICE\_STATE`



\### Audio



\* `AUDIO\_INFO`

\* `AUDIO\_REQUEST`

\* `AUDIO\_TRANSFER\_START`

\* `AUDIO\_TRANSFER\_PROGRESS`

\* `AUDIO\_TRANSFER\_COMPLETE`

\* `AUDIO\_VERIFY`

\* `AUDIO\_READY`



\### Synchronization



\* `TIME\_SYNC\_REQUEST`

\* `TIME\_SYNC\_RESPONSE`

\* `SYNC\_STATUS`

\* `PLAYBACK\_POSITION`

\* `DRIFT\_REPORT`



\### Playback



\* `PREPARE`

\* `PLAY`

\* `PAUSE`

\* `RESUME`

\* `SEEK`

\* `STOP`



\### Health



\* `PING`

\* `PONG`

\* `HEARTBEAT`

\* `ERROR`



The exact message set may evolve.



\---



\# 31. Reliable Commands



Playback commands such as:



```text

PLAY

PAUSE

RESUME

SEEK

STOP

```



MUST be delivered reliably.



A command MUST NOT be silently lost.



Commands should contain enough information to determine whether they are:



\* current;

\* duplicated;

\* stale;

\* already executed.



\---



\# 32. Playback Command Model



A playback command should conceptually contain:



```text

command {

&#x20;   generation

&#x20;   commandType

&#x20;   targetPlaybackTime

&#x20;   audioId

&#x20;   position

}

```



For example:



```text

PLAY

audioId = A

targetTime = T

position = 0

generation = 18

```



The command does not mean:



> play immediately.



It means:



> prepare to begin playback at the specified shared timeline position.



This is consistent with the synchronization specification.



\---



\# 33. Synchronization Traffic



Networking MUST expose a mechanism for the synchronization layer to perform timestamp exchanges.



Example:



```text

Participant → Host

t1



Host → Participant

t2 / t3



Participant

t4

```



The exact packet structure is defined by `synchronization.md`.



Networking MUST preserve the timestamps required by the synchronization algorithm as accurately as the selected transport permits.



\---



\# 34. Heartbeats



Connections SHOULD use heartbeats.



Conceptually:



```text

Host → Participant: PING

Participant → Host: PONG

```



Heartbeats allow SoundMesh to detect:



\* disconnected devices;

\* stalled connections;

\* network changes;

\* temporary failures.



Heartbeat intervals MUST NOT be hard-coded throughout the application.



They should be centrally configurable.



\---



\# 35. Heartbeat Failure



Missing one heartbeat MUST NOT immediately remove a participant.



Networks can temporarily experience:



\* congestion;

\* scheduling delays;

\* radio interference;

\* OS scheduling delays.



The connection manager should use a failure threshold.



Conceptually:



```text

healthy

&#x20;  ↓

missed heartbeat

&#x20;  ↓

degraded

&#x20;  ↓

multiple failures

&#x20;  ↓

connection lost

```



Exact thresholds must be experimentally determined.



\---



\# 36. Network Degradation



The networking system SHOULD distinguish:



```text

CONNECTED

DEGRADED

DISCONNECTED

```



A degraded connection may still be usable.



Examples:



\* increased RTT;

\* increased jitter;

\* delayed heartbeat;

\* packet retransmission;

\* reduced throughput.



The synchronization system should receive this information.



It may decide to:



\* increase scheduling margin;

\* recalibrate;

\* reduce update frequency;

\* pause;

\* resynchronize.



\---



\# 37. Reconnection



Temporary network loss SHOULD trigger reconnection attempts.



Conceptually:



```text

ACTIVE

&#x20; ↓

CONNECTION LOST

&#x20; ↓

RECONNECTING

&#x20; ↓

RECONNECTED

&#x20; ↓

STATE RESYNC

&#x20; ↓

CALIBRATION

&#x20; ↓

READY

```



A participant MUST NOT immediately resume normal playback after reconnecting without validating its state.



\---



\# 38. Reconnection State Recovery



After reconnection, the participant should obtain:



\* current room generation;

\* current audio ID;

\* current playback state;

\* current playback position;

\* current session state;

\* synchronization status;

\* whether it must re-download audio;

\* whether recalibration is required.



The participant should then determine whether it can:



```text

resume

```



or must:



```text

resynchronize

```



\---



\# 39. Audio Transfer



When the selected architecture distributes audio locally, audio transfer MUST be treated as a separate phase from playback.



Recommended lifecycle:



```text

AUDIO\_SELECTED

&#x20;     ↓

AUDIO\_METADATA

&#x20;     ↓

TRANSFER

&#x20;     ↓

VERIFY

&#x20;     ↓

DECODE/PREPARE

&#x20;     ↓

AUDIO\_READY

```



Playback MUST NOT begin until every required participant has reached an acceptable preparation state.



\---



\# 40. Audio Integrity



Transferred audio MUST be verified.



A transfer completing successfully does not necessarily prove that the resulting file is correct.



The system SHOULD use a content identifier or cryptographic hash.



Conceptually:



```text

audioId

contentLength

contentHash

format

sampleRate

channels

duration

```



The participant verifies the received content against the expected identity.



\---



\# 41. Audio Transfer Resumption



If practical, large audio transfers SHOULD support resumption.



Example:



```text

Host:

audio size = 20 MB



Participant:

received = 12 MB



Connection lost



Reconnect



Participant:

resume from 12 MB

```



This is not mandatory for the first prototype if files are small, but the architecture SHOULD avoid making resumability impossible.



\---



\# 42. File Transfer Must Not Block Control



Audio transfer MUST NOT prevent important control messages from being processed.



For example, while a large audio file is transferring:



```text

AUDIO DATA

AUDIO DATA

AUDIO DATA



&#x20;       +--> PING

&#x20;       +--> ROOM STATE

&#x20;       +--> ERROR

&#x20;       +--> CANCEL

```



The networking architecture must allow control traffic to remain responsive.



\---



\# 43. Participant Joining



A participant joining an active room should follow:



```text

SCAN QR

&#x20;  ↓

CONNECT

&#x20;  ↓

AUTHENTICATE

&#x20;  ↓

RECEIVE ROOM STATE

&#x20;  ↓

RECEIVE AUDIO IF NECESSARY

&#x20;  ↓

PREPARE

&#x20;  ↓

CALIBRATE

&#x20;  ↓

READY

```



If playback is already active, the participant MUST NOT automatically begin playing immediately.



It must be synchronized to the current playback timeline.



\---



\# 44. Late Joining



Late joiners must be handled explicitly.



A participant joining while the room is already playing should receive:



\* current audio;

\* current playback state;

\* current playback position;

\* synchronization information;

\* required calibration;

\* a future synchronization target.



The participant then begins at the appropriate future point.



\---



\# 45. Participant Leaving



A participant may leave because of:



\* user action;

\* connection loss;

\* application termination;

\* battery shutdown;

\* network failure;

\* host removal.



The host should update room state.



Remaining participants should not wait indefinitely for a device that has already left.



\---



\# 46. Host Failure



The MVP does NOT require seamless host migration.



If the host disappears:



```text

HOST LOST

&#x20;   ↓

ROOM DEGRADED

&#x20;   ↓

PARTICIPANTS DETECT FAILURE

&#x20;   ↓

CONTROLLED RECOVERY

```



The MVP may require the session to end and be recreated.



Future versions may investigate:



```text

Participant → new host

```



but this should not complicate the first synchronization architecture.



\---



\# 47. Network Change



A device may change network conditions while the application is running.



Examples:



\* Wi-Fi disconnect;

\* Wi-Fi reconnect;

\* hotspot changes;

\* interface changes;

\* temporary network loss;

\* network becomes unavailable.



A network change MUST trigger explicit state handling.



It MUST NOT be treated as an invisible implementation detail.



\---



\# 48. IP Addresses Are Not Device Identity



An IP address MUST NOT be used as the permanent identity of a participant.



IP addresses can change.



For example:



```text

Participant A

192.168.1.7

&#x20;    ↓

network reconnect

&#x20;    ↓

192.168.1.12

```



The participant identity remains unchanged.



The connection address changes.



\---



\# 49. Discovery vs Connection



These concepts MUST remain separate.



\### Discovery



Answers:



> Where is a SoundMesh service?



\### Connection



Answers:



> Can I establish communication with that device?



\### Authentication



Answers:



> Is this participant allowed into this room?



\### Session registration



Answers:



> Is this participant currently part of the room?



The implementation should not collapse these responsibilities into one mechanism.



\---



\# 50. Bonjour / Service Discovery



On Apple platforms, Bonjour is a candidate for local service discovery.



If used, SoundMesh must correctly declare the relevant Bonjour service types and local-network permissions.



Apple's current documentation states that Bonjour registration, browsing, and resolution require local-network access.



Bonjour should therefore be considered a discovery mechanism, not the SoundMesh application protocol itself.



\---



\# 51. Android Service Discovery



Android may use appropriate local-network discovery mechanisms.



Wi-Fi Direct service discovery is available for direct nearby discovery even without an existing network, but permission and platform behavior must be accounted for.



The exact Android discovery mechanism is:



\*\*Status: EXPERIMENTAL\*\*



It must be validated on real devices before becoming an architectural requirement.



\---



\# 52. QR as the MVP Discovery Escape Hatch



The MVP should not become dependent on automatic discovery working perfectly.



QR joining provides a deterministic fallback:



```text

Automatic discovery

&#x20;      ↓

if unavailable

&#x20;      ↓

QR bootstrap

&#x20;      ↓

direct connection

```



This is especially important for cross-platform reliability.



\---



\# 53. Network Security Model



SoundMesh is a local application, but local networks cannot automatically be considered trusted.



The system SHOULD assume that another device may be present on the same Wi-Fi network.



Therefore, room communication SHOULD use:



\* short-lived join credentials;

\* room-scoped authorization;

\* authenticated protocol messages;

\* integrity protection;

\* no unnecessary personal data.



The exact cryptographic protocol is an architectural decision that must be researched and recorded in `decisions.md`.



\---



\# 54. Encryption



Encryption SHOULD be used for sensitive room communication.



However, cryptographic implementation MUST NOT be improvised.



The project should prefer:



\* established platform cryptographic APIs;

\* established protocol libraries;

\* standard authenticated encryption;

\* well-reviewed primitives.



The MVP must not invent a custom encryption algorithm.



\---



\# 55. Threat Model



The minimum networking threat model should consider:



\### Unauthorized room joining



A nearby device attempts to join without permission.



\### QR interception



Someone sees the QR code and attempts to join.



\### Message injection



A device on the same network attempts to send fake control messages.



\### Message replay



An old playback command is resent.



\### Stale command execution



A delayed command arrives after a newer command.



\### Room impersonation



A malicious device attempts to pretend to be the host.



\### Audio tampering



Transferred audio is modified or corrupted.



\### Denial of service



A malicious device floods the local room with traffic.



The MVP does not need enterprise-grade security, but these threats should influence protocol design.



\---



\# 56. Message Ordering



Messages must be categorized according to whether ordering matters.



For example:



```text

PLAY generation 10

PAUSE generation 11

PLAY generation 12

```



A delayed:



```text

PLAY generation 10

```



must not execute after generation 12.



Generation numbers or equivalent ordering metadata MUST therefore be used for state-changing commands.



\---



\# 57. Duplicate Messages



The protocol should tolerate duplicate messages where practical.



Example:



```text

PLAY #42

PLAY #42

```



The second instance should be recognized as a duplicate rather than causing a second playback operation.



This is especially important if future transports introduce retries.



\---



\# 58. Error Model



Networking errors MUST be structured.



Examples:



```text

NETWORK\_UNAVAILABLE

CONNECTION\_REFUSED

CONNECTION\_TIMEOUT

AUTHENTICATION\_FAILED

PROTOCOL\_MISMATCH

ROOM\_NOT\_FOUND

ROOM\_FULL

TRANSFER\_FAILED

TRANSFER\_CORRUPTED

PEER\_DISCONNECTED

NETWORK\_CHANGED

PERMISSION\_DENIED

DISCOVERY\_FAILED

```



The UI should receive actionable error categories rather than raw socket exceptions.



\---



\# 59. Permission Errors



Platform permission failures MUST be surfaced separately from ordinary network failures.



For example:



```text

LOCAL\_NETWORK\_PERMISSION\_DENIED

```



should not be reported simply as:



```text

CONNECTION\_FAILED

```



This allows the UI to explain the actual problem.



Apple explicitly documents local-network denial as a distinct condition that networking APIs such as Network framework can surface.



\---



\# 60. Network State Machine



The overall networking subsystem SHOULD use a state machine similar to:



```text

&#x20;                        ┌───────────────┐

&#x20;                        │  DISCONNECTED │

&#x20;                        └───────┬───────┘

&#x20;                                │

&#x20;                             connect

&#x20;                                │

&#x20;                                ▼

&#x20;                        ┌───────────────┐

&#x20;                        │   CONNECTING  │

&#x20;                        └───────┬───────┘

&#x20;                                │

&#x20;                             success

&#x20;                                │

&#x20;                                ▼

&#x20;                        ┌───────────────┐

&#x20;                        │ AUTHENTICATING │

&#x20;                        └───────┬───────┘

&#x20;                                │

&#x20;                             success

&#x20;                                │

&#x20;                                ▼

&#x20;                        ┌───────────────┐

&#x20;                        │     READY     │

&#x20;                        └───────┬───────┘

&#x20;                                │

&#x20;                             active

&#x20;                                │

&#x20;                                ▼

&#x20;                        ┌───────────────┐

&#x20;                        │     ACTIVE    │

&#x20;                        └───────┬───────┘

&#x20;                                │

&#x20;                        network degradation

&#x20;                                │

&#x20;                                ▼

&#x20;                        ┌───────────────┐

&#x20;                        │   DEGRADED    │

&#x20;                        └───────┬───────┘

&#x20;                                │

&#x20;                        connection lost

&#x20;                                │

&#x20;                                ▼

&#x20;                        ┌───────────────┐

&#x20;                        │ RECONNECTING  │

&#x20;                        └───────┬───────┘

&#x20;                                │

&#x20;                      ┌─────────┴─────────┐

&#x20;                      │                   │

&#x20;                   success              failure

&#x20;                      │                   │

&#x20;                      ▼                   ▼

&#x20;                   ACTIVE              FAILED

```



The exact implementation may differ, but equivalent state semantics are required.



\---



\# 61. Networking and Synchronization Boundary



Networking provides:



```text

Connection

Message transport

Timestamps

RTT measurements

Connection state

Playback command delivery

```



Synchronization provides:



```text

Clock offset

Clock relationship

Latency interpretation

Scheduled playback

Drift estimation

Drift correction

Resynchronization

```



Networking MUST NOT decide whether two devices are "synchronized."



\---



\# 62. Timing Data Requirements



Networking must provide timestamps from an appropriate monotonic timing source where timing measurements are required.



Wall-clock time such as:



```text

2026-09-05 23:00:00

```



must not be assumed to be suitable for precise synchronization.



The synchronization layer defines the clock model.



\---



\# 63. Control Plane vs Timing Plane



The networking architecture should conceptually distinguish:



```text

CONTROL PLANE

├── room state

├── participant state

├── playback commands

├── audio metadata

├── errors

└── heartbeats



TIMING PLANE

├── timestamp exchange

├── RTT measurements

├── playback position reports

└── timing diagnostics

```



They may initially use the same physical connection.



They remain logically separate so the timing system can evolve independently.



\---



\# 64. Avoiding Flutter Timing Bottlenecks



High-frequency timing traffic MUST NOT require:



```text

Native

&#x20; ↓

Flutter

&#x20; ↓

Native

&#x20; ↓

Flutter

```



for every timing event.



Flutter is the application/UI layer.



Timing-sensitive loops should remain as close as practical to native timing and audio infrastructure.



Flutter should receive meaningful state rather than every low-level event.



\---



\# 65. Connection Manager



The application SHOULD contain a dedicated connection manager responsible for:



\* connection lifecycle;

\* peer registration;

\* reconnect attempts;

\* connection state;

\* message routing;

\* heartbeat;

\* protocol errors;

\* transport abstraction.



The connection manager MUST NOT contain audio synchronization algorithms.



\---



\# 66. Room Manager



A room manager should be responsible for:



\* room creation;

\* room identity;

\* participant registration;

\* participant removal;

\* room state;

\* host authority;

\* room lifecycle.



The room manager communicates with the connection manager.



\---



\# 67. Protocol Layer



A dedicated protocol layer should convert application events into wire messages.



Conceptually:



```text

RoomManager

&#x20;    ↓

Protocol

&#x20;    ↓

Transport

&#x20;    ↓

Socket

```



This prevents application code from becoming coupled directly to TCP/UDP implementation details.



\---



\# 68. Transport Layer



The transport abstraction should expose operations such as:



```text

connect()

disconnect()

send()

receive()

close()

getState()

```



The actual API can differ.



The important property is that higher layers should not need to know whether communication is:



```text

TCP

UDP

future transport

```



\---



\# 69. Suggested Logical Architecture



```text

┌──────────────────────────────────────────────┐

│                  Flutter                     │

│                                              │

│ UI                                           │

│ Room Controller                              │

│ Playback Controller                          │

│ Application State                             │

└──────────────────────┬───────────────────────┘

&#x20;                      │

&#x20;                 Typed API

&#x20;                      │

┌──────────────────────▼───────────────────────┐

│            Native Networking Layer            │

│                                              │

│ Connection Manager                           │

│ Room Manager                                 │

│ Protocol                                     │

│ Transport                                    │

│ Discovery                                    │

│ Audio Transfer                               │

│ Timing Transport                             │

└──────────────────────┬───────────────────────┘

&#x20;                      │

&#x20;             ┌────────┴─────────┐

&#x20;             │                  │

&#x20;          Network            Network

&#x20;          Interface          Interface

```



\---



\# 70. Network Events



The networking subsystem SHOULD emit structured events such as:



```text

PeerConnected

PeerDisconnected

PeerDegraded

PeerReconnected

RoomStateChanged

TransferStarted

TransferProgress

TransferCompleted

TransferFailed

NetworkChanged

ProtocolError

PermissionError

```



These events should be consumed by the application state layer.



\---



\# 71. Observability



Networking must expose diagnostic information during development.



Useful metrics include:



\* connection establishment time;

\* RTT;

\* minimum RTT;

\* RTT variance;

\* bytes transferred;

\* transfer duration;

\* reconnect count;

\* heartbeat failures;

\* message count;

\* failed messages;

\* protocol errors;

\* network state;

\* active participant count.



These metrics are important for determining why synchronization succeeds or fails.



\---



\# 72. Debug Mode



A development/debug mode SHOULD expose networking diagnostics.



Example:



```text

Room: A7F2

Role: HOST

Peers: 4



Peer A

Connected: 12.4 s

RTT: 8.2 ms

State: READY



Peer B

Connected: 11.9 s

RTT: 15.4 ms

State: PLAYING



Peer C

Connected: 11.7 s

RTT: 24.1 ms

State: DEGRADED

```



This should not necessarily be visible in the production UI.



\---



\# 73. Network Stress Testing



Networking must be tested under:



\* high latency;

\* variable latency;

\* packet loss;

\* temporary disconnection;

\* Wi-Fi interference;

\* bandwidth limitation;

\* multiple simultaneous participants;

\* hotspot mode;

\* router-based Wi-Fi;

\* Android-only groups;

\* iOS-only groups;

\* Android/iOS mixed groups.



Testing should use real devices wherever platform behavior matters.



\---



\# 74. Device Scaling



The MVP target should be:



```text

2 devices

```



Then:



```text

3 devices

↓

5 devices

↓

10 devices

↓

larger groups

```



The system MUST NOT claim support for an arbitrary number of devices without testing.



The practical limit may be determined by:



\* network throughput;

\* host CPU;

\* transfer bandwidth;

\* connection count;

\* protocol overhead;

\* synchronization quality;

\* device hardware;

\* hotspot limitations.



\---



\# 75. Network Scaling Strategy



The architecture should avoid requiring the host to continuously stream audio to every participant.



Preferred:



```text

&#x20;             Host

&#x20;         /     |     \\

&#x20;      transfer transfer transfer

&#x20;       /         |         \\

&#x20;      A          B          C



then:



&#x20;      A          B          C

&#x20;      │          │          │

&#x20;      └──── local scheduled playback ────┘

```



This should scale better than continuously streaming the same audio stream through the host.



\---



\# 76. Backpressure



The networking layer MUST account for slow participants.



A slow participant must not indefinitely block faster participants.



For example:



```text

Participant A → READY

Participant B → READY

Participant C → TRANSFERRING

```



The host should maintain explicit readiness state.



Playback policy belongs to the session/synchronization layer.



The networking layer only reports the actual state.



\---



\# 77. Cancellation



Long-running operations should be cancellable.



Examples:



\* audio transfer;

\* connection attempt;

\* discovery;

\* reconnection;

\* room joining.



A cancelled operation must clean up:



\* sockets;

\* buffers;

\* timers;

\* temporary files;

\* pending callbacks;

\* state.



\---



\# 78. Resource Management



Networking code MUST avoid:



\* leaked sockets;

\* unbounded buffers;

\* infinite retry loops;

\* orphaned timers;

\* duplicate connections;

\* stale callbacks;

\* uncontrolled background tasks.



Every connection must have a clear owner and lifecycle.



\---



\# 79. Duplicate Connections



The host should prevent multiple active connections representing the same participant identity.



If a participant reconnects:



```text

old connection

&#x20;    ↓

new connection

```



the room manager must decide which connection is authoritative.



The old connection should be invalidated.



\---



\# 80. Room Closure



When the host closes a room:



```text

ROOM\_CLOSING

&#x20;    ↓

notify participants

&#x20;    ↓

stop accepting joins

&#x20;    ↓

close active transfers

&#x20;    ↓

close connections

&#x20;    ↓

ROOM\_CLOSED

```



Participants should cleanly return to the disconnected state.



\---



\# 81. Network Permissions and UX



Permissions should be requested close to the moment they are needed.



The user should understand:



```text

Why does SoundMesh need this permission?

```



rather than encountering an unexplained operating-system denial.



The application must distinguish:



```text

Permission denied

```



from:



```text

No devices found

```



and:



```text

Network unavailable

```



\---



\# 82. No Internet Requirement



A successful MVP test must be possible with:



```text

Internet = OFF

```



while:



```text

Local Wi-Fi = ON

```



The following must still work:



\* create room;

\* join room;

\* transfer audio;

\* synchronize;

\* play;

\* monitor;

\* leave.



This is a critical product requirement.



\---



\# 83. Failure Matrix



| Failure                         | Expected networking behavior           |

| ------------------------------- | -------------------------------------- |

| Wi-Fi unavailable               | Clearly report network unavailable     |

| Local-network permission denied | Explain permission requirement         |

| Host unreachable                | Connection fails with actionable state |

| Wrong room token                | Reject join                            |

| Protocol mismatch               | Reject connection                      |

| Participant disconnects         | Mark participant disconnected          |

| Participant reconnects          | Re-authenticate and resync state       |

| Audio transfer fails            | Report failure and allow retry         |

| Audio corrupted                 | Reject verification                    |

| Network temporarily degrades    | Mark connection degraded               |

| Host disappears                 | Enter controlled recovery              |

| Duplicate command               | Ignore duplicate                       |

| Stale command                   | Ignore stale generation                |

| Room closes                     | Disconnect cleanly                     |

| Network changes                 | Re-evaluate connection and reconnect   |

| Internet unavailable            | No effect on local playback            |



\---



\# 84. MVP Networking Requirements



The MVP networking implementation MUST support:



\### Required



\* host/participant model;

\* local Wi-Fi;

\* phone hotspot testing;

\* QR-based room joining;

\* direct host-participant connections;

\* protocol handshake;

\* room identity;

\* participant identity;

\* protocol versioning;

\* reliable control messages;

\* audio transfer;

\* audio integrity verification;

\* heartbeats;

\* connection state;

\* reconnect handling;

\* network failure reporting;

\* synchronization timestamp exchange;

\* playback command delivery;

\* generation-based stale-command protection;

\* offline local operation.



\### Preferred



\* automatic local discovery;

\* transfer resumption;

\* rich diagnostics;

\* graceful late joining;

\* degraded-network classification.



\### Experimental



\* UDP timing channel;

\* Wi-Fi Direct;

\* peer-to-peer fallback;

\* host migration;

\* advanced transport optimization.



\---



\# 85. Explicit Non-Goals



The MVP networking system is NOT required to provide:



\* Internet playback;

\* cloud relay servers;

\* global device discovery;

\* remote rooms over the Internet;

\* social networking;

\* user accounts;

\* persistent device identity;

\* enterprise networking;

\* arbitrary WAN synchronization;

\* seamless host migration;

\* unlimited device scaling.



\---



\# 86. Important Architectural Rule



Do not optimize the networking layer for theoretical throughput before measuring the actual SoundMesh bottleneck.



The important question is not:



> "What networking technology is fastest?"



The important question is:



> "What networking architecture produces the most reliable, measurable, cross-platform synchronization with the least unnecessary complexity?"



\---



\# 87. Experimental Networking Plan



Networking should be validated progressively.



\## Experiment 1 — Basic Local Connection



Two phones on the same Wi-Fi network.



Verify:



\* connection;

\* handshake;

\* message exchange;

\* disconnect.



\---



\## Experiment 2 — QR Bootstrap



Verify:



```text

QR

→ connect

→ authenticate

→ join

```



\---



\## Experiment 3 — Offline Operation



Disable Internet access.



Verify complete room functionality.



\---



\## Experiment 4 — Audio Transfer



Transfer the same audio file to two phones.



Verify:



\* integrity;

\* duration;

\* metadata;

\* playback readiness.



\---



\## Experiment 5 — Timestamp Exchange



Measure:



\* RTT;

\* RTT variance;

\* clock offset estimation.



Compare results against the synchronization specification.



\---



\## Experiment 6 — Hotspot



Use one phone as a hotspot.



Test:



```text

Host + 1 participant

Host + 2 participants

Host + 4 participants

```



\---



\## Experiment 7 — Cross-Platform



Test:



```text

Android → Android

iOS → iOS

Android → iOS

iOS → Android

```



\---



\## Experiment 8 — Network Stress



Introduce:



\* congestion;

\* temporary disconnect;

\* reconnect;

\* high RTT;

\* packet loss.



Measure synchronization impact.



\---



\## Experiment 9 — Scaling



Test:



```text

2

3

5

10

```



devices where hardware availability permits.



Measure:



\* connection time;

\* transfer time;

\* RTT;

\* synchronization quality;

\* CPU;

\* memory;

\* battery;

\* failure rate.



\---



\# 88. Networking Acceptance Criteria



The networking architecture is considered MVP-ready only when:



1\. two real devices can create and join a local room;

2\. the room works without Internet access;

3\. QR joining works reliably;

4\. participants receive a unique identity;

5\. protocol versions are validated;

6\. audio can be transferred and verified;

7\. control commands are reliably delivered;

8\. stale playback commands cannot override newer commands;

9\. heartbeats detect meaningful connection failures;

10\. temporary disconnections can be detected and handled;

11\. the synchronization layer can perform timestamp exchanges;

12\. network failures produce actionable states;

13\. Android and iOS implementations can communicate through the same logical protocol;

14\. the architecture does not require Flutter for high-frequency timing operations;

15\. network behavior is measurable;

16\. all important networking behavior has automated or repeatable tests;

17\. no Internet connection is required for ordinary playback.



\---



\# 89. Open Questions



The following remain intentionally unresolved until experiments provide evidence.



1\. Which exact Flutter networking abstraction should be used?

2\. Should the initial implementation place all socket handling in native code?

3\. Should TCP be implemented using native platform APIs or a shared Dart implementation?

4\. What exact wire serialization format should be used?

5\. JSON, MessagePack, protobuf, or another format?

6\. Should timing probes use TCP initially?

7\. Does UDP measurably improve synchronization?

8\. What local discovery mechanism is most reliable cross-platform?

9\. How reliable is Bonjour for the intended environment?

10\. How reliable is Android service discovery across target devices?

11\. How much should QR joining replace automatic discovery?

12\. What exact join-token mechanism should be used?

13\. Should connections use TLS or another authenticated encrypted transport?

14\. How should encryption keys be established?

15\. What is the best host failure strategy after MVP?

16\. What is the practical maximum number of participants?

17\. How should hotspot-specific limitations be handled?

18\. How should network changes be detected on each platform?

19\. How aggressively should reconnect attempts occur?

20\. Should large audio transfers support resumable chunks in MVP?

21\. Should the host distribute audio to all participants or should participants obtain it another way?

22\. What transport behavior is required for background/locked devices?

23\. Which network diagnostics should be visible to users?

24\. Which diagnostics should remain developer-only?

25\. Which networking choices produce the best synchronization results on real heterogeneous phones?



These questions MUST NOT silently become implementation decisions.



They must be resolved through:



```text

research

→ experiment

→ measurement

→ decision

→ documentation

```



with major decisions recorded in `DOCS/decisions.md`.



\---



\# 90. Final Networking Principle



SoundMesh does not need the fanciest networking stack.



It needs a networking layer that is:



\* local-first;

\* reliable;

\* measurable;

\* cross-platform;

\* resilient;

\* secure enough for its environment;

\* simple enough to maintain;

\* capable of providing precise timing information;

\* independent from the Flutter UI;

\* compatible with the synchronization architecture.



The networking system exists to make this possible:



```text

&#x20;                SOUND MESH

&#x20;                    │

&#x20;             ┌──────┴──────┐

&#x20;             │             │

&#x20;         NETWORK        TIMING

&#x20;             │             │

&#x20;      connect devices   measure clocks

&#x20;      transfer audio   estimate latency

&#x20;      send commands    schedule playback

&#x20;      detect failure   correct drift

&#x20;             │             │

&#x20;             └──────┬──────┘

&#x20;                    │

&#x20;             COORDINATED AUDIO

&#x20;                    │

&#x20;         Multiple phones behave

&#x20;            like one speaker

```



\*\*Core principle:\*\*



> The network should carry coordination, not unnecessary complexity.



> SoundMesh should make the network invisible to the user while making its behavior observable to the engineers.



