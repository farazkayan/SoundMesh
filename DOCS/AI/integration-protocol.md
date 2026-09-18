# SoundMesh — Integration Protocol

**Status:** ACTIVE
**Owner:** Faraz
**Last Updated:** 2026-09-06

---

## 1. Purpose

This document defines how SoundMesh's major subsystems integrate with one another.

It establishes the boundaries between:

* Flutter UI and application state
* Android-native audio capture
* Audio networking
* Synchronization and timing
* Native scheduled audio output
* Room/session lifecycle

This document is an integration contract, not an implementation guide.

---

## 2. Architecture

The authoritative live-audio path is:

```text
External Media App
        ↓
Android AudioPlaybackCapture
        ↓
Native Audio Capture
        ↓
Timestamp + Sequence Number
        ↓
Live Audio Transport
        ↓
Participant Jitter Buffer
        ↓
Synchronization / Shared Timeline
        ↓
Native Scheduled Audio Output
        ↓
Speakers
```

Flutter observes and controls high-level application state around this pipeline.

Flutter does not execute the high-frequency audio path.

---

## 3. System Ownership

### Flutter

Flutter owns:

* UI
* navigation
* room creation/joining UX
* QR presentation/scanning
* capture-permission UX
* session status presentation
* connection status
* synchronization status
* recovery UX
* coarse diagnostics
* user-facing session lifecycle actions

Flutter does not own:

* audio frame transport
* sample-level scheduling
* jitter-buffer timing
* monotonic clock calculations
* real-time audio output
* external media playback
* media seeking
* media pause/resume
* media selection

---

### Android Native Layer

Android-native code owns:

* AudioPlaybackCapture
* MediaProjection lifecycle
* foreground-service requirements
* captured PCM/audio frames
* capture timestamps
* sequence numbers
* high-frequency audio transport
* jitter buffering
* native output
* scheduled rendering
* monotonic timing
* output timestamps
* audio-route handling
* interruption handling
* capture/output recovery

---

### Room / Session Layer

The room/session layer owns:

* room identity
* participant membership
* host/participant roles
* session generation
* lifecycle state
* connection state
* capability/status exchange

It does not own media playback.

---

### Synchronization Layer

Synchronization owns:

* shared timeline
* clock-offset estimation
* timing measurements
* output scheduling targets
* drift detection
* drift correction policy
* resynchronization

Synchronization does not capture or render audio.

---

### External Media Application

The external media application owns:

* media selection
* play/pause
* seeking
* playback speed
* track selection
* subtitles
* media position
* media-specific controls

SoundMesh observes the resulting audio stream rather than attempting to control the external application.

---

## 4. Integration Boundary

The primary integration boundary is:

```text
Flutter
   ↕
Native SoundMesh Bridge
   ↕
Native Audio / Networking / Timing Systems
```

The bridge should expose low-frequency commands, state, and diagnostics.

It must not continuously send individual audio frames through Flutter.

---

## 5. Native Bridge Principles

The Flutter/native bridge should:

* use explicit typed commands
* return explicit success/failure results
* expose stable state values
* expose coarse-grained events
* expose diagnostics when requested
* avoid high-frequency event flooding
* avoid transferring large audio buffers through Flutter
* preserve session-generation information
* reject stale commands

Audio frames should remain entirely within native code.

---

## 6. Session Generation

Every active audio session has a monotonically increasing:

```text
sessionGeneration
```

Generation values protect the system against stale asynchronous work.

Any native operation involving a live session should validate its generation.

Examples of stale work that must be rejected:

* old audio frames
* delayed network packets
* previous output schedules
* old recovery callbacks
* callbacks from a stopped capture session
* callbacks from a previous room session

A newer generation always invalidates older session work.

---

## 7. High-Level Commands

The exact method names are implementation-defined, but the bridge should provide concepts equivalent to:

```text
createRoom()
joinRoom(joinData)

getRoomState()
getSessionState()

requestCapturePermission()
startCapture()
stopCapture()
getCaptureState()

startAudioSession()
stopAudioSession()

getOutputState()
getSyncState()

getDiagnostics()
```

Commands that directly control external media must not exist.

The following are explicitly outside the SoundMesh API:

```text
play()
pause()
resume()
seek()
next()
previous()
selectTrack()
```

---

## 8. Capture Integration

The capture subsystem reports coarse state to the application layer.

Conceptual states:

```text
UNAVAILABLE
PERMISSION_REQUIRED
READY
CAPTURING
INTERRUPTED
DEGRADED
ERROR
STOPPED
```

Important capture events include:

```text
CapturePermissionRequired
CaptureStarted
CaptureStopped
CaptureInterrupted
SourceNotCaptureable
CapturePermissionRevoked
CaptureFormatChanged
CaptureError
```

The UI should translate these into user-understandable states.

---

## 9. Audio Frame Integration

Captured audio frames remain inside the native realtime path.

Conceptual frame:

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

The frame must contain enough metadata for:

* ordering
* generation validation
* timing
* format validation
* loss detection

Flutter must not receive every `AudioFrame`.

---

## 10. Networking Integration

Networking receives captured frames from the native capture layer and delivers them to participant native audio pipelines.

Conceptual flow:

```text
Capture
  ↓
Packetizer
  ↓
Transport
  ↓
Receiver
  ↓
Jitter Buffer
  ↓
Output Scheduler
```

Networking reports coarse metrics such as:

* connected devices
* RTT
* jitter
* packet loss
* packet gaps
* throughput
* reconnect state
* buffer health

The exact transport protocol remains an implementation decision until measured on real devices.

---

## 11. Jitter Buffer Integration

The jitter buffer absorbs network timing variation before output.

It must:

* preserve sequence ordering
* reject stale generations
* detect missing frames
* track buffer fill
* identify late frames
* prevent unbounded memory growth
* report underruns
* provide frames to the output scheduler according to the shared timeline

Buffering must remain bounded.

One slow participant must not indefinitely block every other participant.

---

## 12. Synchronization Integration

Synchronization consumes timing information from:

* room/session timing
* network measurements
* capture timestamps
* local monotonic clock
* output timestamps

It produces:

```text
targetOutputTime
```

or an equivalent scheduling target.

The output layer executes this target.

The output layer must not independently invent synchronization corrections.

---

## 13. Output Integration

The native output layer receives audio from the jitter buffer and schedules rendering against the synchronization timeline.

Conceptual operations:

```text
startOutputSession()
enqueueFrame()
scheduleFrame()
flushOutput()
stopOutputSession()
getOutputTimestamp()
getOutputState()
```

The output layer owns:

* rendering
* scheduling
* underrun detection
* output timestamps
* audio-route changes
* interruption state

It does not own:

* media files
* songs
* duration
* seeking
* external-app playback controls

---

## 14. Host Output

In the MVP, the host's external media application normally outputs directly through the host device's audio route.

The participant path is:

```text
External App
    ↓
Capture
    ↓
Network
    ↓
Buffer
    ↓
Scheduled Output
```

Therefore:

```text
host direct-output latency
≠
participant replay latency
```

This difference must be measured rather than assumed away.

Host-routing through SoundMesh may be investigated as an experiment, but it is not part of the required MVP contract.

---

## 15. Flutter State Model

Flutter should receive a coarse representation of system state.

Example:

```text
RoomState
SessionState
CaptureState
ConnectionState
SyncState
OutputState
DiagnosticsState
```

The UI should never infer technical state from arbitrary strings or missing callbacks.

State transitions should be explicit.

---

## 16. Recommended Session Flow

The normal integration sequence is:

```text
Create / Join Room
        ↓
Connect Participants
        ↓
Prepare Audio Session
        ↓
Request Capture Permission
        ↓
Start Capture
        ↓
Open External Media App
        ↓
External App Produces Audio
        ↓
Capture Audio
        ↓
Transport Audio
        ↓
Fill Participant Buffers
        ↓
Synchronize Timeline
        ↓
Schedule Output
        ↓
Active Session
```

The user remains in the external media application while SoundMesh continues operating in the background as required by Android lifecycle rules.

---

## 17. External Media Handoff

SoundMesh should provide a clear handoff:

```text
SoundMesh is ready.

Open your media app and play normally.
SoundMesh will capture eligible audio automatically.
```

After capture begins:

```text
SoundMesh is listening.
```

During streaming:

```text
Streaming
Everyone is getting synchronized audio.
```

SoundMesh must not present its own media-player controls.

---

## 18. Error Propagation

Errors should propagate upward without losing their original meaning.

Example:

```text
Android Capture
    ↓
SOURCE_NOT_CAPTUREABLE
    ↓
Session Layer
    ↓
Flutter
    ↓
"This app doesn't allow audio capture."
```

Do not convert technical failures into misleading generic messages.

Important error categories include:

```text
CAPTURE_PERMISSION_DENIED
CAPTURE_UNAVAILABLE
SOURCE_NOT_CAPTUREABLE
MEDIAPROJECTION_REVOKED
CAPTURE_INTERRUPTED

NETWORK_UNAVAILABLE
NETWORK_TIMEOUT
PACKET_LOSS
STREAM_UNDERRUN

OUTPUT_UNAVAILABLE
AUDIO_ROUTE_CHANGED
OUTPUT_INTERRUPTED

CLOCK_SYNC_FAILED
SYNC_DEGRADED
RESYNC_REQUIRED
```

---

## 19. Recovery Integration

Recovery is coordinated across layers.

Example:

```text
Network interruption
        ↓
Networking detects failure
        ↓
Session becomes DEGRADED
        ↓
Flutter displays recovery state
        ↓
Networking reconnects
        ↓
Current generation remains valid
        ↓
Jitter buffer refills
        ↓
Synchronization recalculates timing
        ↓
Output resumes at a future target
        ↓
Session returns ACTIVE
```

Recovery must never replay stale audio from a previous generation.

---

## 20. Audio Route Changes

When an output route changes:

```text
Native Output
    ↓
Route Changed
    ↓
Session / Sync notified
    ↓
Output timing re-measured
    ↓
Synchronization recalibrated if required
```

A route change must not silently preserve an invalid timing assumption.

Examples include:

* speaker → Bluetooth
* Bluetooth → speaker
* wired headset → speaker
* audio device becoming unavailable

---

## 21. Background Operation

SoundMesh must remain capable of maintaining the required capture/session lifecycle when the user switches from SoundMesh to the external media application.

Android-specific foreground-service and notification requirements belong to the native implementation.

Flutter should observe the resulting state rather than attempting to keep the realtime system alive itself.

---

## 22. Performance Boundary

The following must remain native:

```text
Audio capture
Audio frame creation
Packetization
Audio transport
Jitter buffering
Clock calculations
Output scheduling
Audio rendering
```

The following may cross into Flutter:

```text
Connection count
Session state
Capture state
Sync state
Buffer health
Error state
Coarse diagnostics
User commands
```

This boundary is required to avoid unnecessary Dart scheduling and bridge overhead in the realtime path.

---

## 23. Timing Contract

All timing-critical native components should use a monotonic clock.

Do not use wall-clock time for audio scheduling.

Wall-clock timestamps may be used for human-readable diagnostics, but not as the authoritative audio timeline.

---

## 24. Format Contract

The capture format must be propagated consistently through the native pipeline.

At minimum:

```text
sampleFormat
sampleRate
channels
```

must remain consistent between:

```text
Capture
→ Transport
→ Jitter Buffer
→ Output
```

Any conversion must be explicit.

The system must not silently assume that all Android devices produce identical capture formats.

---

## 25. Testing Boundaries

Integration tests should validate subsystem contracts rather than UI appearance alone.

Required areas include:

* capture → transport
* transport → jitter buffer
* jitter buffer → output
* timing → output scheduling
* generation invalidation
* recovery
* route changes
* interruption
* format consistency
* Flutter/native state synchronization

Real-device testing is required for timing-sensitive behavior.

---

## 26. Two-Device Integration Milestone

The first complete integration milestone is:

> Two real Android phones can connect to the same SoundMesh room, capture eligible external-app audio from the host, transport that live audio to the participant, schedule participant output against a shared timeline, and produce measured, repeatable synchronized sound.

This milestone must be demonstrated on physical devices.

A simulated success is insufficient.

---

## 27. Multi-Device Integration

After two-device validation, the system should be tested with:

```text
2 devices
3 devices
5 devices
10 devices
```

where hardware and network conditions permit.

Testing should measure:

* synchronization spread
* packet loss
* jitter
* buffer behavior
* CPU usage
* memory usage
* recovery behavior
* drift
* route differences

---

## 28. Diagnostics

The integration layer should expose enough information to determine where synchronization problems originate.

Useful metrics include:

```text
captureTimestamp
outputTimestamp
RTT
network jitter
packet loss
sequence gaps
buffer fill
buffer underruns
clock offset
estimated drift
output route
capture state
output state
session generation
```

Diagnostics should distinguish:

```text
capture problem
network problem
buffer problem
clock problem
output problem
```

rather than reporting only "sync failed."

---

## 29. API Stability

Public Flutter-facing APIs should remain small and stable.

Implementation details may change internally without requiring UI rewrites.

The following are implementation details unless explicitly promoted into a stable contract:

* TCP vs UDP vs another transport
* PCM vs encoded audio
* AudioTrack vs Oboe vs AAudio
* packet size
* jitter-buffer algorithm
* clock synchronization algorithm
* discovery mechanism
* exact native class structure

Decisions should be driven by experiments and measurements.

---

## 30. Anti-Patterns

The following integration patterns are prohibited:

### Media-player integration

```text
Flutter → play(song)
Flutter → pause()
Flutter → seek()
```

### File-distribution integration

```text
Flutter → selectAudio()
Host → upload file
Participant → download file
Participant → play file
```

### Realtime Flutter audio path

```text
Native → every AudioFrame → Flutter → Native
```

### Fake synchronization

```text
Flutter timers → approximate playback
```

### Stale-session processing

```text
Old frame → current output
Old callback → new session
Old buffer → new generation
```

---

## 31. Definition of Done

The integration layer is considered ready when:

* Flutter can create/join and observe a real room/session.
* Capture can be requested and started through the defined boundary.
* Native audio remains outside Flutter.
* Live captured audio can reach participants.
* Participant output is scheduled against the synchronization timeline.
* Session generations prevent stale work.
* Capture, network, buffer, sync, and output failures are distinguishable.
* Recovery works on real devices.
* Route changes are handled.
* Background operation follows Android requirements.
* Two-device physical validation succeeds.
* Multi-device behavior is measurable.
* No obsolete media-player or file-distribution assumptions remain.

---

## 32. Final Integration Principle

```text
Flutter presents the system.

Capture acquires sound.

Networking transports sound.

Synchronization determines when sound should be rendered.

Output renders sound at that timeline.

Room/session coordinates participants.

The external media app owns the media.
```

SoundMesh integrates these systems without taking ownership of the media itself.
