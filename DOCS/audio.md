# SoundMesh — Audio Specification

**Document status:** Living engineering specification

**Document role:** Defines how SoundMesh captures, transports, buffers, schedules, outputs, monitors, and synchronizes live audio across participating Android devices.

**Primary authority:** This document defines audio-system behavior.

**Related specifications:**

* `DOCS/blueprint.md` — product definition and MVP boundaries
* `DOCS/architecture.md` — application and platform architecture
* `DOCS/networking.md` — communication and live audio transport
* `DOCS/synchronization.md` — timing, clock synchronization, drift correction
* `DOCS/testing.md` — audio and synchronization validation
* `DOCS/decisions.md` — major technology and architecture decisions
* `DOCS/interfaces/audio-api.md` — audio subsystem interface
* `DOCS/interfaces/playback-api.md` — synchronized native output interface

---

# 1. Purpose

SoundMesh exists to make multiple independent smartphones reproduce the same live audio as a coordinated speaker system.

The MVP is an **Android-first live audio synchronization system**.

The host may use an external Android application such as:

* YouTube
* Spotify
* VLC
* a web browser
* a video player
* another application that permits Android audio playback capture

SoundMesh does not own the external media.

Instead:

```text
External media application
          ↓
Host device audio output
          ↓
Android AudioPlaybackCapture
          ↓
SoundMesh live audio pipeline
          ↓
Network distribution
          ↓
Participant audio pipeline
          ↓
Synchronized native output
          ↓
Multiple device speakers
```

The audio subsystem is therefore responsible for:

1. obtaining permission to capture eligible external audio;
2. capturing live audio from the host device;
3. validating the capture configuration;
4. converting captured audio into the transport representation;
5. packetizing or framing live audio;
6. providing timestamps or sequence information;
7. buffering captured audio;
8. transporting live audio to participants;
9. receiving and buffering live audio on participants;
10. scheduling synchronized native output;
11. exposing actual audio timing;
12. detecting output drift;
13. supporting timing correction;
14. handling capture interruptions;
15. handling audio-route changes;
16. handling output-device limitations;
17. detecting underruns and dropouts;
18. reporting meaningful audio state;
19. managing CPU, memory, battery, and thermal usage;
20. providing deterministic behavior within validated Android devices.

The audio subsystem MUST cooperate closely with the networking and synchronization subsystems.

---

# 2. Fundamental Principle

SoundMesh is not distributing a completed audio file for every participant to play later.

It is synchronizing a **live audio stream** captured from the host.

The core problem is therefore:

```text
Live audio capture
        +
Reliable low-latency transport
        +
Buffering
        +
Shared timeline
        +
Device timing
        +
Output latency
        +
Drift monitoring
        +
Correction
```

The system must coordinate both:

```text
WHAT audio should be reproduced
```

and:

```text
WHEN that audio should become audible
```

Two devices receiving the same audio samples does not guarantee synchronized sound.

Two devices receiving the same samples at nearly the same network time does not guarantee synchronized sound either.

---

# 3. Product Audio Model

The authoritative MVP audio model is:

```text
                    HOST

       External Android media app
                    │
                    ▼
          Android audio output
                    │
                    ▼
       AudioPlaybackCapture
                    │
                    ▼
          Capture audio stream
                    │
                    ▼
        SoundMesh live pipeline
                    │
             ┌──────┴──────┐
             ▼             ▼
       Participant A   Participant B
             │             │
             ▼             ▼
        Jitter buffer  Jitter buffer
             │             │
             └──────┬──────┘
                    ▼
          Shared SoundMesh timeline
                    │
                    ▼
          Native synchronized output
                    │
             ┌──────┼──────┐
             ▼      ▼      ▼
           Phone A Phone B Phone C
```

The host's external application remains the source of media.

SoundMesh becomes the synchronization and distribution layer.

---

# 4. External Audio Capture

## 4.1 Android AudioPlaybackCapture

The MVP uses Android's audio playback capture facilities where supported.

Capture requires the appropriate Android permission and user authorization flow.

The implementation MUST NOT assume that every external application permits capture.

An external application may opt out of playback capture.

Therefore:

```text
Capture requested
        ↓
Permission granted?
        ↓
Capture actually available?
        ↓
External source capturable?
        ↓
Live audio received?
```

Each condition must be distinguishable.

---

## 4.2 Capture Permission

The host must explicitly authorize audio capture when Android requires it.

The application MUST NOT imply that capture is active before the required authorization has succeeded.

The UI should distinguish:

```text
CAPTURE_PERMISSION_REQUIRED
CAPTURE_PERMISSION_GRANTED
CAPTURE_STARTING
CAPTURING
CAPTURE_STOPPED
CAPTURE_FAILED
```

The exact state names may be defined by the audio API.

---

## 4.3 Capture Eligibility

Not every Android audio source is necessarily capturable.

The system MUST handle:

```text
External app permits capture
```

and:

```text
External app does not permit capture
```

as different outcomes.

If the source cannot be captured, SoundMesh must report that condition rather than producing silent or fabricated audio.

---

# 5. Capture Pipeline

The host-side pipeline is conceptually:

```text
External application
        ↓
Android playback mixer
        ↓
AudioPlaybackCapture
        ↓
Native capture buffer
        ↓
Timestamp / sequence assignment
        ↓
Transport framing
        ↓
Network
```

Capture must remain native.

High-frequency audio capture MUST NOT depend on Flutter/Dart execution.

---

# 6. Live Audio Ownership

The external application owns:

* media selection;
* song/video;
* play;
* pause;
* seek;
* playback speed;
* subtitles;
* media queue;
* media format;
* media UI.

SoundMesh owns:

* capture;
* live audio distribution;
* synchronization;
* synchronized output;
* synchronization monitoring;
* recovery from audio transport failures.

This boundary is mandatory.

SoundMesh MUST NOT become a media player as a consequence of its audio implementation.

---

# 7. Audio Format

The live capture format is:

**Status: EXPERIMENTAL**

The implementation must determine the most reliable representation for the MVP.

Potential considerations include:

* PCM;
* sample rate;
* channel count;
* sample format;
* frame size;
* bandwidth;
* encoding latency;
* CPU usage;
* memory usage;
* Android device compatibility.

The initial implementation should prioritize:

1. predictable behavior;
2. low latency;
3. synchronization accuracy;
4. sufficient audio quality;
5. manageable bandwidth.

Codec variety is not a goal for the MVP.

---

# 8. Audio Format Conversion

The capture format may differ from the optimal network or output format.

If conversion is required, the system must measure:

* processing latency;
* CPU cost;
* memory cost;
* timestamp effects;
* sample-rate effects;
* channel conversion effects.

Conversion MUST NOT silently alter the logical audio timeline.

---

# 9. Audio Frames

Live audio must be divided into bounded frames or packets for transport.

Conceptually:

```text
AudioFrame {

    sequenceNumber

    captureTimestamp

    sampleRate

    channelCount

    sampleFormat

    payload

}
```

The exact structure is defined by the audio API and networking contracts.

Every frame must be associated with enough information to reconstruct its position in the live audio timeline.

---

# 10. Sequence Numbers

Live audio frames MUST have monotonically increasing sequence identifiers.

Example:

```text
1001
1002
1003
1004
...
```

Sequence numbers allow participants to detect:

* missing frames;
* duplicated frames;
* reordered frames;
* gaps;
* stale frames.

Sequence numbers are not a substitute for timing information.

---

# 11. Audio Timestamps

Audio frames SHOULD have a monotonic timing reference associated with their capture position.

The system must distinguish:

```text
capture timestamp
```

from:

```text
network arrival timestamp
```

and:

```text
actual output timestamp
```

These are not interchangeable.

---

# 12. Audio Timeline

SoundMesh requires a shared logical audio timeline.

Conceptually:

```text
Captured audio position
        ↓
SoundMesh timeline
        ↓
Participant buffer
        ↓
Scheduled output
        ↓
Actual audible output
```

A participant must be able to determine which portion of the live stream should be reproduced at a particular synchronized time.

---

# 13. Live Buffering

Because the audio is live, participants require a jitter buffer.

The jitter buffer absorbs normal variation caused by:

* network latency;
* packet arrival variation;
* scheduling variation;
* temporary CPU contention.

Conceptually:

```text
Network
   ↓
Receive
   ↓
Jitter Buffer
   ↓
Synchronization Target
   ↓
Native Output
```

The buffer MUST NOT grow without bound.

---

# 14. Buffer Depth

The ideal buffer depth is an experimental parameter.

It must balance:

```text
Lower latency
        vs.
Greater resilience
```

Too little buffering may cause:

* underruns;
* dropouts;
* synchronization instability.

Too much buffering may cause:

* excessive latency;
* slow recovery;
* unnecessary memory usage.

Buffer depth must be measured experimentally.

---

# 15. Host Capture Buffer

The host must buffer captured audio sufficiently to prevent transient processing delays from immediately causing stream failure.

The host buffer must remain bounded.

The system must distinguish:

```text
capture buffer underrun
```

from:

```text
network transmission failure
```

and:

```text
participant output underrun
```

---

# 16. Participant Jitter Buffer

Each participant should maintain a bounded jitter buffer.

The participant should not immediately output every received packet.

Instead:

```text
Receive
  ↓
Validate
  ↓
Reorder if required
  ↓
Buffer
  ↓
Wait for synchronization target
  ↓
Output
```

This creates controlled latency in exchange for improved synchronization stability.

---

# 17. Packet Loss

Live audio transport must tolerate reasonable packet loss.

The implementation must determine experimentally whether missing audio should be handled using:

* concealment;
* repetition;
* silence;
* retransmission;
* forward error correction;
* another mechanism.

The chosen strategy must prioritize continuous synchronized output.

---

# 18. Packet Reordering

Packets may arrive out of order.

Sequence numbers should allow the participant to detect reordering.

The participant must not blindly output packets in arrival order.

---

# 19. Late Packets

A packet arriving after its intended output deadline may no longer be useful.

The system must define a policy for stale audio.

A late packet must not cause a participant to output old audio after the shared timeline has advanced beyond it.

---

# 20. Audio Startup

Unlike the old file-distribution architecture, startup does not require every participant to possess an entire audio asset.

The live startup flow is:

```text
1. Create/join room
2. Establish synchronization
3. Authorize host capture
4. Start host capture
5. Establish live audio stream
6. Participants receive audio
7. Participants build sufficient buffer
8. Establish shared output target
9. Participants schedule native output
10. Audio begins
11. Actual timing is measured
```

The system MUST NOT treat "capture started" as equivalent to "participant output is ready."

---

# 21. Output Readiness

A participant is `AUDIO_READY` only when:

1. the participant audio pipeline is initialized;
2. sufficient live audio is buffered;
3. the native output engine is ready;
4. timing information is available;
5. the participant can schedule output against the shared timeline;
6. the participant reports readiness to the session coordinator.

---

# 22. Preparation Barrier

The host SHOULD maintain a preparation barrier before synchronized output begins.

Conceptually:

```text
Participant A → AUDIO_READY
Participant B → AUDIO_READY
Participant C → AUDIO_READY
```

Only required participants that have sufficient buffered audio should enter synchronized output.

A participant that has not received enough audio must not silently start late.

---

# 23. Synchronized Output

SoundMesh MUST use scheduled native output rather than relying on simultaneous immediate commands.

The synchronization system determines a target:

```text
T_target
```

The audio subsystem receives a request conceptually equivalent to:

```text
Output audio position P
at target native time T_target
```

Each device schedules its own local output.

---

# 24. Never Use "Play Now" as the Primary Sync Mechanism

The following model is rejected:

```text
Host:

PLAY NOW!

Participant A:

play()

Participant B:

play()

Participant C:

play()
```

The correct model is:

```text
Capture
   ↓
Buffer
   ↓
Synchronize
   ↓
Choose future target
   ↓
Schedule native output
   ↓
Output
```

The exact implementation may differ, but the system must use a common future timing target rather than command-arrival simultaneity.

---

# 25. Native Audio Boundary

Flutter SHOULD control:

* high-level audio-session state;
* capture preparation UI;
* permission UI;
* host/participant presentation;
* synchronization status;
* user-facing errors;
* room controls.

Native platform code SHOULD control:

* AudioPlaybackCapture;
* capture buffers;
* audio frame processing;
* packetization;
* native audio output;
* timing-sensitive scheduling;
* native timestamps;
* jitter buffers;
* audio callbacks;
* audio-route handling;
* high-frequency monitoring.

Flutter MUST NOT be responsible for sample-accurate audio timing.

---

# 26. Android Native Audio Output

The MVP should evaluate Android native audio facilities including:

* `AudioTrack`;
* AAudio;
* Oboe.

The final implementation choice is:

**Status: EXPERIMENTAL**

Evaluation criteria:

* output latency;
* timestamp quality;
* scheduling capability;
* buffer control;
* stability;
* Android API coverage;
* device compatibility;
* CPU usage;
* implementation complexity.

The chosen engine must be validated on real devices.

---

# 27. Native Audio Clock

The audio pipeline must use an appropriate monotonic/native timing reference.

Conceptually:

```text
SoundMesh shared timeline
        ↕
Device monotonic clock
        ↕
Native audio timing
        ↕
Actual output
```

Flutter application timing MUST NOT be used as the authoritative precise audio clock.

---

# 28. Capture-to-Output Timing

The complete path is:

```text
External application
        ↓
System audio mixer
        ↓
AudioPlaybackCapture
        ↓
Capture processing
        ↓
Network transport
        ↓
Participant jitter buffer
        ↓
Native audio scheduling
        ↓
Audio output
        ↓
Speaker
```

Every stage may contribute latency.

The synchronization system must therefore consider **end-to-end capture-to-output latency**, not only network latency.

---

# 29. Latency Definitions

The following must remain distinct:

```text
Capture latency
≠
Processing latency
≠
Network latency
≠
Clock offset
≠
Buffer latency
≠
Audio output latency
≠
End-to-end latency
```

A participant receiving audio quickly does not necessarily mean that its speaker produces the audio at the correct moment.

---

# 30. Host vs Participant Timing

The host presents an additional challenge because the external application may already be producing sound locally while SoundMesh captures that audio for distribution.

Conceptually:

```text
External app
     │
     ├──────────────→ Host speaker
     │
     └→ AudioPlaybackCapture
             ↓
        SoundMesh
             ↓
        Participants
```

The host's direct output path and the participant replay path may have different latency.

This must be measured.

If the host's direct output cannot be aligned sufficiently with participant output, the architecture must explicitly determine an alternative strategy.

This is a critical MVP experiment.

---

# 31. Host Monitoring

The system should determine whether the host's local output is:

* part of the synchronized speaker group;
* independently audible;
* delayed;
* muted during synchronized output;
* or otherwise compensated.

The correct strategy is:

**Status: UNDECIDED**

It must be resolved through measurement.

---

# 32. Playback Position

The native output subsystem MUST expose actual audio position to the synchronization subsystem.

Conceptually:

```text
PlaybackPosition {

    audioPosition

    nativeTimestamp

    localMonotonicTimestamp

}
```

The exact structure is implementation-defined.

---

# 33. Actual vs Requested State

SoundMesh must distinguish:

```text
REQUESTED:

start synchronized output
```

from:

```text
ACTUAL:

native output is active
```

A successful command transmission does not prove that audio is actually being reproduced.

---

# 34. Drift

Even after synchronized startup, devices may gradually diverge.

Potential causes include:

* clock differences;
* audio-output clock differences;
* hardware oscillators;
* operating-system scheduling;
* native audio behavior;
* resampling;
* device-specific processing.

Therefore:

```text
Synchronized startup
≠
Permanent synchronization
```

The audio subsystem must continuously expose enough timing information for drift monitoring.

---

# 35. Drift Monitoring

During synchronized output, the synchronization layer should periodically obtain:

```text
Audio position
+
Timing timestamp
+
Output state
+
Audio route
```

The synchronization system can then estimate:

```text
position error
drift rate
```

as defined in `synchronization.md`.

---

# 36. Playback-Rate Correction

Small timing errors may potentially be corrected using small output-rate adjustments.

Example:

```text
Participant slightly behind
        ↓
Small rate increase
        ↓
Participant catches up
        ↓
Return to normal rate
```

The correction mechanism is:

**Status: EXPERIMENTAL**

It must be validated for:

* audible artifacts;
* platform support;
* stability;
* correction speed.

---

# 37. Position Correction

If rate correction is insufficient, a bounded position correction may be required.

Corrections should be:

* controlled;
* bounded;
* measurable;
* infrequent.

Large repeated corrections are discouraged.

---

# 38. Audible Artifacts

Timing correction can introduce:

* clicks;
* pops;
* pitch changes;
* speed changes;
* gaps;
* repeated samples;
* dropped samples.

Synchronization quality must therefore consider both:

```text
Timing accuracy
        vs.
Audio quality
```

A theoretically smaller timing error is not automatically preferable if the correction is clearly audible.

---

# 39. Audio Dropout

The system must detect audio dropouts.

Where measurable, record:

* timestamp;
* duration;
* audio position;
* route;
* buffer state;
* relevant transport state.

The cause may include:

* capture failure;
* network loss;
* CPU pressure;
* buffer underrun;
* native audio failure;
* OS interruption;
* thermal throttling.

---

# 40. Buffer Underrun

A buffer underrun is a significant event.

Possible sources include:

```text
Capture underrun
Transport starvation
Jitter-buffer underrun
Native output underrun
```

These must be distinguishable where practical.

The synchronization layer must determine whether the participant can recover or requires resynchronization.

---

# 41. Audio Route

The MVP should prioritize built-in speakers.

Potential routes include:

* built-in speaker;
* wired headphones;
* Bluetooth;
* other Android-supported outputs.

Route changes may invalidate output-latency measurements.

The audio subsystem MUST notify the synchronization layer when relevant route changes occur.

---

# 42. Bluetooth

Bluetooth introduces additional and potentially variable latency.

Therefore:

**Bluetooth synchronized output is EXPERIMENTAL.**

The initial competition configuration should prioritize validated built-in-speaker behavior.

If Bluetooth cannot maintain acceptable synchronization, the participant may be:

* marked degraded;
* recalibrated;
* warned;
* temporarily excluded from synchronized output.

---

# 43. Audio Route Changes

A route change may look like:

```text
Built-in speaker
       ↓
Bluetooth
```

or:

```text
Bluetooth
       ↓
Built-in speaker
```

The system must:

1. detect the change;
2. notify synchronization;
3. invalidate stale latency assumptions;
4. determine whether recalibration is required.

---

# 44. Interruption Handling

Android may interrupt or alter audio behavior because of:

* phone calls;
* alarms;
* notifications;
* other audio applications;
* audio focus changes;
* OS-level events;
* permission changes;
* media projection termination.

The audio subsystem MUST detect relevant interruptions.

It must not claim normal synchronized output while audio is actually interrupted.

---

# 45. Interruption Recovery

A possible recovery flow is:

```text
INTERRUPTED
     ↓
Capture/output restored
     ↓
Check audio pipeline
     ↓
Check current stream position
     ↓
Check group state
     ↓
Resynchronize
     ↓
Resume synchronized output
```

The exact policy is defined by the session architecture.

---

# 46. Background Operation

SoundMesh must remain capable of operating while the user switches to an external media application.

The intended Android behavior is:

```text
SoundMesh foreground activity
        ↓
User starts SoundMesh session
        ↓
Required capture authorization
        ↓
SoundMesh foreground service / native session
        ↓
User opens external media application
        ↓
SoundMesh continues capture + transport + synchronization
```

The implementation MUST follow Android foreground-service and MediaProjection lifecycle requirements.

SoundMesh must not assume unrestricted invisible background execution.

The persistent notification/foreground-service behavior must be treated as part of the Android architecture.

---

# 47. Screen Lock

Screen-lock behavior must be tested separately.

The system must determine whether:

* capture continues;
* network communication continues;
* native output continues;
* the foreground service remains active;
* Android power management changes behavior.

Screen-lock behavior is:

**Status: EXPERIMENTAL**

until validated on target devices.

---

# 48. Battery and Thermal Behavior

The live pipeline may require continuous:

* audio capture;
* network communication;
* buffering;
* native output;
* synchronization monitoring.

Therefore CPU, memory, battery, and thermal behavior must be measured.

The implementation should avoid unnecessary high-frequency work.

---

# 49. Audio Callback Design

Timing-sensitive callbacks MUST remain native.

Avoid:

```text
Native audio callback
        ↓
Flutter
        ↓
Dart
        ↓
Flutter plugin
        ↓
Native audio callback
```

The preferred model is:

```text
Native callback
      ↓
Native audio state
      ↓
Occasional summarized event
      ↓
Flutter
```

Flutter should receive meaningful state changes rather than raw high-frequency audio events.

---

# 50. Flutter Responsibilities

Flutter should handle:

* capture preparation UI;
* permission UI;
* room/device presentation;
* host/participant role;
* audio-session state;
* synchronization state;
* sync-quality presentation;
* errors;
* recovery presentation;
* diagnostics;
* user-facing room controls.

Flutter should NOT directly implement:

* audio capture;
* sample scheduling;
* jitter buffering;
* precise audio-clock management;
* packet processing loops;
* real-time drift correction;
* native audio callbacks.

---

# 51. Native Responsibilities

Native Android code should handle:

* AudioPlaybackCapture;
* MediaProjection lifecycle;
* foreground audio service lifecycle;
* capture buffers;
* audio frame processing;
* packetization;
* native timestamps;
* jitter buffering;
* synchronized output;
* audio-route changes;
* interruptions;
* native output callbacks;
* timing-sensitive correction.

---

# 52. Audio Engine Interface

The logical audio interface should represent the live audio pipeline rather than a media-player API.

Conceptually:

```text
AudioEngine

startCapture()

stopCapture()

getCaptureState()

getCaptureTimestamp()

receiveAudioFrame()

bufferAudio()

getBufferState()

scheduleOutput(audioPosition, targetTime)

startOutput()

stopOutput()

getPlaybackPosition()

getPlaybackTimestamp()

getOutputRoute()

getOutputState()

getCapabilities()
```

The exact API is defined in:

`DOCS/interfaces/audio-api.md`

The implementation must not reintroduce:

```text
selectAudio()
preparePlayback(audioId)
play()
pause()
seek()
```

as the primary SoundMesh architecture.

External media playback remains outside SoundMesh.

---

# 53. Audio Session State

The audio subsystem should expose states conceptually similar to:

```text
IDLE

CAPTURE_PERMISSION_REQUIRED

CAPTURE_STARTING

CAPTURING

CAPTURE_FAILED

STREAMING

BUFFERING

READY

SCHEDULED

OUTPUTTING

INTERRUPTED

RECOVERING

STOPPED

ERROR
```

The exact authoritative state names should be defined by `audio-api.md`.

---

# 54. Capability Reporting

Each device should report relevant audio capabilities.

Potential fields include:

```text
AudioCapabilities {

    captureSupport

    outputSupport

    sampleRates

    channelCounts

    schedulingSupport

    timestampSupport

    rateAdjustmentSupport

    supportedRoutes

}
```

Not all information needs to be shown to the user.

---

# 55. Unsupported Capabilities

A device must not claim support for an operation it cannot perform reliably.

Example:

```text
Scheduled native output = unsupported
```

The session must choose an appropriate policy rather than silently proceeding.

---

# 56. Sample Rate

Sample rate must be treated as an explicit audio property.

Examples:

```text
44.1 kHz
48 kHz
```

The implementation must determine:

* capture sample rate;
* transport sample rate;
* output sample rate;
* whether resampling occurs;
* where resampling occurs;
* whether resampling affects timing.

The final MVP configuration is:

**Status: UNDECIDED**

---

# 57. Channels

The system must explicitly handle:

* mono;
* stereo;
* device output-channel configuration.

The MVP should prefer a configuration with reliable Android support across validated devices.

---

# 58. Resampling

If capture and output sample rates differ, resampling may be required.

The project must determine:

* where it occurs;
* its latency;
* its CPU cost;
* its effect on timing;
* whether behavior differs across devices.

Resampling must be included in synchronization experiments when it affects timing.

---

# 59. Compression

Live compression may reduce bandwidth but introduce:

* encoding latency;
* decoding latency;
* CPU usage;
* buffering;
* codec-specific timing behavior.

Therefore:

**Compression strategy: EXPERIMENTAL**

The MVP should prioritize reliable synchronized audio over maximum bandwidth efficiency.

---

# 60. Audio Cache

The old file-distribution model does not require a persistent audio-asset cache.

SoundMesh MUST NOT build a media library or persistent downloaded-song system merely to support synchronization.

Temporary live buffers may exist for:

* jitter buffering;
* startup buffering;
* recovery.

These are not media-library assets.

---

# 61. Temporary Audio Data

Temporary live audio buffers must be bounded.

The system must release unnecessary buffered audio when:

* the session ends;
* a participant leaves;
* the stream resets;
* a recovery operation invalidates old data.

Stale audio must not remain eligible for output after the session timeline has advanced.

---

# 62. Generation and Stale Audio

Major live-session resets SHOULD advance a generation identifier.

Examples:

```text
Start capture
Restart capture
Stream reset
Resynchronization
Session restart
```

Old audio frames belonging to an invalidated generation must not be played after a newer generation becomes authoritative.

This prevents stale packets from corrupting the current live timeline.

---

# 63. Capture Stop

When host capture stops:

```text
CAPTURING
     ↓
CAPTURE_STOPPED
```

The system must determine whether:

* the session pauses;
* participants continue buffered audio;
* the room enters recovery;
* the session terminates.

The correct behavior depends on the room/session contract.

---

# 64. External Media Stopping

SoundMesh does not control the external media application.

Therefore, if the external app stops producing capturable audio, SoundMesh may observe:

```text
No new captured audio
```

It must not fabricate a media-player state such as `PAUSED` unless the external source state is actually observable and represented by the contract.

The UI should communicate the actual SoundMesh state.

---

# 65. Capture Source Failure

If the external application refuses or stops allowing capture:

```text
CAPTURE_SOURCE_UNAVAILABLE
```

should be represented through the appropriate audio/API error state.

The participant devices should not be blamed for a host capture failure.

---

# 66. Audio Errors

Errors should be structured.

Examples:

```text
CAPTURE_PERMISSION_REQUIRED

CAPTURE_PERMISSION_DENIED

CAPTURE_UNAVAILABLE

CAPTURE_SOURCE_UNAVAILABLE

CAPTURE_FAILED

AUDIO_FORMAT_UNSUPPORTED

AUDIO_PROCESSING_FAILED

BUFFER_UNDERRUN

AUDIO_OUTPUT_UNAVAILABLE

AUDIO_OUTPUT_FAILED

AUDIO_INTERRUPTED

AUDIO_ROUTE_CHANGED

AUDIO_STREAM_STARVED

AUDIO_STREAM_RESET

SCHEDULING_FAILED
```

Exact error identifiers belong in `audio-api.md`.

---

# 67. Audio Stream Starvation

If a participant stops receiving enough live audio to maintain synchronized output:

```text
AUDIO_STREAM_STARVED
```

The system must determine whether:

* buffering can recover;
* output should pause;
* resynchronization is required;
* the participant should temporarily leave synchronized output.

---

# 68. Audio Quality Priority

The engineering priority should be:

1. correct captured audio;
2. reliable live transport;
3. reliable native output;
4. synchronized timing;
5. acceptable end-to-end latency;
6. correction without obvious artifacts;
7. efficient resource usage;
8. advanced audio features.

Do not sacrifice stable synchronized output for theoretical improvements that users cannot perceive.

---

# 69. Measurement Requirements

Audio experiments should measure:

* capture startup latency;
* capture timestamp behavior;
* frame production rate;
* transport latency;
* packet loss;
* packet reordering;
* jitter;
* jitter-buffer depth;
* output scheduling time;
* actual output timing;
* startup synchronization spread;
* steady-state drift;
* correction duration;
* correction magnitude;
* buffer underruns;
* audio dropouts;
* CPU usage;
* memory usage;
* battery impact;
* thermal behavior;
* audio-route changes;
* interruption recovery.

Where possible, measurements should use external instrumentation.

---

# 70. End-to-End Synchronization Validation

Software timestamps alone cannot prove that speakers produce sound simultaneously.

The project should use external measurement methods such as:

* microphone recordings;
* multiple microphones;
* controlled acoustic tests;
* waveform analysis;
* reference signals.

The goal is to measure:

```text
Actual audible synchronization
```

rather than merely:

```text Software state synchronization
```

---

# 71. Critical Host-Participant Experiment

The project must explicitly test:

```text
External media app
        ↓
Host speaker

AND

External media app
        ↓
AudioPlaybackCapture
        ↓
SoundMesh
        ↓
Participant speaker
```

Measure the audible difference between host and participant.

This experiment is required because the host's direct output path may have a different latency from the captured-and-redistributed path.

If the difference is too large, the architecture must determine how the host should participate in the synchronized speaker group.

---

# 72. Initial Audio Experiments

## Experiment 1 — Capture

Verify:

* MediaProjection authorization;
* AudioPlaybackCapture initialization;
* capture from a supported external app;
* capture failure from an app that blocks capture;
* capture startup latency;
* capture continuity.

---

## Experiment 2 — Single Device Output

Verify:

* native output initialization;
* buffering;
* scheduled output;
* playback timing;
* output timestamps;
* route behavior.

---

## Experiment 3 — Two Devices

Use:

```text
Android Host
+
Android Participant
```

Verify:

* capture;
* transport;
* participant buffering;
* scheduled output;
* audible synchronization.

---

## Experiment 4 — Three or More Devices

Determine whether synchronization quality degrades as participants increase.

---

## Experiment 5 — Host vs Participant

Measure:

```text
Host direct output
vs.
Participant synchronized output
```

This is a critical architecture experiment.

---

## Experiment 6 — Network Conditions

Test:

* low latency;
* normal LAN;
* jitter;
* packet loss;
* temporary network interruption.

Determine how much buffering is required.

---

## Experiment 7 — Long Session

Run synchronized live audio for an extended duration.

Measure:

```text
startup spread
drift
correction frequency
final spread
```

---

## Experiment 8 — External Apps

Test multiple external Android applications.

Determine:

* whether capture works;
* whether capture quality is correct;
* whether behavior differs between applications;
* whether any applications block capture.

---

## Experiment 9 — Audio Routes

Compare:

```text
Built-in speaker ↔ built-in speaker
Built-in speaker ↔ Bluetooth
```

Bluetooth support remains experimental.

---

## Experiment 10 — Interruptions

Test:

* incoming call;
* notification;
* audio focus change;
* screen lock;
* application switching;
* capture termination;
* route changes.

---

# 73. Audio Acceptance Criteria

The audio system is MVP-ready only when:

1. supported external Android audio can be captured reliably;
2. capture permission is handled correctly;
3. unsupported capture sources are detected;
4. live audio frames can be produced continuously;
5. frames have sufficient sequencing/timing information;
6. live audio can be transported to participants;
7. participants maintain bounded jitter buffers;
8. native output can be scheduled against the shared timing system;
9. actual output timing can be measured;
10. capture failures are detectable;
11. stream starvation is detectable;
12. output failures are detectable;
13. interruptions are detectable;
14. route changes are detectable;
15. synchronized output can recover from reasonable failures;
16. long-running sessions can be monitored for drift;
17. the host-to-participant latency relationship is understood;
18. external measurement demonstrates that software synchronization corresponds reasonably to audible synchronization;
19. the validated Android device matrix behaves reliably.

---

# 74. Initial Synchronization Targets

The following are engineering targets, NOT guarantees.

Initial target:

```text
Startup group spread:

≤ 20 ms

Steady-state group spread:

≤ 20 ms
```

Preferred stretch target:

```text
≤ 10 ms
```

These values must be validated through real acoustic experiments.

They may be changed in `decisions.md` if evidence demonstrates that another target is more appropriate.

---

# 75. Important Distinction

SoundMesh should never claim:

> "Every phone is perfectly synchronized."

The engineering question is:

> "Is the difference in audible playback timing small enough that users perceive the phones as one coordinated speaker system?"

This distinction is fundamental.

---

# 76. Audio and Networking Boundary

Networking is responsible for:

```text
Connection
Room communication
Live audio transport
Packet/frame delivery
Sequence handling
Transport-level integrity
```

Audio is responsible for:

```text
Audio capture
Audio frame representation
Capture timing
Audio buffering
Jitter buffering
Native output
Output timing
Audio routes
Audio interruptions
Audio pipeline state
```

Synchronization is responsible for:

```text
Shared timeline
Clock relationship
Target output time
Drift estimation
Correction
Resynchronization
```

These boundaries must remain explicit.

---

# 77. Audio and Synchronization Boundary

Synchronization tells audio:

```text
"When should this audio position become audible?"
```

Audio tells synchronization:

```text
"When was/is this audio position actually being reproduced?"
```

This bidirectional relationship is essential.

---

# 78. Recommended Data Flow

```text
                 HOST

       External Media App
               │
               ▼
     AudioPlaybackCapture
               │
               ▼
        Capture Pipeline
               │
               ▼
        Live Audio Frames
               │
               ▼
           Network
               │
       ┌───────┴───────┐
       ▼               ▼
 Participant A    Participant B
       │               │
       ▼               ▼
 Jitter Buffer    Jitter Buffer
       │               │
       └───────┬───────┘
               ▼
       Synchronization
               │
               ▼
      Native Audio Output
               │
               ▼
             Speaker
               │
               ▼
       Actual Timing Data
               │
               ▼
       Synchronization
```

---

# 79. Design Rules

The audio implementation MUST follow these rules:

1. Do not use wall-clock time for precise audio scheduling.
2. Do not depend on Flutter timers for precise audio timing.
3. Do not depend on Flutter for high-frequency audio processing.
4. Do not assume identical audio latency across devices.
5. Do not assume identical clocks across devices.
6. Do not assume identical Android hardware.
7. Do not assume every external application permits audio capture.
8. Do not claim capture is active before capture actually succeeds.
9. Do not treat network arrival time as audio timing.
10. Do not output live audio directly on packet arrival without buffering/timing policy.
11. Do not allow stale audio from an invalidated generation to play.
12. Do not begin synchronized output before required buffering/readiness is achieved.
13. Do not use "play now" as the primary synchronization mechanism.
14. Do not silently ignore audio interruptions.
15. Do not silently ignore route changes.
16. Do not silently ignore buffer underruns.
17. Do not perform uncontrolled correction loops.
18. Do not claim synchronization without external validation.
19. Do not introduce codec complexity without measurement.
20. Do not turn experimental assumptions into permanent architecture without evidence.
21. Do not turn SoundMesh into a media player.
22. Do not introduce media-library or room-history requirements into the audio system.

---

# 80. Open Questions

The following remain intentionally unresolved:

1. Which Android native output engine should be used?
2. AudioTrack vs AAudio vs Oboe?
3. What exact capture format should the MVP use?
4. What exact sample rate should the pipeline use?
5. What channel configuration should the MVP use?
6. Should live audio be transmitted as PCM or compressed data?
7. What frame duration provides the best latency/reliability tradeoff?
8. What jitter-buffer depth is optimal?
9. How should packet loss be concealed?
10. How should late packets be handled?
11. How accurately can capture timestamps be obtained?
12. How accurately can actual output timestamps be obtained?
13. What is the end-to-end capture-to-output latency?
14. Can host direct output be synchronized with participant output sufficiently?
15. Should the host's direct speaker output participate in the synchronized group?
16. Can output latency be estimated consistently across device models?
17. How should sample-rate conversion affect synchronization?
18. What correction mechanism produces the fewest audible artifacts?
19. What playback-rate correction range is acceptable?
20. Can Bluetooth output be synchronized sufficiently?
21. How should screen-lock behavior work?
22. How should capture behave when SoundMesh moves behind another app?
23. How should capture failure from an external application be presented?
24. What happens when the host stops producing capturable audio?
25. What is the maximum acceptable packet-loss rate?
26. What is the maximum acceptable buffer-underrun rate?
27. What CPU usage is acceptable?
28. What battery usage is acceptable?
29. What thermal behavior is acceptable?
30. What external instrumentation should become part of automated testing?
31. What startup synchronization threshold is perceptually acceptable?
32. What steady-state synchronization threshold is perceptually acceptable?
33. How should a participant recover after prolonged stream starvation?
34. How should host capture restart affect the shared timeline?
35. How should Android foreground-service lifecycle events affect an active session?

These MUST remain explicit until resolved through research and experiments.

---

# 81. Definition of Done

`audio.md` is considered successfully implemented as a specification when:

* external audio capture ownership is clear;
* SoundMesh's media-player boundary is explicit;
* Android capture requirements are defined;
* live audio transport is distinguished from file distribution;
* capture timing is defined;
* frame sequencing is defined;
* jitter buffering is defined;
* native output responsibilities are clear;
* Flutter/native responsibilities are clear;
* synchronized output is required;
* actual output timing is measurable;
* capture latency is distinguished from network latency;
* output latency is distinguished from capture and network latency;
* host direct-output latency is explicitly considered;
* interruptions are defined;
* route changes are defined;
* stream starvation is defined;
* drift interaction is defined;
* external acoustic validation is required;
* measurable acceptance criteria exist;
* unresolved technical decisions are explicitly marked.

---

# 82. Final Audio Principle

SoundMesh is not trying to distribute an audio file to several phones.

It is trying to transform:

```text
One live external audio source
```

into:

```text
One coordinated acoustic event
```

across multiple independent devices.

That means the audio architecture must treat:

```text
Capture
+
Audio frames
+
Transport
+
Buffering
+
Shared timeline
+
Native clock
+
Output scheduling
+
Output latency
+
Actual playback position
```

as one connected synchronization problem.

The ultimate goal is:

```text
             EXTERNAL MEDIA
                   │
                   ▼
              HOST PHONE
                   🔊
                   │
             live capture
                   │
          ┌────────┴────────┐
          ▼                 ▼
       PHONE B           PHONE C
          🔊                 🔊
            \               /
             \             /
              \           /
               ▼         ▼
                 PHONE D
                    🔊

                    ↓

            ONE COORDINATED
              SOUND FIELD
```

**Core principle:**

> Synchronization is only successful when the speakers are synchronized — not merely when the software says they are synchronized.

> SoundMesh must measure the difference between those two things.
