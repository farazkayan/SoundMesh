# SoundMesh — Networking Specification

**Document status:** Living engineering specification

**Document role:** Defines how SoundMesh devices establish local communication, create and join rooms, exchange control and timing data, transport live captured audio, maintain sessions, and recover from network failures.

**Primary authority:** This document defines networking behavior and networking architecture.

**Related specifications:**

* `DOCS/blueprint.md` — product-level requirements and boundaries
* `DOCS/architecture.md` — system architecture and platform boundaries
* `DOCS/synchronization.md` — timing, clock synchronization, scheduled output, drift correction
* `DOCS/audio.md` — external-audio capture, live audio pipeline, buffering, and native output
* `DOCS/testing.md` — validation and acceptance testing
* `DOCS/decisions.md` — records major architectural decisions

---

# 1. Purpose

SoundMesh requires multiple independent smartphones to communicate reliably enough that they can behave as one coordinated speaker system.

The networking layer is responsible for:

1. discovering or bootstrapping nearby SoundMesh devices;
2. creating and joining rooms;
3. establishing device-to-device connections;
4. identifying participants;
5. exchanging room and session state;
6. transporting live captured audio;
7. exchanging synchronization measurements;
8. delivering session and synchronization commands;
9. reporting connection and device state;
10. detecting connection failures;
11. reconnecting when possible;
12. handling device joins and departures;
13. handling network changes;
14. protecting room communication from unauthorized participants;
15. providing deterministic communication primitives to the synchronization layer.

Networking is **not** responsible for determining whether audio is synchronized correctly.

That responsibility belongs to the synchronization system defined in `synchronization.md`.

Networking must instead provide the communication primitives, timestamps, transport behavior, and measurements required by synchronization and live audio delivery.

SoundMesh is **not a media player**.

The external media application running on the host remains responsible for media playback. SoundMesh networking transports the audio captured from that external application.

---

# 2. Core Networking Principles

SoundMesh networking MUST follow these principles.

## 2.1 Local-first

Normal SoundMesh operation MUST NOT require Internet access.

The intended path is:

```text
Phone A ─┐
Phone B ─┼── Local network ── Phone C
Phone D ─┘
```

The Internet should not be a dependency for:

* room creation;
* room joining;
* device discovery or QR bootstrap;
* live audio transport;
* synchronization;
* session control;
* synchronization monitoring;
* recovery.

Internet connectivity may exist, but SoundMesh should not depend on it for ordinary operation.

---

## 2.2 Android-first MVP

The current MVP is **Android-first / Android-only** because the intended audio source is another application's audio output.

The networking protocol SHOULD remain logically transport- and platform-independent where practical, but the MVP does not require iOS networking or iOS audio participation.

The architecture MUST NOT retain iOS-specific requirements merely for historical compatibility with the previous design.

Future platforms may implement the same logical protocol if their audio-capture capabilities permit the SoundMesh architecture.

---

## 2.3 Networking must support heterogeneous Android devices

SoundMesh cannot assume every device has:

* the same CPU;
* the same Wi-Fi chipset;
* the same network stack;
* the same clock behavior;
* the same IP address;
* the same network latency;
* the same audio subsystem;
* the same Android version;
* the same permissions;
* the same network capabilities.

The protocol MUST therefore avoid depending on device-specific behavior.

---

## 2.4 Networking must be measurable

The networking layer MUST expose enough information for synchronization and diagnostics to measure:

* round-trip time;
* message timing;
* connection state;
* connection establishment duration;
* live audio throughput;
* audio transport latency;
* transport failures;
* reconnect attempts;
* network changes;
* message ordering;
* sequence numbers;
* packet loss or missing audio frames where applicable;
* buffering state.

A connection that merely "seems connected" is insufficient.

SoundMesh synchronization depends on measured behavior.

---

## 2.5 Control traffic and live audio traffic are different

SoundMesh MUST distinguish between control traffic and live audio traffic.

### Control traffic

Examples:

* room information;
* participant information;
* readiness;
* session state;
* capture state;
* synchronization commands;
* synchronization probes;
* heartbeat;
* error reports;
* recovery messages.

### Live audio traffic

Examples:

* captured audio frames;
* audio frame timestamps;
* sequence numbers;
* stream metadata;
* stream start information;
* buffering information.

These traffic classes should not be treated identically.

Control messages generally require reliable delivery and ordering.

Live audio requires low and predictable latency, bounded buffering, sequencing, loss handling, and backpressure behavior.

The exact transport strategy remains an implementation and experimental decision.

---

# 3. Initial Network Architecture

The initial SoundMesh architecture SHOULD use a **host-and-participant topology**.

```text
                    ┌───────────────┐
                    │     HOST      │
                    │               │
                    │ Room authority│
                    │ Session state │
                    │ Audio source  │
                    │ Coordination  │
                    └───────┬───────┘
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
        Participant    Participant    Participant
             A              B              C
```

The host is responsible for room coordination and is the source of the live captured audio stream.

The primary live-audio path is:

```text
External Media App
       ↓
Host Audio Capture
       ↓
Captured Audio Frames
       ↓
Host Networking
       ↓
Participant Networking
       ↓
Participant Audio Buffer
       ↓
Synchronized Native Output
```

The host MAY also use SoundMesh's native output pipeline if required for synchronization.

The host MUST NOT be treated merely as a file distributor.

SoundMesh does not transfer an audio file once and then abandon the network during playback.

The live audio stream is part of the active session.

---

# 4. Live Audio Transport Model

The previous file-distribution architecture is obsolete.

SoundMesh MUST treat captured audio as a **live stream**.

The conceptual pipeline is:

```text
External Media App
        ↓
AudioPlaybackCapture
        ↓
Captured PCM / audio frames
        ↓
Timestamp + sequence number
        ↓
Packetization
        ↓
Local network
        ↓
Participant jitter buffer
        ↓
Scheduled native output
```

Audio frames are transient session data.

The MVP does not require permanent storage of the captured stream.

The network therefore has two simultaneous responsibilities:

```text
CONTROL PLANE
    ↓
room + session + synchronization

AUDIO PLANE
    ↓
live captured audio
```

Both must coexist without allowing audio traffic to make room control unresponsive.

---

# 5. Audio Stream Ownership

The external media application remains the source of truth for the media being played.

Examples may include:

* YouTube;
* VLC;
* a browser;
* Spotify;
* another eligible Android media application.

SoundMesh does not own:

* the media library;
* the song list;
* the video;
* subtitles;
* seeking;
* playback speed;
* media metadata;
* external application playback controls.

The host external application produces audio.

SoundMesh captures that audio and synchronizes its distribution.

Therefore networking MUST NOT be designed around an `audioId` representing a transferable media file.

---

# 6. Local Wi-Fi

The primary MVP networking environment SHOULD be ordinary local Wi-Fi.

Example:

```text
              Wi-Fi Router

             /     |      \

          Host    Phone A  Phone B
```

The router does not need Internet access.

It only needs to provide local connectivity.

A completely offline Wi-Fi network is therefore valid.

---

# 7. Phone Hotspot

Phone hotspot support is an important target scenario.

Example:

```text
          Host Phone
       Wi-Fi Hotspot
         /       \
        /         \
  Phone A       Phone B
```

The host may simultaneously:

* provide the local network;
* run the SoundMesh host session;
* capture external application audio;
* participate in the synchronized output pipeline.

This scenario MUST be tested separately from ordinary Wi-Fi.

Hotspot behavior can differ between Android devices.

SoundMesh MUST NOT assume that all phones expose identical hotspot behavior.

---

# 8. Wi-Fi Direct / Peer-to-Peer

Direct peer-to-peer networking SHOULD be treated as a future or experimental capability rather than an MVP dependency.

Android provides platform-specific peer-to-peer mechanisms, but their permissions and behavior vary across devices and Android versions.

Therefore:

```text
MVP:

Local Wi-Fi
+
Phone hotspot

Future / Experimental:

Wi-Fi Direct
Other peer-to-peer mechanisms
```

The application architecture SHOULD allow future transports without rewriting the SoundMesh application protocol.

---

# 9. Protocol Independence

The SoundMesh application protocol MUST NOT depend on a specific physical transport.

Conceptually:

```text
SoundMesh Protocol
        │
        ▼
Transport Interface
        │
   ┌────┴────┐
   │         │
 TCP       Datagram
```

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

The same principle applies to the live audio transport.

---

# 10. Flutter Networking Boundary

Flutter SHOULD own:

* networking state presentation;
* room UI;
* participant list;
* connection status;
* audio-session status;
* user actions;
* error presentation;
* application-level orchestration.

Native Android code SHOULD own functionality that depends heavily on platform networking APIs or timing-sensitive behavior.

The preferred architecture is:

```text
┌─────────────────────────────────────────────┐
│                  Flutter                    │
│                                             │
│ UI                                          │
│ Room state                                  │
│ Session state                               │
│ User actions                                │
│ Application orchestration                  │
└──────────────────────┬──────────────────────┘
                       │
                 Typed interface
                   / Pigeon
                       │
┌──────────────────────▼──────────────────────┐
│             Android Native Layer             │
│                                             │
│ Connection Manager                          │
│ Room Manager                                │
│ Protocol                                    │
│ Transport                                   │
│ Live Audio Transport                        │
│ Timing Transport                            │
└──────────────────────┬──────────────────────┘
                       │
                Local Network
```

High-frequency synchronization and live-audio processing MUST NOT depend on repeatedly crossing the Flutter/native boundary.

Flutter should receive meaningful state rather than every low-level network or audio event.

---

# 11. Android Networking

Android networking SHOULD use standard platform networking APIs where practical.

Android-specific discovery mechanisms may be implemented behind the networking abstraction.

The Android implementation MUST explicitly account for:

* Android API level;
* nearby-device permissions where applicable;
* local network availability;
* hotspot behavior;
* background restrictions;
* connection changes;
* foreground-service interaction;
* network interface changes.

---

# 12. Device Discovery

Discovery answers:

> "Which SoundMesh devices are available to join?"

Discovery is separate from connection establishment.

The preferred MVP user flow is:

```text
Host creates room
       ↓
Room receives identity
       ↓
Host displays QR code
       ↓
Participant scans QR
       ↓
Participant obtains bootstrap information
       ↓
Participant connects to host
```

Discovery therefore does not necessarily require automatic scanning.

---

# 13. QR Code Joining

QR joining SHOULD be the primary MVP onboarding mechanism.

The QR code should contain only the information necessary to bootstrap the connection.

Conceptual structure:

```text
soundmesh://join?
    room=<room-id>
    host=<bootstrap-address>
    port=<bootstrap-port>
    version=<protocol-version>
    token=<short-lived-join-token>
```

The exact encoding is implementation-defined.

The implemented encoding is defined in 14.1 below.

The QR code MUST NOT contain:

* permanent credentials;
* user passwords;
* long-lived secrets;
* unnecessary personal information;
* audio data.

---

# 14. QR Code Security

A QR code should be considered visible to nearby people.

Therefore, the QR payload MUST NOT be treated as a permanent authentication credential.

Room joining SHOULD use a short-lived, room-specific join credential.

Example:

```text
Room ID
+
Protocol version
+
Short-lived join token
```

The token SHOULD:

* expire;
* be scoped to the current room;
* become invalid when the room closes;
* preferably become invalid after successful use or after a defined lifetime.

---

## 14.1 Implemented Join Payload Contract (Phase 7)

The bootstrap payload is formalized as a transport-independent `JoinPayload`
structure shared by both bootstrap transports. The Dart implementation is
`app/lib/infrastructure/discovery/join_payload.dart`.

### Payload fields

```text
JoinPayload {
    roomId            // the room's actual identifier (must match the
                      //   WELCOME handshake roomId — see below)
    hostAddress       // host TCP control IP
    hostPort          // host TCP control port
    protocolVersion   // application protocol version this payload targets
    code              // short-lived join credential (6-digit numeric in MVP)
    issuedAt          // when the credential was issued (optional on the wire)
    expiresAt         // when the credential expires (optional on the wire)
}
```

### Transport forms

**(a) UDP discovery announcement** (live broadcast, 2-second interval):

```text
{
  "type": "room_announcement",
  "version": 1,
  "code": "123456",
  "host_ip": "192.168.1.100",
  "host_port": 8765,
  "room_id": "<room-id>",
  "host_name": "<optional display name>",
  "expires_at": <epoch-millis>
}
```

`expires_at` is optional so senders that do not carry expiration remain
parseable. Participant-side validation of announcements covers message type,
protocol version, and 6-digit code format; an announcement whose credential
has expired is ignored (the scan continues and times out).

**(b) QR bootstrap URI** (per DEC-013):

```text
soundmesh://join?room=<room-id>&host=<addr>&port=<port>&version=<v>
    &token=<code>&expires=<epoch-millis>
```

The credential is transmitted in the `token` parameter; `code` is accepted as
an alias on parse. `expires` is omitted when the payload carries no
expiration. The same `JoinPayload` structure backs both forms: swapping or
adding a transport does not change the data structure, only how it is
transmitted and received.

### Join credential lifetime

* Default lifetime: 10 minutes from issuance (`kJoinCodeLifetime`).
* The effective lifetime is also bounded by the host session: broadcasting
  stops when the room closes, and the host stops broadcasting automatically
  when the credential expires.
* Validation allows a 60-second clock-skew allowance for wall-clock
  differences between devices (`kJoinExpiryClockSkewAllowance`).
* The credential is short-lived and single-purpose: scoped to one room
  session. It is never a permanent credential.

### Host roomId consistency

The discovery announcement's `roomId` MUST be the host's actual room
identifier, not a separate discovery-time value. The host pre-assigns the
room ID at room creation and uses it for the WELCOME handshake, so the
announcement and the joined room agree. Cross-validating the announced
`roomId` against the WELCOME `roomId` on the participant side is a follow-up
(the current HELLO handshake does not yet carry the join credential).

### Participant-side validation

Malformed codes, payload parse failures, and version mismatches raise
structured errors (see 14.2). A discovery scan timeout surfaces as a null
result, mapped to `CODE_NOT_FOUND`.

---

## 14.2 Join Payload Error Taxonomy (Phase 7)

| Error Code | Meaning | Where it surfaces |
|------------|---------|-------------------|
| `INVALID_PAYLOAD` | Malformed/corrupt payload: unparseable, missing required fields, invalid port or expiration | QR/URI parse; malformed code input |
| `CODE_EXPIRED` | Join credential expired beyond the 60s clock-skew allowance | QR/URI parse; expired UDP announcements are ignored (scan then times out) |
| `PROTOCOL_VERSION_UNSUPPORTED` | Payload targets an incompatible protocol version | QR/URI parse; discovery announcements with a wrong version are ignored |
| `CODE_NOT_FOUND` | Scan completed without finding the requested code | Discovery scan timeout (null result → "Code not found on this network") |
| `ROOM_NOT_FOUND` | Host-side rejection after a connect attempt | Reserved; currently unreachable because a discovery-resolved connection always targets the advertising host. Host-side rejection uses the `JOIN_REJECTED` taxonomy (`ROOM_FULL` / `VERSION_MISMATCH` / `CLOSED`) |

Dart implementation: `JoinPayloadException` carrying a `JoinPayloadErrorCode`
in `join_payload.dart`. Raw exceptions must not leak into user-facing state.

---

# 15. Room Identity

Every active room MUST have a unique room identifier.

Example:

```text
roomId = random opaque identifier
```

The room ID must not be based solely on:

* device name;
* IP address;
* username;
* timestamp;
* phone model.

Room IDs exist at the application protocol level.

---

# 16. Device Identity

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

---

# 17. Host Identity

The host must also have a participant/device identity.

Conceptually:

```text
Room
 ├── Host
 │    └── participantId
 │
 ├── Participant
 │    └── participantId
 │
 └── Participant
      └── participantId
```

The host additionally has room-authority responsibilities.

---

# 18. Transport Selection

The initial implementation MAY use TCP for control traffic because it provides:

* reliable delivery;
* ordering;
* connection state;
* simplicity;
* cross-platform implementation;
* straightforward debugging.

Live audio transport is a separate engineering concern.

The initial live-audio transport SHOULD be selected through measurement rather than assumption.

Possible approaches include:

```text
TCP stream
```

or:

```text
Datagram-based audio transport
```

or another bounded-latency mechanism.

No transport should be declared permanently optimal before real-device experiments.

---

# 19. Live Audio Transport Requirements

The live audio transport MUST support the properties required by synchronized playback.

At minimum, the audio stream needs:

* sequence numbers;
* timestamps;
* stream/session identity;
* bounded buffering;
* ordering information;
* loss detection;
* duplicate detection where applicable;
* backpressure;
* stream-start coordination;
* stream termination;
* recovery behavior.

A participant must be able to determine:

```text
Which audio frame is this?
When was it captured?
Which session does it belong to?
Is it newer than what I already received?
Can it be scheduled for output?
```

---

# 20. Why Live Audio Requires Special Handling

Unlike a file transfer, a live audio stream cannot simply wait for every byte to arrive before playback.

The participant must continuously handle:

```text
capture
   ↓
transport
   ↓
network jitter
   ↓
buffer
   ↓
scheduled output
```

Network conditions may vary while the stream is active.

Therefore SoundMesh needs a bounded jitter buffer rather than an unbounded queue.

Too little buffering can cause:

* underruns;
* dropouts;
* audible gaps.

Too much buffering can cause:

* excessive latency;
* poor host/participant alignment;
* delayed recovery.

The correct buffering policy must be experimentally measured.

---

# 21. Audio Packetization

Captured audio SHOULD be divided into bounded frames suitable for network transport.

Conceptually:

```text
Captured Audio
      ↓
Frame 100
Frame 101
Frame 102
Frame 103
      ↓
Network
```

Each frame should contain or be associated with:

```text
stream/session ID
sequence number
capture timestamp
audio payload
format information where required
```

The exact packet structure is implementation-defined.

Frames MUST NOT rely solely on arrival order to determine playback order.

---

# 22. Audio Sequence Numbers

Every live audio stream MUST use monotonically increasing sequence numbers or an equivalent ordering mechanism.

Example:

```text
1001
1002
1003
1004
```

If:

```text
1003
```

arrives after:

```text
1004
```

the participant must recognize that the frame arrived out of order.

Missing sequence numbers should be detectable.

Example:

```text
1001
1002
1004
```

indicates that frame `1003` may have been lost or delayed.

The audio subsystem determines the appropriate recovery behavior.

---

# 23. Audio Timestamps

Every live audio frame MUST be associated with timing information sufficient for synchronized output.

Timestamps SHOULD originate from an appropriate monotonic/native timing source.

Wall-clock time MUST NOT be used as the primary high-precision synchronization clock.

The synchronization specification defines how these timestamps are interpreted.

Networking is responsible for transporting them accurately.

---

# 24. Stream Start Coordination

Participants MUST NOT simply begin output when the first audio frame arrives.

The first received frame is subject to unknown network delay.

Instead, the session should establish:

```text
stream established
       ↓
buffer sufficient audio
       ↓
shared timing information
       ↓
future output target
       ↓
scheduled output
```

This allows the synchronization layer to account for network and device timing.

---

# 25. Host Audio Latency

The host presents a special synchronization problem.

The external media application may produce sound directly through the host's audio output while SoundMesh simultaneously captures that audio for distribution.

Therefore:

```text
External App
     │
     ├──────────────→ Host direct output
     │
     ↓
SoundMesh Capture
     ↓
Network
     ↓
Participants
```

The host's direct audio path and participant audio path may have different latency.

This latency difference MUST be measured.

SoundMesh MUST NOT assume that:

```text
host capture timestamp
=
host audible output timestamp
```

The final host-output synchronization strategy remains an experimental architecture question.

---

# 26. Control Traffic

Control messages include:

* room state;
* participant state;
* session state;
* capture state;
* synchronization commands;
* stream lifecycle;
* errors;
* recovery;
* heartbeats.

Control messages MUST remain responsive even while live audio traffic is active.

---

# 27. Control Plane vs Audio Plane

The networking subsystem should conceptually expose:

```text
CONTROL PLANE

├── room state
├── participant state
├── session state
├── synchronization commands
├── errors
└── heartbeats


AUDIO PLANE

├── live audio frames
├── sequence numbers
├── capture timestamps
├── stream state
└── buffering telemetry
```

They may initially share a physical connection.

They remain logically separate.

---

# 28. Protocol Independence

The logical SoundMesh protocol MUST remain independent of whether the underlying transport is:

```text
TCP
UDP/datagram
future transport
```

The same application-level concepts should remain valid.

This allows the live audio transport to evolve without redesigning room management.

---

# 29. Connection Lifecycle

A participant connection SHOULD follow:

```text
DISCONNECTED
      ↓
CONNECTING
      ↓
CONNECTED
      ↓
AUTHENTICATING
      ↓
READY
      ↓
ACTIVE
      ↓
DEGRADED
      ↓
RECONNECTING
      ↓
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

---

# 30. Connection Establishment

A participant connection SHOULD follow:

```text
QR scanned
    ↓
Bootstrap information validated
    ↓
Host address resolved
    ↓
Transport connection established
    ↓
Protocol handshake
    ↓
Version compatibility checked
    ↓
Join token validated
    ↓
Participant registered
    ↓
Room/session state received
    ↓
Connection READY
```

The participant MUST NOT be considered fully joined merely because a socket opened.

---

# 31. Protocol Handshake

Every connection MUST begin with a protocol handshake.

The handshake should establish:

* protocol version;
* participant ID;
* device role;
* supported capabilities;
* session/room identity;
* authentication/join authorization;
* audio transport capabilities.

Conceptually:

```text
Participant → Host:

HELLO


Host → Participant:

WELCOME
```

---

# 32. Protocol Versioning

Every protocol implementation MUST declare a protocol version.

Example:

```text
protocolMajor
protocolMinor
```

Major-version incompatibility SHOULD result in rejection.

Minor-version differences MAY be supported when compatibility is explicitly defined.

The application MUST NOT silently assume compatibility.

---

# 33. Message Envelope

All SoundMesh protocol messages SHOULD use a common envelope.

Conceptual structure:

```text
Message {
    protocolVersion
    messageType
    messageId
    sessionId
    senderId
    generation
    timestamp
    payload
}
```

Not every field must be transmitted in exactly this form.

The final wire format is an implementation decision.

The protocol MUST provide equivalent semantics.

---

# 34. Message IDs

Messages that require acknowledgement SHOULD have unique message IDs.

Example:

```text
messageId = unique identifier
```

This allows the receiver to detect:

* duplicates;
* retries;
* acknowledgements;
* stale messages.

---

# 35. Generation Numbers

State-changing session commands MUST include a generation or equivalent ordering mechanism.

Example:

```text
generation = 42
```

A participant receiving generation `42` after already processing generation `43` MUST NOT execute the stale state change.

Generations protect against delayed network messages modifying newer session state.

---

# 36. Core Message Categories

The protocol SHOULD support categories such as:

### Session

* `HELLO`
* `WELCOME`
* `JOIN_REQUEST`
* `JOIN_ACCEPTED`
* `JOIN_REJECTED`
* `LEAVE`
* `ROOM_STATE`
* `SESSION_STATE`

### Device

* `DEVICE_INFO`
* `DEVICE_CAPABILITIES`
* `DEVICE_STATE`

### Capture

* `CAPTURE_STATE`
* `CAPTURE_CAPABILITIES`
* `CAPTURE_STARTED`
* `CAPTURE_STOPPED`
* `CAPTURE_ERROR`

### Audio Stream

* `AUDIO_STREAM_INFO`
* `AUDIO_STREAM_START`
* `AUDIO_STREAM_STOP`
* `AUDIO_BUFFER_STATUS`
* `AUDIO_STREAM_ERROR`

Actual audio frames may use a dedicated binary transport rather than normal control messages.

### Synchronization

* `TIME_SYNC_REQUEST`
* `TIME_SYNC_RESPONSE`
* `SYNC_STATUS`
* `TIMING_REPORT`
* `DRIFT_REPORT`
* `RESYNC_REQUEST`

### Health

* `PING`
* `PONG`
* `HEARTBEAT`
* `ERROR`

The exact message set may evolve.

---

# 37. Reliable Commands

Commands that change room or session state MUST be delivered reliably.

A command MUST NOT be silently lost.

Commands should contain enough information to determine whether they are:

* current;
* duplicated;
* stale;
* already executed.

Live audio frames are handled separately because retransmitting every lost frame may increase latency beyond the value of the missing frame.

---

# 38. Session Command Model

A session command should conceptually contain:

```text
command {
    generation
    commandType
    targetTime
    sessionId
}
```

For example:

```text
START_AUDIO_SESSION

sessionId = S
targetTime = T
generation = 18
```

This does not mean:

> begin immediately.

It means:

> begin the corresponding session behavior at the specified synchronized timeline point.

---

# 39. Synchronization Traffic

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

The exact timing algorithm is defined by `synchronization.md`.

Networking MUST preserve timestamps with sufficient accuracy for the synchronization algorithm.

---
 
# 40. Heartbeats
 
Connections SHOULD use heartbeats.
 
Conceptually:
 
```text
Host → Participant: PING
Participant → Host: PONG
```
 
Heartbeats allow SoundMesh to detect:
 
* disconnected devices;
* stalled connections;
* network changes;
* temporary failures.
 
Heartbeat intervals MUST be centrally configurable.
 
Default configuration:
* Interval: 5 seconds
* Timeout: 15 seconds (3 missed intervals)
 
The heartbeat mechanism runs on the native layer (Android/iOS) to avoid Flutter timing bottlenecks. Both host and participant send PING at the configured interval and expect PONG responses. The receiver of a PING must respond with a PONG containing the original messageId for correlation.
 
On heartbeat timeout:
* Host: Marks the participant as disconnected, emits HEARTBEAT_TIMEOUT error
* Participant: Initiates bounded reconnection attempts (see Reconnection)
 
---

# 41. Heartbeat Failure

Missing one heartbeat MUST NOT immediately remove a participant.

Networks can temporarily experience:

* congestion;
* scheduling delays;
* radio interference;
* OS scheduling delays.

The connection manager should use a failure threshold.

Conceptually:

```text
healthy
   ↓
missed heartbeat
   ↓
degraded
   ↓
multiple failures
   ↓
connection lost
```

Exact thresholds must be experimentally determined.
 
---
 
# 42. Network Degradation
 
The networking system SHOULD distinguish:
 
```text
CONNECTED
DEGRADED
DISCONNECTED
```
 
A degraded connection may still be usable.
 
Examples:
 
* increased RTT;
* increased jitter;
* delayed heartbeat;
* increased audio-frame loss;
* reduced throughput;
* growing jitter-buffer pressure.
 
The synchronization/audio systems should receive this information.
 
They may decide to:
 
* increase scheduling margin;
* increase buffering within safe bounds;
* resynchronize;
* temporarily stop output;
* recover the audio stream.
 
Networking only reports the observed condition.
 
---
 
# 43. Reconnection
 
Temporary network loss SHOULD trigger reconnection attempts.
 
Conceptually:
 
```text
ACTIVE
  ↓
CONNECTION LOST
  ↓
RECONNECTING
  ↓
RECONNECTED
  ↓
STATE RESYNC
  ↓
TIMING REVALIDATION
  ↓
AUDIO STREAM RECOVERY
  ↓
ACTIVE
```
 
A participant MUST NOT simply continue normal output after reconnecting without validating its session and timing state.
 
## Reconnection Implementation
 
The reconnection mechanism uses bounded retries with exponential backoff:
 
* Maximum attempts: 5
* Initial delay: 1 second
* Exponential backoff: 1s, 2s, 4s, 8s, 10s (capped at 10s)
* State during retry: `RECONNECTING` (distinct from `FAILED`)
* On success: Returns to `CONNECTED` → `READY`, resumes heartbeat
* On exhaustion: Emits `RECONNECTION_FAILED` error, transitions to `FAILED`
 
The participant stores the last known host IP/port during initial connection for use during reconnection. Clean disconnect (user-initiated) does not trigger reconnection.
 
---

# 44. Reconnection State Recovery

After reconnection, the participant should obtain:

* current room generation;
* current session ID;
* current capture/session state;
* current audio stream state;
* current timing state;
* current synchronization information;
* whether the audio stream is still active;
* whether a fresh stream buffer is required;
* whether recalibration is required.

The participant should then determine whether it can:

```text
resume current session
```

or must:

```text
rebuild buffer
resynchronize
restart audio stream participation
```

---

# 45. Live Audio Stream Recovery

When the network loses live audio frames, the participant MUST NOT treat the event as a file-transfer failure.

Instead, the audio pipeline should determine whether the missing frames can be:

* recovered within the available latency budget;
* concealed or skipped;
* ignored because newer frames have already arrived;
* handled by rebuilding the buffer;
* handled by resynchronization.

The exact policy is an audio/synchronization decision.

---

# 46. Participant Joining

A participant joining an active room should follow:

```text
SCAN QR
   ↓
CONNECT
   ↓
AUTHENTICATE
   ↓
RECEIVE ROOM STATE
   ↓
RECEIVE SESSION STATE
   ↓
CALIBRATE TIMING
   ↓
BUFFER LIVE AUDIO
   ↓
RECEIVE FUTURE OUTPUT TARGET
   ↓
READY
```

If a live audio session is already active, the participant MUST NOT begin output merely because it receives audio data.

It must synchronize to a future point on the shared timeline.

---

# 47. Late Joining

Late joiners must be handled explicitly.

A participant joining while the room is already active should receive:

* current room state;
* current session state;
* current audio stream metadata;
* synchronization information;
* required calibration;
* a sufficient future audio buffer;
* a future synchronization target.

The participant then begins output at the appropriate future point.

---

# 48. Participant Leaving

A participant may leave because of:

* user action;
* connection loss;
* application termination;
* battery shutdown;
* network failure;
* host removal.

The host should update room state.

Remaining participants should not wait indefinitely for a device that has already left.

---

# 49. Host Failure

The MVP does NOT require seamless host migration.

If the host disappears:

```text
HOST LOST
    ↓
ROOM DEGRADED
    ↓
PARTICIPANTS DETECT FAILURE
    ↓
CONTROLLED RECOVERY
```

The MVP may require the session to end and be recreated.

Future versions may investigate participant-to-participant host migration.

---

# 50. Network Change

A device may change network conditions while the application is running.

Examples:

* Wi-Fi disconnect;
* Wi-Fi reconnect;
* hotspot changes;
* interface changes;
* temporary network loss;
* network becomes unavailable.

A network change MUST trigger explicit state handling.

It MUST NOT be treated as an invisible implementation detail.

---

# 51. IP Addresses Are Not Device Identity

An IP address MUST NOT be used as the permanent identity of a participant.

IP addresses can change.

For example:

```text
Participant A

192.168.1.7
    ↓
network reconnect
    ↓
192.168.1.12
```

The participant identity remains unchanged.

Only the connection address changes.

---

# 52. Discovery vs Connection

These concepts MUST remain separate.

### Discovery

Answers:

> Where is a SoundMesh service?

### Connection

Answers:

> Can I establish communication with that device?

### Authentication

Answers:

> Is this participant allowed into this room?

### Session registration

Answers:

> Is this participant currently part of the room?

The implementation should not collapse these responsibilities into one mechanism.

---

# 53. QR as the MVP Discovery Escape Hatch

The MVP should not become dependent on automatic discovery working perfectly.

QR joining provides a deterministic bootstrap:

```text
Automatic discovery
       ↓
if unavailable
       ↓
QR bootstrap
       ↓
direct connection
```

This allows SoundMesh to function without requiring a sophisticated discovery system.

---

# 54. Network Security Model

SoundMesh is a local application, but local networks cannot automatically be considered trusted.

The system SHOULD assume another device may be present on the same Wi-Fi network.

Therefore, room communication SHOULD use:

* short-lived join credentials;
* room-scoped authorization;
* authenticated protocol messages;
* integrity protection;
* no unnecessary personal data.

The exact cryptographic protocol is an architectural decision that must be researched and recorded in `decisions.md`.

---

# 55. Encryption

Encryption SHOULD be used for sensitive room communication.

Cryptographic implementation MUST NOT be improvised.

The project should prefer:

* established Android cryptographic APIs;
* established protocol libraries;
* standard authenticated encryption;
* well-reviewed primitives.

The MVP must not invent a custom encryption algorithm.

The encryption strategy for high-throughput audio transport must also be evaluated for CPU, latency, and battery impact.

---

# 56. Threat Model

The minimum networking threat model should consider:

### Unauthorized room joining

A nearby device attempts to join without permission.

### QR interception

Someone sees the QR code and attempts to join.

### Message injection

A device on the same network attempts to send fake control messages.

### Message replay

An old session command is resent.

### Stale command execution

A delayed command arrives after a newer command.

### Room impersonation

A malicious device attempts to pretend to be the host.

### Audio tampering

Live audio data is modified or corrupted in transit.

### Audio stream flooding

A malicious device attempts to overwhelm a participant with excessive audio data.

### Denial of service

A malicious device floods the local room with traffic.

The MVP does not need enterprise-grade security, but these threats should influence protocol design.

---

# 57. Message Ordering

Messages must be categorized according to whether ordering matters.

For example:

```text
SESSION_STATE generation 10

SESSION_STATE generation 11

SESSION_STATE generation 12
```

A delayed generation `10` message must not override generation `12`.

Generation numbers or equivalent ordering metadata MUST therefore be used for state-changing commands.

Live audio ordering is handled separately using sequence numbers.

---

# 58. Duplicate Messages

The protocol should tolerate duplicate control messages where practical.

Example:

```text
SESSION_UPDATE #42
SESSION_UPDATE #42
```

The second instance should be recognized as a duplicate rather than causing the state transition twice.

This is especially important if future transports introduce retries.

---

# 59. Error Model

Networking errors MUST be structured.

Examples:

```text
NETWORK_UNAVAILABLE
NETWORK_UNREACHABLE
CONNECTION_REFUSED
CONNECTION_TIMEOUT
HANDSHAKE_FAILED
HEARTBEAT_TIMEOUT
PROTOCOL_VERSION_MISMATCH
AUTHENTICATION_FAILED
ROOM_NOT_FOUND
ROOM_FULL
PEER_DISCONNECTED
NETWORK_CHANGED
PERMISSION_DENIED
DISCOVERY_FAILED
AUDIO_TRANSPORT_FAILED
AUDIO_STREAM_INTERRUPTED
AUDIO_BUFFER_UNDERRUN
AUDIO_FRAME_LOSS
TRANSPORT_UNAVAILABLE
```

The UI should receive actionable error categories rather than raw socket exceptions.

Audio-specific errors should remain distinguishable from ordinary connection failures.

---

### 59.1 Error Code Definitions

| Error Code | Description |
|------------|-------------|
| `NETWORK_UNREACHABLE` | Host unreachable at IP layer (e.g., AP/client isolation, no route to host). Distinct from CONNECTION_REFUSED. |
| `CONNECTION_REFUSED` | Host reachable at IP layer, but no listener on the target port. |
| `CONNECTION_TIMEOUT` | TCP connection attempt timed out. |
| `HANDSHAKE_FAILED` | TCP connected, but protocol/version mismatch or handshake protocol failure. |
| `HEARTBEAT_TIMEOUT` | No heartbeat response within configured timeout threshold. |
| `PROTOCOL_VERSION_MISMATCH` | Protocol version negotiation failed (major version mismatch). |
| `INVALID_PAYLOAD` | Bootstrap payload malformed/corrupt (see 14.2). |
| `CODE_EXPIRED` | Short-lived join credential expired (see 14.2). |
| `CODE_NOT_FOUND` | Discovery scan timeout: requested room code not found (see 14.2). |
| `ROOM_NOT_FOUND` | Host-side rejection after a connect attempt (reserved, see 14.2). |

# 60. Permission Errors

Platform permission failures MUST be surfaced separately from ordinary network failures.

For example:

```text
LOCAL_NETWORK_PERMISSION_DENIED
```

must not simply become:

```text
CONNECTION_FAILED
```

Similarly, audio-capture permission failures belong to the capture subsystem and must not be disguised as network failures.

This allows the UI to explain the actual problem.

---

# 61. Network State Machine

The overall networking subsystem SHOULD use a state machine similar to:

```text
                         ┌───────────────┐
                         │  DISCONNECTED │
                         └───────┬───────┘
                                 │
                              connect
                                 │
                                 ▼
                         ┌───────────────┐
                         │   CONNECTING  │
                         └───────┬───────┘
                                 │
                              success
                                 │
                                 ▼
                         ┌───────────────┐
                         │ AUTHENTICATING│
                         └───────┬───────┘
                                 │
                              success
                                 │
                                 ▼
                         ┌───────────────┐
                         │     READY     │
                         └───────┬───────┘
                                 │
                              active
                                 │
                                 ▼
                         ┌───────────────┐
                         │     ACTIVE    │
                         └───────┬───────┘
                                 │
                         network degradation
                                 │
                                 ▼
                         ┌───────────────┐
                         │   DEGRADED    │
                         └───────┬───────┘
                                 │
                         connection lost
                                 │
                                 ▼
                         ┌───────────────┐
                         │ RECONNECTING  │
                         └───────┬───────┘
                                 │
                       ┌─────────┴─────────┐
                       │                   │
                    success              failure
                       │                   │
                       ▼                   ▼
                    ACTIVE              FAILED
```

The exact implementation may differ, but equivalent state semantics are required.
 
## 61.1 Implemented State Machine (Phase 6)
 
The Phase 6 implementation uses a simplified state machine aligned with the connection lifecycle:
 
```text
DISCONNECTED
      ↓
CONNECTING
      ↓
HANDSHAKING
      ↓
CONNECTED
      ↓
READY (handshake complete, room joined)
      ↓
RECONNECTING (on heartbeat timeout / connection loss)
      ↓
CONNECTED (reconnection success)
      ↓
READY (state resync)
 
RECONNECTING → FAILED (after 5 bounded retries)
CONNECTED → DISCONNECTED (clean leave / disconnect())
```
 
This state machine is exposed via `NetworkConnectionState` enum on the Dart side and corresponding string states on the native side.
 
---

# 62. Networking and Synchronization Boundary

Networking provides:

```text
Connection
Message transport
Audio transport
Timestamps
Sequence numbers
RTT measurements
Connection state
Stream state
```

Synchronization provides:

```text
Clock offset
Clock relationship
Latency interpretation
Shared timeline
Scheduled output
Drift estimation
Drift correction
Resynchronization
```

Networking MUST NOT decide whether two devices are "synchronized."

---

# 63. Timing Data Requirements

Networking must provide timestamps from an appropriate monotonic timing source where timing measurements are required.

Wall-clock time such as:

```text
2026-09-05 23:00:00
```

must not be assumed to be suitable for precise synchronization.

The synchronization layer defines the clock model.

---

# 64. Control Plane vs Timing Plane

The networking architecture should conceptually distinguish:

```text
CONTROL PLANE

├── room state
├── participant state
├── session state
├── errors
└── heartbeats


TIMING PLANE

├── timestamp exchange
├── RTT measurements
├── timing reports
└── synchronization diagnostics
```

They may initially use the same physical connection.

They remain logically separate so the timing system can evolve independently.

The live audio plane is separate from both logically:

```text
AUDIO PLANE

├── audio frames
├── sequence numbers
├── capture timestamps
├── stream state
└── buffering
```

---

# 65. Avoiding Flutter Timing Bottlenecks

High-frequency timing and audio traffic MUST NOT require:

```text
Native
  ↓
Flutter
  ↓
Native
  ↓
Flutter
```

for every event.

Flutter is the application/UI layer.

Timing-sensitive loops and audio transport processing should remain as close as practical to native timing and audio infrastructure.

Flutter should receive meaningful state rather than every low-level frame or timestamp.

---

# 66. Connection Manager

The application SHOULD contain a dedicated connection manager responsible for:

* connection lifecycle;
* peer registration;
* reconnect attempts;
* connection state;
* message routing;
* heartbeat;
* protocol errors;
* transport abstraction.

The connection manager MUST NOT contain audio synchronization algorithms.

---

# 67. Room Manager

A room manager should be responsible for:

* room creation;
* room identity;
* participant registration;
* participant removal;
* room state;
* host authority;
* room lifecycle.

The room manager communicates with the connection manager.

---

# 68. Protocol Layer

A dedicated protocol layer should convert application events into wire messages.

Conceptually:

```text
RoomManager
     ↓
Protocol
     ↓
Transport
     ↓
Socket / Stream
```

This prevents application code from becoming coupled directly to transport implementation details.

---

# 69. Live Audio Transport Layer

A dedicated live-audio transport layer should handle:

* stream creation;
* frame packetization;
* sequence numbers;
* timestamps;
* sending;
* receiving;
* reordering;
* loss detection;
* buffering;
* backpressure;
* stream termination;
* transport statistics.

Conceptually:

```text
AudioCapture
      ↓
LiveAudioTransport
      ↓
Transport
      ↓
Network
      ↓
Transport
      ↓
LiveAudioTransport
      ↓
AudioOutput
```

This layer must remain separate from the external media application's playback controls.

---

# 70. Suggested Logical Architecture

```text
┌─────────────────────────────────────────────┐
│                  Flutter                    │
│                                             │
│ UI                                          │
│ Room Controller                             │
│ Session Controller                          │
│ Application State                           │
└──────────────────────┬──────────────────────┘
                       │
                  Typed API
                       │
┌──────────────────────▼──────────────────────┐
│             Android Native Layer             │
│                                             │
│ Connection Manager                          │
│ Room Manager                                │
│ Protocol                                    │
│ Control Transport                           │
│ Live Audio Transport                        │
│ Timing Transport                            │
│ Network Monitoring                          │
└───────────────┬───────────────┬─────────────┘
                │               │
             Control         Audio
             Traffic         Stream
                │               │
                └───────┬───────┘
                        │
                  Local Network
```

Audio capture and native audio output are defined by `audio.md`, not by the networking layer.

---

# 71. Network Events

The networking subsystem SHOULD emit structured events such as:

```text
PeerConnected
PeerDisconnected
PeerDegraded
PeerReconnected

RoomStateChanged
SessionStateChanged

AudioStreamStarted
AudioStreamStopped
AudioStreamDegraded
AudioFrameLossDetected
AudioBufferPressureChanged

NetworkChanged

ProtocolError
PermissionError
TransportError
```

These events should be consumed by the application state layer.

---

# 72. Observability

Networking must expose diagnostic information during development.

Useful metrics include:

* connection establishment time;
* RTT;
* minimum RTT;
* RTT variance;
* audio bytes transmitted;
* audio throughput;
* audio frame rate;
* frame loss;
* frame reordering;
* stream latency;
* jitter-buffer depth;
* buffer underruns;
* reconnect count;
* heartbeat failures;
* message count;
* failed messages;
* protocol errors;
* network state;
* active participant count.

These metrics are important for determining why synchronization succeeds or fails.

---

# 73. Debug Mode

A development/debug mode SHOULD expose networking diagnostics.

Example:

```text
Room: A7F2
Role: HOST
Peers: 3

Peer A
Connected: 12.4 s
RTT: 8.2 ms
Audio: ACTIVE
Buffer: 84 ms
State: READY

Peer B
Connected: 11.9 s
RTT: 15.4 ms
Audio: ACTIVE
Buffer: 91 ms
State: ACTIVE

Peer C
Connected: 11.7 s
RTT: 24.1 ms
Audio: DEGRADED
Buffer: 42 ms
State: DEGRADED
```

This should not necessarily be visible in the production UI.

---

# 74. Network Stress Testing

Networking must be tested under:

* high latency;
* variable latency;
* packet loss;
* temporary disconnection;
* Wi-Fi interference;
* bandwidth limitation;
* multiple simultaneous participants;
* hotspot mode;
* router-based Wi-Fi;
* Android-only groups.

Testing should use real devices wherever platform behavior matters.

The MVP does not require iOS networking validation.

---

# 75. Device Scaling

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

* network throughput;
* host CPU;
* audio encoding/transport cost;
* connection count;
* protocol overhead;
* synchronization quality;
* device hardware;
* hotspot limitations;
* audio buffering requirements.

---

# 76. Network Scaling Strategy

Unlike the previous architecture, live audio MUST be transported during an active audio session.

The initial topology is:

```text
                 Host
              /   |   \
             /    |    \
        audio   audio   audio
          /       |       \
         A        B        C
```

The host therefore has to support simultaneous live audio delivery to participants.

The architecture should be measured for:

* host upload throughput;
* CPU usage;
* memory;
* participant latency;
* jitter;
* packet/frame loss;
* synchronization quality.

If direct host-to-participant streaming becomes a bottleneck, future architectures may investigate:

* peer-assisted forwarding;
* relay participants;
* multicast where available;
* alternative transport strategies.

These are experimental and MUST NOT become assumptions without measurement.

---

# 77. Backpressure

The networking layer MUST account for slow participants.

A slow participant must not indefinitely block faster participants.

For example:

```text
Participant A → AUDIO HEALTHY
Participant B → AUDIO HEALTHY
Participant C → AUDIO DEGRADED
```

The host should maintain explicit per-participant stream state.

The audio/synchronization layers determine the appropriate response.

Networking only reports the actual transport condition.

---

# 78. Cancellation

Long-running operations should be cancellable.

Examples:

* connection attempt;
* discovery;
* reconnection;
* room joining;
* live audio stream;
* stream recovery.

A cancelled operation must clean up:

* sockets;
* audio transport buffers;
* timers;
* pending callbacks;
* state;
* background tasks.

---

# 79. Resource Management

Networking code MUST avoid:

* leaked sockets;
* unbounded audio buffers;
* infinite retry loops;
* orphaned timers;
* duplicate connections;
* stale callbacks;
* uncontrolled background tasks;
* unbounded packet queues.

Every connection and stream must have a clear owner and lifecycle.

---

# 80. Duplicate Connections

The host should prevent multiple active connections representing the same participant identity.

If a participant reconnects:

```text
old connection
     ↓
new connection
```

the room manager must decide which connection is authoritative.

The old connection should be invalidated.

---

# 81. Room Closure

When the host closes a room:

```text
ROOM_CLOSING
     ↓
notify participants
     ↓
stop accepting joins
     ↓
stop live audio stream
     ↓
close timing activity
     ↓
close connections
     ↓
ROOM_CLOSED
```

Participants should cleanly return to the disconnected state.

---

# 82. Network Permissions and UX

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

and:

```text
Audio capture unavailable
```

and:

```text
Source application does not permit capture
```

---

# 83. No Internet Requirement

A successful MVP test must be possible with:

```text
Internet = OFF
```

while:

```text
Local Wi-Fi = ON
```

The following must still work:

* create room;
* join room;
* establish local connections;
* capture eligible external audio;
* transport live audio;
* synchronize output;
* monitor session state;
* leave.

Internet access must not be required by the SoundMesh architecture itself.

---

# 84. Failure Matrix

| Failure                            | Expected networking behavior                 |
| ---------------------------------- | -------------------------------------------- |
| Wi-Fi unavailable                  | Clearly report network unavailable           |
| Host unreachable                   | Connection fails with actionable state       |
| Wrong room token                   | Reject join                                  |
| Protocol mismatch                  | Reject connection                            |
| Participant disconnects            | Mark participant disconnected                |
| Participant reconnects             | Re-authenticate and resync state             |
| Audio stream fails                 | Report stream failure and allow recovery     |
| Audio frames are lost              | Detect loss and expose transport degradation |
| Network temporarily degrades       | Mark connection degraded                     |
| Host disappears                    | Enter controlled recovery                    |
| Duplicate command                  | Ignore duplicate                             |
| Stale command                      | Ignore stale generation                      |
| Room closes                        | Disconnect cleanly                           |
| Network changes                    | Re-evaluate connection and reconnect         |
| Internet unavailable               | No effect on local operation                 |
| Capture permission denied          | Capture subsystem reports permission failure |
| Source audio is not captureable    | Report source incompatibility                |
| Audio transport underruns          | Report stream degradation                    |
| Participant cannot maintain buffer | Mark participant degraded                    |

---

# 85. MVP Networking Requirements

The MVP networking implementation MUST support:

### Required

* host/participant model;
* local Wi-Fi;
* phone hotspot testing;
* QR-based room joining;
* direct host-participant connections;
* protocol handshake;
* room identity;
* participant identity;
* protocol versioning;
* reliable control messages;
* live audio transport;
* audio sequence numbers;
* audio timestamps;
* bounded participant buffering;
* heartbeats;
* connection state;
* reconnect handling;
* network failure reporting;
* synchronization timestamp exchange;
* generation-based stale-command protection;
* offline local operation.

### Preferred

* automatic local discovery;
* rich diagnostics;
* graceful late joining;
* degraded-network classification;
* stream recovery without restarting the entire room.

### Experimental

* UDP/datagram audio transport;
* specialized timing channel;
* Wi-Fi Direct;
* peer-to-peer audio forwarding;
* multicast;
* host migration;
* advanced transport optimization.

---

# 86. Explicit Non-Goals

The MVP networking system is NOT required to provide:

* Internet audio relay;
* cloud relay servers;
* global device discovery;
* remote rooms over the Internet;
* social networking;
* user accounts;
* persistent device identity;
* enterprise networking;
* arbitrary WAN synchronization;
* seamless host migration;
* unlimited device scaling;
* media-file distribution;
* SoundMesh-owned media playback;
* media library synchronization;
* subtitles or video synchronization;
* seek/pause/playback control over the external media application.

---

# 87. Important Architectural Rule

Do not optimize the networking layer for theoretical throughput before measuring the actual SoundMesh bottleneck.

The important question is not:

> "What networking technology is fastest?"

The important question is:

> "What networking architecture produces the most reliable, measurable synchronized live audio on real heterogeneous Android devices with the least unnecessary complexity?"

The architecture MUST prioritize measured:

```text
latency
jitter
frame loss
buffer behavior
CPU
memory
battery
synchronization quality
```

over theoretical benchmark numbers.

---

# 88. Experimental Networking Plan

Networking should be validated progressively.

## Experiment 1 — Basic Local Connection

Two Android phones on the same Wi-Fi network.

Verify:

* connection;
* handshake;
* message exchange;
* disconnect.

---

## Experiment 2 — QR Bootstrap

Verify:

```text
QR
→ connect
→ authenticate
→ join
```

---

## Experiment 3 — Offline Operation

Disable Internet access.

Verify room creation, joining, control, and local networking.

---

## Experiment 4 — Live Audio Transport

Use one Android device as the host.

Capture eligible external application audio.

Verify:

* audio frames are captured;
* frames are packetized;
* frames reach a participant;
* sequence numbers are correct;
* timestamps are preserved;
* participant buffering works;
* audio output is produced.

---

## Experiment 5 — Two-Device Synchronization

Host and participant receive the same live captured audio.

Measure:

* capture-to-output latency;
* network latency;
* jitter;
* output timing difference;
* audible synchronization.

Compare results against `synchronization.md`.

---

## Experiment 6 — External Source Compatibility

Test several eligible external audio sources where technically and legally appropriate.

Examples may include:

* YouTube;
* VLC;
* browser audio;
* Spotify;
* other Android media applications.

Verify whether each source permits capture.

The test must record incompatibilities rather than assuming every application is captureable.

---

## Experiment 7 — Host Direct Output vs Participant Output

Measure:

```text
External app
     ↓
Host direct audio
```

against:

```text
External app
     ↓
Capture
     ↓
Network
     ↓
Participant output
```

Determine the actual latency difference.

This experiment is critical to the host synchronization architecture.

---

## Experiment 8 — Hotspot

Use one Android phone as a hotspot.

Test:

```text
Host + 1 participant
Host + 2 participants
Host + 4 participants
```

Measure connection reliability and live audio behavior.

---

## Experiment 9 — Network Stress

Introduce:

* congestion;
* temporary disconnect;
* reconnect;
* high RTT;
* jitter;
* packet loss;
* bandwidth limitation.

Measure:

* audio loss;
* buffering;
* underruns;
* synchronization impact;
* recovery time.

---

## Experiment 10 — Long Session

Run a continuous live audio session.

Measure:

* drift;
* buffer stability;
* memory usage;
* CPU usage;
* battery impact;
* frame loss;
* reconnection behavior.

---

## Experiment 11 — Scaling

Test:

```text
2
3
5
10
```

devices where hardware availability permits.

Measure:

* connection time;
* audio throughput;
* host CPU;
* participant CPU;
* memory;
* network usage;
* synchronization quality;
* failure rate.

---

# 89. Networking Acceptance Criteria

The networking architecture is considered MVP-ready only when:

1. two real Android devices can create and join a local room;
2. the room works without Internet access;
3. QR joining works reliably;
4. participants receive unique identities;
5. protocol versions are validated;
6. reliable control messages work;
7. live captured audio can be transported between devices;
8. live audio frames contain usable sequence and timing information;
9. participants maintain bounded audio buffers;
10. the synchronization layer can perform timestamp exchanges;
11. stale session commands cannot override newer state;
12. heartbeats detect meaningful connection failures;
13. temporary disconnections can be detected and handled;
14. network failures produce actionable states;
15. live audio transport remains responsive while control traffic is active;
16. the architecture does not require Flutter for high-frequency timing or audio transport operations;
17. network behavior is measurable;
18. two real devices can produce synchronized audible output from the captured external audio;
19. source applications that refuse capture are handled explicitly;
20. host direct-output latency versus participant-output latency has been measured;
21. background/foreground-service interaction required for the capture architecture has been validated;
22. all important networking behavior has automated or repeatable tests;
23. no Internet connection is required for ordinary SoundMesh operation;
24. the networking architecture does not turn SoundMesh into a media player or file-distribution system.

---

# 90. Open Questions

The following remain intentionally unresolved until experiments provide evidence.

1. Which exact Flutter networking abstraction should be used?
2. Should initial socket handling remain entirely in native Android code?
3. Should control transport use TCP initially?
4. Should live audio use TCP initially?
5. Does a datagram transport measurably improve live audio behavior?
6. What exact wire serialization format should be used?
7. JSON, MessagePack, protobuf, or another format?
8. Should timing probes initially share the control transport?
9. Does a specialized timing channel improve synchronization?
10. What local discovery mechanism is most reliable on target Android devices?
11. How much should QR joining replace automatic discovery?
12. What exact join-token mechanism should be used?
13. Should connections use TLS or another authenticated encrypted transport?
14. How should encryption keys be established?
15. What audio frame size provides the best latency/CPU tradeoff?
16. Should the live audio stream use PCM or a compressed representation?
17. What jitter-buffer depth provides the best reliability without excessive latency?
18. How should lost audio frames be handled?
19. How should the host's direct audio latency be measured?
20. Should the host also route captured audio through the SoundMesh output pipeline?
21. What transport behavior is required while the host switches to an external media application?
22. What background/foreground-service behavior is required on target Android versions?
23. How should source applications that disable capture be communicated to the user?
24. What is the practical maximum number of participants?
25. How should hotspot-specific limitations be handled?
26. How should network changes be detected?
27. How aggressively should reconnect attempts occur?
28. Which diagnostics should be visible to users?
29. Which diagnostics should remain developer-only?
30. Which networking choices produce the best synchronization results on real heterogeneous Android phones?

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

---

# 91. Final Networking Principle

SoundMesh does not need the fanciest networking stack.

It needs a networking layer that is:

* local-first;
* reliable;
* measurable;
* low-latency;
* resilient;
* secure enough for its environment;
* simple enough to maintain;
* capable of carrying live captured audio;
* capable of providing precise timing information;
* independent from the Flutter UI;
* compatible with the synchronization architecture.

The networking system exists to make this possible:

```text
                    SOUND MESH

                        │
             ┌──────────┼──────────┐
             │          │          │
          NETWORK     AUDIO      TIMING
             │          │          │
       connect devices  │    measure clocks
       send commands    │    estimate latency
       detect failure   │    schedule output
             │          │    correct drift
             │          │          │
             └──────────┼──────────┘
                        │
                 LIVE AUDIO SESSION
                        │
              Multiple phones behave
                 like one speaker
```

**Core principle:**

> The network should carry the live sound and the coordination required to synchronize it, without turning SoundMesh into a media player.

> SoundMesh should make network complexity invisible to the user while making its behavior observable to the engineers.
