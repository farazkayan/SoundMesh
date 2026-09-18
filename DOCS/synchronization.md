\# SoundMesh — Synchronization Specification



\*\*Document:\*\* `DOCS/synchronization.md`

\*\*Status:\*\* Living engineering specification

\*\*Authority:\*\* Synchronization model, timing architecture, calibration, drift handling, and synchronization experiments

\*\*Project:\*\* SoundMesh

\*\*Platform:\*\* Flutter application with native Android/iOS timing and audio implementations



\---



\# 1. Purpose



This document defines how SoundMesh attempts to make multiple independent smartphones behave like one coordinated speaker system.



Synchronization is the central technical problem of SoundMesh.



The system must coordinate devices that may have:



\* different hardware;

\* different operating systems;

\* different clocks;

\* different clock rates;

\* different audio hardware;

\* different audio-buffer sizes;

\* different audio output latency;

\* different CPU loads;

\* different network latency;

\* different network jitter;

\* different power-management behavior;

\* different Bluetooth/audio routes;

\* different lifecycle states.



The objective is not to make the devices mathematically identical.



The objective is:



> \*\*Make the audible playback difference between participating devices small enough that the group is perceived as one coordinated speaker system under supported conditions.\*\*



The system must measure synchronization rather than assume it.



\---



\# 2. Core Principle



SoundMesh must never treat this:



```text

HOST → "PLAY NOW" → all devices

```



as a synchronization protocol.



Network messages do not arrive at exactly the same time.



Even if the messages were transmitted simultaneously, the receiving operating systems and audio pipelines would not necessarily begin audible playback simultaneously.



Instead, SoundMesh uses:



```text

Measure

&#x20;  ↓

Estimate

&#x20;  ↓

Prepare

&#x20;  ↓

Schedule

&#x20;  ↓

Measure again

&#x20;  ↓

Correct

```



\---



\# 3. Synchronization Architecture



The synchronization subsystem is divided into:



```text

Synchronization

│

├── ClockSource

│

├── ClockModel

│

├── TimestampExchange

│

├── LatencyEstimator

│

├── OffsetEstimator

│

├── UncertaintyEstimator

│

├── CalibrationEngine

│

├── SharedTimeline

│

├── PlaybackScheduler

│

├── PlaybackMonitor

│

├── DriftEstimator

│

├── CorrectionController

│

└── RecoverySynchronizer

```



No UI component should directly implement any of these responsibilities.



\---



\# 4. Timing Terminology



\## 4.1 Wall clock



A wall clock represents civil time.



Example:



```text

2026-09-05 23:00:00

```



Wall clocks can be adjusted.



They are therefore unsuitable as the primary source for elapsed-time synchronization.



SoundMesh must not use calendar time as its primary playback clock.



\---



\# 4.2 Monotonic clock



A monotonic clock is intended for measuring elapsed time.



Conceptually:



```text

t0 < t1 < t2 < t3

```



within the same clock domain.



Monotonic clocks are preferred for synchronization measurements because they are designed for elapsed-time measurement rather than human-readable calendar time.



Android exposes monotonic elapsed-time sources through `SystemClock`; iOS exposes host-time representations through the audio timing APIs.



\---



\# 4.3 Host clock



The host maintains the authoritative SoundMesh session timeline.



This does \*\*not\*\* mean that participant devices literally use the host's physical clock.



Instead, participants estimate a relationship between their local monotonic clock and the host timeline.



\---



\# 4.4 Participant clock



Each participant has its own local timing source.



Example:



```text

Host clock:

H(t)



Participant A clock:

A(t)



Participant B clock:

B(t)

```



These clocks cannot be assumed to have:



```text

same origin

same current value

same rate

same accuracy

same audio latency

```



\---



\# 4.5 Clock offset



Clock offset describes the estimated difference between two timing domains at a particular moment.



Conceptually:



```text

offset = host\_time - participant\_time

```



The exact representation used in code must be defined by the synchronization implementation.



\---



\# 4.6 Clock drift



Clock drift describes the gradual change in relative timing between devices.



Two devices can begin with:



```text

error ≈ 0 ms

```



and later become:



```text

error = +20 ms

```



because their clocks/audio sample clocks progress at slightly different rates.



Therefore:



> \*\*Calibration is not sufficient by itself.\*\*



\---



\# 4.7 RTT



RTT means round-trip time.



A simplified measurement is:



```text

Participant → Host → Participant

```



and:



```text

RTT = response\_arrival - request\_send

```



RTT gives information about network delay but does not directly equal one-way latency.



\---



\# 4.8 Network jitter



Network jitter is variation in message delivery timing.



Example:



```text

measurement 1: 7 ms

measurement 2: 11 ms

measurement 3: 8 ms

measurement 4: 23 ms

measurement 5: 9 ms

```



SoundMesh must account for this variability.



A single timing measurement must not automatically be treated as ground truth.



\---



\# 4.9 Audio latency



Audio latency is the delay between an application's scheduling/command point and actual audible output.



It may include:



```text

application

&#x20;   ↓

audio buffer

&#x20;   ↓

audio engine

&#x20;   ↓

OS audio stack

&#x20;   ↓

hardware

&#x20;   ↓

speaker

```



Two devices can have different audio latency even when their network timing is identical.



Therefore:



> \*\*Network synchronization alone is insufficient.\*\*



\---



\# 4.10 Synchronization error



Synchronization error is the difference between the intended shared playback position and a device's actual playback position.



Conceptually:



```text

syncError =

&#x20;   actualPlaybackTime

&#x20;   -

&#x20;   expectedPlaybackTime

```



The sign convention must be standardized in implementation.



\---



\# 5. Synchronization Model



SoundMesh uses a shared logical timeline.



Conceptually:



```text

Shared timeline



0ms ─────── 1000ms ─────── 2000ms ─────── 3000ms

&#x20;            ↑

&#x20;        playback start

```



Every participant maps this shared timeline to its local timing system.



The host does not need to know the absolute physical clock value of every device.



It needs a sufficiently accurate model of the relationship between each participant and the session timeline.



\---



\# 6. Why Immediate Playback Fails



Consider:



```text

Host sends PLAY

```



at:



```text

Host time = 10,000 ms

```



Participant A receives it after:



```text

5 ms

```



Participant B receives it after:



```text

15 ms

```



Participant C receives it after:



```text

9 ms

```



Even if every phone begins playback immediately after receiving the message:



```text

A starts ≈ +5 ms

B starts ≈ +15 ms

C starts ≈ +9 ms

```



The resulting spread is approximately:



```text

10 ms

```



before considering:



\* OS scheduling;

\* audio buffers;

\* decoder state;

\* audio engine startup;

\* hardware output latency.



Therefore immediate commands cannot provide reliable synchronization.



\---



\# 7. Future Playback Scheduling



SoundMesh should schedule playback for a future target.



Example:



```text

Current shared time:

10,000 ms



Target playback time:

12,000 ms

```



The extra time allows devices to:



\* receive the command;

\* convert the target time;

\* prepare audio;

\* fill buffers;

\* configure the audio engine;

\* enter the required playback state;

\* wait for the target.



Conceptually:



```text

NOW

&#x20;│

&#x20;├── synchronization

&#x20;│

&#x20;├── audio preparation

&#x20;│

&#x20;├── buffering

&#x20;│

&#x20;├── scheduler setup

&#x20;│

&#x20;└──────────────► TARGET

&#x20;                  │

&#x20;                  ▼

&#x20;               PLAYBACK

```



\---



\# 8. Target Playback Margin



The target playback time must not be chosen arbitrarily.



Let:



```text

T\_now

```



be the current session time.



Let:



```text

M

```



be the scheduling safety margin.



Then:



```text

T\_target = T\_now + M

```



`M` must be large enough to accommodate measured:



\* command propagation;

\* processing;

\* audio preparation;

\* scheduling uncertainty;

\* network jitter.



But an excessively large margin makes the system feel unnecessarily slow.



Therefore `M` must be experimentally determined.



\---



\# 9. Initial Synchronization



Before synchronized playback begins, each participant should perform calibration.



Conceptually:



```text

JOIN

&#x20;↓

CONNECT

&#x20;↓

TIME CALIBRATION

&#x20;↓

AUDIO PREPARATION

&#x20;↓

READY

&#x20;↓

SCHEDULE

&#x20;↓

PLAY

```



A participant must not enter `READY` merely because its network connection exists.



It should have enough timing information to participate.



\---



\# 10. Timestamp Exchange



A basic synchronization exchange can use four timestamps.



Participant sends:



```text

t1 = participant send time

```



Host receives:



```text

t2 = host receive time

```



Host responds:



```text

t3 = host send time

```



Participant receives:



```text

t4 = participant receive time

```



Conceptually:



```text

Participant                    Host



&#x20;   t1  ─────────────────────► t2



&#x20;       ◄───────────────────── t3



&#x20;   t4

```



This produces information about:



\* round-trip delay;

\* estimated clock offset;

\* timing uncertainty.



The exact offset formula must account for the chosen sign convention.



\---



\# 11. Basic Offset Estimation



Under an approximately symmetric network-delay assumption, a commonly used estimate is:



```text

offset =

&#x20;   ((t2 - t1) + (t3 - t4)) / 2

```



where the sign convention is:



```text

host\_time ≈ participant\_time + offset

```



This formula is an \*\*estimate\*\*, not a guarantee.



The network may have asymmetric forward and reverse delays.



Therefore SoundMesh must not treat the result as exact.



\---



\# 12. RTT Estimation



Using the same timestamps:



```text

RTT = (t4 - t1) - (t3 - t2)

```



This estimates the time spent outside the host's processing interval.



RTT should be stored alongside the offset estimate.



Example:



```text

offset = +3.2 ms

RTT = 8.4 ms

```



\---



\# 13. Multiple Measurements



A single timestamp exchange is insufficient.



SoundMesh should perform multiple measurements.



Example:



```text

Round 1

Round 2

Round 3

...

Round N

```



Each produces:



```text

offset\_i

RTT\_i

```



The system can then reject clearly abnormal samples and estimate a more stable result.



\---



\# 14. Why Minimum RTT Is Useful



Suppose measurements are:



```text

RTT:

8 ms

9 ms

8 ms

31 ms

10 ms

9 ms

```



The 31 ms sample may represent temporary queueing or contention.



The lower-delay samples may provide a better approximation of the network path without substantial queueing.



Therefore calibration should investigate strategies such as:



```text

minimum RTT sample

low percentile RTT

weighted filtering

median filtering

robust regression

```



The final estimator remains an experimental decision.



\---



\# 15. Clock Offset Is Not Network Latency



These are separate concepts.



```text

Clock offset:

"How far apart are our timing domains?"



Network latency:

"How long does communication take?"



Audio latency:

"How long until scheduled audio becomes audible?"

```



The synchronization architecture must keep these quantities separate.



\---



\# 16. Timing Uncertainty



Every estimate should have an uncertainty measure.



Example:



```text

offset estimate:

+2.8 ms



estimated uncertainty:

±1.7 ms

```



A device with:



```text

±0.5 ms

```



is not equivalent to one with:



```text

±15 ms

```



even if both report the same offset.



Uncertainty should influence:



\* scheduling margin;

\* confidence;

\* diagnostics;

\* correction decisions.



\---



\# 17. Calibration Result



A participant's calibration state should conceptually contain:



```text

CalibrationResult

├── clockOffset

├── estimatedRtt

├── minimumRtt

├── timingUncertainty

├── measurementCount

├── calibrationDuration

└── confidence

```



Exact field names are implementation details.



\---



\# 18. Calibration Quality



A calibration attempt should be classified.



Example:



```text

GOOD

DEGRADED

FAILED

```



A participant should not silently continue if calibration quality is too poor for the current synchronization target.



\---



\# 19. Clock Rate Differences



Clock offset can remain stable while clock rate differs.



Example:



```text

Device A:

1000.000 ms

2000.000 ms

3000.000 ms



Device B:

1000.000 ms

2000.007 ms

3000.014 ms

```



The initial offset may be almost zero.



But the error grows over time.



Therefore SoundMesh must eventually estimate not only:



```text

offset

```



but also:



```text

relative clock rate / drift

```



\---



\# 20. Drift Model



A simple conceptual model is:



```text

error(t) = offset + driftRate × elapsedTime

```



where:



```text

offset

```



represents initial timing difference and:



```text

driftRate

```



represents relative clock-rate difference.



The real implementation may use a more robust model.



\---



\# 21. Drift Measurement



After playback begins, participants should periodically report timing information.



Example:



```text

t = 0 s     error = +1 ms

t = 10 s    error = +2 ms

t = 20 s    error = +3 ms

t = 30 s    error = +4 ms

```



This suggests a positive drift.



A different device might show:



```text

t = 0 s     error = +1 ms

t = 10 s    error = +1 ms

t = 20 s    error = +1 ms

t = 30 s    error = +2 ms

```



which suggests substantially lower drift.



\---



\# 22. Drift Rate



A basic estimate is:



```text

driftRate =

&#x20;   (error2 - error1)

&#x20;   /

&#x20;   (time2 - time1)

```



For example:



```text

error1 = 2 ms

error2 = 6 ms



elapsed = 20 s



driftRate = 4 ms / 20 s

&#x20;         = 0.2 ms/s

```



The estimate should not be based on a single noisy pair in production.



Multiple observations should be used.



\---



\# 23. Drift Filtering



Measured synchronization error contains noise.



Therefore the system should avoid interpreting every measurement as real clock drift.



Possible techniques include:



```text

moving average

median filtering

low-pass filtering

linear regression

robust regression

```



The simplest reliable method should be selected through experiments.



Do not add complex mathematical machinery unless measurements justify it.



\---



\# 24. Playback Position



The synchronization system needs a meaningful playback position.



Conceptually:



```text

Playback position = audio timeline position

```



This should preferably come from the native audio engine rather than Flutter's UI timer.



A UI timer is not an authoritative audio clock.



\---



\# 25. Native Audio Time



The native audio layer should expose enough timing information for synchronization.



On Apple platforms, `AVAudioTime` can represent a moment using host time and/or audio sample time, and sample time represents the number of audio samples tracked by the audio device.



This provides an architectural bridge between:



```text

system host time

```



and:



```text

audio sample timeline

```



The Android implementation must provide an equivalent native timing abstraction rather than exposing Android-specific timing concepts directly to the rest of the application.



\---



\# 26. Shared Playback Position



Suppose:



```text

shared position = 30.000 s

```



Participant A reports:



```text

30.004 s

```



Participant B reports:



```text

29.996 s

```



Then:



```text

A error = +4 ms

B error = -4 ms

```



The group spread is:



```text

8 ms

```



This is more useful than merely checking whether every device says:



```text

PLAYING

```



\---



\# 27. Group Synchronization Error



For a group of devices:



```text

E = max(position\_i) - min(position\_i)

```



This measures the playback-position spread.



Example:



```text

Device A = 30.001 s

Device B = 30.004 s

Device C = 29.998 s

```



Then:



```text

E = 30.004 - 29.998

&#x20; = 0.006 s

&#x20; = 6 ms

```



This metric is useful for validation.



\---



\# 28. Reference Device



The host may act as the session reference.



However, group quality should also consider pairwise/group spread.



It is not sufficient to say:



```text

"Everyone is close to the host."

```



if the host's own playback position is not representative of actual audio output.



The validation system should eventually measure:



```text

host-relative error

group spread

actual audible alignment

```



where practical.



\---



\# 29. Startup Synchronization



Startup should occur in phases.



```text

1\. Audio identified

2\. Audio available

3\. Audio decoded/prepared

4\. Buffer ready

5\. Timing calibrated

6\. Participant ready

7\. Future target selected

8\. Playback scheduled

9\. Playback begins

10\. Startup error measured

```



A participant that misses the preparation deadline should not start late and pretend it is synchronized.



\---



\# 30. Preparation Barrier



The host should maintain a preparation barrier.



Conceptually:



```text

Host

&#x20;├── Participant A READY

&#x20;├── Participant B READY

&#x20;├── Participant C READY

&#x20;└── Participant D READY

&#x20;         │

&#x20;         ▼

&#x20;      schedule

```



The host should know which participants are actually ready.



The UI may show:



```text

3/4 devices ready

```



rather than simply:



```text

Connected: 4

```



\---



\# 31. Playback Command



The playback command should contain enough information to reconstruct the intended playback state.



Conceptually:



```text

PLAYBACK\_START

├── sessionId

├── generation

├── assetId

├── targetSharedTime

├── targetAudioPosition

└── timingMetadata

```



The exact protocol belongs in `networking.md`.



\---



\# 32. Generation Numbers



Playback commands must be ordered.



Example:



```text

generation 41

generation 42

generation 43

```



If a delayed packet containing generation 41 arrives after generation 43, the participant must not revert to generation 41.



This prevents stale network messages from corrupting playback state.



\---



\# 33. Late Join



A late participant must synchronize to the \*\*current\*\* shared playback timeline.



Example:



```text

Current shared playback:

87.3 seconds

```



The participant must:



```text

download/locate asset

&#x20;       ↓

prepare audio

&#x20;       ↓

calibrate

&#x20;       ↓

calculate target position

&#x20;       ↓

schedule entry

```



It must not restart the song at:



```text

0 seconds

```



unless the user explicitly requested that behavior.



\---



\# 34. Late-Join Entry Point



If the participant finishes preparation at:



```text

shared time = 100.0 s

```



and current playback is:



```text

audio position = 37.5 s

```



the participant should calculate a future target such as:



```text

start at audio position 37.5 s

```



at a future synchronized shared time.



The exact minimum preparation margin must be measured.



\---



\# 35. Pause



Pause must be a shared state transition.



The host should determine the pause position.



Conceptually:



```text

current shared position = 52.314 s

```



Then participants transition toward:



```text

PAUSED @ 52.314 s

```



Minor local differences may exist due to timing uncertainty.



\---



\# 36. Resume



Resume should preferably use future scheduling.



Bad:



```text

RESUME NOW

```



Preferred:



```text

RESUME AT SHARED TIME X

FROM AUDIO POSITION Y

```



This gives participants time to prepare.



\---



\# 37. Seek



Seek is equivalent to creating a new synchronization point.



Example:



```text

User seeks to 120.0 s

```



The host should establish:



```text

new generation

new target position

new future playback time

```



Participants then schedule from the new position.



\---



\# 38. Stop



Stop terminates the current playback generation.



A new playback operation should receive a new generation.



This prevents delayed packets from an old session from restarting audio.



\---



\# 39. Drift Correction



The system should classify drift before correcting it.



Example:



```text

error = +2 ms

```



May require no correction.



```text

error = +15 ms

```



May require a gentle correction.



```text

error = +500 ms

```



May require resynchronization rather than subtle correction.



\---



\# 40. Correction Levels



A conceptual correction hierarchy:



```text

LEVEL 0

No correction



LEVEL 1

Monitor



LEVEL 2

Very small playback-rate adjustment



LEVEL 3

Small position correction



LEVEL 4

Controlled resynchronization



LEVEL 5

Leave/rejoin synchronization state

```



Exact thresholds must be experimentally determined.



\---



\# 41. Small Drift Correction



For small persistent errors, a tiny temporary playback-rate adjustment may be preferable to an audible seek.



Example:



```text

Device is slightly behind.



Instead of:



seek +20 ms



the system may temporarily:



play slightly faster

```



until the device approaches the target.



This is only a candidate strategy.



It must be tested for:



\* audio quality;

\* platform behavior;

\* pitch artifacts;

\* stability;

\* correction time.



\---



\# 42. Large Drift Correction



Large synchronization errors should not necessarily be corrected using tiny rate adjustments.



Example:



```text

error = 800 ms

```



Trying to remove this using a tiny rate change could take too long.



The system may instead:



```text

pause briefly

seek to target

resume on a future synchronized timestamp

```



The exact behavior must be validated experimentally.



\---



\# 43. Correction Stability



The correction system must avoid oscillation.



Bad:



```text

behind

→ speed up too much

→ ahead

→ slow down too much

→ behind

→ repeat

```



The correction controller should use:



\* measured error;

\* error trend;

\* correction history;

\* confidence;

\* maximum correction rate.



\---



\# 44. Correction Deadband



A deadband may be used.



Example:



```text

|error| < threshold

&#x20;   → do nothing

```



This prevents constant micro-corrections caused by measurement noise.



The threshold must be determined through testing.



\---



\# 45. Correction Rate Limit



The system should limit how aggressively it changes playback.



Conceptually:



```text

maximumRateAdjustment

maximumSeekCorrection

maximumCorrectionFrequency

```



These values must not be guessed permanently.



They should be configurable during experiments.



\---



\# 46. Synchronization Confidence



Each participant should have a synchronization confidence state.



Example:



```text

HIGH

MEDIUM

LOW

UNKNOWN

```



Confidence may consider:



```text

measurement count

RTT stability

offset stability

drift stability

audio timing validity

network quality

```



This is useful for diagnostics and recovery.



\---



\# 47. Network Degradation



A network can become temporarily worse without completely disconnecting.



Example:



```text

RTT:

8 ms

9 ms

10 ms

70 ms

65 ms

12 ms

```



The system should detect degradation.



However, playback should not necessarily stop immediately.



If local audio is sufficiently buffered, playback can continue while synchronization telemetry attempts recovery.



\---



\# 48. Temporary Disconnection



If a participant temporarily loses communication:



```text

PLAYING

&#x20;  ↓

NETWORK DEGRADED

&#x20;  ↓

TEMPORARY DISCONNECT

```



The participant may continue locally for a limited period if it has enough information to maintain playback.



When connectivity returns:



```text

reconnect

&#x20;↓

re-estimate timing

&#x20;↓

compare playback position

&#x20;↓

correct if necessary

```



\---



\# 49. Prolonged Disconnection



If the participant has been disconnected too long, local timing confidence may become insufficient.



The device should transition to:



```text

RESYNC\_REQUIRED

```



rather than pretending it remains synchronized indefinitely.



\---



\# 50. Host Disconnect



The MVP does not require seamless host migration.



If the host disappears:



```text

HOST LOST

```



participants should enter a controlled recovery state.



Possible MVP behavior:



```text

stop / pause

show recovery state

allow user to recreate room

```



Automatic host migration remains a future feature.



\---



\# 51. Audio Route Changes



Changing audio output may alter effective latency.



Example:



```text

Phone speaker

&#x20;     ↓

Bluetooth headphones

```



or:



```text

Bluetooth

&#x20;     ↓

phone speaker

```



The participant should notify the synchronization system.



Depending on the magnitude of the timing change, the system may require recalibration.



\---



\# 52. Bluetooth



Bluetooth audio must not be assumed to have the same latency characteristics as the phone's internal speaker.



Different Bluetooth devices and codecs can introduce different buffering and latency.



Therefore Bluetooth output should initially be treated as:



```text

SUPPORTED ONLY IF VALIDATED

```



rather than:



```text

guaranteed synchronized output

```



The architecture must measure actual behavior.



\---



\# 53. Backgrounding



Mobile operating systems can alter application execution when an app leaves the foreground.



Therefore:



```text

Flutter screen hidden

```



must not automatically mean:



```text

room ended

```



but the synchronization system must account for platform lifecycle constraints.



Background playback behavior is platform-specific and must be validated independently.



\---



\# 54. Audio Interruptions



Examples:



```text

incoming call

alarm

system audio interruption

another app taking audio focus

headphone disconnect

Bluetooth route change

```



These events can invalidate synchronization assumptions.



The audio subsystem must report interruptions to the synchronization coordinator.



\---



\# 55. Recalibration Triggers



Potential recalibration triggers include:



```text

initial join

large network change

audio route change

large drift

long interruption

resume after suspension

large timing uncertainty

loss of timing reference

```



Not every trigger necessarily requires a full room restart.



The system should distinguish:



```text

light correction

partial recalibration

full recalibration

```



\---



\# 56. Synchronization State Machine



Each participant should conceptually follow:



```text

UNSYNCHRONIZED

&#x20;     ↓

MEASURING

&#x20;     ↓

CALIBRATED

&#x20;     ↓

PREPARED

&#x20;     ↓

SCHEDULED

&#x20;     ↓

PLAYING

&#x20;     ↓

MONITORING

&#x20;     │

&#x20;     ├───────────────┐

&#x20;     │               │

&#x20;     ▼               ▼

CORRECTING       DEGRADED

&#x20;     │               │

&#x20;     └───────┬───────┘

&#x20;             ▼

&#x20;          PLAYING

```



Failure:



```text

PLAYING

&#x20;  ↓

RESYNC\_REQUIRED

&#x20;  ↓

MEASURING

```



\---



\# 57. Synchronization Coordinator



The central synchronization coordinator should own:



```text

current calibration

shared timeline mapping

target playback times

drift state

correction state

synchronization confidence

```



It should not own:



```text

Flutter widgets

network socket implementation

audio driver implementation

file storage

```



\---



\# 58. Clock Abstraction



The synchronization code must use an abstract clock interface.



Conceptually:



```text

Clock

├── now()

├── nowNanos()

└── resolution()

```



The implementation differs by platform.



This allows synchronization algorithms to be tested using a fake clock.



\---



\# 59. Fake Clock



Testing must support deterministic clock simulation.



Example:



```text

FakeClock A

FakeClock B

```



where:



```text

A starts at 0

B starts at +12 ms

B drifts +20 ppm

```



The synchronization algorithm can then be tested without physical phones.



\---



\# 60. Simulated Network



Synchronization tests should also simulate:



```text

fixed latency

variable latency

packet delay

packet loss

reordering

temporary outage

```



Example:



```text

Base latency: 8 ms

Jitter: ±3 ms

Occasional spike: 50 ms

```



This allows the synchronization algorithm to be stress-tested before hardware testing.



\---



\# 61. Physical Testing



Simulation is necessary but insufficient.



SoundMesh must eventually be tested on real devices.



Minimum matrix:



```text

Android ↔ Android

Android ↔ iOS

iOS ↔ iOS

```



with devices that differ in:



\* manufacturer;

\* model;

\* OS version;

\* speaker hardware;

\* CPU performance;

\* network hardware.



\---



\# 62. Two-Device First



The first synchronization experiment should use two devices.



Success condition:



```text

Device A

Device B

```



play the same audio with a consistently small measured playback-position difference.



Only after this works should the system expand to:



```text

3 devices

```



then:



```text

5 devices

```



then larger groups.



\---



\# 63. Group Scaling



Adding participants increases synchronization complexity.



For:



```text

2 devices

```



there is one pair.



For:



```text

5 devices

```



there are:



```text

10 device pairs

```



For:



```text

10 devices

```



there are:



```text

45 device pairs

```



The architecture should therefore avoid requiring every participant to directly synchronize with every other participant unless measurement demonstrates that this is necessary.



A host/reference architecture is preferred initially.



\---



\# 64. Synchronization Topology



Preferred initial topology:



```text

&#x20;             HOST

&#x20;            / |  \\

&#x20;           /  |   \\

&#x20;          A   B    C

```



rather than:



```text

&#x20;       A ─── B

&#x20;      / \\   / \\

&#x20;     C ─── D ─── E

```



The host can provide:



\* common session timeline;

\* common playback commands;

\* centralized participant state;

\* simpler diagnostics.



Peer-to-peer synchronization may be investigated later.



\---



\# 65. Host Timing Model



The host should maintain:



```text

sessionTime

```



which is conceptually related to its monotonic clock.



The exact implementation should avoid relying on wall-clock time.



Example:



```text

host monotonic time

&#x20;       ↓

session timeline

```



\---



\# 66. Participant Timeline Mapping



Each participant maintains a mapping:



```text

participantClock

&#x20;       ↓

shared session time

```



Conceptually:



```text

sharedTime ≈ localTime + offset

```



with an evolving drift model.



The implementation may use a richer model if measurements justify it.



\---



\# 67. Scheduling Conversion



Suppose:



```text

target shared time = T

```



and:



```text

participant offset = O

```



Then the participant calculates the corresponding local target.



Conceptually:



```text

localTarget ≈ T - O

```



The exact sign depends on the chosen clock convention and must be encoded consistently throughout the implementation.



No component may independently invent its own sign convention.



\---



\# 68. Timing Units



The synchronization core should use a high-resolution integer representation internally where practical.



Recommended conceptual representation:



```text

nanoseconds

```



or another sufficiently precise monotonic integer unit.



Floating-point seconds may be used at API boundaries when appropriate, but the timing-critical core should avoid unnecessary precision loss.



\---



\# 69. Audio Position Units



Audio positions should be represented using a suitable audio-domain unit.



Depending on the native implementation:



```text

audio frames

samples

high-resolution duration

```



may be appropriate.



The synchronization layer must not assume that:



```text

1 millisecond = exactly the same physical audio timing behavior

```



across every device.



\---



\# 70. Sample Rate



Audio sample rate affects the relationship between:



```text

audio sample position

```



and:



```text

elapsed time

```



Example:



```text

48,000 frames/sec

```



means:



```text

48 frames ≈ 1 ms

```



The exact audio format must be defined in `audio.md`.



Synchronization code must obtain actual playback timing from the audio layer rather than assuming a fixed format.



\---



\# 71. Audio Clock vs System Clock



The system clock and audio sample clock are conceptually different.



```text

System clock

&#x20;    │

&#x20;    │ relationship

&#x20;    ▼

Audio clock

```



A device's audio clock can progress at a slightly different rate from its general-purpose timing source.



Therefore the synchronization architecture must eventually account for the audio clock itself.



This is especially important for long playback sessions.



\---



\# 72. Audio Clock Drift



Even if:



```text

System clock drift ≈ 0

```



the effective audio sample clock may still differ between devices.



Therefore long-term synchronization testing must measure actual audio playback position rather than relying exclusively on network timestamp estimates.



\---



\# 73. Measurement Layers



SoundMesh should distinguish three timing layers:



```text

LAYER 1

Network timing



LAYER 2

System/platform timing



LAYER 3

Actual audio playback timing

```



The final user experience depends on Layer 3.



\---



\# 74. Synchronization Error Budget



Eventually SoundMesh should define an error budget.



Conceptually:



```text

Total perceived timing error

=

network estimation error

\+

clock estimation error

\+

scheduler error

\+

audio pipeline error

\+

measurement error

```



This is not necessarily a simple arithmetic sum in the final system.



The purpose is to identify where timing error originates.



\---



\# 75. Acceptance Targets



Initial engineering targets should be treated as \*\*targets to validate\*\*, not platform guarantees.



Proposed experimental targets:



\### Startup



Target:



```text

≤ 20 ms group playback spread

```



Stretch target:



```text

≤ 10 ms

```



\### Steady-state



Target:



```text

≤ 20 ms group spread

```



during normal supported conditions.



Stretch target:



```text

≤ 10 ms

```



\### Recovery



After a temporary disruption:



```text

return to target synchronization

without unnecessary audible interruption

```



The actual thresholds may be changed after physical testing.



\---



\# 76. Why 20 ms Is an Engineering Target



These thresholds are not claims that humans universally perceive 20 ms as identical or different.



They are engineering targets intended to force measurable quality.



The actual perceptual result depends on:



\* room acoustics;

\* speaker placement;

\* frequency content;

\* device speakers;

\* listener position;

\* volume;

\* reflections;

\* synchronization direction.



Therefore the project must combine:



```text

objective measurements

\+

subjective listening tests

```



\---



\# 77. Audible Testing



Physical tests should include:



\### Test A — Click track



Play sharp transient sounds.



This makes timing differences easier to hear.



\### Test B — Percussion



Use rhythmically precise material.



\### Test C — Voice



Check whether doubled/echo-like artifacts appear.



\### Test D — Music



Evaluate realistic listening quality.



\---



\# 78. Objective Measurement



Where possible, record the devices' outputs.



A suitable test setup can compare waveforms.



Conceptually:



```text

Device A recording

&#x20;      │

&#x20;      ▼

waveform



Device B recording

&#x20;      │

&#x20;      ▼

waveform

&#x20;      │

&#x20;      ▼

cross-correlation

&#x20;      │

&#x20;      ▼

estimated delay

```



This can provide a stronger measurement than human judgment alone.



\---



\# 79. Cross-Correlation



For test recordings, waveform cross-correlation can estimate relative delay.



Conceptually:



```text

signal A

&#x20;  ↕

signal B

&#x20;  ↓

correlation peak

&#x20;  ↓

relative timing estimate

```



This should be used as a validation tool, not necessarily as part of the production app.



\---



\# 80. Test Environments



Synchronization should be tested under:



```text

same Wi-Fi router

different Wi-Fi signal strengths

busy Wi-Fi

phone hotspot

different device combinations

screen on

screen locked where supported

battery saver

backgrounding

audio route changes

network congestion

participant join/leave

```



\---



\# 81. Network Stress Tests



At minimum:



```text

low latency / low jitter

high latency / low jitter

low latency / high jitter

temporary latency spikes

packet loss

temporary disconnect

reconnect

```



The system must be evaluated against all of these.



\---



\# 82. Long-Running Test



A critical test is:



```text

30 seconds

5 minutes

15 minutes

30 minutes

60 minutes

```



with multiple devices playing continuously.



This reveals drift that startup-only tests cannot detect.



\---



\# 83. Drift Test



For each device record:



```text

elapsed playback time

measured group error

```



Then plot:



```text

time → synchronization error

```



A healthy system should show bounded error rather than continuously increasing error.



\---



\# 84. Calibration Test



Repeat calibration many times.



Example:



```text

Calibration 1

Calibration 2

...

Calibration 100

```



Record:



```text

offset

RTT

uncertainty

calibration duration

startup error

```



This reveals whether calibration is stable or highly variable.



\---



\# 85. Calibration Failure



Calibration should fail when measurements are insufficiently reliable.



Potential reasons:



```text

network unavailable

RTT extremely unstable

insufficient samples

permission failure

native timing unavailable

audio timing unavailable

device lifecycle interruption

```



The user should receive a useful explanation rather than:



```text

Unknown error

```



\---



\# 86. Synchronization Failure Modes



\## Failure 1 — Clock measurement unavailable



Result:



```text

CALIBRATION\_FAILED

```



\---



\## Failure 2 — Network unstable



Result:



```text

CALIBRATION\_DEGRADED

```



and potentially retry.



\---



\## Failure 3 — Audio cannot schedule



Result:



```text

AUDIO\_SYNC\_UNAVAILABLE

```



\---



\## Failure 4 — Drift exceeds correction range



Result:



```text

RESYNC\_REQUIRED

```



\---



\## Failure 5 — Participant disappears



Result:



```text

PARTICIPANT\_DEGRADED

```



or:



```text

PARTICIPANT\_DISCONNECTED

```



\---



\# 87. Synchronization Telemetry



During development, record:



```text

timestamp

deviceId

sessionId

generation

clockOffset

rtt

timingUncertainty

playbackPosition

expectedPosition

syncError

driftRate

correctionAmount

networkState

audioState

```



Telemetry must be structured so experiments can be analyzed later.



\---



\# 88. Privacy



Synchronization telemetry should not contain unnecessary personal information.



It should not require:



\* user names;

\* contacts;

\* location;

\* cloud accounts.



Device IDs should be temporary or locally generated where possible.



\---



\# 89. Flutter Synchronization Boundary



Flutter should interact with synchronization through high-level commands.



Example:



```text

startCalibration()

getSyncStatus()

preparePlayback(...)

schedulePlayback(...)

pause(...)

resume(...)

seek(...)

requestResync()

```



Flutter should not directly calculate:



```text

clock offset

```



or:



```text

audio sample timing

```



unless a future architecture decision explicitly changes this boundary.



\---



\# 90. Native Timing Boundary



Native code should expose:



```text

monotonic timestamp

audio timestamp

playback position

audio timing validity

```



to the synchronization subsystem.



The native implementation should hide platform-specific APIs.



\---



\# 91. Platform Timing Abstraction



Conceptually:



```text

PlatformClock

├── nowMonotonic()

├── nowNanos()

└── capabilities()

```



and:



```text

PlatformAudioClock

├── currentPlaybackPosition()

├── currentHostTime()

├── sampleRate()

└── timingValidity()

```



The exact interface is implementation-specific.



\---



\# 92. Flutter ↔ Native Communication



The Flutter/native synchronization boundary should use a typed interface.



Flutter currently supports custom platform channels and Pigeon-generated type-safe interfaces for communication with Kotlin/Swift native code.



For synchronization-critical APIs, type-safe generated interfaces are preferred over large collections of loosely typed string-based method calls.



\---



\# 93. Do Not Send High-Frequency Timing Through Flutter



The system should not continuously send every audio timing event through a Flutter platform channel.



Bad:



```text

native audio callback

&#x20;   ↓

Flutter

&#x20;   ↓

Dart

&#x20;   ↓

native

```



for every audio frame/callback.



Instead:



```text

Native audio engine

&#x20;      │

&#x20;      ▼

Native timing state

&#x20;      │

&#x20;      ▼

periodic synchronization metrics

&#x20;      │

&#x20;      ▼

Flutter/application layer

```



Flutter receives meaningful state rather than realtime audio callbacks.



\---



\# 94. Synchronization Threading



The timing-critical synchronization implementation must not block the UI thread.



Similarly:



```text

audio realtime callback

```



must not perform expensive synchronization calculations.



The architecture should separate:



```text

audio realtime execution

```



from:



```text

synchronization control logic

```



\---



\# 95. Determinism



Synchronization behavior should be deterministic given equivalent inputs where practical.



For example:



```text

same timestamps

same RTT samples

same configuration

```



should produce approximately the same:



```text

offset estimate

confidence

target scheduling decision

```



This improves debugging and testing.



\---



\# 96. No Magic Numbers



Avoid code such as:



```text

if error > 17:

```



without explaining:



\* what 17 represents;

\* why it exists;

\* which unit it uses;

\* how it was chosen;

\* whether it is configurable;

\* which experiment supports it.



Synchronization constants must be documented.



\---



\# 97. Configuration



During development, synchronization parameters should be configurable.



Examples:



```text

calibrationSampleCount

maxCalibrationRTT

targetSchedulingMargin

driftMeasurementInterval

correctionDeadband

maxRateAdjustment

resyncThreshold

```



These should eventually move toward validated production defaults.



\---



\# 98. Production Defaults



Once experiments establish reliable values, defaults should be centralized.



Do not scatter values across:



```text

Dart

Kotlin

Swift

```



without a documented reason.



\---



\# 99. Protocol and Timing Versioning



Timing behavior may change between application versions.



Therefore synchronization protocol messages should include:



```text

protocolVersion

```



and potentially:



```text

syncAlgorithmVersion

```



if algorithm compatibility becomes necessary.



\---



\# 100. Synchronization Algorithm Evolution



The initial implementation should prioritize:



```text

simple

measurable

debuggable

```



over:



```text

mathematically sophisticated

```



A simple algorithm that reliably achieves the target is preferable to a complex algorithm nobody can debug.



\---



\# 101. Initial Algorithm Direction



The initial experimental implementation should investigate:



```text

1\. Monotonic clocks

2\. Multi-round timestamp exchange

3\. RTT measurement

4\. Offset estimation

5\. Outlier rejection

6\. Future playback scheduling

7\. Native audio timing measurement

8\. Periodic playback-position reports

9\. Drift estimation

10\. Small corrective adjustments

11\. Full resynchronization for large errors

```



This is an implementation direction, not a final mathematical specification.



\---



\# 102. Proposed Calibration Procedure



Initial experiment:



```text

Participant connects

&#x20;       │

&#x20;       ▼

Clock capability check

&#x20;       │

&#x20;       ▼

Perform N timestamp exchanges

&#x20;       │

&#x20;       ▼

Record:

\- RTT

\- offset

&#x20;       │

&#x20;       ▼

Reject obvious outliers

&#x20;       │

&#x20;       ▼

Estimate stable offset

&#x20;       │

&#x20;       ▼

Estimate uncertainty

&#x20;       │

&#x20;       ▼

Return calibration result

```



The value of `N` must be experimentally determined.



\---



\# 103. Proposed Startup Procedure



```text

1\. Host selects audio.

2\. Host creates playback generation.

3\. Participants verify asset availability.

4\. Missing assets are transferred.

5\. Participants prepare native audio.

6\. Participants report READY.

7\. Synchronization calibration runs.

8\. Host chooses future shared target.

9\. Participants convert target to local timing.

10\. Native audio playback is scheduled.

11\. Playback begins.

12\. Startup synchronization is measured.

13\. Monitoring begins.

```



\---



\# 104. Proposed Monitoring Procedure



During playback:



```text

periodically:



1\. Obtain local audio playback position.

2\. Convert to shared timeline.

3\. Calculate synchronization error.

4\. Update drift estimate.

5\. Update confidence.

6\. Determine whether correction is required.

7\. Apply correction if appropriate.

8\. Record telemetry.

```



The monitoring interval must be experimentally selected.



\---



\# 105. Proposed Recovery Procedure



If synchronization quality degrades:



```text

NORMAL

&#x20; ↓

DEGRADED

&#x20; ↓

attempt correction

&#x20; ↓

still degraded?

&#x20; ├── no → NORMAL

&#x20; │

&#x20; └── yes

&#x20;       ↓

&#x20;    RESYNC

&#x20;       ↓

&#x20;    CALIBRATE

&#x20;       ↓

&#x20;    SCHEDULE

&#x20;       ↓

&#x20;    PLAYING

```



\---



\# 106. Recovery Must Be Bounded



The application must not remain indefinitely in:



```text

RECOVERING

```



without communicating meaningful state.



Recovery should have:



```text

attempt count

timeout

failure state

user-visible explanation

```



where appropriate.



\---



\# 107. Synchronization Invariants



The following are architectural invariants.



\## SYNC-INV-001



Wall-clock time must not be the authoritative elapsed-time source.



\## SYNC-INV-002



All synchronization calculations must specify their clock domain.



\## SYNC-INV-003



Every timestamp must have an explicit unit.



\## SYNC-INV-004



A network message's arrival time must not be treated as playback time.



\## SYNC-INV-005



Immediate playback commands must not be used as the primary synchronization mechanism.



\## SYNC-INV-006



Synchronization must use future scheduling where supported.



\## SYNC-INV-007



Audio playback position must ultimately come from the native audio layer.



\## SYNC-INV-008



Clock offset and network latency must remain separate concepts.



\## SYNC-INV-009



Calibration must produce an uncertainty/confidence estimate.



\## SYNC-INV-010



Drift must be monitored after startup.



\## SYNC-INV-011



Stale playback commands must not override newer generations.



\## SYNC-INV-012



Flutter UI timing must never be treated as the authoritative audio clock.



\## SYNC-INV-013



Synchronization constants must not be undocumented magic numbers.



\## SYNC-INV-014



A synchronization claim must be supported by measurements.



\## SYNC-INV-015



The system must distinguish measured behavior from theoretical assumptions.



\---



\# 108. Acceptance Criteria



A synchronization implementation must eventually demonstrate:



\### AC-SYNC-001



Two supported devices can establish timing calibration.



\### AC-SYNC-002



The system can estimate clock relationship using multiple timing measurements.



\### AC-SYNC-003



Both devices can schedule playback for a future target.



\### AC-SYNC-004



Startup synchronization can be measured.



\### AC-SYNC-005



Playback drift can be measured.



\### AC-SYNC-006



Small drift can be corrected without obvious audible artifacts.



\### AC-SYNC-007



Large drift can trigger controlled resynchronization.



\### AC-SYNC-008



Temporary network degradation does not automatically destroy playback.



\### AC-SYNC-009



A disconnected participant does not automatically stop remaining participants.



\### AC-SYNC-010



Late participants can synchronize to an already-playing session.



\### AC-SYNC-011



The system can expose synchronization diagnostics.



\### AC-SYNC-012



Synchronization behavior is reproducible enough to debug.



\---



\# 109. Experimental Targets



These values are \*\*engineering targets, not guarantees\*\*.



Initial target:



```text

startup group spread ≤ 20 ms

```



Stretch target:



```text

startup group spread ≤ 10 ms

```



Steady-state target:



```text

group spread ≤ 20 ms

```



Stretch target:



```text

group spread ≤ 10 ms

```



These values must be validated using actual hardware and may be revised.



\---



\# 110. What Must Be Measured



The following must eventually have real measurements:



```text

Calibration duration

RTT distribution

Clock-offset stability

Timing uncertainty

Startup spread

Steady-state spread

Drift rate

Correction time

Correction artifacts

Recovery time

Audio-route impact

Device-to-device differences

Maximum reliable device count

```



\---



\# 111. What Must Not Be Assumed



Do not assume:



```text

all phones have identical clocks

all phones have identical audio latency

Wi-Fi latency is constant

TCP arrival time equals playback time

Bluetooth latency is negligible

Android devices behave identically

iOS devices behave identically

Flutter timers are audio clocks

network synchronization equals audible synchronization

```



\---



\# 112. Unknowns Requiring Experiments



The following remain `UNDECIDED`:



```text

SYNC-UNK-001

Best number of calibration samples.



SYNC-UNK-002

Best outlier rejection strategy.



SYNC-UNK-003

Best offset estimator.



SYNC-UNK-004

Actual clock-rate differences across devices.



SYNC-UNK-005

Best scheduling margin.



SYNC-UNK-006

Best drift monitoring interval.



SYNC-UNK-007

Best correction strategy.



SYNC-UNK-008

Whether playback-rate correction is sufficiently transparent.



SYNC-UNK-009

Whether position correction introduces audible artifacts.



SYNC-UNK-010

Best resynchronization threshold.



SYNC-UNK-011

Actual Bluetooth timing behavior.



SYNC-UNK-012

Actual hotspot timing behavior.



SYNC-UNK-013

Maximum acceptable group size.



SYNC-UNK-014

Cross-platform synchronization performance.



SYNC-UNK-015

Background execution limitations affecting synchronization.



SYNC-UNK-016

Best synchronization telemetry frequency.



SYNC-UNK-017

Whether peer-to-peer timing improves results enough to justify complexity.



SYNC-UNK-018

Whether a separate UDP timing channel provides measurable benefit.



SYNC-UNK-019

Whether audio-clock drift requires platform-specific correction.



SYNC-UNK-020

Final production synchronization algorithm.

```



\---



\# 113. Required Experiment Sequence



Synchronization development should follow this order.



\## EXP-SYNC-001 — Clock experiment



Verify that native monotonic timing can be exposed consistently through the platform abstraction.



\---



\## EXP-SYNC-002 — Timestamp experiment



Implement multi-round timestamp exchange.



Measure:



```text

RTT

offset stability

jitter

```



\---



\## EXP-SYNC-003 — Scheduled playback experiment



On two devices:



```text

schedule playback

```



rather than:



```text

play immediately

```



Measure startup spread.



\---



\## EXP-SYNC-004 — Audio timing experiment



Determine whether native playback timing can provide sufficiently accurate playback-position information.



\---



\## EXP-SYNC-005 — Drift experiment



Run synchronized playback for at least:



```text

5 minutes

```



and measure error over time.



\---



\## EXP-SYNC-006 — Correction experiment



Introduce known timing offsets and determine whether correction can remove them without obvious artifacts.



\---



\## EXP-SYNC-007 — Network stress experiment



Test:



```text

stable Wi-Fi

busy Wi-Fi

high jitter

temporary packet delays

temporary disconnect

```



\---



\## EXP-SYNC-008 — Heterogeneous device experiment



Test different:



```text

Android devices

iOS devices

Android ↔ iOS

```



\---



\## EXP-SYNC-009 — Scaling experiment



Test:



```text

2

3

5

10

```



devices where hardware availability permits.



\---



\# 114. Research vs Measurement



The team must distinguish:



\### Platform fact



Something documented by Android/iOS/Flutter.



\### Engineering hypothesis



Something we believe should work.



\### Experimental result



Something we actually measured.



Example:



```text

FACT:

Native platforms expose timing APIs.



HYPOTHESIS:

Those timing sources can support SoundMesh synchronization.



MEASUREMENT:

Two physical devices achieved X ms startup spread.

```



Only the third supports a claim about SoundMesh's actual performance.



\---



\# 115. Documentation Rule



Whenever a synchronization experiment changes the architecture:



1\. record the experiment;

2\. record the measured result;

3\. explain the implication;

4\. update this document;

5\. record a significant architectural decision in `decisions.md`.



Do not silently modify the synchronization model based on undocumented experiments.



\---



\# 116. Relationship to Other Documents



This document owns:



```text

timing

clock model

calibration

offset estimation

drift

scheduling

correction

synchronization recovery

sync experiments

```



It does not own:



```text

UI design

audio codecs

network packet schemas

room UX

project roadmap

AI coding rules

```



Those belong to:



```text

ui-ux.md

audio.md

networking.md

blueprint.md

roadmap.md

AI/rules.md

```



\---



\# 117. Definition of Done



The synchronization architecture is sufficiently defined for implementation when:



\* timing terminology is standardized;

\* monotonic timing is used conceptually;

\* clock domains are explicit;

\* network timing is separated from audio timing;

\* multi-round calibration is defined;

\* clock-offset estimation is defined;

\* uncertainty is represented;

\* future playback scheduling is defined;

\* playback monitoring is defined;

\* drift is defined;

\* correction levels are defined;

\* late joining is defined;

\* pause/resume/seek behavior is defined;

\* failure and recovery states are defined;

\* physical testing is defined;

\* objective metrics are defined;

\* initial acceptance targets exist;

\* unknowns are explicitly recorded;

\* no critical synchronization assumption is hidden inside UI code.



\---



\# 118. Final Synchronization Principle



SoundMesh does not attempt to make multiple phones share a magical universal clock.



Instead:



```text

Each phone has its own timing system.

&#x20;             │

&#x20;             ▼

SoundMesh measures relationships between them.

&#x20;             │

&#x20;             ▼

SoundMesh creates a shared logical timeline.

&#x20;             │

&#x20;             ▼

Each device schedules its own native audio.

&#x20;             │

&#x20;             ▼

SoundMesh measures actual playback behavior.

&#x20;             │

&#x20;             ▼

SoundMesh corrects drift when necessary.

```



The fundamental loop is:



```text

&#x20;       ┌─────────────────────┐

&#x20;       │                     │

&#x20;       ▼                     │

&#x20;     MEASURE                 │

&#x20;       │                     │

&#x20;       ▼                     │

&#x20;     ESTIMATE                │

&#x20;       │                     │

&#x20;       ▼                     │

&#x20;    SCHEDULE                 │

&#x20;       │                     │

&#x20;       ▼                     │

&#x20;     PLAY                   │

&#x20;       │                     │

&#x20;       ▼                     │

&#x20;     MONITOR                │

&#x20;       │                     │

&#x20;       ▼                     │

&#x20;     CORRECT ────────────────┘

```



The product experience should be:



> \*\*"The phones just play together."\*\*



The engineering reality is:



> \*\*Every device continuously maintains an estimate of where it should be in a shared audio timeline, then uses native audio timing to stay there.\*\*



That is the core synchronization problem SoundMesh exists to solve.



