\# SoundMesh — System Architecture



\*\*Document:\*\* `DOCS/architecture.md`

\*\*Status:\*\* Living engineering specification

\*\*Authority:\*\* System architecture and component-boundary definition

\*\*Project:\*\* SoundMesh

\*\*Platform direction:\*\* Flutter-based mobile application

\*\*Primary target platforms:\*\* Android and iOS



\---



\# 1. Purpose



This document defines the technical architecture of SoundMesh.



Its purpose is to provide developers and AI coding agents with a precise model of:



\* how SoundMesh is divided into components;

\* which components own which responsibilities;

\* how Flutter interacts with native platform functionality;

\* how devices communicate;

\* how rooms and sessions are represented;

\* how audio is prepared and played;

\* where synchronization logic lives;

\* how timing-critical operations are isolated from UI code;

\* how platform-specific differences are contained;

\* how the architecture can evolve without rewriting the entire application.



This document is intentionally implementation-oriented.



It does \*\*not\*\* define every implementation detail. Detailed synchronization algorithms belong in `DOCS/synchronization.md`, networking protocols belong in `DOCS/networking.md`, and audio implementation details belong in `DOCS/audio.md`.



\---



\# 2. Architectural Summary



SoundMesh is a \*\*Flutter-first, native-capable, local-first distributed audio system\*\*.



The architecture has five major layers:



```text

┌──────────────────────────────────────────────────────┐

│                    Flutter UI                        │

│ Screens • Widgets • User Interaction • Visual State │

└──────────────────────────┬───────────────────────────┘

&#x20;                          │

&#x20;                          ▼

┌──────────────────────────────────────────────────────┐

│              Flutter Application Layer               │

│ Room State • Commands • Session Logic • Controllers  │

└──────────────────────────┬───────────────────────────┘

&#x20;                          │

&#x20;                          ▼

┌──────────────────────────────────────────────────────┐

│              Flutter Platform Interface             │

│ Typed abstraction over native networking + audio    │

└───────────────┬───────────────────────────┬──────────┘

&#x20;               │                           │

&#x20;               ▼                           ▼

┌──────────────────────────┐     ┌─────────────────────┐

│ Native Networking Layer  │     │ Native Audio Layer  │

│ Android / iOS            │     │ Android / iOS       │

│ discovery • transport   │     │ clock • buffering   │

│ connections • timing    │     │ scheduling • output │

└──────────────┬───────────┘     └──────────┬──────────┘

&#x20;              │                            │

&#x20;              ▼                            ▼

┌──────────────────────────────────────────────────────┐

│                Operating System / Hardware           │

│ Wi-Fi • network stack • audio driver • speaker      │

└──────────────────────────────────────────────────────┘

```



The central architectural principle is:



> \*\*Flutter should control the product. Native code should control platform-critical timing and hardware behavior.\*\*



Flutter is responsible for application orchestration and user experience.



Native code is responsible for operations where platform APIs, real-time behavior, or precise audio timing matter.



\---



\# 3. Core Architectural Principles



\## 3.1 Flutter-first



SoundMesh will be implemented primarily in Flutter/Dart.



Flutter should contain:



\* UI;

\* navigation;

\* application state;

\* room state representation;

\* user-facing workflows;

\* configuration;

\* diagnostics presentation;

\* protocol-independent business logic;

\* non-time-critical orchestration.



Flutter should not become responsible for:



\* sample-accurate audio scheduling;

\* high-frequency audio callbacks;

\* platform-specific audio rendering;

\* platform-specific network socket internals;

\* assumptions about Android/iOS hardware behavior.



\---



\# 3.2 Native where necessary



SoundMesh will use native platform implementations when Flutter alone cannot reliably provide the required behavior.



Expected native responsibilities include:



\### Android



\* local network discovery;

\* Wi-Fi/P2P-related operations where required;

\* native socket/network primitives where appropriate;

\* low-latency audio;

\* audio timestamps;

\* playback scheduling;

\* audio routing;

\* platform lifecycle integration.



\### iOS



\* local network discovery;

\* Network framework integration;

\* Bonjour service discovery;

\* local-network permission handling;

\* peer-to-peer networking where appropriate;

\* AVFoundation audio scheduling;

\* audio-session configuration;

\* platform lifecycle integration.



The native implementations must expose a \*\*stable platform-independent interface\*\* to Dart.



\---



\# 3.3 Local-first



Ordinary SoundMesh playback must not require an internet connection.



The normal architecture assumes:



```text

Device A ─────┐

&#x20;             │

Device B ─────┼──── Local network

&#x20;             │

Device C ─────┘

```



The internet is not part of the playback data path.



No cloud server should be required to:



\* create a room;

\* discover nearby participants;

\* transfer local audio;

\* synchronize playback;

\* maintain a local playback session.



Cloud functionality, if ever introduced, must remain optional and must not become a hidden dependency of the core product.



\---



\# 3.4 Synchronization is a first-class subsystem



Synchronization is not a side effect of networking.



The architecture treats synchronization as its own subsystem:



```text

Networking

&#x20;    │

&#x20;    ▼

Timing Measurements

&#x20;    │

&#x20;    ▼

Clock / Offset Estimation

&#x20;    │

&#x20;    ▼

Playback Scheduling

&#x20;    │

&#x20;    ▼

Playback Monitoring

&#x20;    │

&#x20;    ▼

Drift Detection

&#x20;    │

&#x20;    ▼

Correction

```



The synchronization system must be able to operate independently of the Flutter UI.



\---



\# 3.5 Local playback over continuous audio streaming



The preferred architecture is:



```text

Host

&#x20;│

&#x20;├── distribute audio

&#x20;│

&#x20;▼

Participants prepare local audio

&#x20;│

&#x20;▼

All devices buffer

&#x20;│

&#x20;▼

Host establishes shared playback timeline

&#x20;│

&#x20;▼

All devices schedule local playback

&#x20;│

&#x20;▼

Devices monitor and correct drift

```



This is preferred over continuously streaming decoded audio from the host because continuous streaming would make synchronization heavily dependent on network jitter.



The exact file-transfer and media-distribution mechanism remains an implementation decision and is defined further in `audio.md` and `networking.md`.



\---



\# 4. System Components



SoundMesh is divided into the following logical components.



```text

SoundMesh

│

├── Presentation

│   ├── Home

│   ├── Create Room

│   ├── Join Room

│   ├── Room

│   ├── Playback

│   └── Diagnostics

│

├── Application

│   ├── Room Controller

│   ├── Session Controller

│   ├── Playback Controller

│   ├── Device Controller

│   └── Recovery Controller

│

├── Domain

│   ├── Room

│   ├── Device

│   ├── Playback Session

│   ├── Audio Asset

│   ├── Synchronization State

│   └── Network State

│

├── Synchronization

│   ├── Clock Model

│   ├── Offset Estimator

│   ├── Latency Estimator

│   ├── Calibration

│   ├── Scheduler

│   ├── Drift Detector

│   └── Correction Controller

│

├── Networking

│   ├── Discovery

│   ├── Connection Manager

│   ├── Transport

│   ├── Protocol

│   └── Network Monitoring

│

├── Audio

│   ├── Audio Import

│   ├── Decoder

│   ├── Buffer Manager

│   ├── Native Playback Engine

│   ├── Playback Clock

│   └── Output Route Manager

│

└── Platform

&#x20;   ├── Android Implementation

&#x20;   └── iOS Implementation

```



\---



\# 5. Presentation Layer



The presentation layer is the Flutter UI.



It must contain no platform-specific networking or audio implementation.



Examples:



```text

CreateRoomScreen

JoinRoomScreen

RoomScreen

PlaybackScreen

DeviceList

SyncStatusWidget

DiagnosticsScreen

```



UI widgets consume application state.



They do not directly:



\* open sockets;

\* perform clock calculations;

\* schedule native audio;

\* manipulate native audio buffers;

\* implement network discovery.



\---



\# 6. Application Layer



The application layer coordinates user actions with domain systems.



Examples:



```text

RoomController

SessionController

PlaybackController

DeviceController

RecoveryController

```



Example flow:



```text

User presses "Create Room"

&#x20;       │

&#x20;       ▼

RoomController

&#x20;       │

&#x20;       ├── creates Room model

&#x20;       │

&#x20;       ├── asks Networking to advertise

&#x20;       │

&#x20;       └── updates application state

```



The controller should not know how Bonjour, Android NSD, TCP sockets, or native audio APIs work.



It should interact with interfaces.



\---



\# 7. Domain Layer



The domain layer contains platform-independent concepts.



Important domain objects include:



\## 7.1 Room



Represents a SoundMesh session.



Conceptual fields:



```text

roomId

hostDeviceId

participants

roomState

protocolVersion

audioAsset

playbackState

syncState

createdAt

```



\---



\## 7.2 Device



Represents one participant.



Conceptual fields:



```text

deviceId

displayName

role

platform

connectionState

audioState

syncState

capabilities

lastSeen

```



\---



\## 7.3 AudioAsset



Represents the audio being synchronized.



Conceptual fields:



```text

assetId

filename

format

duration

sampleRate

channels

size

contentHash

```



\---



\## 7.4 PlaybackSession



Represents one synchronized playback instance.



Conceptual fields:



```text

sessionId

assetId

startTimestamp

currentPlaybackPosition

playbackState

generation

```



The `generation` field is important.



A new playback command should be distinguishable from an old delayed network command.



\---



\# 8. Host and Participant Architecture



SoundMesh uses a logical host/participant model.



```text

&#x20;                 HOST

&#x20;                  │

&#x20;       ┌──────────┼──────────┐

&#x20;       │          │          │

&#x20;       ▼          ▼          ▼

&#x20;  Participant Participant Participant

```



The host is the session authority.



The host determines:



\* room identity;

\* participant membership;

\* playback commands;

\* synchronized start times;

\* session generation;

\* authoritative playback state.



Participants:



\* connect to the host;

\* report their capabilities;

\* receive synchronization information;

\* prepare audio;

\* schedule local playback;

\* report timing/health information;

\* perform local corrections.



\---



\# 9. Host Is Not the Audio Clock



The host must not simply send:



```text

"PLAY NOW"

```



and expect all phones to start simultaneously.



Instead:



```text

Host

&#x20;│

&#x20;│ "PLAY AT T = 42,000 ms"

&#x20;▼

Participants

&#x20;│

&#x20;├── calculate local equivalent

&#x20;├── prepare audio

&#x20;├── wait for target time

&#x20;└── start native playback

```



The host defines a shared logical timeline.



Each participant maps that timeline to its own local timing source.



Detailed clock mathematics belong in:



`DOCS/synchronization.md`



\---



\# 10. Networking Architecture



Networking is divided into four independent responsibilities.



```text

Discovery

&#x20;  │

&#x20;  ▼

Connection

&#x20;  │

&#x20;  ▼

Transport

&#x20;  │

&#x20;  ▼

SoundMesh Protocol

```



These must not be treated as one subsystem.



\---



\## 10.1 Discovery



Discovery answers:



> "Which nearby devices are running SoundMesh?"



Discovery does not itself perform synchronization.



The initial preferred architecture is local-network service discovery.



Platform implementations may use:



\### Android



Android local-network discovery / Wi-Fi APIs.



\### iOS



Network framework + Bonjour.



Apple's current Network framework supports service browsing, listeners, TCP/UDP, and peer-to-peer networking. Multipeer Connectivity should not be treated as the primary long-term iOS networking architecture because Apple currently marks it deprecated.



\---



\# 11. Networking Strategy



The networking architecture must support two conceptual environments.



\## Mode A — Existing local network



Example:



```text

Phone A ─┐

Phone B ─┼── Wi-Fi router

Phone C ─┘

```



This is the preferred initial MVP environment.



\---



\## Mode B — Phone-created local network



Example:



```text

Host phone

&#x20;  │

&#x20;  ├── hotspot/local network

&#x20;  │

&#x20;  ├── Participant

&#x20;  ├── Participant

&#x20;  └── Participant

```



This is a major target for SoundMesh because real-world users may not have an existing router.



The exact cross-platform hotspot workflow must be experimentally validated before being treated as universally supported.



\---



\## Mode C — Direct peer-to-peer



Direct peer-to-peer Wi-Fi may be explored as a later capability.



Android exposes Wi-Fi Direct/P2P service discovery, while Apple provides peer-to-peer Wi-Fi and Wi-Fi Aware mechanisms with different platform constraints.



Direct P2P must therefore remain a platform capability rather than an assumption of the core protocol.



\---



\# 12. Transport Layer



The transport layer carries SoundMesh protocol messages.



Possible transport candidates include:



```text

TCP

UDP

QUIC

```



The first MVP should prioritize \*\*reliability and simplicity\*\* over theoretical maximum performance.



Recommended initial split:



```text

TCP

&#x20;├── control messages

&#x20;├── room state

&#x20;├── synchronization commands

&#x20;├── device information

&#x20;└── audio file transfer



UDP

&#x20;└── only if later measurements prove that

&#x20;    a datagram channel is useful for timing/telemetry

```



The architecture must not introduce UDP merely because SoundMesh is an audio application.



\---



\# 13. SoundMesh Protocol



The protocol must be versioned.



Conceptually:



```text

Message

├── protocolVersion

├── messageType

├── messageId

├── sessionId

├── generation

├── senderId

└── payload

```



Examples:



```text

HELLO

WELCOME

ROOM\_STATE

DEVICE\_CAPABILITIES

AUDIO\_METADATA

AUDIO\_TRANSFER\_START

AUDIO\_TRANSFER\_COMPLETE

SYNC\_REQUEST

SYNC\_RESPONSE

CALIBRATION\_START

CALIBRATION\_RESULT

PLAYBACK\_PREPARE

PLAYBACK\_START

PLAYBACK\_PAUSE

PLAYBACK\_RESUME

PLAYBACK\_SEEK

PLAYBACK\_STOP

PLAYBACK\_STATUS

DRIFT\_REPORT

CORRECTION\_COMMAND

HEARTBEAT

LEAVE

ERROR

```



Exact message schemas belong in `networking.md`.



\---



\# 14. Protocol Versioning



Every network message must contain enough information to detect incompatible protocol versions.



The application must never silently assume:



```text

same app version = same protocol

```



Instead:



```text

App version

≠

Protocol version

```



A future application update may retain compatibility with older protocol versions.



Compatibility rules belong in `networking.md`.



\---



\# 15. Flutter ↔ Native Boundary



The Flutter layer must communicate with native functionality through explicit interfaces.



Conceptually:



```text

Dart

&#x20;│

&#x20;▼

Platform Interface

&#x20;│

&#x20;├───────────────┐

&#x20;▼               ▼

Android         iOS

Kotlin          Swift

```



Flutter officially supports platform channels and custom plugins for accessing platform-specific APIs. Type-safe generated interfaces such as Pigeon may also be used where appropriate.



\---



\# 16. Platform Interface Design



The Dart application should see interfaces such as:



```text

NetworkPlatform

AudioPlatform

DevicePlatform

LifecyclePlatform

```



Example conceptual API:



```text

NetworkPlatform.startDiscovery()

NetworkPlatform.stopDiscovery()

NetworkPlatform.connect(endpoint)

NetworkPlatform.send(message)

NetworkPlatform.disconnect(deviceId)

```



Audio:



```text

AudioPlatform.prepare(asset)

AudioPlatform.schedulePlayback(targetTime)

AudioPlatform.pause()

AudioPlatform.resume()

AudioPlatform.seek(position)

AudioPlatform.stop()

AudioPlatform.getPlaybackClock()

AudioPlatform.getPlaybackPosition()

```



The actual API names are implementation details.



The architectural rule is that Flutter must not directly depend on Android or iOS classes.



\---



\# 17. Native Audio Architecture



The audio system is timing-critical.



Therefore:



```text

Flutter

&#x20; │

&#x20; │ high-level commands

&#x20; ▼

Native Audio Controller

&#x20; │

&#x20; ▼

Native Audio Engine

&#x20; │

&#x20; ▼

Operating System Audio Pipeline

&#x20; │

&#x20; ▼

Speaker / Headphones

```



Flutter should not be responsible for pushing individual audio frames at realtime frequency.



\---



\# 18. Android Audio



Android's current high-performance audio APIs include AAudio, with Google recommending Oboe as a C++ wrapper for high-performance cross-device audio. Android also provides `AudioTrack`, including timestamp and low-latency facilities.



The Android implementation should therefore be designed around a native audio abstraction capable of using:



```text

Oboe / AAudio

```



where appropriate.



The architecture must not assume that every Android device provides identical latency.



Android audio output latency varies by hardware and configuration, so SoundMesh must measure behavior rather than assume a universal fixed value.



\---



\# 19. iOS Audio



The iOS implementation should use native AVFoundation audio facilities.



`AVAudioPlayerNode` supports scheduling audio buffers/files against an audio timeline, which is directly relevant to SoundMesh's scheduled-playback model.



Conceptually:



```text

SoundMesh target time

&#x20;       │

&#x20;       ▼

iOS native audio scheduler

&#x20;       │

&#x20;       ▼

AVAudioEngine / AVAudioPlayerNode

&#x20;       │

&#x20;       ▼

Audio output

```



Exact AVAudioSession configuration belongs in `audio.md`.



\---



\# 20. Shared Audio Model



Regardless of platform, the application should expose a common conceptual model:



```text

Audio Asset

&#x20;    │

&#x20;    ▼

Decoded / prepared representation

&#x20;    │

&#x20;    ▼

Buffered audio

&#x20;    │

&#x20;    ▼

Scheduled playback

&#x20;    │

&#x20;    ▼

Playback clock

```



Android and iOS may implement these stages differently.



The synchronization layer must not depend on platform-specific class names.



\---



\# 21. Audio Distribution



Preferred flow:



```text

Host selects audio

&#x20;       │

&#x20;       ▼

Calculate metadata/hash

&#x20;       │

&#x20;       ▼

Participants check whether asset exists

&#x20;       │

&#x20;       ├── yes → reuse local asset

&#x20;       │

&#x20;       └── no  → transfer asset

&#x20;       │

&#x20;       ▼

All participants prepare audio

&#x20;       │

&#x20;       ▼

Synchronization begins

```



The audio file should preferably be transferred before synchronized playback begins.



This allows the playback phase to depend primarily on timing rather than continuous network delivery.



\---



\# 22. Audio Identity



An audio asset must have a deterministic identity.



A content hash should be used where practical.



Conceptually:



```text

assetId = hash(audio-content)

```



This allows:



\* duplicate detection;

\* transfer verification;

\* caching;

\* recovery;

\* future reuse.



The exact hashing algorithm remains an implementation decision.



\---



\# 23. Synchronization Architecture



Synchronization is composed of:



```text

┌───────────────────────────────┐

│ Clock Measurement             │

├───────────────────────────────┤

│ Network Latency Measurement   │

├───────────────────────────────┤

│ Clock Offset Estimation       │

├───────────────────────────────┤

│ Playback Scheduling           │

├───────────────────────────────┤

│ Playback Position Monitoring  │

├───────────────────────────────┤

│ Drift Detection               │

├───────────────────────────────┤

│ Drift Correction              │

└───────────────────────────────┘

```



The synchronization subsystem must not depend on UI frame timing.



\---



\# 24. Shared Timeline



SoundMesh needs a logical shared timeline.



For example:



```text

T = 0 ms

│

├── calibration

│

├── preparation

│

├── scheduled start

│

├── playback

│

├── drift measurement

│

└── correction

```



The host establishes a session timeline.



Each device estimates how its local clock corresponds to that timeline.



\---



\# 25. Synchronization Data Flow



Conceptually:



```text

Participant

&#x20;    │

&#x20;    │ timestamp request

&#x20;    ▼

Host

&#x20;    │

&#x20;    │ timestamp response

&#x20;    ▼

Participant

&#x20;    │

&#x20;    ▼

Estimate:

\- round-trip time

\- clock offset

\- timing uncertainty

&#x20;    │

&#x20;    ▼

Calibration result

&#x20;    │

&#x20;    ▼

Playback scheduler

```



Multiple measurements should be preferred over a single timing sample.



The synchronization algorithm must account for network jitter and asymmetric delays.



Exact estimation methods belong in `synchronization.md`.



\---



\# 26. Playback Scheduling



SoundMesh should use \*\*scheduled future playback\*\*, not immediate commands.



Bad architecture:



```text

PLAY NOW

```



Preferred architecture:



```text

PLAY AT SHARED TIMELINE = X

```



This provides time for:



\* network propagation;

\* device preparation;

\* audio buffering;

\* scheduler setup;

\* native audio startup.



The scheduled start should be sufficiently far in the future to accommodate measured system uncertainty.



The exact scheduling margin must be experimentally determined.



\---



\# 27. Drift Correction



Two devices can begin together and gradually diverge.



Therefore:



```text

Synchronization

≠

One-time calibration

```



The system must continuously or periodically monitor playback position.



Conceptually:



```text

Expected position

&#x20;      │

&#x20;      ▼

Actual position

&#x20;      │

&#x20;      ▼

Error

&#x20;      │

&#x20;      ├── acceptable → continue

&#x20;      │

&#x20;      └── excessive → correction

```



Correction strategies may include:



\* small playback-rate adjustment;

\* controlled rescheduling;

\* tiny seek correction;

\* pause/resume correction for large errors.



The selected correction mechanism must be experimentally validated.



Abrupt repeated seeking should be avoided because it can create audible artifacts.



\---



\# 28. Correction Safety



A correction must not make the system worse.



Every correction operation should consider:



```text

current error

error trend

correction magnitude

audio position

device capability

network stability

```



The system should avoid oscillating between:



```text

too early

→ correction

→ too late

→ correction

→ too early

```



A stable control strategy is required.



\---



\# 29. Room State Machine



The architecture follows the state model defined in `blueprint.md`.



```text

CREATED

&#x20;  ↓

DISCOVERABLE

&#x20;  ↓

JOINING

&#x20;  ↓

CALIBRATING

&#x20;  ↓

READY

&#x20;  ↓

PLAYING

&#x20;  ↓

PAUSED

&#x20;  ↓

PLAYING

&#x20;  ↓

ENDING

&#x20;  ↓

CLOSED

```



Recovery states may temporarily interrupt this flow:



```text

PLAYING

&#x20;  ↓

RECOVERING

&#x20;  ↓

PLAYING

```



Invalid state transitions must be rejected.



\---



\# 30. Device State Machine



Each participant should independently track its connection and playback state.



Example:



```text

UNKNOWN

&#x20; ↓

DISCOVERED

&#x20; ↓

CONNECTING

&#x20; ↓

CONNECTED

&#x20; ↓

PREPARING

&#x20; ↓

CALIBRATING

&#x20; ↓

READY

&#x20; ↓

PLAYING

&#x20; ↓

DISCONNECTED / RECOVERING

```



The device state must not be inferred solely from UI state.



\---



\# 31. Late Joining



A device joining an already-playing room must not simply begin playback immediately.



Preferred flow:



```text

Join

&#x20;│

&#x20;▼

Authenticate / identify

&#x20;│

&#x20;▼

Receive room state

&#x20;│

&#x20;▼

Obtain audio

&#x20;│

&#x20;▼

Calibrate timing

&#x20;│

&#x20;▼

Calculate current playback position

&#x20;│

&#x20;▼

Schedule entry

&#x20;│

&#x20;▼

Join playback

```



The late-join algorithm belongs in `synchronization.md`.



\---



\# 32. Pause and Resume



Pause is a coordinated operation.



Host:



```text

PAUSE AT / PAUSE NOW

```



Participants:



```text

receive command

→ capture local playback position

→ pause native playback

→ report state

```



Resume should use a future synchronized timestamp rather than an immediate command whenever possible.



\---



\# 33. Seeking



Seeking changes the shared playback position.



Therefore:



```text

seek(position)

```



must be treated as a synchronization event.



Preferred flow:



```text

Host selects position

&#x20;       │

&#x20;       ▼

Broadcast target position

&#x20;       │

&#x20;       ▼

Participants prepare local audio position

&#x20;       │

&#x20;       ▼

Host selects future synchronized start

&#x20;       │

&#x20;       ▼

All devices resume

```



\---



\# 34. Host Failure



The MVP may treat the host as authoritative.



If the host disappears:



```text

PLAYING

&#x20;  ↓

HOST LOST

&#x20;  ↓

RECOVERY

```



The first MVP does not require seamless host migration.



Host migration is an advanced capability and should not complicate the initial implementation unless testing demonstrates that it is essential.



\---



\# 35. Participant Failure



A participant disconnecting must not stop the entire room.



Preferred behavior:



```text

Participant disconnects

&#x20;       │

&#x20;       ▼

Host marks participant unavailable

&#x20;       │

&#x20;       ▼

Remaining devices continue

```



The UI should clearly show that the device left the synchronized group.



\---



\# 36. Network Failure



Temporary network loss should be distinguishable from permanent disconnect.



Conceptual states:



```text

CONNECTED

&#x20;  ↓

DEGRADED

&#x20;  ↓

RECOVERING

&#x20;  ↓

CONNECTED

```



The system should use buffered playback where possible so that short network interruptions do not immediately interrupt audio.



\---



\# 37. Audio Route Changes



A participant may change audio output:



```text

Speaker

&#x20; ↓

Bluetooth headphones

```



or:



```text

Bluetooth

&#x20; ↓

Phone speaker

```



The audio subsystem must notify the synchronization subsystem because output-route changes can alter timing and latency.



The system may need to recalibrate after significant route changes.



\---



\# 38. App Lifecycle



Mobile operating systems can:



\* background apps;

\* suspend execution;

\* interrupt audio;

\* change network availability;

\* revoke or alter resources;

\* terminate processes.



Therefore the architecture must treat lifecycle events as first-class system events.



Example:



```text

ACTIVE

&#x20; ↓

BACKGROUND

&#x20; ↓

INTERRUPTED / SUSPENDED

&#x20; ↓

FOREGROUND

&#x20; ↓

REVALIDATE

```



The application must not assume that a backgrounded device continues behaving exactly like a foreground device.



\---



\# 39. Flutter Lifecycle vs Playback Lifecycle



These are different concepts.



```text

Flutter UI lifecycle

&#x20;       ≠

Network lifecycle

&#x20;       ≠

Audio lifecycle

&#x20;       ≠

Room lifecycle

```



For example:



```text

Flutter screen disappears

```



does not necessarily mean:



```text

Room ended

```



The architecture must keep these lifecycles separate.



\---



\# 40. Diagnostics Architecture



SoundMesh must expose measurable internal state.



Important metrics include:



```text

RTT

Clock offset estimate

Timing uncertainty

Estimated sync error

Playback position

Drift rate

Correction amount

Buffer level

Network state

Packet/message loss

Audio underruns

CPU usage

Memory usage

Battery state

```



These metrics should be available to a diagnostics layer.



They should not require developers to attach a debugger to understand basic synchronization failures.



\---



\# 41. Developer Diagnostics



A developer/debug mode should eventually provide information such as:



```text

Room

&#x20; ID: ABC123

&#x20; Host: Device A



Participants

&#x20; Device B

&#x20;   RTT: XX ms

&#x20;   Offset: XX ms

&#x20;   Sync error: XX ms

&#x20;   Drift: XX ms/s

&#x20;   Buffer: XX ms



&#x20; Device C

&#x20;   RTT: XX ms

&#x20;   Offset: XX ms

&#x20;   Sync error: XX ms

&#x20;   Drift: XX ms/s

&#x20;   Buffer: XX ms

```



Exact metrics and UI belong in `testing.md` and `ui-ux.md`.



\---



\# 42. Security Boundary



SoundMesh is local-first, but local does not automatically mean secure.



The architecture should eventually protect:



\* room membership;

\* control commands;

\* audio transfer;

\* protocol integrity.



At minimum, participants should not be able to accidentally control unrelated SoundMesh rooms on the same network.



The exact authentication/pairing mechanism remains `UNDECIDED`.



\---



\# 43. Room Identity



Rooms should use unpredictable identifiers.



A room identifier should not simply be:



```text

Room 1

```



or:



```text

192.168.1.5

```



The room should have an application-level identity separate from network addressing.



\---



\# 44. QR Code Architecture



QR codes should contain enough information for joining without requiring the user to manually type network details.



Conceptually:



```text

SoundMesh Join Payload

│

├── protocol version

├── room identifier

├── host/service information

└── short-lived join information

```



The QR code is an onboarding mechanism.



It must not become the synchronization protocol.



\---



\# 45. Platform Permission Architecture



Permissions must be handled by the platform layer and exposed to Flutter through a common state model.



Example:



```text

PermissionState

├── granted

├── denied

├── restricted

└── unavailable

```



The Flutter UI can then present appropriate instructions.



Platform-specific permission differences must remain inside platform implementations.



\---



\# 46. iOS Local Network Considerations



iOS local-network communication requires appropriate local-network privacy configuration.



Bonjour-based discovery also requires declaring the appropriate service types.



The application must therefore treat local-network permission as part of the networking initialization process rather than as an afterthought.



\---



\# 47. Android Wi-Fi Considerations



Android versions differ in their Wi-Fi permissions and capabilities.



Modern Android requires the appropriate nearby-Wi-Fi permission for relevant Wi-Fi APIs, and older Android versions have different permission requirements.



Therefore the networking implementation must use capability detection and version-aware permission handling.



\---



\# 48. Platform Abstraction Rule



Never write:



```text

if Android:

&#x20;   implement entire feature

else if iOS:

&#x20;   implement completely different feature

```



Instead:



```text

Common SoundMesh Interface

&#x20;         │

&#x20;    ┌────┴────┐

&#x20;    ▼         ▼

&#x20;Android      iOS

implementation implementation

```



Platform differences should exist behind explicit interfaces.



\---



\# 49. Suggested Flutter Project Boundaries



The eventual project should approximately follow:



```text

lib/

├── app/

│   ├── app.dart

│   ├── routing/

│   └── theme/

│

├── presentation/

│   ├── home/

│   ├── create\_room/

│   ├── join\_room/

│   ├── room/

│   ├── playback/

│   └── diagnostics/

│

├── application/

│   ├── room/

│   ├── playback/

│   ├── devices/

│   └── recovery/

│

├── domain/

│   ├── room/

│   ├── device/

│   ├── audio/

│   ├── playback/

│   └── synchronization/

│

├── infrastructure/

│   ├── networking/

│   ├── audio/

│   ├── platform/

│   └── storage/

│

└── shared/

&#x20;   ├── models/

&#x20;   ├── errors/

&#x20;   ├── logging/

&#x20;   └── utilities/

```



This is an architectural direction, not a requirement to create every directory immediately.



\---



\# 50. Native Project Boundaries



Android:



```text

android/

└── app/

&#x20;   └── src/

&#x20;       └── main/

&#x20;           ├── kotlin/

&#x20;           │   └── .../

&#x20;           │       ├── networking/

&#x20;           │       ├── audio/

&#x20;           │       ├── synchronization/

&#x20;           │       └── platform/

&#x20;           │

&#x20;           └── cpp/

&#x20;               └── audio/

```



The exact native structure may change if an existing Flutter plugin provides an appropriate abstraction.



iOS:



```text

ios/

└── Runner/

&#x20;   ├── Networking/

&#x20;   ├── Audio/

&#x20;   ├── Synchronization/

&#x20;   └── Platform/

```



Native code must remain isolated from UI implementation.



\---



\# 51. Synchronization Ownership



The synchronization system should eventually be split into:



```text

SyncCoordinator

&#x20;      │

&#x20;      ├── ClockEstimator

&#x20;      ├── LatencyEstimator

&#x20;      ├── CalibrationEngine

&#x20;      ├── PlaybackScheduler

&#x20;      ├── DriftDetector

&#x20;      └── CorrectionEngine

```



No UI component should calculate clock offsets.



No screen should directly control drift correction.



\---



\# 52. Audio Ownership



Audio should eventually be split into:



```text

AudioCoordinator

&#x20;      │

&#x20;      ├── AssetManager

&#x20;      ├── Decoder

&#x20;      ├── BufferManager

&#x20;      ├── NativeAudioEngine

&#x20;      ├── PlaybackClock

&#x20;      └── RouteManager

```



The synchronization system interacts with the audio system through explicit commands and measurements.



\---



\# 53. Networking Ownership



Networking should eventually be split into:



```text

NetworkCoordinator

&#x20;      │

&#x20;      ├── DiscoveryService

&#x20;      ├── ConnectionManager

&#x20;      ├── Transport

&#x20;      ├── ProtocolCodec

&#x20;      └── NetworkMonitor

```



The application layer should not care whether discovery uses Bonjour, Android NSD, Wi-Fi P2P, or another mechanism.



\---



\# 54. Dependency Direction



Dependencies should point inward.



Preferred:



```text

Presentation

&#x20;    ↓

Application

&#x20;    ↓

Domain

&#x20;    ↑

Infrastructure

&#x20;    ↑

Platform

```



The domain must not depend directly on:



```text

Flutter widgets

Android APIs

iOS APIs

socket implementations

audio drivers

```



\---



\# 55. No Global God Controller



Avoid creating one enormous class such as:



```text

SoundMeshManager

```



that owns:



\* networking;

\* audio;

\* synchronization;

\* UI;

\* room state;

\* device state;

\* permissions;

\* storage.



This would create an untestable architecture.



Instead, responsibilities must remain separated.



\---



\# 56. Event-Driven Communication



Subsystems should communicate using explicit events or commands.



Example:



```text

Network:

&#x20;   ParticipantConnected



Room:

&#x20;   ParticipantReady



Synchronization:

&#x20;   CalibrationCompleted



Audio:

&#x20;   PlaybackPrepared



Playback:

&#x20;   PlaybackStarted

```



This prevents tightly coupled components.



\---



\# 57. Commands vs Events



Use a conceptual distinction:



\### Commands



Something wants an action performed.



```text

StartPlayback

PausePlayback

SeekPlayback

JoinRoom

LeaveRoom

Calibrate

```



\### Events



Something already happened.



```text

ParticipantConnected

PlaybackStarted

PlaybackEnded

NetworkDisconnected

CalibrationCompleted

```



AI agents should preserve this distinction when designing application code.



\---



\# 58. Error Handling



Errors should be structured.



Avoid relying only on strings such as:



```text

"Something went wrong"

```



Prefer:



```text

SoundMeshError

├── NetworkError

├── DiscoveryError

├── PermissionError

├── ProtocolError

├── AudioError

├── SynchronizationError

├── AssetTransferError

└── LifecycleError

```



Errors should contain enough information for:



\* user-facing messaging;

\* developer diagnostics;

\* recovery decisions;

\* logging.



\---



\# 59. Logging



Logging should be structured.



Important fields may include:



```text

timestamp

deviceId

roomId

sessionId

component

event

severity

message

metadata

```



Synchronization logs must include timing information.



Example:



```text

SYNC\_CALIBRATION\_RESULT

device=B

offset=...

rtt=...

uncertainty=...

```



Sensitive user data must not be logged unnecessarily.



\---



\# 60. Performance Rule



UI performance and synchronization performance are separate concerns.



A slow Flutter rebuild must never directly cause audio timing failure.



A network callback must never block the audio callback.



An audio callback must never perform:



\* network operations;

\* disk I/O;

\* expensive allocation;

\* UI operations.



\---



\# 61. Real-Time Audio Rule



Timing-critical audio code must be designed around realtime constraints.



Android's audio documentation specifically highlights buffer sizing, high-priority callbacks, and low-latency modes for high-performance audio applications.



Therefore:



```text

Audio callback

&#x20;   ↓

minimal work

&#x20;   ↓

no blocking network

&#x20;   ↓

no UI calls

&#x20;   ↓

no unnecessary allocation

```



\---



\# 62. Storage



Local storage should be used for:



\* downloaded audio;

\* room/session metadata where necessary;

\* cached assets;

\* diagnostic information where appropriate.



The architecture should not introduce a remote database for MVP.



\---



\# 63. No Backend Requirement



The MVP must be capable of operating with:



```text

Phone A

Phone B

Phone C

```



and no:



```text

Firebase

Supabase

custom server

cloud database

cloud audio server

```



A backend may be introduced later for optional features, but the synchronized-speaker core must remain locally functional.



\---



\# 64. Data Flow: Create Room



```text

User

&#x20;│

&#x20;▼

Flutter UI

&#x20;│

&#x20;▼

RoomController

&#x20;│

&#x20;▼

Room created

&#x20;│

&#x20;▼

NetworkCoordinator

&#x20;│

&#x20;▼

Native discovery/advertising

&#x20;│

&#x20;▼

Room becomes discoverable

```



\---



\# 65. Data Flow: Join Room



```text

User scans QR

&#x20;│

&#x20;▼

Flutter parses join payload

&#x20;│

&#x20;▼

NetworkCoordinator

&#x20;│

&#x20;▼

Connect to host

&#x20;│

&#x20;▼

Protocol handshake

&#x20;│

&#x20;▼

Device identified

&#x20;│

&#x20;▼

Room state received

&#x20;│

&#x20;▼

Participant enters preparation

```



\---



\# 66. Data Flow: Start Playback



```text

Host

&#x20;│

&#x20;▼

Select audio

&#x20;│

&#x20;▼

Asset verification / transfer

&#x20;│

&#x20;▼

Participants prepare

&#x20;│

&#x20;▼

Clock calibration

&#x20;│

&#x20;▼

Host creates future playback timestamp

&#x20;│

&#x20;▼

PLAYBACK\_PREPARE

&#x20;│

&#x20;▼

Participants schedule native playback

&#x20;│

&#x20;▼

PLAYBACK\_START

&#x20;│

&#x20;▼

Synchronized playback

```



\---



\# 67. Data Flow: Drift Correction



```text

Playback

&#x20;  │

&#x20;  ▼

Measure local position

&#x20;  │

&#x20;  ▼

Compare against shared timeline

&#x20;  │

&#x20;  ▼

Estimate synchronization error

&#x20;  │

&#x20;  ├── small → continue

&#x20;  │

&#x20;  └── large → correction

&#x20;                   │

&#x20;                   ▼

&#x20;             native audio adjustment

```



\---



\# 68. Data Flow: Participant Disconnect



```text

Network failure

&#x20;     │

&#x20;     ▼

Native network layer

&#x20;     │

&#x20;     ▼

NetworkCoordinator

&#x20;     │

&#x20;     ▼

Room state update

&#x20;     │

&#x20;     ▼

Host removes/degrades participant

&#x20;     │

&#x20;     ▼

Flutter UI updates

```



The UI does not directly determine that the participant disconnected.



\---



\# 69. Architecture Invariants



The following rules are considered architectural invariants.



\## INV-001



Flutter UI must never be responsible for realtime audio scheduling.



\## INV-002



Synchronization calculations must not depend on Flutter frame timing.



\## INV-003



The internet must not be required for ordinary local playback.



\## INV-004



Platform-specific functionality must be isolated behind interfaces.



\## INV-005



Audio callbacks must not perform network or UI work.



\## INV-006



A participant disconnect must not automatically terminate the room.



\## INV-007



The system must not assume all devices have identical clocks.



\## INV-008



The system must not assume all devices have identical audio latency.



\## INV-009



The system must measure synchronization rather than assume it.



\## INV-010



Protocol messages must be versioned.



\## INV-011



Room state and Flutter UI state must remain separate concepts.



\## INV-012



Architecture decisions must not silently convert `UNDECIDED` requirements into permanent implementation choices.



\---



\# 70. Explicit Non-Goals



This architecture does not currently attempt to solve:



\* professional multi-room audio;

\* studio-grade sample synchronization;

\* arbitrary internet-based synchronization;

\* unlimited device counts;

\* automatic host migration;

\* cross-continent synchronized playback;

\* cloud-hosted audio streaming;

\* every Android/iOS version;

\* every possible Bluetooth audio configuration;

\* perfect mathematical synchronization.



The goal is a robust consumer-level local synchronized speaker experience.



\---



\# 71. MVP Architecture Scope



The first implementation should target:



```text

Flutter UI

\+

Android native support

\+

iOS native support

\+

Local network discovery

\+

Reliable local connection

\+

Audio asset transfer

\+

Native local playback

\+

Clock calibration

\+

Scheduled playback

\+

Basic drift measurement

\+

Basic drift correction

```



The first physical test target should be:



```text

2 phones

```



Then:



```text

3 phones

↓

5 phones

↓

larger groups

```



The architecture must not be optimized for ten or twenty devices before two-device synchronization works reliably.



\---



\# 72. Experimental Architecture



The following areas are explicitly experimental:



```text

Direct Wi-Fi P2P

Phone hotspot automation

UDP timing channel

QUIC transport

Automatic playback-rate correction

Host migration

Large device groups

Advanced background playback

Cross-platform peer discovery without infrastructure

```



Experimental features must not become MVP dependencies until validated.



\---



\# 73. Current Architectural Decisions



\### DEC-ARCH-001



\*\*Decision:\*\* SoundMesh will use Flutter as the primary application framework.



\*\*Reason:\*\* Cross-platform UI and application logic can be shared while still allowing native Android/iOS integration.



\---



\### DEC-ARCH-002



\*\*Decision:\*\* Native platform implementations are allowed and expected for timing-critical functionality.



\*\*Reason:\*\* Flutter provides platform integration mechanisms, while audio/network primitives may require direct native APIs.



\---



\### DEC-ARCH-003



\*\*Decision:\*\* Synchronization will be implemented as an independent subsystem.



\*\*Reason:\*\* Synchronization is the core technical problem and must not be buried inside UI, networking, or playback code.



\---



\### DEC-ARCH-004



\*\*Decision:\*\* Local playback is preferred over continuous host-to-participant audio streaming.



\*\*Reason:\*\* This reduces dependence on continuous network timing and allows synchronization to focus primarily on playback scheduling.



\---



\### DEC-ARCH-005



\*\*Decision:\*\* The first networking target is local-network operation.



\*\*Reason:\*\* It provides a practical common environment across platforms while direct P2P mechanisms have platform-specific differences.



\---



\### DEC-ARCH-006



\*\*Decision:\*\* iOS networking should target Apple's modern Network framework rather than building new architecture around Multipeer Connectivity.



\*\*Reason:\*\* Apple's current documentation directs developers toward Network framework and marks Multipeer Connectivity deprecated.



\---



\# 74. Decisions Still UNDECIDED



The following must not be silently decided by an AI agent:



```text

UNDECIDED-001

Exact Flutter state-management solution.



UNDECIDED-002

Exact Flutter networking package, if any.



UNDECIDED-003

Whether to use custom native networking or an existing Flutter plugin.



UNDECIDED-004

Exact transport protocol.



UNDECIDED-005

Whether TCP alone is sufficient.



UNDECIDED-006

Whether a UDP timing channel is necessary.



UNDECIDED-007

Exact service-discovery implementation.



UNDECIDED-008

Exact hotspot strategy.



UNDECIDED-009

Whether direct Wi-Fi P2P belongs in MVP.



UNDECIDED-010

Exact audio codec support.



UNDECIDED-011

Exact audio decoding library.



UNDECIDED-012

Exact Android audio implementation.



UNDECIDED-013

Exact iOS audio implementation details.



UNDECIDED-014

Clock synchronization algorithm.



UNDECIDED-015

Latency estimation algorithm.



UNDECIDED-016

Drift correction algorithm.



UNDECIDED-017

Target synchronization error threshold.



UNDECIDED-018

Maximum supported device count.



UNDECIDED-019

Host migration strategy.



UNDECIDED-020

Room authentication mechanism.



UNDECIDED-021

Audio asset hashing algorithm.



UNDECIDED-022

Background execution strategy.



UNDECIDED-023

Exact local persistence mechanism.



UNDECIDED-024

Exact diagnostics format.



UNDECIDED-025

Production optimization strategy.

```



\---



\# 75. Architecture Decision Rule



Before permanently choosing a significant technology or algorithm, the team must:



1\. define the problem;

2\. identify realistic alternatives;

3\. research platform constraints;

4\. build a minimal experiment;

5\. measure the result;

6\. document the evidence;

7\. choose an approach;

8\. record the decision in `DOCS/decisions.md`.



Do not choose technology merely because:



```text

"It is popular."

```



or:



```text

"An AI suggested it."

```



or:



```text

"It looks easier."

```



SoundMesh's central engineering decisions must be evidence-driven.



\---



\# 76. Architecture Testing Philosophy



Architecture must be validated with physical devices.



At minimum:



```text

Android ↔ Android

Android ↔ iOS

iOS ↔ iOS

```



should eventually be tested.



A synchronization architecture that works perfectly between two identical phones but fails across heterogeneous devices is not considered complete.



\---



\# 77. Required Early Experiments



Before implementing the full product, the team should validate:



\### Experiment 1 — Local discovery



Can two SoundMesh instances discover each other reliably?



\### Experiment 2 — Connection



Can they establish a stable local connection?



\### Experiment 3 — Clock measurement



Can the application obtain sufficiently stable timing measurements?



\### Experiment 4 — Audio scheduling



Can native audio begin playback at a scheduled target time?



\### Experiment 5 — Two-device synchronization



Can two different phones start the same audio perceptually together?



\### Experiment 6 — Drift



Do the devices remain synchronized over several minutes?



\### Experiment 7 — Correction



Can measurable drift be corrected without obvious audible artifacts?



\### Experiment 8 — Heterogeneous devices



Does the system remain reliable when devices differ significantly?



These experiments should precede large-scale feature development.



\---



\# 78. Architecture Success Criteria



The architecture is successful when developers can answer all of the following without ambiguity:



\* Where does room state live?

\* Where does networking live?

\* Where does synchronization live?

\* Where does audio playback live?

\* Where does platform-specific code live?

\* How does Flutter communicate with native code?

\* How does a host command synchronized playback?

\* How does a participant calculate when to play?

\* How is drift detected?

\* How is drift corrected?

\* What happens when a participant disconnects?

\* What happens when the network temporarily fails?

\* What happens when audio output changes?

\* What happens when the app is backgrounded?

\* Which decisions are still experimental?

\* Which components can be tested independently?



If these answers cannot be given clearly, the architecture is not sufficiently defined.



\---



\# 79. Relationship to Other Documents



This document defines \*\*system structure\*\*.



Other documents own the following:



| Document              | Responsibility                                        |

| --------------------- | ----------------------------------------------------- |

| `blueprint.md`        | Product definition and boundaries                     |

| `architecture.md`     | System architecture and component boundaries          |

| `synchronization.md`  | Timing, clocks, calibration, drift, correction        |

| `networking.md`       | Discovery, connections, transport, protocol           |

| `audio.md`            | Audio formats, decoding, buffering, native playback   |

| `ui-ux.md`            | User experience and interface                         |

| `testing.md`          | Validation, experiments, benchmarks, acceptance tests |

| `decisions.md`        | Significant engineering decisions                     |

| `roadmap.md`          | Development sequence and milestones                   |

| `AI/ai-context.md`    | Context AI agents need                                |

| `AI/rules.md`         | Rules AI agents must follow                           |

| `AI/task-protocol.md` | How AI agents should execute tasks                    |



If two documents disagree, the conflict must be explicitly resolved rather than silently choosing one.



\---



\# 80. Definition of Done



This architecture document is considered complete for the current planning stage when:



\* Flutter is established as the primary application framework;

\* Flutter/native boundaries are defined;

\* Android and iOS responsibilities are separated;

\* networking responsibilities are separated from synchronization;

\* audio responsibilities are separated from synchronization;

\* host/participant architecture is defined;

\* room and device state concepts are defined;

\* synchronized scheduled playback is established as the architectural model;

\* local-first operation is established;

\* failure/recovery boundaries are defined;

\* platform-specific constraints are acknowledged;

\* architectural invariants are documented;

\* major undecided decisions are explicitly marked;

\* future developers can determine where a new feature belongs.



This document must evolve as experiments produce real evidence.



\---



\# 81. Final Architectural Principle



SoundMesh is not fundamentally a Flutter UI project.



It is a \*\*distributed real-time audio system with a Flutter application layer\*\*.



Flutter gives SoundMesh:



\* shared UI;

\* shared application logic;

\* rapid development;

\* cross-platform product consistency.



Native platform layers give SoundMesh:



\* precise audio control;

\* platform-specific networking;

\* operating-system integration;

\* hardware-aware behavior.



The architecture therefore follows one central rule:



> \*\*Share everything that can safely be shared. Isolate everything that must be platform-specific. Measure everything that affects synchronization.\*\*



And the most important boundary in the entire system is:



```text

&#x20;                SOUNDMesh

&#x20;                    │

&#x20;         ┌──────────┴──────────┐

&#x20;         │                     │

&#x20;      PRODUCT                REAL-TIME

&#x20;      LAYER                    LAYER

&#x20;         │                     │

&#x20;      Flutter              Native

&#x20;         │                     │

&#x20;         ▼                     ▼

&#x20;      UI / State        Audio / Network

&#x20;      Workflow          Timing / Hardware

```



The user should experience:



> \*\*"All our phones just became one speaker."\*\*



The engineering underneath should be considerably more complicated.



That complexity belongs inside the architecture—not in the user's experience.



