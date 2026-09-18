\# SoundMesh — Testing \& Validation Specification



\*\*Document Status:\*\* REQUIRED

\*\*Document Type:\*\* Engineering Test \& Validation Specification

\*\*Applies To:\*\* Entire SoundMesh repository

\*\*Primary Authority:\*\* Testing, validation, acceptance criteria, and quality gates

\*\*Related Documents:\*\*



\* `DOCS/blueprint.md`

\* `DOCS/architecture.md`

\* `DOCS/networking.md`

\* `DOCS/synchronization.md`

\* `DOCS/audio.md`

\* `DOCS/ui-ux.md`

\* `DOCS/decisions.md`

\* `DOCS/roadmap.md`

\* `DOCS/AI/task-protocol.md`



\---



\# 1. Purpose



This document defines how SoundMesh is tested, measured, validated, and considered complete.



SoundMesh is a distributed realtime system.



Therefore, ordinary application testing is insufficient.



A test suite must validate:



\* application correctness

\* networking correctness

\* audio correctness

\* synchronization correctness

\* recovery behavior

\* performance

\* compatibility

\* usability

\* accessibility

\* reliability

\* real-world physical playback behavior



The most important principle is:



> \*\*SoundMesh must be measured, not merely assumed to work.\*\*



\---



\# 2. Testing Philosophy



Testing should answer five questions:



1\. \*\*Does it function?\*\*

2\. \*\*Does it function reliably?\*\*

3\. \*\*Does it remain synchronized?\*\*

4\. \*\*Does it recover from realistic failures?\*\*

5\. \*\*Does the real-world result match the software's measurements?\*\*



A passing unit test does not prove synchronized audio.



A successful connection does not prove reliable networking.



A low reported synchronization error does not automatically prove low audible synchronization error.



\---



\# 3. Test Levels



SoundMesh uses multiple levels of testing.



```text

Unit

&#x20;↓

Component

&#x20;↓

Integration

&#x20;↓

Device

&#x20;↓

System

&#x20;↓

Synchronization

&#x20;↓

Stress

&#x20;↓

Physical / Audible Validation

```



Each level validates different failure modes.



\---



\# 4. Test Categories



\## 4.1 Unit Tests



Test isolated deterministic logic.



Examples:



\* clock calculations

\* offset calculations

\* RTT calculations

\* drift calculations

\* state transitions

\* protocol serialization

\* protocol parsing

\* hash verification

\* generation handling

\* configuration validation



\---



\## 4.2 Component Tests



Test individual subsystems.



Examples:



\* room manager

\* connection manager

\* synchronization engine

\* audio preparation

\* playback scheduler

\* drift controller

\* QR payload parser



\---



\## 4.3 Integration Tests



Test multiple subsystems together.



Examples:



```text

Room

\+

Networking

\+

Audio preparation

\+

Synchronization

```



\---



\## 4.4 Device Tests



Run the application on physical phones.



Required for:



\* audio

\* networking

\* synchronization

\* battery

\* thermal behavior

\* background behavior

\* interruptions

\* device compatibility



\---



\## 4.5 System Tests



Test the complete user journey.



Example:



```text

Create room

&#x20;↓

Join room

&#x20;↓

Transfer audio

&#x20;↓

Prepare

&#x20;↓

Calibrate

&#x20;↓

Schedule

&#x20;↓

Play

&#x20;↓

Monitor

&#x20;↓

Stop

```



\---



\## 4.6 Physical Synchronization Tests



Use external measurement to validate actual sound output.



These tests are essential for proving synchronization quality.



\---



\# 5. Test Environment



Every synchronization test should record the environment.



Minimum metadata:



```text

Test ID

Date

Application version

Git commit

Protocol version

Device model

OS version

Battery level

Network type

Host device

Participant devices

Audio file

Audio format

Sample rate

Channel configuration

Volume

Audio route

Bluetooth status

Screen state

Background/foreground state

Ambient conditions

```



\---



\# 6. Device Matrix



Testing must eventually cover heterogeneous devices.



A device matrix should include differences in:



\* manufacturer

\* model

\* Android/iOS version

\* CPU

\* audio hardware

\* speaker configuration

\* Wi-Fi hardware



Initial progression:



```text

2 identical/similar phones

&#x20;↓

2 different Android phones

&#x20;↓

Android + iOS

&#x20;↓

3 devices

&#x20;↓

5 devices

&#x20;↓

larger groups

```



\---



\# 7. Test Naming



Tests should use predictable identifiers.



Example:



```text

NET-001

NET-002



SYNC-001

SYNC-002



AUD-001

AUD-002



UI-001

UI-002



REC-001

REC-002

```



A test ID should remain stable even if its implementation changes.



\---



\# 8. Test Result States



Every executed test should produce one of:



```text

PASS

FAIL

BLOCKED

NOT RUN

NOT APPLICABLE

```



Never mark a test as PASS when it was merely not observed failing.



\---



\# 9. Bug Severity



Use:



\### P0 — Critical



System unusable or dangerous failure.



Examples:



\* application crashes consistently

\* corrupted playback

\* unrecoverable room failure



\### P1 — Major



Core functionality significantly broken.



Examples:



\* synchronization unusable

\* devices cannot join

\* playback frequently fails



\### P2 — Moderate



Important but non-core issue.



Examples:



\* recovery occasionally requires user intervention

\* diagnostics incorrect



\### P3 — Minor



Low-impact issue.



Examples:



\* visual defect

\* minor wording issue



\---



\# 10. Unit Testing Requirements



Unit tests should cover all deterministic mathematical logic.



Required areas include:



\* RTT calculation

\* offset calculation

\* drift estimation

\* timing uncertainty

\* synchronization state transitions

\* generation comparison

\* message validation

\* QR parsing

\* room-state transitions



\---



\# 11. Timestamp Calculation Test



Given:



```text

t1 = participant send

t2 = host receive

t3 = host send

t4 = participant receive

```



The implementation must correctly calculate the documented offset and RTT formulas.



Test cases must include:



\* zero delay

\* symmetric delay

\* asymmetric delay

\* large RTT

\* repeated measurements

\* invalid timestamps

\* timestamps out of order



\---



\# 12. Clock Offset Tests



Test:



\* positive offset

\* negative offset

\* zero offset

\* large offset

\* noisy measurements

\* changing offset

\* insufficient samples



The algorithm must not silently accept invalid measurements.



\---



\# 13. Outlier Rejection Tests



Synchronization measurements should tolerate occasional bad network samples.



Test scenarios:



```text

Normal

Normal

Normal

Huge outlier

Normal

Normal

```



The outlier must not disproportionately distort the clock model.



\---



\# 14. Drift Tests



Generate known synthetic drift.



Examples:



```text

+1 ppm

+10 ppm

\-10 ppm

+50 ppm

\-50 ppm

```



Verify that:



\* drift is detected

\* drift estimate converges

\* correction remains stable

\* correction does not oscillate unnecessarily



\---



\# 15. State Machine Tests



Every important state transition must have tests.



Example:



```text

CREATED

→ DISCOVERABLE

→ JOINING

→ CALIBRATING

→ READY

→ PLAYING

→ ENDING

→ CLOSED

```



Invalid transitions must be rejected.



\---



\# 16. Generation Number Tests



Test stale commands.



Example:



```text

Generation 10 → PLAY

Generation 11 → PAUSE

Generation 10 → PLAY

```



The final old-generation PLAY command must not override the newer state.



\---



\# 17. Networking Tests



Networking tests must cover:



\* discovery

\* connection

\* handshake

\* authentication/session authorization

\* message delivery

\* audio transfer

\* reconnect

\* disconnect

\* timeout

\* network change

\* malformed packets

\* duplicate messages

\* stale messages



\---



\# 18. Connection Establishment Test



Expected:



```text

Host creates room

&#x20;↓

Participant scans QR

&#x20;↓

Participant connects

&#x20;↓

HELLO

&#x20;↓

WELCOME

&#x20;↓

Participant registered

```



The participant should reach the expected room state without manual network configuration.



\---



\# 19. Duplicate Message Tests



Send the same message multiple times.



The system must not:



\* duplicate playback

\* duplicate devices

\* corrupt state

\* restart transfers unnecessarily



Messages should be safely handled according to their semantics.



\---



\# 20. Message Ordering Tests



Send messages in unusual order.



Examples:



```text

PLAY

PAUSE

PLAY

```



and:



```text

NEW\_STATE

OLD\_STATE

```



The application must preserve the correct logical state.



\---



\# 21. Audio Transfer Tests



Test:



\* valid file

\* corrupted file

\* interrupted transfer

\* incomplete transfer

\* duplicate transfer

\* insufficient storage

\* unsupported format

\* checksum mismatch



A failed integrity check must prevent playback of the invalid asset.



\---



\# 22. Audio Preparation Tests



A participant is considered ready only after:



\* correct asset exists

\* integrity is verified

\* decoding is available

\* playback engine is initialized

\* required buffers are prepared

\* synchronization calibration is complete



Test each failure independently.



\---



\# 23. Synchronization Test Environment



Synchronization tests should begin with two physical devices.



The first goal is not scale.



The first goal is:



> \*\*Prove that two real phones can reliably synchronize.\*\*



Only after this works should the system scale to more devices.



\---



\# 24. SYNC-001 — Two-Device Startup Synchronization



\### Objective



Measure whether two devices begin playback within the target synchronization window.



\### Procedure



1\. Connect two phones.

2\. Transfer identical audio.

3\. Prepare both devices.

4\. Calibrate.

5\. Schedule future playback.

6\. Start playback.

7\. Measure actual output timing.



\### Record



```text

Host start time

Participant start time

Observed difference

Network RTT

Clock offset

Timing uncertainty

```



\### Initial target



```text

Startup spread ≤ 20 ms

```



This is a target, not a guarantee.



\---



\# 25. SYNC-002 — Steady-State Synchronization



\### Objective



Determine whether devices remain synchronized after playback begins.



\### Procedure



1\. Start synchronized playback.

2\. Continue for an extended period.

3\. Measure output timing repeatedly.

4\. Calculate maximum and average spread.



\### Initial target



```text

Steady-state spread ≤ 20 ms

```



\---



\# 26. SYNC-003 — Drift Test



\### Objective



Determine whether devices drift apart over time.



Measure:



```text

t = 0

t = 10 s

t = 30 s

t = 60 s

t = 5 min

t = 10 min

```



Record:



\* measured spread

\* drift estimate

\* correction activity



\---



\# 27. SYNC-004 — Drift Correction



Intentionally create or select devices with different timing behavior.



Verify:



1\. drift is detected

2\. correction is applied

3\. correction does not produce audible artifacts

4\. devices return toward target synchronization

5\. correction does not oscillate continuously



\---



\# 28. SYNC-005 — Network Jitter



Introduce variable network delay.



Example:



```text

10 ms

30 ms

80 ms

20 ms

150 ms

15 ms

```



The system should avoid interpreting every network fluctuation as actual clock drift.



\---



\# 29. SYNC-006 — High RTT



Test synchronization under increased network latency.



Record:



\* RTT

\* calibration confidence

\* startup error

\* steady-state error



The system should degrade gracefully rather than falsely reporting high confidence.



\---



\# 30. SYNC-007 — Packet Loss



Test under packet loss.



Verify:



\* playback does not immediately fail

\* timing measurements tolerate missing samples

\* control messages recover

\* synchronization status reflects degradation



\---



\# 31. SYNC-008 — Late Join



Procedure:



1\. Host begins playback.

2\. Participant joins later.

3\. Participant receives audio.

4\. Participant prepares.

5\. Participant calibrates.

6\. Participant joins at a valid future timeline position.



The participant must not simply start playback immediately.



\---



\# 32. SYNC-009 — Participant Disconnect



Procedure:



1\. Start synchronized playback.

2\. Disconnect one participant.

3\. Continue playback.

4\. Reconnect participant.



Verify:



\* remaining devices continue correctly

\* disconnected participant enters appropriate state

\* participant resynchronizes before rejoining active playback



\---



\# 33. SYNC-010 — Host Disconnect



Procedure:



1\. Start synchronized playback.

2\. Remove host connectivity.

3\. Observe behavior.



MVP expectation:



\* controlled failure/recovery

\* no false claim of seamless migration



\---



\# 34. SYNC-011 — Pause



Test:



```text

Playing

&#x20;↓

Pause

&#x20;↓

Paused

&#x20;↓

Resume

&#x20;↓

Playing

```



Verify all devices resume according to the shared timeline.



\---



\# 35. SYNC-012 — Seek



Test:



\* forward seek

\* backward seek

\* repeated seek

\* seek during buffering

\* seek during degraded network



All devices must move to the same logical playback position.



\---



\# 36. SYNC-013 — Stop



Verify:



\* playback stops on all devices

\* stale commands do not restart playback

\* state returns to the correct room state



\---



\# 37. Audio Synchronization vs Software Synchronization



These must be tested separately.



\### Software synchronization



Measures internal playback/timing values.



\### Physical synchronization



Measures actual sound output.



A test cannot be considered complete merely because software reports:



```text

Sync error = 5 ms

```



The physical output may still differ because of:



\* speaker hardware

\* audio pipeline latency

\* Bluetooth

\* OS behavior

\* device-specific processing



\---



\# 38. Physical Measurement Method



The preferred validation method is simultaneous recording of device outputs.



Conceptual setup:



```text

Phone A ─┐

&#x20;        ├──→ microphone(s) ─→ recording

Phone B ─┤

Phone C ─┘

```



Use a known test signal where waveform alignment can be detected.



Examples:



\* impulse

\* click

\* short tone burst

\* repeated pulse sequence



\---



\# 39. Measurement Analysis



For each recording:



1\. identify the reference signal

2\. detect waveform onset

3\. calculate onset time

4\. compare devices

5\. calculate maximum spread

6\. calculate average spread

7\. record confidence



Example:



```text

Device A: 0.000 s

Device B: 0.008 s

Device C: 0.013 s

Device D: 0.019 s

```



Group spread:



```text

19 ms

```



\---



\# 40. Measurement Repeatability



A synchronization result should not rely on one lucky run.



For important tests:



```text

Minimum:

10 repetitions

```



Prefer more repetitions for final validation.



Report:



\* minimum

\* maximum

\* mean

\* median

\* percentile where useful

\* standard deviation where appropriate



\---



\# 41. Test Signals



Dedicated synchronization tests should use controlled audio.



Avoid judging synchronization solely with ordinary music because musical transients vary.



A controlled signal makes timing differences easier to measure.



\---



\# 42. Human Listening Tests



Physical measurement should be supplemented with human listening.



Testers should evaluate:



\* obvious echo

\* flanging

\* doubled transients

\* phase-like artifacts

\* audible timing separation

\* correction artifacts



Human perception is not a replacement for measurement, but it is an important validation layer.



\---



\# 43. Audio Route Tests



Test:



\* built-in speaker

\* wired headphones where supported

\* Bluetooth where supported

\* route changes during playback



Bluetooth results must be recorded separately.



\---



\# 44. Volume Tests



Test:



\* low volume

\* medium volume

\* high volume

\* different devices with different maximum loudness



Volume synchronization must not be confused with timing synchronization.



\---



\# 45. Interruption Tests



Test:



\* incoming call

\* notification/audio interruption

\* another application taking audio focus

\* system audio changes



Verify that the room state remains truthful.



\---



\# 46. Background Tests



Test:



\* screen off

\* app backgrounded

\* device locked

\* battery saver

\* thermal pressure



Record whether playback:



\* continues

\* pauses

\* degrades

\* terminates



Platform-specific behavior must be documented.



\---



\# 47. Battery Tests



Long-running sessions should measure:



\* battery percentage before

\* battery percentage after

\* duration

\* CPU usage

\* thermal state where available



The test should compare:



```text

Idle

Playback

Playback + synchronization

```



\---



\# 48. Thermal Tests



Run extended sessions.



Watch for:



\* increased latency

\* audio dropouts

\* CPU throttling

\* synchronization degradation

\* application termination



\---



\# 49. Memory Tests



Monitor:



\* application memory

\* audio buffer memory

\* transferred file storage

\* cached audio

\* growth over time



A stable session should not continuously leak memory.



\---



\# 50. Stress Testing



Stress variables include:



\* number of participants

\* audio file size

\* session duration

\* network latency

\* packet loss

\* device heterogeneity

\* repeated join/leave

\* repeated play/pause

\* repeated seek



\---



\# 51. Scaling Test Sequence



Use:



```text

2 devices

3 devices

5 devices

10 devices

```



Do not assume that success with two devices implies success with ten.



\---



\# 52. Join/Leave Stress



Repeatedly:



```text

Join

Leave

Join

Leave

Join

Leave

```



The system must not:



\* leak resources

\* duplicate participants

\* corrupt room state

\* retain stale connections

\* accumulate stale playback commands



\---



\# 53. Reliability Testing



A useful reliability metric is:



```text

Successful sessions

\-------------------

Total attempted sessions

```



Record:



\* connection success rate

\* audio preparation success rate

\* synchronization success rate

\* playback success rate

\* recovery success rate



\---



\# 54. Reproducibility



Important bugs must include enough information to reproduce them.



Bug reports should include:



```text

Device

OS

App version

Commit

Network

Room size

Audio file

Steps

Expected result

Actual result

Logs

Diagnostics

Frequency

```



\---



\# 55. Logging Requirements



Logs should support diagnosis without overwhelming normal operation.



Useful categories:



```text

ROOM

NETWORK

AUDIO

SYNC

PLAYBACK

RECOVERY

PERFORMANCE

ERROR

```



\---



\# 56. Synchronization Diagnostics



Diagnostic mode should expose relevant information such as:



```text

Device

Connection state

RTT

Estimated clock offset

Timing uncertainty

Calibration confidence

Playback state

Playback generation

Estimated drift

Correction state

```



Diagnostics must distinguish:



```text

estimated

measured

reported

```



\---



\# 57. Never Fake Test Results



No developer or AI agent may:



\* invent synchronization numbers

\* mark an untested device as compatible

\* claim physical synchronization without measurement

\* claim a test passed because the application launched

\* fabricate benchmark results



If a value is unknown, report:



```text

UNKNOWN

NOT MEASURED

```



\---



\# 58. Automated Test Requirements



Where practical, CI should automatically run:



\* unit tests

\* static analysis

\* formatting checks

\* protocol tests

\* state-machine tests

\* serialization tests

\* deterministic synchronization mathematics



Physical audio synchronization cannot be fully replaced by CI.



\---



\# 59. Build Verification



Every release candidate must verify:



\* clean build

\* dependency resolution

\* application launch

\* core room flow

\* networking

\* audio preparation

\* playback

\* synchronization

\* stop/end behavior



\---



\# 60. Regression Testing



Every bug fix should receive a regression test when practical.



Example:



```text

Bug:

Old PLAY command restarted playback.



Fix:

Generation validation.



Regression test:

Old-generation PLAY is ignored.

```



\---



\# 61. Acceptance Criteria



The MVP should not be considered technically complete until the following are demonstrated.



\### Core flow



\* room creation works

\* QR joining works

\* participant registration works

\* audio transfer works

\* audio integrity is verified

\* audio preparation works

\* synchronized playback starts

\* pause/resume works

\* stop works

\* participant leaving works



\### Synchronization



\* two-device synchronization is measured

\* startup synchronization is measured

\* steady-state synchronization is measured

\* drift is measured

\* correction is tested

\* failures are handled



\### Reliability



\* disconnect behavior is tested

\* reconnection behavior is tested

\* late joining is tested

\* malformed/invalid messages are tested

\* transfer failures are tested



\### Physical validation



\* actual sound output is measured

\* multiple repetitions are performed

\* heterogeneous devices are tested



\---



\# 62. Initial MVP Quality Gate



The first meaningful milestone is:



> \*\*Two real phones can join a local SoundMesh room, receive the same audio, prepare independently, start from a shared future timeline, and demonstrate measured synchronized playback.\*\*



Nothing beyond this should be considered proof that the core technology works.



\---



\# 63. Engineering Target Table



| Metric                              |   Initial Target | Status       |

| ----------------------------------- | ---------------: | ------------ |

| Startup spread                      |           ≤20 ms | Target       |

| Steady-state spread                 |           ≤20 ms | Target       |

| Preferred correction stretch        |           ≤10 ms | Target       |

| Successful two-device session       | High reliability | Must measure |

| Audio transfer integrity            |    100% verified | Required     |

| Stale command rejection             |             100% | Required     |

| Physical synchronization validation |         Required | Required     |



These values are engineering targets, not universal guarantees.



\---



\# 64. What Counts as Proof?



\### Weak evidence



> “It sounded synchronized.”



\### Better evidence



> “Software measured 8 ms spread.”



\### Strong evidence



> “Software measured 8 ms spread across 20 runs.”



\### Strongest practical evidence



> “Software measured synchronization and simultaneous external recordings independently confirmed the physical output timing across repeated runs and heterogeneous devices.”



SoundMesh should aim for the strongest practical evidence available.



\---



\# 65. Definition of Done



A feature is DONE only when:



1\. implementation exists

2\. expected behavior is documented

3\. applicable tests exist

4\. tests pass

5\. failure behavior is considered

6\. relevant real-device testing is completed

7\. diagnostics are sufficient

8\. documentation is updated

9\. no known critical regression remains



For synchronization features, physical validation is additionally required when the feature affects actual playback timing.



\---



\# 66. AI Testing Rules



AI coding agents must:



\* run relevant tests after changes

\* inspect failures

\* fix root causes rather than hiding failures

\* avoid deleting tests to make CI pass

\* avoid weakening assertions without justification

\* report untested areas

\* distinguish build success from feature correctness

\* never fabricate test results



An AI agent must not say:



> “Everything works.”



unless the relevant evidence exists.



\---



\# 67. AI Completion Report



When an AI agent completes a substantial task, its final report should include:



```text

Implementation:

\- What changed



Tests run:

\- Test command

\- Result



Validation:

\- Device/platform tested

\- Manual tests performed



Known limitations:

\- Anything not tested



Potential follow-up:

\- Remaining risks

```



\---



\# 68. Test Evidence



Important synchronization experiments should preserve evidence where practical.



Examples:



\* logs

\* test recordings

\* timing measurements

\* benchmark results

\* device information

\* screenshots

\* reproduction steps



Evidence should be associated with a test ID.



Example:



```text

SYNC-001

SYNC-001-run-01

SYNC-001-run-02

SYNC-001-recording

```



\---



\# 69. Experimental Test Discipline



Experiments should have:



```text

Hypothesis

Setup

Variables

Procedure

Measurements

Results

Conclusion

Decision

```



Example:



```text

Hypothesis:

Future scheduled playback produces lower startup spread than immediate playback.



Experiment:

Compare both approaches on five devices.



Measurement:

Physical waveform onset difference.



Result:

...



Conclusion:

...



Decision:

Scheduled playback retained.

```



\---



\# 70. Test Environment Stability



When comparing synchronization algorithms, avoid changing multiple variables simultaneously.



For example, do not compare two synchronization algorithms while also changing:



\* audio engine

\* network transport

\* audio format

\* device set

\* buffer size



unless the experiment specifically intends to test their combined effect.



\---



\# 71. Controlled Variables



When possible, keep constant:



\* audio asset

\* volume

\* device placement

\* network

\* OS version

\* application version

\* test duration

\* measurement equipment



Only intentionally vary the variable under investigation.



\---



\# 72. Network Fault Injection



Future test infrastructure should support controlled simulation of:



\* latency

\* jitter

\* packet loss

\* temporary disconnect

\* bandwidth limitation



The purpose is to test recovery behavior without relying exclusively on naturally occurring bad networks.



\---



\# 73. Real-World Testing



After controlled testing, test realistic scenarios.



Examples:



\### Scenario A — Village gathering



Several phones connected through one hotspot.



\### Scenario B — Home Wi-Fi



Multiple devices connected to a conventional router.



\### Scenario C — Mixed devices



Android + iOS.



\### Scenario D — Weak network



High latency and intermittent connectivity.



\### Scenario E — Long session



30+ minutes of playback.



The environment should be recorded rather than described vaguely.



\---



\# 74. Compatibility Claims



Do not claim:



> Works on all Android phones.



or:



> Works on all iPhones.



unless supported by an appropriate compatibility matrix.



Prefer:



> Tested on the following devices…



\---



\# 75. Performance Budgeting



Performance measurements should eventually track:



\* CPU

\* memory

\* network bandwidth

\* storage

\* battery

\* temperature

\* synchronization accuracy



Optimization should be guided by measurements.



\---



\# 76. Test Prioritization



When time is limited, prioritize:



```text

1\. Core synchronization

2\. Core audio playback

3\. Networking reliability

4\. Recovery

5\. Real-device compatibility

6\. Performance

7\. Accessibility

8\. Visual polish

```



A beautiful application with broken synchronization is not a successful SoundMesh MVP.



\---



\# 77. Final Testing Principle



SoundMesh is fundamentally a physical distributed system.



The application code is only part of the product.



The final validation chain is:



```text

Code

&#x20;↓

Network

&#x20;↓

Clock model

&#x20;↓

Audio engine

&#x20;↓

Device hardware

&#x20;↓

Physical sound

&#x20;↓

Human perception

```



Testing must therefore follow the entire chain.



> \*\*If we want to claim that SoundMesh turns five phones into one speaker, we need evidence that five physical phones actually behave like one.\*\*



\*\*End of Testing \& Validation Specification.\*\*



