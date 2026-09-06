\# SoundMesh Synchronization API Contract



\*\*File:\*\* `DOCS/interfaces/sync-api.md`

\*\*Status:\*\* EXPERIMENTAL

\*\*Owner:\*\* Faraz

\*\*Primary Consumers:\*\* Core API, Playback API, Device API, Networking System, Audio System, Integration Tests



\---



\# 1. Purpose



The Synchronization API defines the authoritative interface for coordinating playback timing across multiple SoundMesh devices.



Its purpose is to provide a stable boundary between:



\* device timing

\* network timing measurements

\* clock models

\* latency estimation

\* synchronization calibration

\* shared playback timelines

\* drift monitoring

\* correction

\* recovery

\* playback scheduling



The Synchronization API exists so that other subsystems do not need to know the internal mathematics or implementation details of SoundMesh synchronization.



The core principle is:



> \*\*Consumers request synchronization information and actions through the Sync API. They must not independently implement synchronization logic.\*\*



\---



\# 2. Scope



The Synchronization API owns:



\* synchronization state

\* clock synchronization

\* timing measurements

\* clock offset estimation

\* uncertainty estimation

\* latency estimation

\* calibration

\* shared timeline coordination

\* drift estimation

\* synchronization quality

\* resynchronization

\* synchronization recovery

\* synchronization-related errors



The Synchronization API does \*\*not\*\* own:



\* room membership

\* network transport implementation

\* audio decoding

\* audio distribution

\* audio playback

\* UI rendering

\* device identity

\* QR-code joining



Those responsibilities belong to their respective systems.



\---



\# 3. Synchronization Objective



SoundMesh does not require mathematical identity between devices.



The objective is:



> \*\*Perceptually coherent synchronized playback across participating devices.\*\*



The system should minimize the perceived timing difference between devices.



The current project-level target is:



```text

Target:

≤ 20 ms group playback spread



Preferred:

≤ 10 ms

```



These are engineering targets, not guarantees.



Final performance must be measured on physical devices.



\---



\# 4. Synchronization Mental Model



SoundMesh synchronization can be viewed as:



```text

Network Timing Measurements

&#x20;           │

&#x20;           ▼

&#x20;     Clock Estimation

&#x20;           │

&#x20;           ▼

&#x20;     Offset Estimation

&#x20;           │

&#x20;           ▼

&#x20;     Latency / Uncertainty

&#x20;           │

&#x20;           ▼

&#x20;       Calibration

&#x20;           │

&#x20;           ▼

&#x20;    Shared Timeline

&#x20;           │

&#x20;           ▼

&#x20;    Playback Scheduling

&#x20;           │

&#x20;           ▼

&#x20;     Drift Monitoring

&#x20;           │

&#x20;           ▼

&#x20;    Correction / Recovery

```



Each stage must have a defined responsibility.



\---



\# 5. Synchronization Components



The conceptual synchronization system contains:



```text

Sync System

├── ClockSource

├── ClockModel

├── TimestampExchange

├── LatencyEstimator

├── OffsetEstimator

├── UncertaintyEstimator

├── CalibrationEngine

├── SharedTimeline

├── PlaybackScheduler

├── PlaybackMonitor

├── DriftEstimator

├── CorrectionController

└── RecoverySynchronizer

```



These are architectural concepts.



They are not necessarily individual classes or files.



AI agents must not create one-to-one implementations of these names unless required by the implementation design.



\---



\# 6. Monotonic Time



Synchronization MUST use monotonic timing sources.



Wall-clock time must not be used as the primary synchronization clock.



Wall-clock time can change because of:



\* NTP adjustments

\* manual clock changes

\* timezone changes

\* daylight-saving behavior

\* operating-system corrections



Synchronization requires elapsed-time semantics.



Platform-specific timing implementations are governed by `architecture.md`.



\---



\# 7. Clock Model



Each device has a local monotonic clock.



Conceptually:



```text

Device A Clock

Device B Clock

Device C Clock

&#x20;      │

&#x20;      ▼

Shared Logical Timeline

```



The system does not need to force physical clocks to become identical.



Instead, it maintains a model of how each device's local clock relates to the shared logical timeline.



\---



\# 8. Timestamp Exchange



The initial synchronization protocol uses a four-timestamp exchange.



Conceptually:



```text

Participant                     Host

&#x20;    │                            │

&#x20;    │────── t1 ────────────────►│

&#x20;    │                            │

&#x20;    │                            │ t2

&#x20;    │                            │

&#x20;    │◄───── t3 ─────────────────│

&#x20;    │                            │

&#x20;    │ t4                         │

```



Where:



```text

t1 = participant send time

t2 = host receive time

t3 = host send time

t4 = participant receive time

```



The initial offset estimate under the symmetric-delay assumption is:



```text

offset ≈ ((t2 - t1) + (t3 - t4)) / 2

```



Round-trip time is:



```text

RTT = (t4 - t1) - (t3 - t2)

```



These formulas are part of the initial engineering model.



They are not proof that real network delay is perfectly symmetric.



\---



\# 9. Measurement Uncertainty



A timing measurement must have associated uncertainty.



A single timestamp exchange must not automatically be treated as exact.



Potential sources of uncertainty include:



\* Wi-Fi contention

\* operating-system scheduling

\* network queueing

\* radio power management

\* packet processing

\* device load

\* platform timing behavior



The exact uncertainty model is:



\*\*UNDECIDED\*\*



The system must preserve uncertainty rather than pretending every measurement is equally reliable.



\---



\# 10. Latency Estimation



The Sync system may estimate relevant latency characteristics.



Potential measurements include:



```text

Network RTT

Estimated one-way network delay

Playback scheduling latency

Audio pipeline latency

Output latency

```



These values are distinct.



Network RTT must not automatically be treated as audio-output latency.



The exact latency model is:



\*\*UNDECIDED\*\*



\---



\# 11. Clock Offset



Clock offset describes the estimated relationship between a device's clock and the reference/shared timing model.



Conceptual:



```text

Device Clock

&#x20;    │

&#x20;    ▼

Clock Offset

&#x20;    │

&#x20;    ▼

Shared Timeline

```



The exact representation may use:



```text

milliseconds

microseconds

nanoseconds

```



The public API precision is:



\*\*UNDECIDED\*\*



Internal timing-critical calculations should preserve sufficient precision.



\---



\# 12. Clock Drift



Clock offset alone is insufficient for long playback sessions.



Two devices may begin closely aligned and gradually diverge.



Conceptually:



```text

Time ─────────────────────────►



Device A ──────────────────────

Device B ─────────────────────╱

&#x20;                             ↑

&#x20;                           drift

```



The synchronization system should therefore model drift.



Conceptually:



```text

error(t) = offset + driftRate × elapsedTime

```



The exact estimator and units are:



\*\*UNDECIDED\*\*



\---



\# 13. Synchronization State



The conceptual synchronization states are:



```text

UNKNOWN

CALIBRATING

SYNCHRONIZED

DEGRADED

FAILED

```



These states are:



\*\*EXPERIMENTAL\*\*



The meaning of each state must remain consistent throughout the system.



\---



\# 14. State Semantics



\### `UNKNOWN`



Insufficient information exists to establish synchronization quality.



\### `CALIBRATING`



The system is actively collecting measurements or establishing timing parameters.



\### `SYNCHRONIZED`



Available evidence indicates that the device is sufficiently aligned with the shared timeline.



\### `DEGRADED`



The system is still functioning but synchronization quality or confidence has fallen.



\### `FAILED`



Synchronization cannot currently provide a sufficiently trustworthy timing model.



Exact thresholds remain:



\*\*UNDECIDED\*\*



\---



\# 15. `getSyncStatus()`



Returns the current synchronization state.



Conceptual result:



```json

{

&#x20; "state": "SYNCHRONIZED",

&#x20; "offsetMs": 4.2,

&#x20; "driftMsPerSecond": 0.3,

&#x20; "confidence": 0.94

}

```



This example is illustrative.



Exact schema:



\*\*UNDECIDED\*\*



Possible fields include:



```text

state

offset

driftRate

uncertainty

confidence

lastMeasurement

generation

```



Only measured or derived values may be reported.



\---



\# 16. Synchronization Confidence



The system may expose a confidence value.



Example:



```text

confidence = 0.94

```



Confidence must represent an actual defined model.



It must not be generated merely for UI presentation.



If no valid confidence model exists:



```text

confidence = UNKNOWN

```



is preferable to a fabricated value.



The exact confidence model is:



\*\*UNDECIDED\*\*



\---



\# 17. Calibration



Calibration establishes the timing relationship necessary for synchronized playback.



Conceptual flow:



```text

Device joins

&#x20;   ↓

Connection established

&#x20;   ↓

Timing measurements

&#x20;   ↓

Clock model

&#x20;   ↓

Latency estimation

&#x20;   ↓

Uncertainty estimation

&#x20;   ↓

Calibration result

```



The exact number of measurements and calibration duration are:



\*\*UNDECIDED\*\*



\---



\# 18. Calibration Result



Conceptual representation:



```text

CalibrationResult

├── state

├── offset

├── driftRate

├── uncertainty

├── confidence

└── timestamp

```



Exact schema:



\*\*UNDECIDED\*\*



A calibration result must identify the timing context in which it was produced.



\---



\# 19. `calibrate()`



Conceptual operation:



```text

calibrate(deviceId)

```



The operation may:



\* collect timing samples

\* estimate clock offset

\* estimate uncertainty

\* update the clock model

\* produce a calibration result



Exact request/result types:



\*\*UNDECIDED\*\*



Calibration must not silently start playback.



\---



\# 20. Shared Timeline



SoundMesh requires a shared logical playback timeline.



The shared timeline provides a common temporal reference for participating devices.



Conceptually:



```text

&#x20;                Shared Timeline

&#x20;                      │

&#x20;         ┌────────────┼────────────┐

&#x20;         ▼            ▼            ▼

&#x20;      Device A      Device B      Device C

&#x20;         │            │            │

&#x20;      Local A      Local B      Local C

&#x20;         │            │            │

&#x20;         └────────────┼────────────┘

&#x20;                      ▼

&#x20;                Synchronized

&#x20;                 Playback

```



The timeline does not require physical clocks to be identical.



\---



\# 21. Shared Timeline Position



A shared playback position may be represented as:



```text

timelinePosition

```



The exact unit and precision:



\*\*UNDECIDED\*\*



The shared timeline must be distinguishable from:



```text

local wall-clock time

local monotonic time

audio file position

network timestamp

```



\---



\# 22. Playback Target Time



The Sync system may produce a future target time for playback.



Conceptually:



```text

T\_target = T\_now + M

```



where:



```text

T\_now = current logical timing point

M = scheduling margin

```



The target should provide enough time for devices to:



\* receive the command

\* prepare execution

\* reach the appropriate local timing point



Exact scheduling margin:



\*\*UNDECIDED\*\*



\---



\# 23. `getPlaybackSchedule()`



Conceptual operation:



```text

getPlaybackSchedule()

```



Possible result:



```text

PlaybackSchedule

├── targetTime

├── targetPosition

├── generation

└── confidence

```



Exact schema:



\*\*UNDECIDED\*\*



Playback consumes this result.



The Sync API does not directly start audio.



\---



\# 24. Synchronization and Playback Boundary



This distinction is mandatory.



\### Sync owns:



```text

clock relationship

offset

drift

latency estimation

uncertainty

calibration

shared timing

correction decisions

```



\### Playback owns:



```text

audio execution

playback state

actual playback position

play/pause/resume/seek/stop

native playback engine

```



Sync may instruct Playback \*\*when\*\* to execute.



Playback determines \*\*how\*\* execution occurs.



\---



\# 25. Drift Monitoring



During playback, synchronization should monitor divergence from the intended timeline.



Conceptual:



```text

Shared Timeline

&#x20;      │

&#x20;      ▼

Expected Position

&#x20;      │

&#x20;      ▼

Actual Device Position

&#x20;      │

&#x20;      ▼

Drift Estimate

```



The exact monitoring frequency is:



\*\*UNDECIDED\*\*



Monitoring must not create excessive CPU, battery, or network overhead.



\---



\# 26. Drift Estimation



Conceptually:



```text

error(t) = offset + driftRate × elapsedTime

```



The drift estimator may use:



\* repeated timing measurements

\* actual playback position

\* clock model

\* native audio timing



The exact estimator is:



\*\*EXPERIMENTAL\*\*



AI agents must not replace it with arbitrary heuristics without documenting the decision.



\---



\# 27. Correction



If a device begins drifting, the system may correct it.



Potential correction strategies include:



```text

Small timing adjustment

Playback rate adjustment

Controlled rescheduling

Timeline correction

Full resynchronization

```



The correction hierarchy is:



\*\*EXPERIMENTAL\*\*



The exact strategy must be validated experimentally.



Corrections should avoid audible artifacts where possible.



\---



\# 28. Correction Limits



Synchronization correction must not create worse perceptual results than the original drift.



Potential constraints include:



```text

Maximum playback-rate adjustment

Maximum correction duration

Maximum correction frequency

Maximum acceptable audible artifact

```



Exact values:



\*\*UNDECIDED\*\*



AI agents must not invent hard-coded thresholds.



\---



\# 29. `requestResync()`



Requests synchronization recovery.



Conceptual:



```text

requestResync(deviceId)

```



Possible flow:



```text

Detect degraded sync

&#x20;       ↓

Request resync

&#x20;       ↓

Re-measure timing

&#x20;       ↓

Update clock model

&#x20;       ↓

Recalculate timeline relationship

&#x20;       ↓

Return to SYNCHRONIZED

```



Exact semantics:



\*\*UNDECIDED\*\*



Resynchronization must not silently restart the entire room unless explicitly defined.



\---



\# 30. Recovery Synchronizer



The Recovery Synchronizer handles synchronization failures or severe degradation.



Potential triggers:



```text

Connection interruption

Large timing error

Excessive drift

Audio route change

Playback interruption

Stale timing model

Host timing failure

```



Exact recovery triggers:



\*\*UNDECIDED\*\*



Recovery behavior must preserve room and playback state unless a defined failure requires otherwise.



\---



\# 31. Synchronization Generation



Synchronization state may be associated with a playback generation.



Example:



```text

Generation 5

&#x20;   ↓

Calibration A

&#x20;   ↓

Playback A



Generation 6

&#x20;   ↓

New timing context

```



Old synchronization results must not automatically apply to an incompatible playback generation.



Exact generation propagation:



\*\*UNDECIDED\*\*



\---



\# 32. Network Dependency



Synchronization requires network timing information during calibration and potentially during monitoring.



However:



> \*\*The Sync API does not own network transport.\*\*



The Networking System provides the transport mechanism.



The Sync System consumes timing-relevant observations.



Conceptually:



```text

Networking

&#x20;   │

&#x20;   ▼

Timestamp Exchange

&#x20;   │

&#x20;   ▼

Sync API

```



The Sync system must not directly create unrelated network connections.



\---



\# 33. Timing Plane vs Control Plane



SoundMesh conceptually separates:



```text

Control Plane

```



from:



```text

Timing Plane

```



Control plane messages include:



\* room commands

\* playback commands

\* state updates

\* metadata



Timing plane information includes:



\* timestamp exchanges

\* timing measurements

\* synchronization data



The exact transport implementation is governed by `networking.md`.



\---



\# 34. Timing Message Integrity



Timing measurements must be associated with the correct:



```text

session

device

generation

measurement context

```



A timestamp from an old session must not be interpreted as current timing information.



Exact metadata fields:



\*\*UNDECIDED\*\*



\---



\# 35. Outlier Handling



Network measurements may contain outliers.



Examples:



```text

Normal:

12 ms

14 ms

13 ms

15 ms



Outlier:

180 ms

```



The synchronization system should not blindly treat every measurement as equally representative.



Potential strategies include:



```text

Median

Trimmed mean

Weighted estimation

Outlier rejection

Confidence reduction

```



The final statistical strategy is:



\*\*UNDECIDED\*\*



\---



\# 36. Measurement Before Optimization



Synchronization performance decisions must be based on measurements.



AI agents must not claim:



```text

"This algorithm is faster."

"This is perfectly synchronized."

"This device is exactly 5 ms behind."

```



without evidence.



Performance claims must specify:



\* measurement method

\* test conditions

\* device count

\* hardware

\* network conditions

\* duration

\* observed result



\---



\# 37. Device Synchronization Status



The Device API may expose Sync information.



Example:



```text

Device

├── connection = CONNECTED

├── readiness = READY

└── synchronization = SYNCHRONIZED

```



The Device API does not calculate these values.



The Sync API is authoritative for synchronization state.



\---



\# 38. Room Synchronization



A room contains multiple synchronization states.



Example:



```text

Room

├── Device A → SYNCHRONIZED

├── Device B → SYNCHRONIZED

└── Device C → DEGRADED

```



The exact room-level aggregation policy is:



\*\*UNDECIDED\*\*



The system must not label the entire room synchronized merely because the host is synchronized.



\---



\# 39. Synchronization Quality



Potential quality metrics include:



```text

Group spread

Mean offset

Maximum offset

Drift rate

Measurement uncertainty

Confidence

```



The exact metric set is:



\*\*UNDECIDED\*\*



The system should prefer metrics that can be measured consistently.



\---



\# 40. Group Spread



The most important system-level metric is the difference between device playback timings.



Conceptually:



```text

Earliest device

&#x20;      │

&#x20;      ├──────── Group spread ────────┤

&#x20;      │                              │

Latest device

```



If:



```text

Device A = 1000 ms

Device B = 1008 ms

Device C = 1014 ms

```



then the observed group spread is:



```text

14 ms

```



The exact measurement methodology must be defined in the testing system.



\---



\# 41. `getGroupSyncStatus()`



A future operation may provide room-level synchronization information.



Conceptual result:



```text

GroupSyncStatus

├── state

├── deviceStatuses

├── groupSpread

├── worstOffset

├── confidence

└── generation

```



Exact schema:



\*\*UNDECIDED\*\*



This operation must not duplicate unrelated Room state.



\---



\# 42. Synchronization Events



Potential events include:



```text

SYNC\_CALIBRATION\_STARTED

SYNC\_CALIBRATION\_COMPLETED

SYNC\_STATUS\_CHANGED

SYNC\_DEGRADED

SYNC\_RECOVERY\_STARTED

SYNC\_RECOVERY\_COMPLETED

SYNC\_FAILED

DRIFT\_DETECTED

CORRECTION\_APPLIED

```



Exact event architecture:



\*\*UNDECIDED\*\*



Event payloads must be defined before implementation.



\---



\# 43. Errors



Potential synchronization errors:



```text

SYNC\_UNAVAILABLE

CALIBRATION\_FAILED

INSUFFICIENT\_MEASUREMENTS

TIMING\_UNCERTAIN

CLOCK\_MODEL\_INVALID

TIMING\_DATA\_STALE

SYNC\_TIMEOUT

SYNC\_DEGRADED

SYNC\_FAILED

RESYNC\_FAILED

INVALID\_GENERATION

INTERNAL\_ERROR

```



These are candidate error codes.



Final error taxonomy:



\*\*UNDECIDED\*\*



Errors must contain structured information where needed.



\---



\# 44. Concurrency



Synchronization operations may overlap with:



\* playback

\* pause

\* resume

\* seek

\* network reconnect

\* audio route changes

\* room changes



The implementation must prevent:



\* stale calibration replacing newer calibration

\* old timing models affecting new playback

\* multiple recovery operations fighting each other

\* stale corrections being applied

\* measurements from different sessions being mixed



Exact concurrency policy:



\*\*UNDECIDED\*\*



\---



\# 45. Cancellation



Long-running synchronization operations may need cancellation.



Examples:



```text

Calibration cancelled

Resync cancelled

Old generation invalidated

Device left room

```



Exact cancellation API:



\*\*UNDECIDED\*\*



Cancellation must prevent obsolete asynchronous work from mutating active synchronization state.



\---



\# 46. Platform Timing Boundary



Synchronization may depend on native timing facilities.



\### Android



Potential timing source:



```text

SystemClock.elapsedRealtime()

```



Other native timing/audio facilities may be used where required.



\### iOS



Potential timing sources include:



```text

AVAudioTime

mach\_continuous\_time

other monotonic platform facilities

```



The final platform abstraction is:



\*\*UNDECIDED\*\*



Flutter should not become the authoritative source of high-precision synchronization timing.



\---



\# 47. Flutter Boundary



Conceptually:



```text

Flutter

&#x20;  │

&#x20;  ▼

Core API

&#x20;  │

&#x20;  ▼

Sync API

&#x20;  │

&#x20;  ▼

Platform Timing Layer

&#x20;  │

&#x20;┌─┴─────────┐

&#x20;▼           ▼

Android     iOS

Timing      Timing

```



High-frequency timing data should not be pushed into Flutter unnecessarily.



UI should receive summarized synchronization state.



\---



\# 48. UI Consumption



The UI may display:



```text

Synchronized

Sync degraded

Calibrating

Sync failed

Estimated offset

Group spread

Confidence

```



Only values backed by actual synchronization data may be shown.



The UI must never:



\* calculate its own synchronization metrics

\* fabricate confidence

\* assume zero offset

\* change synchronization algorithms

\* declare synchronization success independently



\---



\# 49. Contract Testing



The Sync API must have contract tests covering at minimum:



\### Clock



```text

Monotonic timing is used

Wall-clock changes do not corrupt synchronization

```



\### Timestamp Exchange



```text

t1/t2/t3/t4 are associated correctly

RTT calculation is correct

Offset calculation follows the defined model

```



\### Calibration



```text

Calibration produces a valid result

Insufficient measurements do not produce false certainty

```



\### State



```text

UNKNOWN is preserved when evidence is insufficient

CALIBRATING transitions correctly

SYNCHRONIZED requires valid evidence

DEGRADED is observable

FAILED is observable

```



\### Generation



```text

Stale timing results cannot overwrite newer generations

```



\### Drift



```text

Drift can be represented

Drift detection does not fabricate measurements

```



\### Recovery



```text

Resync can be requested

Recovery invalidates stale timing information where required

```



\---



\# 50. Real-Device Testing



Synchronization cannot be considered complete through simulation alone.



Minimum validation target:



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



Tests should include:



\* different phone models

\* different operating-system versions

\* different Wi-Fi conditions

\* phone hotspot

\* normal Wi-Fi

\* network congestion

\* device CPU load

\* long playback sessions

\* device disconnect/reconnect

\* audio route changes

\* pause/resume

\* seek

\* late joining

\* synchronization recovery



\---



\# 51. Physical Timing Measurement



The project must eventually measure actual acoustic or playback timing.



Potential measurement methods include:



```text

External microphones

Waveform capture

Oscilloscope-equivalent measurement

Recorded simultaneous output

Acoustic impulse comparison

```



The final measurement apparatus is:



\*\*UNDECIDED\*\*



The important requirement is:



> \*\*Synchronization claims must ultimately be supported by physical evidence.\*\*



\---



\# 52. AI Implementation Rules



AI agents implementing synchronization functionality MUST:



1\. Read this contract before modifying synchronization code.

2\. Read `synchronization.md`.

3\. Read `architecture.md`.

4\. Read `networking.md`.

5\. Read `playback-api.md`.

6\. Read `device-api.md`.

7\. Use monotonic timing.

8\. Preserve the shared timeline model.

9\. Preserve generation semantics.

10\. Never fabricate synchronization metrics.

11\. Never claim synchronization without evidence.

12\. Never implement synchronization logic inside UI.

13\. Never implement unrelated network transport inside Sync.

14\. Add/update contract tests.

15\. Measure real-device behavior where applicable.

16\. Document algorithmic changes.

17\. Stop when synchronization semantics are undefined.



\---



\# 53. AI Stop Conditions



The agent MUST STOP and report a blocker when:



1\. The clock model is undefined for the requested feature.

2\. Timing precision requirements are unclear.

3\. A timestamp source is ambiguous.

4\. Calibration semantics are undefined.

5\. The requested change requires choosing an unapproved synchronization algorithm.

6\. Drift correction behavior is undefined.

7\. Playback timing conflicts with Sync behavior.

8\. Network timing data is unavailable or ambiguous.

9\. Generation semantics are unclear.

10\. Multiple timing models are simultaneously plausible.

11\. Existing implementation contradicts this contract.

12\. A requested metric has no defined measurement method.

13\. The agent would need to fabricate timing data.

14\. The agent would need to use wall-clock time for synchronization.

15\. The agent would need to bypass the Sync API.

16\. The agent cannot determine which timing behavior is authoritative.



The agent must not resolve these by guessing.



\---



\# 54. Contract Change Procedure



Any significant synchronization contract change must document:



```text

Current Contract:

<existing behavior>



Proposed Change:

<new behavior>



Reason:

<why>



Timing Impact:

<effect on synchronization>



Affected Systems:

<Playback / Audio / Networking / Device / Core / Room>



Measurement Plan:

<how the change will be validated>



Compatibility Impact:

<breaking or non-breaking>



Required Updates:

<code / tests / docs>



Decision:

UNDECIDED

```



Synchronization changes should be treated as high-risk architectural changes.



\---



\# 55. Dependency Map



```text

&#x20;                        ┌──────────────┐

&#x20;                        │   Core API   │

&#x20;                        └──────┬───────┘

&#x20;                               │

&#x20;                               ▼

&#x20;                      ┌─────────────────┐

&#x20;                      │     Sync API    │

&#x20;                      └────────┬────────┘

&#x20;                               │

&#x20;             ┌─────────────────┼──────────────────┐

&#x20;             ▼                 ▼                  ▼

&#x20;       Networking          Playback            Device

&#x20;             │                 │                  │

&#x20;             ▼                 ▼                  │

&#x20;       Timing Data       Actual Position          │

&#x20;             │                 │                  │

&#x20;             └─────────────────┼──────────────────┘

&#x20;                               ▼

&#x20;                        Physical Testing

```



The Sync API is the authoritative timing boundary.



\---



\# 56. Relationship to Other Contracts



This contract must remain consistent with:



```text

DOCS/interfaces/README.md

DOCS/interfaces/core-api.md

DOCS/interfaces/room-api.md

DOCS/interfaces/device-api.md

DOCS/interfaces/audio-api.md

DOCS/interfaces/playback-api.md

DOCS/architecture.md

DOCS/synchronization.md

DOCS/networking.md

DOCS/audio.md

DOCS/testing.md

DOCS/contract-testing.md

DOCS/AI/rules.md

DOCS/AI/task-protocol.md

DOCS/AI/integration-protocol.md

```



If these documents conflict, the project authority hierarchy applies.



\---



\# 57. Current Open Questions



The following remain intentionally unresolved:



```text

1\. Exact SyncStatus schema

2\. Exact timestamp representation

3\. Clock model representation

4\. Clock offset precision

5\. Drift-rate representation

6\. Measurement uncertainty model

7\. Confidence model

8\. Calibration sample count

9\. Calibration duration

10\. Outlier rejection algorithm

11\. Latency estimation algorithm

12\. Scheduling margin

13\. Drift monitoring frequency

14\. Drift correction strategy

15\. Maximum correction rate

16\. Audible correction limits

17\. Group synchronization aggregation

18\. Exact resynchronization procedure

19\. Recovery triggers

20\. Recovery behavior

21\. Sync event architecture

22\. Sync error taxonomy

23\. Cancellation semantics

24\. Generation propagation

25\. Native timing abstraction

26\. Flutter/native synchronization boundary

27\. Physical measurement apparatus

28\. Long-duration synchronization strategy

29\. Bluetooth synchronization behavior

30\. Host timing failure behavior

```



These questions must remain visible until explicitly resolved.



\---



\# 58. Definition of Done



Synchronization API implementation is complete only when:



```text

□ Monotonic timing is implemented

□ Clock model is defined

□ Timestamp exchange is implemented

□ Offset estimation is implemented

□ Uncertainty is represented

□ Calibration is implemented

□ Shared timeline is implemented

□ Scheduled timing can be provided to Playback

□ Drift monitoring is implemented

□ Drift behavior is measurable

□ Recovery/resynchronization is implemented

□ Generation protection exists

□ Stale timing data is rejected

□ Synchronization metrics are truthful

□ Structured errors exist

□ Contract tests exist

□ Integration tests exist

□ Real-device tests exist

□ Physical timing measurements exist

□ Performance targets are measured

□ Documentation matches implementation

□ No undocumented synchronization behavior exists

□ No fabricated synchronization metrics exist

□ Git diff has been reviewed

```



\---



\# 59. Final Principle



The Synchronization API answers:



> \*\*“How does this device relate to the shared playback timeline, how trustworthy is that relationship, and what timing information does Playback need?”\*\*



It does not answer:



> \*\*“How do devices communicate?”\*\*



That belongs to Networking.



It does not answer:



> \*\*“How does audio play?”\*\*



That belongs to Playback and Audio.



It does not answer:



> \*\*“Who is in the room?”\*\*



That belongs to Room.



It does not answer:



> \*\*“What should the UI display?”\*\*



That belongs to the application/UI layer.



\*\*Networking provides timing observations.

Sync turns observations into a timing model.

Playback executes the timing model.

Physical testing tells us whether it actually worked.\*\*



The synchronization contract exists to make SoundMesh's hardest technical problem measurable, testable, and impossible for an AI agent to casually redefine.



