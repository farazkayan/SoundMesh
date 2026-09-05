\# SoundMesh — Audio Specification



\*\*Document status:\*\* Living engineering specification

\*\*Document role:\*\* Defines how SoundMesh acquires, validates, prepares, decodes, buffers, schedules, plays, monitors, and manages audio across participating devices.



\*\*Primary authority:\*\* This document defines audio-system behavior.

\*\*Related specifications:\*\*



\* `DOCS/blueprint.md` — product definition and MVP boundaries

\* `DOCS/architecture.md` — application and platform architecture

\* `DOCS/networking.md` — communication and audio transfer

\* `DOCS/synchronization.md` — timing, scheduled playback, drift correction

\* `DOCS/testing.md` — audio and synchronization validation

\* `DOCS/decisions.md` — major technology and architecture decisions



\---



\# 1. Purpose



SoundMesh exists to make multiple independent smartphones reproduce the same audio as a coordinated speaker system.



The audio subsystem is responsible for:



1\. identifying audio input;

2\. validating supported audio;

3\. obtaining audio data;

4\. transferring audio to participants when necessary;

5\. verifying audio integrity;

6\. decoding audio;

7\. preparing audio buffers;

8\. selecting an appropriate playback engine;

9\. scheduling playback;

10\. reporting actual playback state;

11\. exposing playback position to synchronization;

12\. detecting playback drift;

13\. handling pause/resume/seek/stop;

14\. handling audio interruptions;

15\. handling audio-route changes;

16\. handling device-specific playback limitations;

17\. managing resource usage;

18\. providing deterministic behavior across supported devices.



The audio subsystem MUST cooperate closely with the synchronization subsystem.



\---



\# 2. Fundamental Principle



SoundMesh synchronization is not achieved merely by sending the same audio file to multiple devices.



The system must coordinate:



```text id="a6xg48"

Same audio

\+

Same intended playback position

\+

Shared timeline

\+

Device-specific timing

\+

Audio output latency

\+

Drift monitoring

\+

Correction

```



Two phones beginning the same file at approximately the same wall-clock time does NOT guarantee synchronized sound.



\---



\# 3. Preferred Audio Architecture



The preferred architecture is:



```text id="3qg1ps"

&#x20;                Host

&#x20;                  │

&#x20;           Selects audio

&#x20;                  │

&#x20;                  ▼

&#x20;           Audio metadata

&#x20;                  │

&#x20;                  ▼

&#x20;         Transfer to devices

&#x20;                  │

&#x20;         ┌────────┼────────┐

&#x20;         ▼        ▼        ▼

&#x20;      Device A Device B Device C

&#x20;         │        │        │

&#x20;      Decode    Decode    Decode

&#x20;         │        │        │

&#x20;      Prepare   Prepare   Prepare

&#x20;         │        │        │

&#x20;         └────────┼────────┘

&#x20;                  │

&#x20;           Synchronization

&#x20;                  │

&#x20;                  ▼

&#x20;         Scheduled playback

```



Each device should preferably maintain its own local audio data and perform its own decoding/playback.



The host SHOULD NOT continuously stream the audio to every participant during ordinary playback unless experiments demonstrate that local distribution is inferior.



\---



\# 4. Why Local Playback Is Preferred



Continuous network audio streaming introduces unnecessary variables:



\* packet loss;

\* jitter;

\* bandwidth variation;

\* buffering;

\* network congestion;

\* host upload load;

\* variable network latency;

\* playback stalls.



With local playback:



```text id="s3t5qo"

Network:

"WHEN should playback happen?"



Device:

"PLAY the already-prepared local audio."

```



This makes synchronization primarily a timing problem rather than a continuous streaming problem.



\---



\# 5. Audio Source



The MVP should support a clearly defined audio source.



Potential sources include:



\* local audio files;

\* audio selected through the application;

\* files transferred from the host;

\* future application-integrated sources.



The MVP MUST NOT depend on unauthorized extraction or redistribution of copyrighted streaming-service audio.



SoundMesh should operate on audio that the application is legally permitted to access and distribute within the room.



\---



\# 6. Supported Audio Formats



The exact supported format set is:



\*\*Status: UNDECIDED\*\*



The implementation MUST NOT claim universal audio-format support.



The initial format should be selected based on:



\* Android support;

\* iOS support;

\* Flutter integration;

\* decoding reliability;

\* hardware/software decoding behavior;

\* metadata availability;

\* sample-rate behavior;

\* channel behavior;

\* seeking support;

\* decoding performance;

\* licensing considerations.



A narrow, reliable format set is preferable to broad but unreliable compatibility.



\---



\# 7. Audio Metadata



Before playback, the system SHOULD know:



```text id="4hyvda"

Audio ID

Format

Codec

File size

Duration

Sample rate

Channel count

Bit depth where applicable

Bitrate where applicable

Content hash

```



The exact metadata fields depend on the chosen audio pipeline.



Metadata MUST NOT be trusted blindly from another device.



Where practical, participants should independently verify important properties.



\---



\# 8. Audio Identity



Every distributed audio asset MUST have a deterministic identity.



Conceptually:



```text id="2x7dd5"

audioId = hash(audio content)

```



or an equivalent content-addressed identifier.



This allows the system to determine:



```text id="b5z2xw"

"Do I already have the exact audio required for this session?"

```



rather than blindly transferring the same file multiple times.



\---



\# 9. Audio Integrity



An audio transfer is not considered successful merely because the expected number of bytes arrived.



The participant SHOULD verify:



```text id="ph9t1w"

Expected content hash

&#x20;       ==

Received content hash

```



If verification fails:



```text id="3l0x1w"

AUDIO\_CORRUPTED

```



The participant MUST NOT use the corrupted asset for synchronized playback.



\---



\# 10. Audio Preparation Lifecycle



The audio subsystem SHOULD expose explicit states:



```text id="bq6q1e"

UNAVAILABLE

&#x20;    ↓

LOADING

&#x20;    ↓

AVAILABLE

&#x20;    ↓

VERIFYING

&#x20;    ↓

VERIFIED

&#x20;    ↓

DECODING

&#x20;    ↓

PREPARING

&#x20;    ↓

READY

&#x20;    ↓

PLAYING

&#x20;    ↓

PAUSED

&#x20;    ↓

STOPPED

```



Failures should transition to:



```text id="5r7h5k"

ERROR

```



The application must not infer audio readiness from a file merely existing on disk.



\---



\# 11. Audio Ready Definition



A device is considered `AUDIO\_READY` only when it has:



1\. the correct audio asset;

2\. verified the asset;

3\. successfully initialized the required decoder/player;

4\. prepared enough data for the scheduled start;

5\. confirmed that the native playback engine can begin;

6\. reported readiness to the session coordinator.



This distinction is essential for synchronized startup.



\---



\# 12. Decode Before Playback



Where practical, the system should perform decoding/preparation before the scheduled playback point.



The goal is:



```text id="g0p6h3"

Network transfer

&#x20;      ↓

Decode/prepare

&#x20;      ↓

Buffer

&#x20;      ↓

Synchronize

&#x20;      ↓

Schedule

&#x20;      ↓

PLAY

```



not:



```text id="v0h6je"

PLAY

&#x20;↓

start downloading

&#x20;↓

start decoding

&#x20;↓

hope buffer is ready

```



The second approach introduces unnecessary startup uncertainty.



\---



\# 13. Buffering



Each device SHOULD maintain enough decoded or decoder-ready data to survive normal scheduling and small execution delays.



Buffer size MUST NOT be chosen arbitrarily.



It should be determined experimentally based on:



\* device performance;

\* audio format;

\* sample rate;

\* channels;

\* memory;

\* playback engine;

\* scheduling accuracy;

\* expected network behavior.



\---



\# 14. Buffering During Playback



For the preferred local-audio architecture, network availability should not normally affect audio playback after preparation completes.



During playback:



```text id="xj2z1u"

Network interruption

&#x20;      ↓

Control/sync affected

&#x20;      ↓

Local audio continues

```



provided the device already has enough local audio prepared.



This is a major reason for distributing the audio before playback.



\---



\# 15. Native Audio Boundary



Flutter SHOULD control:



\* playback intent;

\* UI state;

\* user actions;

\* track selection;

\* high-level playback state.



Native platform code SHOULD control:



\* timing-sensitive playback;

\* low-level audio scheduling;

\* audio buffers;

\* native playback clocks;

\* platform audio sessions;

\* output routing;

\* high-frequency playback monitoring.



The Flutter layer must not be responsible for sample-accurate or high-frequency audio timing.



\---



\# 16. Android Audio Architecture



Android audio should use a native abstraction.



For low-latency/high-performance paths, the project should evaluate Android's native audio facilities, including AAudio/Oboe and `AudioTrack`, against actual SoundMesh requirements.



The final engine choice is:



\*\*Status: EXPERIMENTAL\*\*



The choice must be based on measurements rather than preference.



Relevant evaluation criteria include:



\* scheduled playback accuracy;

\* timestamp availability;

\* latency;

\* buffer control;

\* stability;

\* API-level coverage;

\* device compatibility;

\* CPU usage;

\* implementation complexity.



\---



\# 17. iOS Audio Architecture



iOS audio should use native AVFoundation APIs.



The implementation should evaluate:



\* `AVAudioEngine`;

\* `AVAudioPlayerNode`;

\* `AVAudioTime`;

\* `AVAudioSession`.



The exact engine architecture is:



\*\*Status: EXPERIMENTAL\*\*



The selected implementation must support the synchronization requirements defined in `synchronization.md`.



\---



\# 18. Native Audio Clock



Each device needs an appropriate monotonic/native timing reference.



The audio engine and synchronization engine must be able to relate:



```text id="p72kri"

shared SoundMesh timeline

&#x20;       ↕

device monotonic clock

&#x20;       ↕

native audio timing

&#x20;       ↕

actual playback

```



The system MUST NOT assume that Flutter's ordinary application timing is sufficient for precise audio scheduling.



\---



\# 19. Scheduled Playback



SoundMesh MUST prefer scheduled playback over immediate playback.



The synchronization system determines:



```text id="5d4ydh"

T\_target

```



The audio subsystem receives a request conceptually equivalent to:



```text id="wqv8f8"

Schedule audio

at target native time

from audio position P

```



The audio subsystem should then use the platform's native scheduling facilities where available.



\---



\# 20. Never Use "Play Now" as the Primary Sync Mechanism



The following is explicitly rejected as the primary synchronization method:



```text id="u0quae"

Host:

PLAY NOW!



Participant A:

play()



Participant B:

play()



Participant C:

play()

```



Even if the commands are sent nearly simultaneously, devices may:



\* receive them at different times;

\* schedule them differently;

\* have different audio-buffer states;

\* have different output latency.



The correct model is:



```text id="r8f9br"

Prepare

&#x20;  ↓

Measure

&#x20;  ↓

Choose future target

&#x20;  ↓

Schedule locally

&#x20;  ↓

Start

```



\---



\# 21. Playback Position



The audio subsystem MUST expose actual playback position to the synchronization subsystem.



The position must be associated with an appropriate timing reference.



Conceptually:



```text id="48qz9j"

PlaybackPosition {

&#x20;   audioPosition

&#x20;   nativeTimestamp

&#x20;   localMonotonicTimestamp

}

```



The exact representation is implementation-defined.



\---



\# 22. Position Must Not Be Based Only on Wall Time



A statement such as:



```text id="d0x7v3"

"Playback started at 11:30:00"

```



is insufficient for synchronization.



The system needs information about the actual audio timeline and native playback timing.



\---



\# 23. Startup Synchronization



Before playback:



```text id="g0x7ef"

1\. Audio selected

2\. Audio transferred

3\. Audio verified

4\. Audio prepared

5\. Timing calibrated

6\. All required devices report ready

7\. Host selects future target

8\. Target distributed

9\. Devices schedule playback

10\. Playback begins

11\. Actual positions measured

12\. Startup synchronization error calculated

```



The audio subsystem must participate in steps 3, 4, 9, 10, and 11.



\---



\# 24. Preparation Barrier



The host SHOULD maintain an explicit preparation barrier.



Example:



```text id="7i1ph4"

Participant A → AUDIO\_READY

Participant B → AUDIO\_READY

Participant C → AUDIO\_READY

```



Only when the required participants are ready should the session proceed to synchronized scheduling.



A device that is still decoding must not silently become part of the playback group.



\---



\# 25. Audio Latency



Audio latency is distinct from network latency.



At minimum:



```text id="l4n0t4"

Network latency

≠

Clock offset

≠

Audio output latency

```



A phone can receive a command at the correct time while its speaker produces sound later than another phone.



Therefore, SoundMesh must investigate device-specific audio latency.



\---



\# 26. Output Latency



The system should distinguish between:



```text id="8zspgk"

scheduled playback

&#x20;       ↓

audio engine processing

&#x20;       ↓

audio output

&#x20;       ↓

speaker/headphones

```



The final audible event may occur after the logical playback position indicates that playback has begun.



This is especially important when comparing different device models.



\---



\# 27. Speaker Hardware Differences



Different smartphones have different:



\* speaker placement;

\* speaker response;

\* amplifier characteristics;

\* audio processing;

\* DSP;

\* volume limits;

\* latency.



SoundMesh does not need identical sound quality.



The primary requirement is coordinated playback.



\---



\# 28. Volume



Volume control should be considered a device-local property.



A participant may have:



```text id="x8r1k0"

Host volume = 80%

Participant A = 100%

Participant B = 65%

```



The MVP may expose independent volume controls.



Group volume normalization is:



\*\*Status: UNDECIDED\*\*



It should not be added merely because it seems convenient.



\---



\# 29. Audio Route



The playback route may be:



\* built-in speaker;

\* wired headphones;

\* Bluetooth output;

\* other platform-supported audio output.



The MVP should prioritize the built-in speaker.



External output support must be validated independently.



\---



\# 30. Bluetooth



Bluetooth introduces additional latency and variability.



A participant using Bluetooth may have substantially different audio-output timing from a participant using its built-in speaker.



Therefore:



\*\*Bluetooth synchronized playback is EXPERIMENTAL.\*\*



The system should detect audio-route changes and report them to the synchronization layer.



If reliable synchronization cannot be maintained, the application may:



\* mark the participant degraded;

\* require recalibration;

\* recommend built-in speakers;

\* or temporarily remove the device from synchronized playback.



\---



\# 31. Audio Route Changes



If a device changes output route during playback:



```text id="e0ujmq"

Speaker

&#x20; ↓

Bluetooth

```



the audio subsystem MUST notify the synchronization layer.



A route change may invalidate previous latency assumptions.



Recalibration may therefore be required.



\---



\# 32. Pause



Pause is a synchronized session operation.



The host should issue a pause command associated with the current generation.



Participants should pause according to the session's synchronization policy.



The system must distinguish:



```text id="r6o9ah"

requested pause

```



from:



```text id="y6n5mb"

actual pause

```



Actual playback state should be reported.



\---



\# 33. Resume



Resume MUST NOT simply mean:



```text id="n7l4v1"

play()

```



The preferred flow is:



```text id="h6j5cx"

Current playback position

&#x20;       ↓

Recalibrate if required

&#x20;       ↓

Choose future target

&#x20;       ↓

Schedule resume

```



This avoids different devices resuming at different moments.



\---



\# 34. Seek



A seek operation changes the audio timeline.



The host should:



1\. generate a new playback generation;

2\. communicate the target audio position;

3\. ensure participants can seek successfully;

4\. establish a new synchronization target;

5\. schedule resumed playback.



A stale pre-seek command must not override the new seek state.



\---



\# 35. Stop



Stopping playback should:



\* invalidate pending playback commands;

\* stop or cancel scheduled audio;

\* release unnecessary buffers;

\* retain reusable decoded/prepared state when practical;

\* report actual stopped state.



\---



\# 36. Playback Generation



Every major timeline-changing operation SHOULD advance the playback generation.



Examples:



```text id="6ryv39"

PLAY

PAUSE

SEEK

RESUME

STOP

```



This prevents old network commands from acting on a newer audio timeline.



\---



\# 37. Drift



Even after successful synchronized startup, devices may gradually diverge.



Potential causes include:



\* clock differences;

\* playback clock differences;

\* hardware oscillator differences;

\* audio-engine timing;

\* platform scheduling;

\* device-specific processing.



Therefore:



```text id="r9l5qi"

Synchronized startup

≠

permanent synchronization

```



The audio subsystem must continuously expose sufficient playback information for drift monitoring.



\---



\# 38. Drift Monitoring



During playback, the synchronization layer should periodically obtain:



```text id="3p8f8v"

Audio position

\+

Timing timestamp

\+

Playback state

\+

Route state

```



The synchronization system then estimates:



```text id="w0c3q6"

position error

drift rate

```



as defined in `synchronization.md`.



\---



\# 39. Playback-Rate Correction



Small timing errors may be corrected using tiny playback-rate adjustments if the platform audio engine supports them reliably.



Conceptually:



```text id="w9s4q4"

Device is slightly behind

&#x20;       ↓

tiny rate increase

&#x20;       ↓

device catches up gradually

&#x20;       ↓

return to normal rate

```



The exact correction range is:



\*\*Status: EXPERIMENTAL\*\*



It must be measured for audible artifacts.



\---



\# 40. Position Correction



A small position correction may be appropriate when playback-rate correction is insufficient.



Corrections should be:



\* controlled;

\* bounded;

\* infrequent;

\* measurable.



Large repeated seeks are explicitly discouraged because they can create audible artifacts and destabilize synchronization.



\---



\# 41. Audible Artifacts



Synchronization correction must consider audio quality.



Potential artifacts include:



\* clicks;

\* pops;

\* pitch changes;

\* speed changes;

\* gaps;

\* repeated samples;

\* dropped samples.



A technically smaller timing error is not automatically better if the correction creates an obviously audible artifact.



The synchronization system must balance:



```text id="e7yq1f"

timing accuracy

vs.

audio quality

```



\---



\# 42. Interruption Handling



Mobile operating systems can interrupt audio because of:



\* calls;

\* notifications;

\* alarms;

\* other applications;

\* audio-session changes;

\* OS-level events.



The audio subsystem MUST detect relevant interruptions.



It must report:



```text id="o9g6n4"

INTERRUPTED

```



rather than pretending playback is still normal.



\---



\# 43. Interruption Recovery



After an interruption:



```text id="d2h9fr"

INTERRUPTED

&#x20;   ↓

AUDIO ROUTE/SESSION RESTORED

&#x20;   ↓

CHECK PLAYBACK POSITION

&#x20;   ↓

CHECK GROUP STATE

&#x20;   ↓

RESYNC

&#x20;   ↓

RESUME

```



The exact behavior depends on the session policy.



\---



\# 44. Backgrounding



Mobile operating systems impose background-execution restrictions.



SoundMesh MUST NOT assume that a Flutter application can remain indefinitely active in the background.



The audio architecture must explicitly investigate:



\* screen locked behavior;

\* background audio;

\* native audio sessions;

\* OS suspension;

\* network connection survival;

\* background restrictions.



Supported background behavior is:



\*\*Status: UNDECIDED\*\*



It must be validated separately on Android and iOS.



\---



\# 45. Screen Lock



Screen lock must be tested independently.



A device may:



\* continue audio playback;

\* reduce network activity;

\* suspend application code;

\* change power-management behavior.



The system should report meaningful state changes.



\---



\# 46. Battery and Thermal Behavior



SoundMesh may require:



\* continuous audio decoding;

\* network communication;

\* synchronization monitoring;

\* native audio callbacks.



Therefore, CPU and battery usage must be measured.



The implementation should avoid unnecessary high-frequency work.



\---



\# 47. Audio Callback Design



Timing-sensitive audio callbacks must remain native.



Do not implement a high-frequency loop such as:



```text id="jhjw4m"

native audio callback

&#x20;   ↓

Flutter

&#x20;   ↓

Dart

&#x20;   ↓

Flutter plugin

&#x20;   ↓

native audio callback

```



This introduces unnecessary scheduling and communication overhead.



The preferred architecture is:



```text id="lq9zmy"

Native audio callback

&#x20;       ↓

Native timing/playback state

&#x20;       ↓

Occasional summarized event

&#x20;       ↓

Flutter

```



\---



\# 48. Flutter Responsibilities



Flutter should handle:



\* track selection UI;

\* play/pause controls;

\* progress display;

\* participant state;

\* volume controls;

\* error presentation;

\* user-facing playback state;

\* room controls.



Flutter should NOT directly implement:



\* sample scheduling;

\* low-level audio callbacks;

\* precise audio-clock management;

\* real-time drift correction loops.



\---



\# 49. Native Responsibilities



Native audio code should handle:



\* audio session configuration;

\* decoder/player initialization where required;

\* buffer management;

\* native scheduling;

\* native timestamps;

\* audio-route changes;

\* interruptions;

\* playback callbacks;

\* low-level playback control.



\---



\# 50. Audio Engine Abstraction



The application should expose a platform-independent logical interface.



Conceptually:



```text id="j1wq7n"

AudioEngine



load(audio)

prepare()

schedule(position, targetTime)

play()

pause()

resume()

seek(position)

stop()

getPlaybackPosition()

getPlaybackTimestamp()

getRoute()

getState()

```



The exact API may differ.



Android and iOS implementations must provide equivalent semantics where supported.



\---



\# 51. Capability Reporting



Each device should report relevant audio capabilities.



Example:



```text id="2x1w6b"

AudioCapabilities {

&#x20;   supportedFormats

&#x20;   sampleRates

&#x20;   channelCounts

&#x20;   schedulingSupport

&#x20;   timestampSupport

&#x20;   rateAdjustmentSupport

&#x20;   route

}

```



Not all fields need to be exposed to the user.



This allows the host to understand heterogeneous participants.



\---



\# 52. Unsupported Capabilities



A participant must not claim support for an operation it cannot perform reliably.



Example:



```text id="0j5r8x"

Host requests scheduled playback



Participant:

scheduled playback = unsupported

```



The session should then choose an appropriate policy rather than silently pretending the device can perform it.



\---



\# 53. Sample Rate



Sample rate must be treated as an explicit audio property.



Examples:



```text id="d7a4e3"

44.1 kHz

48 kHz

```



Different devices may use different native output configurations.



The implementation must determine whether:



\* all devices should use the same sample rate;

\* resampling is required;

\* platform audio engines perform resampling;

\* resampling affects synchronization.



This is:



\*\*Status: UNDECIDED\*\*



\---



\# 54. Channels



Stereo/mono behavior must be considered.



The MVP should preferably use audio content and playback configurations that are reliably supported across target devices.



The project should not assume identical speaker/channel configurations.



\---



\# 55. Resampling



If the source audio's sample rate differs from the native output rate, resampling may occur.



The project must determine:



\* where resampling happens;

\* whether it changes timing;

\* whether it introduces meaningful latency;

\* whether it differs across devices.



Resampling behavior must be included in synchronization experiments if it affects playback timing.



\---



\# 56. Decoder Determinism



When every participant decodes the same compressed audio independently, the project should verify that the resulting playback timeline remains sufficiently equivalent.



The objective is not necessarily bit-identical decoded buffers.



The requirement is:



```text id="1x7s4z"

Equivalent audio timeline

\+

Predictable playback timing

```



\---



\# 57. Compression and Codec Effects



Compressed audio introduces decoding behavior that may differ between devices.



The project should therefore validate the chosen formats across:



\* multiple Android devices;

\* multiple iOS devices;

\* different OS versions;

\* different hardware classes.



The MVP should prefer predictable compatibility over maximum codec variety.



\---



\# 58. Audio File Caching



Participants SHOULD cache verified audio assets when useful.



A cache may be indexed by:



```text id="q0u7mp"

audioId

```



This can avoid unnecessary retransfers.



Cache management must have bounded storage usage.



\---



\# 59. Temporary Files



Incomplete audio transfers should be stored separately from verified assets.



Recommended conceptual structure:



```text id="q3l7k0"

/audio/

&#x20;   verified/

&#x20;   temporary/

```



An incomplete transfer must never overwrite the verified version.



\---



\# 60. Storage Cleanup



Temporary audio data should be cleaned after:



\* transfer failure;

\* cancelled transfer;

\* session termination;

\* successful replacement.



Verified cached assets may be retained according to the cache policy.



\---



\# 61. Playback State Reporting



The native audio subsystem should report states such as:



```text id="2y8k4a"

IDLE

LOADING

PREPARING

READY

SCHEDULED

PLAYING

PAUSED

INTERRUPTED

SEEKING

STOPPED

ERROR

```



The synchronization system must be able to distinguish these states.



\---



\# 62. Actual vs Requested State



SoundMesh must distinguish between:



```text id="j8jz6h"

REQUESTED:

PLAY

```



and:



```text id="j7g6x4"

ACTUAL:

PLAYING

```



The same applies to:



\* pause;

\* seek;

\* stop;

\* resume.



A command being sent does not mean it succeeded.



\---



\# 63. Audio Errors



Errors should be structured.



Examples:



```text id="2m1r9x"

AUDIO\_NOT\_FOUND

UNSUPPORTED\_FORMAT

DECODER\_FAILED

AUDIO\_CORRUPTED

PREPARATION\_FAILED

SCHEDULING\_FAILED

OUTPUT\_UNAVAILABLE

AUDIO\_INTERRUPTED

AUDIO\_ROUTE\_CHANGED

BUFFER\_UNDERRUN

PLAYBACK\_FAILED

```



The application should receive actionable error states.



\---



\# 64. Buffer Underrun



A buffer underrun is a serious event.



If it occurs:



```text id="r8q4r9"

BUFFER\_UNDERRUN

```



the audio subsystem must report it immediately.



The synchronization layer must determine whether the device can recover or requires resynchronization.



\---



\# 65. Audio Dropout



A short audio dropout should not be silently treated as successful playback.



The system should record:



\* timestamp;

\* duration where measurable;

\* playback position;

\* route;

\* buffer state.



This information is useful for diagnosing whether the cause was:



\* CPU pressure;

\* audio engine;

\* network;

\* OS interruption;

\* thermal throttling.



\---



\# 66. Volume Synchronization



Synchronizing timing does not automatically synchronize loudness.



Volume normalization is a separate problem.



Therefore:



```text id="l3q2z6"

Timing synchronization = REQUIRED

Volume normalization = UNDECIDED

```



The initial product should prioritize synchronized timing.



\---



\# 67. Audio Quality Priority



The engineering priority should be:



1\. correct audio;

2\. reliable playback;

3\. synchronized timing;

4\. acceptable latency;

5\. correction without noticeable artifacts;

6\. efficient resource use;

7\. advanced audio quality features.



Do not sacrifice playback stability for tiny theoretical synchronization improvements.



\---



\# 68. Measurement Requirements



Audio experiments should measure:



\* scheduled start time;

\* actual playback start;

\* playback position;

\* startup offset;

\* drift;

\* correction duration;

\* correction magnitude;

\* buffer underruns;

\* decoder startup time;

\* preparation time;

\* CPU usage;

\* memory usage;

\* battery impact;

\* route changes;

\* interruption recovery.



Where possible, measurements should use external instrumentation rather than trusting application logs alone.



\---



\# 69. External Synchronization Validation



Application timestamps alone cannot prove that speakers produce sound simultaneously.



The project should eventually use external measurement methods such as:



\* microphone recordings;

\* multiple microphones;

\* audio waveform analysis;

\* controlled acoustic tests;

\* reference signals.



The purpose is to measure:



```text id="i1m7ac"

actual audible synchronization

```



rather than merely:



```text id="z1t4d7"

software state synchronization

```



\---



\# 70. Initial Audio Experiment Plan



\## Experiment 1 — Single Device



Verify:



\* audio loading;

\* decoding;

\* preparation;

\* playback;

\* pause;

\* resume;

\* seek;

\* stop.



\---



\## Experiment 2 — Two Devices



Use identical audio.



Measure whether scheduled playback begins within the target synchronization range.



\---



\## Experiment 3 — Three Devices



Add a third device.



Determine whether group synchronization degrades.



\---



\## Experiment 4 — Different Hardware



Use different:



\* phone models;

\* CPU classes;

\* Android/iOS versions;

\* speaker hardware.



\---



\## Experiment 5 — Route Differences



Compare:



```text id="s9i1f7"

Built-in speaker ↔ built-in speaker

Built-in speaker ↔ Bluetooth

```



Determine whether Bluetooth can be supported.



\---



\## Experiment 6 — Long Playback



Run synchronized playback for an extended duration.



Measure:



```text id="k7u8t2"

startup error

drift

correction frequency

final error

```



\---



\## Experiment 7 — Interruptions



Test:



\* incoming call;

\* notification;

\* application backgrounding;

\* screen lock;

\* audio-route change.



\---



\## Experiment 8 — Network Loss



After audio is prepared:



```text id="u4g8j0"

disconnect network

```



Determine whether local playback continues.



This experiment validates the local-distribution architecture.



\---



\# 71. Audio Acceptance Criteria



The audio system is MVP-ready only when:



1\. supported audio can be loaded reliably;

2\. participants can obtain the required audio;

3\. audio integrity is verified;

4\. audio preparation completes before scheduled playback;

5\. native playback can be scheduled against an appropriate timing source;

6\. actual playback position can be measured;

7\. pause/resume/seek/stop are represented explicitly;

8\. playback failures are detectable;

9\. interruptions are detectable;

10\. route changes are detectable;

11\. synchronization can access playback timing;

12\. long playback can be monitored for drift;

13\. audio transfer is not required continuously during playback;

14\. the implementation works across the validated Android/iOS device matrix;

15\. external testing demonstrates that software-reported synchronization corresponds reasonably to actual audible synchronization.



\---



\# 72. Initial Synchronization Targets



The following are engineering targets, NOT guarantees.



Initial target:



```text id="m7n4rx"

Startup group spread:

≤ 20 ms



Steady-state group spread:

≤ 20 ms

```



Preferred stretch target:



```text id="1q4k8d"

≤ 10 ms

```



These values must be validated through real experiments.



They may be changed in `decisions.md` if evidence demonstrates that a different target is more appropriate.



\---



\# 73. Important Distinction



SoundMesh should never claim:



> "Every phone is perfectly synchronized."



Instead, the engineering question is:



> "Is the difference in audible playback timing small enough that users perceive the phones as one coordinated speaker system?"



This distinction is fundamental.



\---



\# 74. Audio and Networking Boundary



Networking handles:



```text id="s5e7u8"

audio metadata

audio transfer

transfer integrity

transfer progress

```



Audio handles:



```text id="8t0l1w"

verification

decoding

buffering

preparation

playback

audio timing

output route

```



Synchronization handles:



```text id="q9e8h4"

shared timeline

clock relationship

scheduled target

drift

correction

resynchronization

```



These boundaries should remain explicit.



\---



\# 75. Audio and Synchronization Boundary



Synchronization tells audio:



```text id="4u6s5n"

"When should this audio position occur?"

```



Audio tells synchronization:



```text id="d5x3v9"

"When did/does this audio position actually occur?"

```



This bidirectional relationship is essential.



\---



\# 76. Recommended Data Flow



```text id="h7x2p1"

&#x20;               ┌───────────────┐

&#x20;               │ Synchronizer  │

&#x20;               └───────┬───────┘

&#x20;                       │

&#x20;               target playback time

&#x20;                       │

&#x20;                       ▼

&#x20;               ┌───────────────┐

&#x20;               │  Audio Engine │

&#x20;               └───────┬───────┘

&#x20;                       │

&#x20;                 native playback

&#x20;                       │

&#x20;                       ▼

&#x20;                   Speaker

&#x20;                       │

&#x20;                 actual position

&#x20;                       │

&#x20;                       ▼

&#x20;               ┌───────────────┐

&#x20;               │ Synchronizer  │

&#x20;               └───────────────┘

```



\---



\# 77. Design Rules



The audio implementation MUST follow these rules:



1\. Do not use wall-clock time for precise audio scheduling.

2\. Do not depend on Flutter timers for precise playback.

3\. Do not assume identical audio latency across devices.

4\. Do not assume identical clocks across devices.

5\. Do not assume identical hardware.

6\. Do not continuously stream audio unless necessary.

7\. Do not begin playback before required preparation completes.

8\. Do not silently ignore audio interruptions.

9\. Do not silently ignore route changes.

10\. Do not silently ignore buffer underruns.

11\. Do not perform uncontrolled correction loops.

12\. Do not claim synchronization without external validation.

13\. Do not add codec support without cross-platform testing.

14\. Do not make platform-specific behavior invisible to synchronization.

15\. Do not turn experimental assumptions into permanent architecture without evidence.



\---



\# 78. Open Questions



The following remain intentionally unresolved:



1\. Which exact audio engine should Android use?

2\. Which exact audio engine should iOS use?

3\. Should Android use Oboe, AAudio directly, AudioTrack, or another approach?

4\. Should iOS use AVAudioPlayerNode, AVAudioEngine, or another architecture?

5\. Which audio formats should MVP support?

6\. Should audio be decoded fully or streamed from local storage through a decoder?

7\. How much buffering is required?

8\. What is the most reliable scheduling API on each platform?

9\. How accurately can actual playback position be measured?

10\. How should audio output latency be measured?

11\. Can output latency be estimated consistently across device models?

12\. Should all participants normalize sample rates?

13\. How should resampling affect synchronization?

14\. What correction mechanisms are least audible?

15\. What playback-rate correction range is acceptable?

16\. Can Bluetooth devices be synchronized sufficiently?

17\. How should background playback behave?

18\. How should screen-lock behavior differ by platform?

19\. What audio interruptions require full resynchronization?

20\. What external instrumentation should become part of automated testing?

21\. What startup synchronization threshold is perceptually acceptable?

22\. What steady-state synchronization threshold is perceptually acceptable?

23\. What is the maximum acceptable buffer underrun rate?

24\. How much CPU and battery usage is acceptable?

25\. How should cached audio be managed?

26\. Should volume normalization become a future feature?

27\. How should audio behavior differ between host and participant devices?

28\. What happens when one participant cannot support the selected audio configuration?



These MUST remain explicit until resolved through research and experiments.



\---



\# 79. Definition of Done



`audio.md` is considered successfully implemented as a specification when:



\* audio ownership boundaries are clear;

\* native/Flutter responsibilities are clear;

\* audio transfer is separated from playback;

\* audio integrity is defined;

\* preparation state is explicit;

\* scheduled playback is required;

\* playback position is measurable;

\* audio latency is distinguished from network latency;

\* interruptions are defined;

\* route changes are defined;

\* drift interaction is defined;

\* external validation is required;

\* measurable acceptance criteria exist;

\* unresolved technical decisions are explicitly marked.



\---



\# 80. Final Audio Principle



SoundMesh is not trying to make five phones play an audio file.



It is trying to make five independent audio systems produce one coherent acoustic event.



That means the audio architecture must treat:



```text id="d6q3x7"

Audio data

\+

Decoder

\+

Buffer

\+

Native clock

\+

Playback engine

\+

Output latency

\+

Actual playback position

```



as part of the synchronization problem.



The ultimate goal is:



```text id="2b5x8k"

&#x20;         PHONE A

&#x20;            🔊

&#x20;             \\

&#x20;              \\

&#x20;         PHONE B 🔊

&#x20;                \\

&#x20;                 \\

&#x20;            PHONE C 🔊

&#x20;                 /

&#x20;                /

&#x20;         PHONE D 🔊



&#x20;       ↓



&#x20;  ONE COORDINATED

&#x20;    SOUND FIELD

```



\*\*Core principle:\*\*



> Synchronization is only successful when the speakers are synchronized—not merely when the software says they are synchronized.



> SoundMesh must measure the difference between those two things.



