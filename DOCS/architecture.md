# SoundMesh — System Architecture

**Document:** `DOCS/architecture.md`
**Status:** Living engineering specification
**Authority:** System architecture and component-boundary definition
**Project:** SoundMesh
**Platform direction:** Flutter-based mobile application with native Android real-time audio/network layers
**Primary MVP platform:** Android

---

# 1. Purpose

This document defines the technical architecture of SoundMesh.

Its purpose is to provide developers and AI coding agents with a precise model of:

* how SoundMesh is divided into components;
* which components own which responsibilities;
* how Flutter interacts with native platform functionality;
* how devices communicate;
* how rooms and live audio sessions are represented;
* how external application audio is captured;
* how captured audio is transported;
* how synchronized audio output is scheduled;
* where synchronization logic lives;
* how timing-critical operations are isolated from UI code;
* how platform-specific differences are contained;
* how the architecture can evolve without rewriting the entire application.

This document is implementation-oriented.

It does **not** define every implementation detail. Detailed synchronization algorithms belong in `DOCS/synchronization.md`, networking protocols belong in `DOCS/networking.md`, and audio capture/output details belong in `DOCS/audio.md`.

SoundMesh is **not a media player** and does not own the media being played by an external application.

---

# 2. Architectural Summary

SoundMesh is a **Flutter-first, native-capable, local-first distributed live-audio synchronization system**.

The MVP is Android-first and may be Android-only because the core feature depends on Android's external application audio-capture capabilities.

The architecture has five major logical layers:

```text
┌──────────────────────────────────────────────────────┐
│                    Flutter UI                        │
│ Screens • Widgets • User Interaction • Visual State │
└──────────────────────────┬───────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────┐
│              Flutter Application Layer               │
│ Room State • Session State • Commands • Controllers  │
└──────────────────────────┬───────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────┐
│              Flutter Platform Interface              │
│ Typed abstraction over native capture/network/audio  │
└───────────────┬───────────────────────┬──────────────┘
                │                       │
                ▼                       ▼
┌──────────────────────────┐   ┌───────────────────────┐
│ Native Networking Layer  │   │ Native Audio Layer    │
│ discovery • transport   │   │ capture • buffering   │
│ connections • timing    │   │ scheduling • output   │
└──────────────┬───────────┘   └──────────┬────────────┘
               │                          │
               └────────────┬─────────────┘
                            ▼
┌──────────────────────────────────────────────────────┐
│                Operating System / Hardware           │
│ Wi-Fi • Audio Capture • Audio Driver • Speaker       │
└──────────────────────────────────────────────────────┘
```

The central architectural principle is:

> **Flutter should control the product. Native code should control platform-critical timing, capture, networking, and audio behavior.**

Flutter is responsible for application orchestration and user experience.

Native code is responsible for operations where platform APIs, real-time behavior, external-audio capture, or precise audio timing matter.

---

# 3. Core Architectural Principles

## 3.1 Flutter-first

SoundMesh will be implemented primarily in Flutter/Dart.

Flutter should contain:

* UI;
* navigation;
* application state;
* room state representation;
* live-session state representation;
* user-facing workflows;
* configuration;
* diagnostics presentation;
* protocol-independent business logic;
* non-time-critical orchestration.

Flutter should not become responsible for:

* sample-accurate audio scheduling;
* high-frequency audio callbacks;
* moving individual audio frames through Dart;
* platform-specific audio rendering;
* platform-specific network socket internals;
* MediaProjection internals;
* assumptions about Android hardware timing.

---

## 3.2 Native where necessary

SoundMesh will use native platform implementations where Flutter alone cannot reliably provide the required behavior.

For the Android MVP, expected native responsibilities include:

* external application audio capture;
* MediaProjection integration;
* AudioPlaybackCapture;
* foreground-service integration where required;
* native networking;
* socket/transport primitives;
* audio buffering;
* audio timestamps;
* scheduled audio output;
* audio routing;
* lifecycle integration;
* timing-critical synchronization operations.

Future platforms may provide their own implementations behind the same conceptual interfaces.

The native implementations must expose a stable interface to Dart.

---

## 3.3 Local-first

Ordinary SoundMesh operation must not require an internet connection.

The normal architecture assumes:

```text
Device A ─────┐
              │
Device B ─────┼──── Local network
              │
Device C ─────┘
```

The internet is not part of the required audio data path.

No cloud server should be required to:

* create a room;
* join a room;
* capture eligible external audio;
* distribute live audio;
* synchronize participants;
* maintain a local audio session.

Cloud functionality, if ever introduced, must remain optional.

---

## 3.4 Synchronization is a first-class subsystem

Synchronization is not a side effect of networking.

The architecture treats synchronization as its own subsystem:

```text
Audio / Network Timing
        │
        ▼
Timestamp Measurements
        │
        ▼
Clock / Offset Estimation
        │
        ▼
Latency Estimation
        │
        ▼
Shared Audio Timeline
        │
        ▼
Output Scheduling
        │
        ▼
Playback Monitoring
        │
        ▼
Drift Detection
        │
        ▼
Correction
```

The synchronization system must operate independently of Flutter UI frame timing.

---

## 3.5 Live audio streaming is a first-class architecture

SoundMesh no longer assumes that audio should be distributed as a file before playback.

The MVP architecture is based on live captured audio:

```text
External Media App
        │
        ▼
AudioPlaybackCapture
        │
        ▼
Captured Audio Frames
        │
        ▼
Timestamp + Sequence Number
        │
        ▼
Live Audio Transport
        │
        ▼
Participant Jitter Buffer
        │
        ▼
Native Scheduled Audio Output
```

This is fundamentally different from a media-player architecture.

SoundMesh does not need to own:

* the media file;
* media selection;
* decoding of arbitrary external media formats;
* playback position;
* seeking;
* subtitles;
* playback speed;
* media-library management.

The external application remains responsible for those functions.

---

## 3.6 SoundMesh synchronizes sound, not media state

The external application is the source of the media.

SoundMesh synchronizes the resulting captured audio.

Therefore:

```text
External App
    │
    │ owns media playback
    ▼
Host Audio Output
    │
    │ audio capture
    ▼
SoundMesh
    │
    │ live synchronized audio
    ▼
Participants
```

SoundMesh must not attempt to reproduce or control the external application's internal playback state.

---

# 4. System Components

SoundMesh is divided into the following logical components:

```text
SoundMesh

├── Presentation
│   ├── Home
│   ├── Create Room
│   ├── Join Room
│   ├── Room
│   └── Diagnostics
│
├── Application
│   ├── Room Controller
│   ├── Session Controller
│   ├── Device Controller
│   └── Recovery Controller
│
├── Domain
│   ├── Room
│   ├── Device
│   ├── Audio Session
│   ├── Capture State
│   ├── Synchronization State
│   └── Network State
│
├── Synchronization
│   ├── Clock Model
│   ├── Offset Estimator
│   ├── Latency Estimator
│   ├── Calibration
│   ├── Timeline
│   ├── Scheduler
│   ├── Drift Detector
│   └── Correction Controller
│
├── Networking
│   ├── Discovery
│   ├── Connection Manager
│   ├── Control Transport
│   ├── Audio Transport
│   ├── Timing Transport
│   └── Network Monitoring
│
├── Audio
│   ├── External Audio Capture
│   ├── Capture Session
│   ├── Frame Buffer
│   ├── Jitter Buffer
│   ├── Native Audio Output
│   ├── Audio Clock
│   └── Output Route Manager
│
└── Platform
    └── Android Implementation
```

The exact implementation boundaries may evolve, but responsibilities must remain conceptually separated.

---

# 5. Presentation Layer

The presentation layer is the Flutter UI.

It must contain no platform-specific networking or audio implementation.

Examples:

```text
HomeScreen
CreateRoomScreen
JoinRoomScreen
RoomScreen
DeviceList
CaptureStatusWidget
SyncStatusWidget
DiagnosticsScreen
```

UI widgets consume application state.

They do not directly:

* open sockets;
* perform clock calculations;
* capture external audio;
* manipulate native audio buffers;
* schedule native audio;
* implement network discovery;
* manage MediaProjection.

---

# 6. Application Layer

The application layer coordinates user actions with domain systems.

Examples:

```text
RoomController
SessionController
DeviceController
RecoveryController
```

Example flow:

```text
User presses "Create Room"
        │
        ▼
RoomController
        │
        ├── creates Room model
        │
        ├── asks Networking to advertise
        │
        └── updates application state
```

The controller should not know how Android NSD, sockets, MediaProjection, AudioPlaybackCapture, or native audio APIs work.

It should interact with interfaces.

---

# 7. Domain Layer

The domain layer contains platform-independent concepts.

Important domain objects include:

## 7.1 Room

Represents a SoundMesh room.

Conceptual fields:

```text
roomId
hostDeviceId
participants
roomState
protocolVersion
sessionGeneration
createdAt
```

A Room does not contain a media file or audio asset.

---

## 7.2 Device

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

Capabilities may include:

```text
captureSupported
capturePermissionState
audioOutputSupported
supportedSampleRates
supportedChannelCounts
transportCapabilities
```

---

## 7.3 AudioSession

Represents one live synchronized audio session.

Conceptual fields:

```text
sessionId
generation
sourceState
captureState
streamState
timelineState
syncState
outputState
```

The session does not represent a song or media file.

It represents the live audio synchronization process.

---

## 7.4 CaptureState

Represents the state of host-side external audio capture.

Conceptual states:

```text
UNAVAILABLE
PERMISSION_REQUIRED
READY
CAPTURING
INTERRUPTED
REVOKED
ERROR
```

---

## 7.5 SynchronizationState

Represents timing and synchronization information.

Conceptual fields:

```text
clockOffset
roundTripTime
timingUncertainty
estimatedSyncError
driftRate
bufferTarget
lastCorrection
```

---

# 8. Host and Participant Architecture

SoundMesh uses a logical host/participant model.

```text
                  HOST
                   │
        ┌──────────┼──────────┐
        │          │          │
        ▼          ▼          ▼
   Participant Participant Participant
```

The host is the room/session authority.

The host determines:

* room identity;
* participant membership;
* session generation;
* live audio session state;
* synchronized timeline targets;
* authoritative session state.

The host does **not** become the owner of the external media.

The external application remains the source of media playback.

Participants:

* connect to the host;
* report capabilities;
* receive live audio;
* maintain jitter buffers;
* schedule native output;
* report timing/health information;
* perform local synchronization corrections.

---

# 9. Host Is Not the Audio Clock

The host must not simply send:

```text
"PLAY NOW"
```

The system instead establishes a shared timing model.

Conceptually:

```text
Host
 │
 │ synchronized target / timeline
 ▼
Participants
 │
 ├── map shared time to local clock
 ├── receive/buffer live audio
 ├── calculate output timing
 └── schedule native output
```

The host provides authoritative timing information, but each device uses its own local monotonic timing source.

The host's external audio output also introduces an important architectural problem:

```text
External App
     │
     ├──────────────► Host speaker
     │
     └── Capture ───► SoundMesh ───► Participant
```

The host's direct output path and participant replay path may have different latency.

Therefore the architecture must support measuring:

```text
capture latency
network latency
buffering latency
native output latency
host direct-output latency
```

The exact host-output synchronization strategy remains experimental until measured.

Detailed clock mathematics belong in:

`DOCS/synchronization.md`

---

# 10. Networking Architecture

Networking is divided into independent responsibilities:

```text
Discovery
    │
    ▼
Connection
    │
    ▼
Control Transport
    │
    ├──────────────┐
    ▼              ▼
Audio Transport  Timing Transport
```

These must not be treated as one undifferentiated subsystem.

The networking layer carries three logical planes:

```text
CONTROL PLANE
Room state
Device state
Session state
Permissions
Errors
Heartbeats
Commands

AUDIO DATA PLANE
Captured audio frames
Sequence numbers
Timestamps
Stream configuration
Loss/reordering information

TIMING PLANE
Timestamp exchange
RTT
Clock offset inputs
Timing uncertainty
Capture/output timing measurements
```

The physical transport may initially be shared, but the logical responsibilities must remain separate.

---

# 11. Networking Strategy

The MVP targets local operation.

## Mode A — Existing local network

```text
Phone A ─┐
Phone B ─┼── Wi-Fi router
Phone C ─┘
```

This is a primary validation environment.

---

## Mode B — Phone-created local network

```text
Host phone
   │
   ├── hotspot/local network
   │
   ├── Participant
   ├── Participant
   └── Participant
```

This is an important target for real-world use.

The exact hotspot workflow must be experimentally validated.

---

## Mode C — Direct peer-to-peer

Direct Wi-Fi peer-to-peer mechanisms may be explored later.

They must remain implementation capabilities rather than assumptions of the core protocol.

---

# 12. Transport Layer

The transport architecture must support both reliable control and low-latency live audio.

Possible transport candidates include:

```text
TCP
UDP
QUIC
WebSocket-based transport
Other platform-supported local transports
```

The exact transport is **UNDECIDED** until experiments provide evidence.

Control traffic generally requires:

```text
reliable
ordered
authenticated
```

delivery.

Live audio has different requirements.

It must support:

```text
low latency
bounded buffering
sequence numbers
timestamps
loss detection
reordering handling
backpressure
```

A reliable stream may be appropriate for an initial prototype, but head-of-line blocking and retransmission latency must be measured before treating it as the final audio transport.

The architecture must not choose a transport merely because it is familiar.

---

# 13. SoundMesh Protocol

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

Possible control messages include:

```text
HELLO
WELCOME
ROOM_STATE
DEVICE_CAPABILITIES

CAPTURE_STATUS
AUDIO_STREAM_START
AUDIO_STREAM_CONFIG
AUDIO_STREAM_STOP
AUDIO_STREAM_STATS
AUDIO_CAPTURE_ERROR
AUDIO_ROUTE_CHANGED
SOURCE_CAPTURE_UNAVAILABLE

SYNC_REQUEST
SYNC_RESPONSE
CALIBRATION_START
CALIBRATION_RESULT
SYNC_TARGET
DRIFT_REPORT
CORRECTION_COMMAND

HEARTBEAT
LEAVE
ERROR
```

High-frequency audio frames should not necessarily be encoded as ordinary JSON/control messages.

A conceptual audio frame is:

```text
AudioFrame {
    sessionGeneration
    sequenceNumber
    captureTimestamp
    sampleFormat
    sampleRate
    channels
    payload
}
```

The exact wire format remains implementation-defined.

---

# 14. Protocol Versioning

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

A future application update may retain compatibility with older protocol versions where practical.

Compatibility rules belong in `networking.md`.

---

# 15. Flutter ↔ Native Boundary

The Flutter layer communicates with native functionality through explicit interfaces.

Conceptually:

```text
Dart
 │
 ▼
Platform Interface
 │
 ├─────────────────────┐
 ▼                     ▼
Android Native     Future Platforms
```

Flutter platform channels or generated type-safe interfaces may be used.

The important architectural rule is that Dart must not directly depend on Android implementation classes.

---

# 16. Platform Interface Design

The Dart application should see conceptual interfaces such as:

```text
NetworkPlatform
AudioCapturePlatform
AudioOutputPlatform
DevicePlatform
LifecyclePlatform
```

Networking:

```text
startDiscovery()
stopDiscovery()
connect(endpoint)
sendControl(message)
disconnect(deviceId)
```

Capture:

```text
requestCapturePermission()
startCapture()
stopCapture()
getCaptureState()
getCaptureFormat()
getCaptureTimestamp()
```

Audio output:

```text
prepareOutput(config)
scheduleFrame(frame, targetTime)
getOutputTimestamp()
getOutputState()
getRoute()
```

These are conceptual interfaces.

Actual API names are implementation details.

Flutter must not directly depend on Android framework classes.

---

# 17. Native Audio Architecture

The audio system is timing-critical.

Therefore:

```text
Flutter
  │
  │ high-level session commands
  ▼
Native Audio Controller
  │
  ├── Capture Engine
  │
  ├── Buffer / Jitter Engine
  │
  └── Output Engine
          │
          ▼
Operating System Audio Pipeline
          │
          ▼
Speaker / Headphones
```

Flutter must not push individual audio frames at realtime frequency.

---

# 18. Android Audio Capture

Android is the MVP platform.

The host-side capture architecture is conceptually:

```text
External Media App
       │
       ▼
Android AudioPlaybackCapture
       │
       ▼
Captured Audio Frames
       │
       ▼
SoundMesh Capture Engine
```

Capture requires platform-controlled permission and user authorization through the appropriate Android APIs.

Not every external application or audio stream is necessarily captureable.

The architecture must therefore distinguish:

```text
capture available
capture permission required
source not captureable
capture interrupted
capture revoked
capture format unsupported
```

SoundMesh must never assume that an arbitrary external application can be captured.

---

# 19. Native Audio Output

Participant output is handled natively.

Conceptually:

```text
Received Audio Frames
        │
        ▼
Jitter Buffer
        │
        ▼
Timing / Synchronization
        │
        ▼
Native Audio Scheduler
        │
        ▼
Audio Output
```

The native output implementation must expose timestamps or other measurements sufficient for synchronization.

Android devices may have significantly different output latency.

The architecture must measure rather than assume a universal latency value.

---

# 20. Shared Audio Model

The old shared model of:

```text
Audio Asset
    │
    ▼
Decoder
    │
    ▼
Prepared File
    │
    ▼
Playback
```

is not the MVP architecture.

The new conceptual model is:

```text
External Audio Source
        │
        ▼
Capture
        │
        ▼
Captured Frames
        │
        ▼
Timestamped Stream
        │
        ▼
Network Transport
        │
        ▼
Jitter Buffer
        │
        ▼
Scheduled Native Output
```

The synchronization subsystem operates on this live stream.

---

# 21. Audio Distribution

Audio is distributed as a **live stream of captured frames**.

Preferred flow:

```text
External Media App
        │
        ▼
AudioPlaybackCapture
        │
        ▼
Captured frames
        │
        ▼
Timestamp + sequence
        │
        ▼
Audio transport
        │
        ▼
Participant jitter buffer
        │
        ▼
Scheduled native output
```

SoundMesh does not require:

* audio file selection;
* file hashing;
* asset transfer;
* local media libraries;
* pre-distributed media files.

The external application remains responsible for selecting and playing the media.

---

# 22. Audio Identity

SoundMesh does not require a deterministic identity for an external media file.

There is no MVP requirement for:

```text
assetId = hash(audio-content)
```

because SoundMesh is synchronizing a live captured stream rather than distributing a reusable media asset.

A future feature may introduce content identity for other purposes, but that must not become an MVP dependency.

---

# 23. Synchronization Architecture

Synchronization is composed of:

```text
┌──────────────────────────────────┐
│ Capture Timestamp Measurement    │
├──────────────────────────────────┤
│ Network Timing Measurement       │
├──────────────────────────────────┤
│ Clock Offset Estimation          │
├──────────────────────────────────┤
│ Latency Estimation               │
├──────────────────────────────────┤
│ Shared Live-Audio Timeline       │
├──────────────────────────────────┤
│ Jitter Buffer Timing             │
├──────────────────────────────────┤
│ Native Output Scheduling         │
├──────────────────────────────────┤
│ Drift Detection                  │
├──────────────────────────────────┤
│ Drift Correction                │
└──────────────────────────────────┘
```

The synchronization subsystem must not depend on UI frame timing.

---

# 24. Shared Timeline

SoundMesh needs a logical shared live-audio timeline.

Conceptually:

```text
T = 0
│
├── room/session initialization
│
├── clock measurement
│
├── capture begins
│
├── audio frames enter stream
│
├── future output target established
│
├── synchronized output
│
├── drift measurement
│
└── correction
```

Each audio frame carries timing information that allows participants to relate received audio to the shared timeline.

The host's capture timestamps and each participant's output timestamps are important inputs.

---

# 25. Synchronization Data Flow

Conceptually:

```text
Participant
    │
    │ timestamp request
    ▼
Host
    │
    │ timestamp response
    ▼
Participant
    │
    ▼
Estimate:
- round-trip time
- clock offset
- timing uncertainty
    │
    ▼
Calibration
    │
    ▼
Shared timeline
    │
    ▼
Output scheduler
```

Multiple timing measurements should be preferred over a single sample.

The synchronization algorithm must account for network jitter and possible asymmetric delays.

Detailed estimation methods belong in `synchronization.md`.

---

# 26. Live Audio Scheduling

SoundMesh should use **scheduled future output**, not immediate output commands.

Bad architecture:

```text
RECEIVE FRAME
→ PLAY IMMEDIATELY
```

Preferred architecture:

```text
Receive timestamped frame
        │
        ▼
Jitter buffer
        │
        ▼
Map timestamp to local timeline
        │
        ▼
Schedule future native output
```

The buffer provides time to absorb:

* network jitter;
* packet reordering;
* processing variation;
* scheduler uncertainty.

The exact buffering margin must be experimentally determined.

---

# 27. Drift Correction

Two devices can begin together and gradually diverge.

Therefore:

```text
Synchronization
≠
One-time calibration
```

The system must monitor synchronization over time.

Conceptually:

```text
Expected audio position
        │
        ▼
Actual output position
        │
        ▼
Synchronization error
        │
        ├── acceptable → continue
        │
        └── excessive → correction
```

Possible correction mechanisms include:

* controlled playback-rate adjustment;
* controlled buffer/timeline adjustment;
* rescheduling;
* other native timing corrections.

The selected mechanism must be experimentally validated.

Abrupt repeated corrections should be avoided because they may create audible artifacts.

---

# 28. Correction Safety

A correction must not make the system less stable.

Every correction should consider:

```text
current error
error trend
correction magnitude
buffer state
network stability
device capability
output timing
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

---

# 29. Room State Machine

The room/session architecture follows the state model defined by the product and core API specifications.

Conceptually:

```text
CREATED
   ↓
DISCOVERABLE
   ↓
JOINING
   ↓
READY
   ↓
PREPARING
   ↓
CAPTURING
   ↓
STREAMING
   ↓
SYNCHRONIZED
   ↓
ENDING
   ↓
CLOSED
```

Recovery may temporarily interrupt the session:

```text
STREAMING
   ↓
DEGRADED
   ↓
RECOVERING
   ↓
STREAMING
```

Invalid state transitions must be rejected.

The exact state names are owned by the authoritative state model.

---

# 30. Device State Machine

Each participant independently tracks connection, capture/output, and synchronization state.

Example:

```text
UNKNOWN
   ↓
DISCOVERED
   ↓
CONNECTING
   ↓
CONNECTED
   ↓
PREPARING
   ↓
BUFFERING
   ↓
READY
   ↓
SYNCHRONIZED
   ↓
DEGRADED / RECOVERING
```

The host may additionally track:

```text
CAPTURE_PERMISSION_REQUIRED
CAPTURE_READY
CAPTURING
SOURCE_UNAVAILABLE
CAPTURE_INTERRUPTED
```

Device state must not be inferred solely from UI state.

---

# 31. Late Joining

A device joining an already-active live session cannot download an old media file and seek to a position.

Instead:

```text
Join
 │
 ▼
Authenticate / identify
 │
 ▼
Receive current room/session state
 │
 ▼
Receive current stream configuration
 │
 ▼
Calibrate timing
 │
 ▼
Join live audio stream
 │
 ▼
Fill jitter buffer
 │
 ▼
Receive future synchronization target
 │
 ▼
Schedule output
 │
 ▼
Join synchronized playback
```

The participant may need to wait briefly for sufficient buffer fill.

The late-join algorithm belongs in `synchronization.md`.

---

# 32. Session Start

Starting a SoundMesh audio session is not equivalent to starting a media player.

The conceptual flow is:

```text
Host
 │
 ▼
Prepare capture
 │
 ▼
Request / verify capture permission
 │
 ▼
Start external audio capture
 │
 ▼
Establish stream configuration
 │
 ▼
Begin timestamped frame production
 │
 ▼
Participants buffer incoming frames
 │
 ▼
Shared timing target established
 │
 ▼
Native synchronized output begins
```

The external application controls the actual media playback.

SoundMesh controls the synchronization of the captured result.

---

# 33. External Media Control Boundary

SoundMesh does not own:

```text
play()
pause()
resume()
seek()
next()
previous()
stop()
playbackSpeed()
subtitle()
media selection
```

Those operations belong to the external application.

SoundMesh may need session-level controls such as:

```text
START_AUDIO_SESSION
STOP_AUDIO_SESSION
RECONNECT_AUDIO_SESSION
RESYNCHRONIZE
```

These control the SoundMesh synchronization session, not the external media player.

---

# 34. Host Failure

The MVP may treat the host as authoritative.

If the host disappears:

```text
STREAMING
   ↓
HOST LOST
   ↓
RECOVERY
```

The first MVP does not require seamless host migration.

Host migration is an advanced capability and should not complicate the initial implementation unless testing demonstrates that it is essential.

---

# 35. Participant Failure

A participant disconnecting must not stop the entire room.

Preferred behavior:

```text
Participant disconnects
        │
        ▼
Host marks participant unavailable
        │
        ▼
Remaining participants continue
```

The disconnected participant may later rejoin the current live session.

---

# 36. Network Failure

Temporary network loss must be distinguishable from permanent disconnect.

Conceptual states:

```text
CONNECTED
    ↓
DEGRADED
    ↓
RECOVERING
    ↓
CONNECTED
```

Participants should use bounded buffering where possible.

Short interruptions may be absorbed by the jitter buffer.

The system must not allow unbounded buffering to accumulate stale audio.

---

# 37. Audio Route Changes

A participant may change output routes:

```text
Speaker
   ↓
Bluetooth headphones
```

or:

```text
Bluetooth
   ↓
Phone speaker
```

Output-route changes can alter audio latency.

Therefore the audio layer must notify synchronization.

The system may need to:

```text
pause output
→ revalidate route
→ recalibrate timing
→ refill buffer
→ resume synchronized output
```

The exact behavior depends on measurement and platform constraints.

---

# 38. App Lifecycle

Mobile operating systems can:

* background applications;
* suspend execution;
* interrupt audio;
* change network availability;
* revoke resources;
* terminate processes.

The architecture must treat lifecycle events as first-class system events.

For the Android host, continued external-audio capture while SoundMesh is no longer foreground may require a compliant foreground-service architecture and persistent notification.

Conceptually:

```text
ACTIVE
  ↓
BACKGROUND
  ↓
FOREGROUND SERVICE / ACTIVE SESSION
  ↓
INTERRUPTED / SUSPENDED
  ↓
FOREGROUND
  ↓
REVALIDATE
```

The exact lifecycle behavior must follow current Android platform restrictions.

---

# 39. Flutter Lifecycle vs Session Lifecycle

These are different concepts.

```text
Flutter UI lifecycle
        ≠
Network lifecycle
        ≠
Capture lifecycle
        ≠
Audio output lifecycle
        ≠
Room lifecycle
        ≠
Session lifecycle
```

For example:

```text
Flutter screen disappears
```

does not necessarily mean:

```text
SoundMesh session ended
```

The architecture must keep these lifecycles separate.

---

# 40. Diagnostics Architecture

SoundMesh must expose measurable internal state.

Important metrics include:

```text
RTT
Clock offset estimate
Timing uncertainty
Capture timestamp
Capture-to-network latency
Network-to-output latency
Estimated synchronization error
Drift rate
Correction amount
Audio buffer level
Jitter
Packet loss
Sequence gaps
Audio underruns
Bytes/sec
Connection state
Reconnect count
Output route
Capture state
```

Diagnostics should not require developers to attach a debugger to understand basic synchronization failures.

---

# 41. Developer Diagnostics

A developer/debug mode should eventually provide information such as:

```text
Room
  ID: ABC123
  Host: Device A

Audio Session
  Generation: 7
  Capture: CAPTURING
  Stream: ACTIVE

Participants

  Device B
    RTT: XX ms
    Offset: XX ms
    Sync error: XX ms
    Drift: XX ms/s
    Jitter: XX ms
    Packet loss: XX %
    Buffer: XX ms
    Output: Speaker

  Device C
    RTT: XX ms
    Offset: XX ms
    Sync error: XX ms
    Drift: XX ms/s
    Jitter: XX ms
    Packet loss: XX %
    Buffer: XX ms
    Output: Bluetooth
```

Exact diagnostics presentation belongs in the appropriate testing/UI documents.

---

# 42. Security Boundary

SoundMesh is local-first, but local does not automatically mean secure.

The architecture should protect:

* room membership;
* control messages;
* live audio data;
* protocol integrity.

At minimum, a participant should not be able to accidentally control an unrelated SoundMesh room on the same network.

The exact authentication mechanism remains **UNDECIDED**.

Custom cryptography must not be introduced without strong justification.

---

# 43. Room Identity

Rooms should use unpredictable application-level identifiers.

A room identifier must not simply be:

```text
Room 1
```

or:

```text
192.168.1.5
```

Room identity must remain separate from network addressing.

---

# 44. QR Code Architecture

QR codes provide deterministic onboarding.

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

It is not the synchronization protocol.

---

# 45. Platform Permission Architecture

Permissions must be handled by platform-specific layers and exposed through a common state model.

Conceptually:

```text
PermissionState

├── granted
├── denied
├── restricted
└── unavailable
```

Audio capture may additionally require states such as:

```text
CAPTURE_PERMISSION_REQUIRED
CAPTURE_DENIED
SOURCE_NOT_CAPTUREABLE
CAPTURE_REVOKED
```

Flutter can present appropriate instructions without owning the platform implementation.

---

# 46. Android Networking and Capture Permissions

The Android implementation must account for platform-version-specific permissions and lifecycle restrictions.

Networking permissions and audio-capture permissions are separate concerns.

The architecture must distinguish:

```text
network unavailable
network permission unavailable
capture permission denied
source not captureable
MediaProjection unavailable/revoked
```

Permission and capability detection must be version-aware.

---

# 47. Platform Capability Model

Because the MVP is Android-focused, the architecture must not pretend that every platform provides identical capabilities.

A future platform implementation should expose capabilities explicitly.

Conceptually:

```text
PlatformCapabilities

├── localNetworking
├── discovery
├── externalAudioCapture
├── backgroundCapture
├── lowLatencyOutput
├── audioTimestamps
└── outputRouteMonitoring
```

Unsupported capabilities must be surfaced rather than silently substituted.

---

# 48. Platform Abstraction Rule

Platform differences must remain behind explicit interfaces.

Preferred:

```text
Common SoundMesh Interface
          │
     ┌────┴────┐
     ▼         ▼
 Android   Future Platform
implementation implementation
```

The MVP may contain Android-only functionality where no equivalent platform capability is available.

This is preferable to creating fake cross-platform abstractions that cannot actually be implemented.

---

# 49. Suggested Flutter Project Boundaries

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
│   ├── create_room/
│   ├── join_room/
│   ├── room/
│   └── diagnostics/
│
├── application/
│   ├── room/
│   ├── session/
│   ├── devices/
│   └── recovery/
│
├── domain/
│   ├── room/
│   ├── device/
│   ├── audio_session/
│   ├── synchronization/
│   └── network/
│
├── infrastructure/
│   ├── networking/
│   ├── audio/
│   ├── platform/
│   └── storage/
│
└── shared/
    ├── models/
    ├── errors/
    ├── logging/
    └── utilities/
```

This is an architectural direction, not a requirement to create every directory immediately.

---

# 50. Native Project Boundaries

Android:

```text
android/

└── app/
    └── src/
        └── main/

            ├── kotlin/
            │   └── ...
            │       ├── networking/
            │       ├── audio/
            │       ├── synchronization/
            │       ├── capture/
            │       └── platform/
            │
            └── cpp/
                └── audio/
```

The exact native structure may change depending on selected libraries.

Native code must remain isolated from Flutter UI implementation.

---

# 51. Synchronization Ownership

The synchronization system should eventually be split into:

```text
SyncCoordinator
      │
      ├── ClockEstimator
      ├── LatencyEstimator
      ├── CalibrationEngine
      ├── TimelineManager
      ├── OutputScheduler
      ├── DriftDetector
      └── CorrectionEngine
```

No UI component should calculate clock offsets.

No screen should directly control drift correction.

---

# 52. Audio Ownership

The audio system should eventually be split into:

```text
AudioCoordinator
      │
      ├── CaptureManager
      ├── CaptureBuffer
      ├── StreamFrameManager
      ├── JitterBuffer
      ├── NativeAudioEngine
      ├── AudioClock
      └── RouteManager
```

The synchronization system interacts with audio through explicit timing commands and measurements.

---

# 53. Networking Ownership

Networking should eventually be split into:

```text
NetworkCoordinator
      │
      ├── DiscoveryService
      ├── ConnectionManager
      ├── ControlTransport
      ├── AudioTransport
      ├── TimingTransport
      ├── ProtocolCodec
      └── NetworkMonitor
```

The application layer should not care whether the implementation uses sockets, QUIC, TCP, UDP, or another mechanism.

---

# 54. Dependency Direction

Dependencies should point inward.

Preferred:

```text
Presentation
    ↓
Application
    ↓
Domain
    ↑
Infrastructure
    ↑
Platform
```

The domain must not depend directly on:

```text
Flutter widgets
Android APIs
platform sockets
audio drivers
MediaProjection
```

---

# 55. No Global God Controller

Avoid creating one enormous class such as:

```text
SoundMeshManager
```

that owns:

* networking;
* capture;
* audio output;
* synchronization;
* UI;
* room state;
* device state;
* permissions;
* storage.

This would create an untestable architecture.

Responsibilities must remain separated.

---

# 56. Event-Driven Communication

Subsystems should communicate using explicit events or commands.

Examples:

```text
Network:
    ParticipantConnected

Room:
    ParticipantReady

Capture:
    CaptureStarted

Audio:
    AudioFrameReceived

Synchronization:
    CalibrationCompleted

Output:
    AudioOutputStarted

Recovery:
    SessionReconnected
```

This prevents tightly coupled components.

---

# 57. Commands vs Events

Use a conceptual distinction.

### Commands

Something wants an action performed.

```text
CreateRoom
JoinRoom
StartAudioSession
StopAudioSession
RequestCapturePermission
StartCapture
Resynchronize
LeaveRoom
Calibrate
```

### Events

Something already happened.

```text
ParticipantConnected
CaptureStarted
CaptureInterrupted
AudioFrameReceived
AudioOutputStarted
NetworkDisconnected
CalibrationCompleted
SessionRecovered
```

AI agents should preserve this distinction.

---

# 58. Error Handling

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
├── CaptureError
├── AudioOutputError
├── SynchronizationError
└── LifecycleError
```

Capture-specific errors may include:

```text
CAPTURE_PERMISSION_DENIED
CAPTURE_UNAVAILABLE
SOURCE_NOT_CAPTUREABLE
MEDIAPROJECTION_REVOKED
CAPTURE_INTERRUPTED
CAPTURE_FORMAT_UNSUPPORTED
```

Audio/network errors may include:

```text
STREAM_UNDERRUN
OUTPUT_UNAVAILABLE
AUDIO_ROUTE_CHANGED
AUDIO_PACKET_LOSS
CONNECTION_LOST
```

Errors should contain enough information for:

* user-facing messaging;
* diagnostics;
* recovery decisions;
* logging.

---

# 59. Logging

Logging should be structured.

Important fields may include:

```text
timestamp
deviceId
roomId
sessionId
generation
component
event
severity
message
metadata
```

Synchronization logs must include timing information.

Example:

```text
SYNC_CALIBRATION_RESULT

device=B
offset=...
rtt=...
uncertainty=...
```

Audio-stream logs may include:

```text
AUDIO_STREAM_STATS

device=B
sequence=...
jitter=...
packetLoss=...
buffer=...
```

Sensitive user data must not be logged unnecessarily.

---

# 60. Performance Rule

UI performance and real-time performance are separate concerns.

A slow Flutter rebuild must never directly cause audio timing failure.

A network callback must never block the audio callback.

An audio callback must never perform:

* network operations;
* disk I/O;
* UI operations;
* expensive allocation;
* blocking synchronization.

---

# 61. Real-Time Audio Rule

Timing-critical audio code must be designed around realtime constraints.

Conceptually:

```text
Audio callback
    ↓
minimal work
    ↓
no blocking network
    ↓
no UI calls
    ↓
no disk I/O
    ↓
no unnecessary allocation
```

Networked audio data must enter bounded queues/buffers outside the realtime callback.

---

# 62. Storage

Local storage may be used for:

* room/session metadata where necessary;
* configuration;
* diagnostic information where appropriate;
* temporary session state.

The MVP must not require a cloud database.

SoundMesh should not build a persistent media library merely to support synchronization.

---

# 63. No Backend Requirement

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

The synchronized-speaker core must remain locally functional.

---

# 64. Data Flow: Create Room

```text
User
 │
 ▼
Flutter UI
 │
 ▼
RoomController
 │
 ▼
Room created
 │
 ▼
NetworkCoordinator
 │
 ▼
Native discovery / advertising
 │
 ▼
Room becomes discoverable
```

---

# 65. Data Flow: Join Room

```text
User scans QR
 │
 ▼
Flutter parses join payload
 │
 ▼
NetworkCoordinator
 │
 ▼
Connect to host
 │
 ▼
Protocol handshake
 │
 ▼
Device identified
 │
 ▼
Room/session state received
 │
 ▼
Participant enters preparation
```

---

# 66. Data Flow: Start Audio Session

```text
Host
 │
 ▼
Prepare capture
 │
 ▼
Request / verify capture permission
 │
 ▼
Start AudioPlaybackCapture
 │
 ▼
Captured audio frames
 │
 ▼
Timestamp + sequence
 │
 ▼
Audio transport
 │
 ▼
Participant jitter buffers
 │
 ▼
Clock/timing synchronization
 │
 ▼
Future synchronized output target
 │
 ▼
Native audio scheduling
 │
 ▼
Synchronized output
```

The external media application remains responsible for starting, pausing, seeking, and otherwise controlling its media.

---

# 67. Data Flow: Drift Correction

```text
Live Audio Output
       │
       ▼
Measure output timing
       │
       ▼
Compare against shared timeline
       │
       ▼
Estimate synchronization error
       │
       ├── small → continue
       │
       └── large → correction
                    │
                    ▼
              Native timing adjustment
```

---

# 68. Data Flow: Participant Disconnect

```text
Network failure
      │
      ▼
Native network layer
      │
      ▼
NetworkCoordinator
      │
      ▼
Room/session state update
      │
      ▼
Host marks participant degraded/disconnected
      │
      ▼
Remaining participants continue
      │
      ▼
Flutter UI updates
```

The UI does not directly determine that a participant disconnected.

---

# 69. Architecture Invariants

The following rules are architectural invariants.

## INV-001

Flutter UI must never be responsible for realtime audio scheduling.

## INV-002

Synchronization calculations must not depend on Flutter frame timing.

## INV-003

The internet must not be required for ordinary local operation.

## INV-004

Platform-specific functionality must be isolated behind interfaces.

## INV-005

Audio callbacks must not perform network or UI work.

## INV-006

A participant disconnect must not automatically terminate the room.

## INV-007

The system must not assume all devices have identical clocks.

## INV-008

The system must not assume all devices have identical audio latency.

## INV-009

The system must measure synchronization rather than assume it.

## INV-010

Protocol messages must be versioned.

## INV-011

Room state and Flutter UI state must remain separate concepts.

## INV-012

Architecture decisions must not silently convert `UNDECIDED` requirements into permanent implementation choices.

## INV-013

SoundMesh must not become responsible for controlling the external media application's playback.

## INV-014

Live audio must be treated as a bounded real-time stream rather than an implicitly reliable file transfer.

## INV-015

Capture failures must be represented explicitly and must not be confused with network failures.

---

# 70. Explicit Non-Goals

This architecture does not currently attempt to solve:

* professional studio-grade multi-room audio;
* sample-perfect synchronization across arbitrary hardware;
* arbitrary internet-based synchronization;
* unlimited device counts;
* automatic host migration;
* cross-continent synchronized playback;
* cloud-hosted audio streaming;
* a universal external-media player;
* arbitrary capture of every Android application;
* iOS external-application audio capture for the MVP;
* every possible Bluetooth configuration;
* perfect mathematical synchronization.

The goal is a robust consumer-level local synchronized-speaker experience.

---

# 71. MVP Architecture Scope

The first implementation should target:

```text
Flutter UI
+
Android native support
+
Local network connection
+
QR room bootstrap
+
Live external-audio capture
+
Live audio transport
+
Native participant audio output
+
Clock/timing calibration
+
Scheduled output
+
Basic drift measurement
+
Basic drift correction
+
Recovery
```

The first physical test target should be:

```text
2 Android phones
```

Then:

```text
3 phones
↓
5 phones
↓
larger groups
```

The architecture must not be optimized for large groups before two-device synchronization works reliably.

---

# 72. Experimental Architecture

The following areas are explicitly experimental:

```text
Exact live-audio transport
TCP vs UDP vs QUIC
Audio packet format
Codec vs PCM
Packet size
Automatic hotspot workflow
Direct Wi-Fi P2P
Host direct-output latency compensation
Host output routing through SoundMesh
Automatic playback-rate correction
Advanced background execution
Large device groups
Host migration
Advanced source-app compatibility
```

Experimental features must not become MVP dependencies until validated.

---

# 73. Current Architectural Decisions

### DEC-ARCH-001

**Decision:** SoundMesh will use Flutter as the primary application framework.

**Reason:** Flutter provides shared UI and application orchestration while allowing native Android integration.

---

### DEC-ARCH-002

**Decision:** Native platform implementations are expected for timing-critical functionality.

**Reason:** External audio capture, realtime audio, platform lifecycle, and precise timing require native platform capabilities.

---

### DEC-ARCH-003

**Decision:** Synchronization will be implemented as an independent subsystem.

**Reason:** Synchronization is the core technical problem and must not be buried inside UI, networking, or audio code.

---

### DEC-ARCH-004

**Decision:** SoundMesh MVP uses live captured-audio streaming rather than pre-distributed audio files.

**Reason:** SoundMesh synchronizes audio produced by external applications rather than owning or distributing their media assets.

---

### DEC-ARCH-005

**Decision:** The MVP targets Android external-audio capture.

**Reason:** Android provides the required AudioPlaybackCapture mechanism for eligible external application audio, subject to platform and source-app restrictions.

---

### DEC-ARCH-006

**Decision:** SoundMesh does not own external media playback controls.

**Reason:** The external media application remains the source of truth for media playback.

---

### DEC-ARCH-007

**Decision:** Networking must separate control, audio-data, and timing responsibilities.

**Reason:** These traffic types have different reliability, latency, ordering, and measurement requirements.

---

### DEC-ARCH-008

**Decision:** Live-audio transport remains experimentally undecided.

**Reason:** The correct transport must be determined through latency, jitter, loss, ordering, and recovery measurements rather than assumption.

---

### DEC-ARCH-009

**Decision:** The host remains the MVP room/session authority.

**Reason:** Central authority simplifies room membership, session generation, timing coordination, and recovery.

---

# 74. Decisions Still UNDECIDED

The following must not be silently decided by an AI agent:

```text
UNDECIDED-001
Exact Flutter state-management solution.

UNDECIDED-002
Exact Flutter networking package, if any.

UNDECIDED-003
Whether networking should primarily use custom native code or an existing package.

UNDECIDED-004
Exact live-audio transport protocol.

UNDECIDED-005
Whether TCP is sufficient for live audio.

UNDECIDED-006
Whether UDP or QUIC provides measurable benefits.

UNDECIDED-007
Exact service-discovery implementation.

UNDECIDED-008
Exact hotspot strategy.

UNDECIDED-009
Whether direct Wi-Fi P2P belongs in MVP.

UNDECIDED-010
Audio frame wire format.

UNDECIDED-011
PCM vs compressed audio representation.

UNDECIDED-012
Exact audio codec, if compression is required.

UNDECIDED-013
Exact Android native audio output implementation.

UNDECIDED-014
Exact capture buffer configuration.

UNDECIDED-015
Clock synchronization algorithm.

UNDECIDED-016
Latency estimation algorithm.

UNDECIDED-017
Capture-to-output latency measurement method.

UNDECIDED-018
Host direct-output synchronization strategy.

UNDECIDED-019
Drift correction algorithm.

UNDECIDED-020
Target synchronization error threshold.

UNDECIDED-021
Maximum supported device count.

UNDECIDED-022
Host migration strategy.

UNDECIDED-023
Room authentication mechanism.

UNDECIDED-024
Background execution strategy.

UNDECIDED-025
Exact local persistence mechanism.

UNDECIDED-026
Exact diagnostics format.

UNDECIDED-027
Production optimization strategy.

UNDECIDED-028
Long-term support for platforms other than Android.
```

AI agents must preserve these as undecided until evidence or an explicit decision changes them.

---

# 75. Architecture Decision Rule

Before permanently choosing a significant technology or algorithm, the team must:

1. define the problem;
2. identify realistic alternatives;
3. research platform constraints;
4. build a minimal experiment;
5. measure the result;
6. document the evidence;
7. choose an approach;
8. record the decision in `DOCS/decisions.md`.

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

---

# 76. Architecture Testing Philosophy

Architecture must be validated with physical Android devices.

The MVP must prioritize:

```text
Android ↔ Android
```

Future platforms may eventually be tested when equivalent capabilities exist.

A synchronization architecture that works on one identical pair of phones but fails across heterogeneous Android hardware is not considered sufficiently validated.

---

# 77. Required Early Experiments

Before implementing the full product, the team should validate:

### Experiment 1 — Local connection

Can two Android SoundMesh instances establish a stable local connection?

### Experiment 2 — QR bootstrap

Can a participant reliably join a room through QR?

### Experiment 3 — External audio capture

Can SoundMesh capture eligible audio from an external application?

### Experiment 4 — Capture persistence

Can capture continue correctly under the required Android foreground/background lifecycle?

### Experiment 5 — Live audio transport

Can captured frames be transported from one device to another continuously?

### Experiment 6 — Packet impairment

How does the system behave under:

```text
jitter
packet loss
reordering
bandwidth limitation
temporary disconnect
```

### Experiment 7 — Native output

Can received audio be output through the participant's native audio pipeline?

### Experiment 8 — Timing

Can capture and output timestamps provide sufficiently stable timing measurements?

### Experiment 9 — Two-device synchronization

Can two different Android phones produce perceptually synchronized output?

### Experiment 10 — Host latency

What is the measured difference between:

```text
host direct external-app output
```

and:

```text
participant SoundMesh output
```

### Experiment 11 — Drift

Do devices remain synchronized over several minutes?

### Experiment 12 — Correction

Can measurable drift be corrected without obvious audible artifacts?

### Experiment 13 — Source compatibility

Which external applications permit capture, and under what conditions?

### Experiment 14 — Multi-device

How does the architecture behave with:

```text
3 devices
5 devices
```

and beyond?

These experiments should precede large-scale feature development.

---

# 78. Architecture Success Criteria

The architecture is successful when developers can answer all of the following without ambiguity:

* Where does room state live?
* Where does live-session state live?
* Where does networking live?
* Where does audio capture live?
* Where does audio output live?
* Where does synchronization live?
* Where does platform-specific code live?
* How does Flutter communicate with native code?
* How does external application audio enter SoundMesh?
* How is captured audio transported?
* How is audio buffered?
* How does a participant calculate when to output a frame?
* How is drift detected?
* How is drift corrected?
* How is host-vs-participant latency measured?
* What happens when a participant disconnects?
* What happens when the network temporarily fails?
* What happens when capture becomes unavailable?
* What happens when audio output changes?
* What happens when the app is backgrounded?
* Which decisions are still experimental?
* Which components can be tested independently?

If these answers cannot be given clearly, the architecture is not sufficiently defined.

---

# 79. Relationship to Other Documents

This document defines **system structure**.

Other documents own the following:

| Document              | Responsibility                                                    |
| --------------------- | ----------------------------------------------------------------- |
| `blueprint.md`        | Product definition and boundaries                                 |
| `architecture.md`     | System architecture and component boundaries                      |
| `synchronization.md`  | Timing, clocks, calibration, drift, correction                    |
| `networking.md`       | Discovery, connections, transport, protocol, live audio transport |
| `audio.md`            | External capture, audio frames, buffering, native audio output    |
| `ui-ux.md`            | User experience and interface                                     |
| `testing.md`          | Validation, experiments, benchmarks, acceptance tests             |
| `decisions.md`        | Significant engineering decisions                                 |
| `roadmap.md`          | Development sequence and milestones                               |
| `AI/ai-context.md`    | Context AI agents need                                            |
| `AI/rules.md`         | Rules AI agents must follow                                       |
| `AI/task-protocol.md` | How AI agents should execute tasks                                |

If two documents disagree, the conflict must be explicitly resolved rather than silently choosing one.

---

# 80. Definition of Done

This architecture document is considered complete for the current planning stage when:

* Flutter is established as the primary application framework;
* Android native responsibilities are defined;
* Flutter/native boundaries are defined;
* networking responsibilities are separated from synchronization;
* audio capture responsibilities are separated from synchronization;
* audio output responsibilities are separated from synchronization;
* host/participant architecture is defined;
* room and device state concepts are defined;
* live captured-audio streaming is established as the MVP architectural model;
* external media ownership remains outside SoundMesh;
* timing-critical operations are isolated from Flutter;
* failure/recovery boundaries are defined;
* Android platform constraints are acknowledged;
* architectural invariants are documented;
* major undecided decisions are explicitly marked;
* future developers can determine where a new feature belongs.

This document must evolve as experiments produce real evidence.

---

# 81. Final Architectural Principle

SoundMesh is not fundamentally a Flutter UI project.

It is a:

> **distributed real-time audio synchronization system with a Flutter application layer.**

Flutter provides:

* shared UI;
* application orchestration;
* room/session workflows;
* diagnostics;
* rapid development;
* product consistency.

Native platform layers provide:

* external-audio capture;
* low-latency audio;
* live audio buffering;
* network transport;
* precise timing;
* operating-system integration;
* hardware-aware behavior.

The architecture therefore follows one central rule:

> **Share everything that can safely be shared. Isolate everything that must be platform-specific. Measure everything that affects synchronization.**

The most important system boundary is:

```text
                 SOUNDMESH
                     │
          ┌──────────┴──────────┐
          │                     │
       PRODUCT               REAL-TIME
       LAYER                   LAYER
          │                     │
       Flutter                Native
          │                     │
          ▼                     ▼
    UI / State          Capture / Audio
    Workflow            Network / Timing
                              Hardware
```

And the core runtime flow is:

```text
External Media App
        │
        ▼
AudioPlaybackCapture
        │
        ▼
Timestamped Live Audio
        │
        ▼
Local Network
        │
        ▼
Participant Jitter Buffer
        │
        ▼
Synchronized Native Output
```

The user should experience:

> **"All our phones just became one speaker."**

The engineering complexity required to make that illusion work belongs inside the architecture—not in the user's experience.
