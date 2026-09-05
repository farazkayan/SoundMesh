\# SoundMesh — Engineering Roadmap



\*\*Document Status:\*\* REQUIRED

\*\*Document Type:\*\* Engineering Roadmap / Build Plan

\*\*Applies To:\*\* Entire SoundMesh repository

\*\*Primary Authority:\*\* Development sequencing, milestones, dependencies, and scope

\*\*Related Documents:\*\*



\* `DOCS/blueprint.md`

\* `DOCS/architecture.md`

\* `DOCS/networking.md`

\* `DOCS/synchronization.md`

\* `DOCS/audio.md`

\* `DOCS/ui-ux.md`

\* `DOCS/decisions.md`

\* `DOCS/testing.md`

\* `DOCS/AI/ai-context.md`

\* `DOCS/AI/rules.md`

\* `DOCS/AI/task-protocol.md`

\* `AGENTS.md`



\---



\# 1. Purpose



This document defines the recommended development order for SoundMesh.



The roadmap exists to prevent the project from becoming:



\* UI-first

\* feature-heavy

\* architecture-heavy without proof

\* difficult to debug

\* overloaded with speculative infrastructure

\* focused on low-risk features while the core technical risk remains unproven



SoundMesh must be built in an order that attacks the highest-risk assumptions first.



\---



\# 2. Core Roadmap Principle



The project should follow:



> \*\*Prove the hardest technical assumption first, then build the product around the proven system.\*\*



The hardest assumption is:



> Can multiple heterogeneous phones reliably produce sufficiently synchronized audio using local networking and native audio scheduling?



Therefore the project must not spend excessive development time polishing the application before this question is answered.



\---



\# 3. Development Strategy



The roadmap follows these broad stages:



```text

Foundation

&#x20;   ↓

Technical Spike

&#x20;   ↓

Two-Device Synchronization

&#x20;   ↓

Reliable Room System

&#x20;   ↓

Audio Pipeline

&#x20;   ↓

Multi-Device Scaling

&#x20;   ↓

Recovery \& Resilience

&#x20;   ↓

Premium UX

&#x20;   ↓

Diagnostics \& Polish

&#x20;   ↓

Competition Validation

&#x20;   ↓

Release / Submission

```



\---



\# 4. Phase 0 — Repository Foundation



\*\*Status:\*\* REQUIRED



\### Objective



Create a clean engineering foundation before implementing product functionality.



\### Tasks



\* initialize repository structure

\* establish branches

\* create documentation

\* establish `AGENTS.md`

\* establish AI development rules

\* configure formatting

\* configure linting

\* configure basic testing

\* establish package/project naming

\* establish development conventions

\* establish issue/task conventions



\### Expected result



The repository is ready for multiple developers and AI coding agents.



\### Exit criteria



\* repository builds

\* project structure is understood

\* documentation is accessible

\* AI agents have repository instructions

\* basic CI/static checks exist where practical



\---



\# 5. Phase 1 — Flutter Application Shell



\*\*Status:\*\* REQUIRED



\### Objective



Create the smallest working Flutter application.



\### Tasks



\* initialize Flutter project

\* configure Android

\* configure iOS

\* establish app entry point

\* establish basic navigation

\* establish theme

\* implement initial design tokens

\* create placeholder screens



\### Initial screens



```text

Home

Create Room

Join Room

Room

Settings

Diagnostics

```



These do not need complete functionality yet.



\### Exit criteria



\* application launches

\* navigation works

\* theme is applied

\* Android build works

\* iOS build works where development environment permits



\---



\# 6. Phase 2 — Native Platform Bridge



\*\*Status:\*\* REQUIRED



\### Objective



Prove that Flutter can communicate cleanly with native Android/iOS systems.



\### Tasks



Create the initial native abstraction boundary.



Conceptually:



```text

Flutter

&#x20;  ↓

Typed interface

&#x20;  ↓

Android / iOS implementation

```



\### Initial capabilities



The bridge should eventually support:



\* device information

\* native timing

\* network operations

\* audio operations



Do not implement the entire system at once.



\### Exit criteria



A simple typed Flutter → native → Flutter operation works reliably on supported platforms.



\---



\# 7. Phase 3 — Local Networking Spike



\*\*Status:\*\* CRITICAL



\### Objective



Prove that nearby devices can establish reliable local connections.



\### First target



Two physical devices.



\### Tasks



Implement the smallest possible networking prototype:



```text

Host

&#x20;↓

Create room

&#x20;↓

Expose connection information

&#x20;↓

Participant

&#x20;↓

Connect

&#x20;↓

Handshake

```



\### Test



Send simple messages:



```text

PING

PONG

HELLO

WELCOME

```



\### Do not build yet



\* audio streaming

\* complex discovery

\* cloud infrastructure

\* advanced authentication

\* large room management



\### Exit criteria



Two physical phones can reliably connect and exchange structured messages over the intended local network.



\---



\# 8. Phase 4 — Room Protocol



\*\*Status:\*\* REQUIRED



\### Objective



Turn the networking spike into an actual SoundMesh room.



\### Implement



\* room ID

\* participant ID

\* session ID

\* host state

\* participant state

\* handshake

\* protocol version

\* message IDs

\* generation numbers

\* connection state



\### Basic room lifecycle



```text

CREATED

&#x20;↓

DISCOVERABLE

&#x20;↓

JOINING

&#x20;↓

READY

&#x20;↓

CLOSED

```



\### Exit criteria



Two devices can join and maintain a valid room state.



\---



\# 9. Phase 5 — QR Joining



\*\*Status:\*\* REQUIRED



\### Objective



Replace technical connection setup with the intended user experience.



\### Flow



```text

Host

&#x20;↓

Create Room

&#x20;↓

QR displayed



Participant

&#x20;↓

Join Room

&#x20;↓

Scan QR

&#x20;↓

Connect

```



\### Requirements



\* QR payload parsing

\* QR generation

\* version validation

\* invalid QR handling

\* expired/invalid token handling

\* connection failure handling



\### Exit criteria



A participant can join without manually entering an IP address.



\---



\# 10. Phase 6 — Audio Asset Pipeline



\*\*Status:\*\* CRITICAL



\### Objective



Get an audio file from the host to another device and prepare it for local playback.



\### Flow



```text

Select audio

&#x20;↓

Identify asset

&#x20;↓

Transfer

&#x20;↓

Verify integrity

&#x20;↓

Store locally

&#x20;↓

Prepare decoder

&#x20;↓

Prepare audio engine

```



\### Implement



\* audio metadata

\* file transfer

\* content hashing

\* transfer progress

\* failure handling

\* local storage

\* preparation state



\### Exit criteria



Two devices possess and can independently prepare the same audio asset.



\---



\# 11. Phase 7 — Native Audio Playback



\*\*Status:\*\* CRITICAL



\### Objective



Prove reliable local audio playback through the native audio layer.



\### Requirements



The system must be able to:



\* load audio

\* prepare audio

\* start

\* pause

\* resume

\* stop

\* report playback state

\* report playback position where supported



\### Important



Do not attempt advanced synchronization yet.



First prove that each device can reliably play audio independently.



\### Exit criteria



A physical device can play the selected test audio reliably.



\---



\# 12. Phase 8 — Native Playback Scheduling Spike



\*\*Status:\*\* HIGHEST TECHNICAL PRIORITY



\### Objective



Prove that native audio can be scheduled for a future target time.



The prototype should support:



```text

Current time

&#x20;    ↓

Future target

&#x20;    ↓

Native scheduler

&#x20;    ↓

Playback

```



\### Test



Schedule two devices to begin playback at the same logical target.



\### Important



Do not use:



```text

send PLAY

```



as the primary mechanism.



\### Exit criteria



Two devices can be scheduled for a future playback event.



\---



\# 13. Phase 9 — Clock Synchronization



\*\*Status:\*\* CRITICAL



\### Objective



Create a relationship between host and participant timing systems.



\### Implement



\* monotonic timestamps

\* timestamp exchange

\* RTT calculation

\* clock-offset estimation

\* multiple measurements

\* outlier rejection

\* timing uncertainty

\* confidence



\### Test



Run repeated calibration measurements between two devices.



\### Exit criteria



The system produces a stable, inspectable clock relationship.



\---



\# 14. Phase 10 — Two-Device Synchronized Playback



\*\*Status:\*\* MILESTONE 1



\### Objective



Prove the core SoundMesh concept.



\### Full flow



```text

Host creates room

&#x20;↓

Participant scans QR

&#x20;↓

Connect

&#x20;↓

Audio transferred

&#x20;↓

Integrity verified

&#x20;↓

Audio prepared

&#x20;↓

Clock calibrated

&#x20;↓

Future target calculated

&#x20;↓

Both devices schedule playback

&#x20;↓

Playback begins

&#x20;↓

Actual timing measured

```



\### Exit criteria



Two physical devices demonstrate repeatable synchronized playback.



\### Required evidence



\* logs

\* synchronization measurements

\* test configuration

\* application version

\* device models

\* network conditions

\* repeated runs



This is the first major proof that SoundMesh's core idea is technically viable.



\---



\# 15. Phase 11 — Synchronization Monitoring



\*\*Status:\*\* REQUIRED



\### Objective



Ensure devices remain synchronized after startup.



\### Implement



\* playback monitoring

\* position measurement

\* drift estimation

\* synchronization error calculation

\* health state



\### States



```text

SYNCHRONIZED

DEGRADED

RECOVERING

RESYNC\_REQUIRED

```



\### Exit criteria



The system can detect synchronization degradation.



\---



\# 16. Phase 12 — Drift Correction



\*\*Status:\*\* REQUIRED



\### Objective



Correct gradual timing divergence.



\### Preferred correction hierarchy



```text

Detect

&#x20;↓

Estimate

&#x20;↓

Tiny playback-rate correction

&#x20;↓

Re-measure

&#x20;↓

Small position correction

&#x20;↓

Controlled resync if required

```



\### Requirements



Corrections must avoid:



\* audible artifacts

\* oscillation

\* repeated unnecessary corrections

\* unstable feedback loops



\### Exit criteria



Controlled drift can be detected and corrected without destabilizing playback.



\---



\# 17. Phase 13 — Playback Controls



\*\*Status:\*\* REQUIRED



\### Implement



\* play

\* pause

\* resume

\* seek

\* stop



\### Important



All playback-affecting operations must operate against the shared session timeline.



\### Exit criteria



Two devices remain logically coordinated through normal playback controls.



\---



\# 18. Phase 14 — Multi-Device Expansion



\*\*Status:\*\* REQUIRED



\### Progression



```text

2

&#x20;↓

3

&#x20;↓

5

&#x20;↓

10

```



Do not jump directly to large-scale testing.



\### Measure



\* startup spread

\* steady-state spread

\* RTT

\* calibration duration

\* CPU

\* memory

\* bandwidth

\* battery

\* failure rate



\### Exit criteria



The architecture behaves predictably as participants increase.



\---



\# 19. Phase 15 — Device Heterogeneity



\*\*Status:\*\* REQUIRED



\### Objective



Test whether the system works across different hardware.



Test combinations such as:



```text

Android + Android

Android + iOS

iOS + iOS

Older + newer device

Different manufacturers

Different speaker hardware

```



\### Important



Identical-device testing is not sufficient.



\### Exit criteria



Known compatible device classes are documented.



Unsupported/problematic configurations are explicitly documented.



\---



\# 20. Phase 16 — Failure Recovery



\*\*Status:\*\* REQUIRED



\### Implement and test



\* participant disconnect

\* participant reconnect

\* network interruption

\* network change

\* failed audio transfer

\* calibration failure

\* audio preparation failure

\* playback failure

\* late joining

\* host failure



\### MVP host failure behavior



Controlled recovery is acceptable.



Seamless host migration is not required.



\### Exit criteria



Expected failures produce controlled states instead of crashes or silent corruption.



\---



\# 21. Phase 17 — Audio Edge Cases



\*\*Status:\*\* REQUIRED



\### Test



\* different formats

\* different sample rates

\* stereo

\* mono

\* unsupported audio

\* large files

\* short files

\* long files

\* audio route changes

\* interruption

\* screen lock

\* backgrounding

\* Bluetooth



\### Bluetooth



Remain experimental unless testing demonstrates acceptable behavior.



\---



\# 22. Phase 18 — Production Room State Machine



\*\*Status:\*\* REQUIRED



Expand room state handling.



Target conceptual state flow:



```text

CREATED

&#x20;↓

DISCOVERABLE

&#x20;↓

JOINING

&#x20;↓

CALIBRATING

&#x20;↓

READY

&#x20;↓

PLAYING

&#x20;↓

PAUSED

&#x20;↓

RECOVERING

&#x20;↓

PLAYING

&#x20;↓

ENDING

&#x20;↓

CLOSED

```



\### Exit criteria



Invalid transitions are rejected and recovery states are explicit.



\---



\# 23. Phase 19 — Real SoundMesh UI



\*\*Status:\*\* REQUIRED



Only after the core system is proven should the complete polished UI be integrated.



\### Implement



\* Home

\* Create Room

\* Room Waiting

\* QR display

\* Join Room

\* QR scanner

\* Device list

\* Mesh visualization

\* Audio picker

\* Preparing

\* Synchronizing

\* Playback

\* Device details

\* Diagnostics

\* Settings

\* Error/recovery screens



\### Principle



The UI should expose simple actions while hiding technical complexity.



\---



\# 24. Phase 20 — UX Refinement



\*\*Status:\*\* REQUIRED



Improve:



\* transitions

\* loading states

\* empty states

\* errors

\* recovery guidance

\* accessibility

\* responsive layouts

\* animation

\* typography

\* spacing

\* visual hierarchy



\### Quality bar



The application should feel intentional and premium rather than like a technical prototype.



\---



\# 25. Phase 21 — Diagnostics



\*\*Status:\*\* REQUIRED



Implement a diagnostic interface useful during testing.



Possible metrics:



```text

Connected devices

Connection state

RTT

Clock offset

Timing uncertainty

Calibration confidence

Playback state

Playback position

Estimated drift

Correction state

Network state

Audio state

```



\### Rule



Diagnostics should be useful to developers without exposing unnecessary technical complexity to ordinary users.



\---



\# 26. Phase 22 — Performance Optimization



\*\*Status:\*\* REQUIRED



Only optimize after measurement.



Measure:



\* CPU

\* memory

\* battery

\* thermal behavior

\* bandwidth

\* startup time

\* calibration time

\* audio preparation time



\### Priority



```text

Audio stability

&#x20;↓

Synchronization

&#x20;↓

Networking

&#x20;↓

Application responsiveness

&#x20;↓

Visual performance

```



\---



\# 27. Phase 23 — Reliability Campaign



\*\*Status:\*\* CRITICAL



Run repeated sessions.



Example:



```text

50 sessions

100 sessions

```



where practical.



Record:



\* successful room creation

\* successful joining

\* successful transfer

\* successful calibration

\* successful playback

\* synchronization failures

\* recovery failures

\* crashes



The exact number of runs may change depending on available devices and development time.



\---



\# 28. Phase 24 — Physical Synchronization Validation



\*\*Status:\*\* CRITICAL



Use external measurement to validate actual sound output.



\### Procedure



```text

Multiple phones

&#x20;↓

Known test signal

&#x20;↓

Simultaneous recording

&#x20;↓

Waveform analysis

&#x20;↓

Measured onset differences

```



\### Goal



Confirm that software synchronization corresponds to physical acoustic synchronization.



\### Required reporting



For important experiments:



\* test ID

\* device models

\* audio asset

\* network

\* software version

\* number of runs

\* measured spread

\* anomalies

\* conclusion



\---



\# 29. Phase 25 — Competitive Differentiation



\*\*Status:\*\* REQUIRED



The project should identify and demonstrate why SoundMesh is compelling beyond the basic concept.



Potential demonstrated strengths:



\* fast QR onboarding

\* local-first operation

\* automatic calibration

\* synchronization diagnostics

\* drift correction

\* heterogeneous device support

\* robust recovery

\* measurable synchronization



Claims must be supported by evidence.



\---



\# 30. Phase 26 — Demo Engineering



\*\*Status:\*\* REQUIRED



Create a reliable demonstration environment.



\### Demo goal



The first impression should communicate:



> Multiple phones are behaving like one speaker.



\### Demo sequence



```text

Open SoundMesh

&#x20;↓

Create Room

&#x20;↓

Show QR

&#x20;↓

Multiple phones scan

&#x20;↓

Devices appear

&#x20;↓

Audio selected

&#x20;↓

Preparing

&#x20;↓

Synchronizing

&#x20;↓

Play

&#x20;↓

All phones play together

```



The demo should avoid unnecessary technical explanations.



\---



\# 31. Phase 27 — Competition Hardening



\*\*Status:\*\* REQUIRED



Before submission:



\* freeze major architecture

\* resolve critical bugs

\* test supported devices

\* test core flows repeatedly

\* verify build/release process

\* verify repository cleanliness

\* verify open-source requirements

\* verify documentation

\* verify demo

\* verify submission materials



No major architecture changes should be introduced immediately before submission without strong justification.



\---



\# 32. Phase 28 — Submission Preparation



\*\*Status:\*\* REQUIRED



Prepare:



\* final source repository

\* license

\* README

\* demo video

\* project description

\* technical explanation

\* screenshots

\* architecture summary

\* testing evidence

\* student verification materials

\* required competition submission information



All competition requirements must be checked against the current official rules before submission.



\---



\# 33. Milestone Definitions



\## M0 — Repository Ready



```text

Docs

\+

Project structure

\+

AI rules

\+

Build

```



\---



\## M1 — Two Devices Connected



```text

Phone A

&#x20;↕

Phone B

```



Structured local communication works.



\---



\## M2 — Audio Transfer Works



Both devices have the same verified audio asset.



\---



\## M3 — Two Devices Synchronized



Both devices perform scheduled synchronized playback.



This is the most important technical milestone.



\---



\## M4 — Synchronization Maintained



Drift is measured and controlled.



\---



\## M5 — Five Devices



Five physical phones participate in one room.



\---



\## M6 — Recovery



Disconnects and other failures are handled predictably.



\---



\## M7 — Production UX



The full intended user experience is implemented.



\---



\## M8 — Validation Complete



Physical measurements and repeated tests support synchronization claims.



\---



\## M9 — Competition Ready



The project is stable, documented, demonstrable, and ready for submission.



\---



\# 34. Dependency Graph



The approximate dependency structure is:



```text

Repository

&#x20;  ↓

Flutter shell

&#x20;  ↓

Native bridge

&#x20;  ↓

Networking

&#x20;  ↓

Room protocol

&#x20;  ↓

Audio transfer

&#x20;  ↓

Native playback

&#x20;  ↓

Playback scheduling

&#x20;  ↓

Clock synchronization

&#x20;  ↓

Two-device synchronized playback

&#x20;  ↓

Monitoring

&#x20;  ↓

Drift correction

&#x20;  ↓

Playback controls

&#x20;  ↓

Multi-device scaling

&#x20;  ↓

Recovery

&#x20;  ↓

Polished UX

&#x20;  ↓

Physical validation

&#x20;  ↓

Competition hardening

```



\---



\# 35. What Must NOT Happen



The following development order is discouraged:



```text

Beautiful UI

&#x20;↓

Animations

&#x20;↓

Settings

&#x20;↓

Accounts

&#x20;↓

Cloud backend

&#x20;↓

Playlists

&#x20;↓

Social features

&#x20;↓

...

&#x20;↓

Eventually investigate synchronization

```



This is backwards for SoundMesh.



The core technical risk must be attacked early.



\---



\# 36. Parallel Development



Some work can happen in parallel after dependencies are stable.



Example:



```text

Synchronization Team

&#x20;       │

&#x20;       ├── Clock model

&#x20;       ├── Scheduling

&#x20;       └── Drift correction



Networking Team

&#x20;       │

&#x20;       ├── Room protocol

&#x20;       ├── QR joining

&#x20;       └── Recovery



UI Team

&#x20;       │

&#x20;       ├── Screens

&#x20;       ├── Components

&#x20;       └── Design system

```



However, parallel work must respect file ownership and architectural boundaries.



Two AI agents must not simultaneously modify the same critical subsystem without coordination.



\---



\# 37. AI Development Strategy



AI agents should receive small, well-defined tasks.



Bad:



> Build SoundMesh.



Good:



> Implement the participant-side timestamp exchange described in `synchronization.md`, add unit tests for RTT and offset calculation, and do not modify the transport layer.



Every AI task should specify:



\* objective

\* scope

\* allowed files

\* relevant specifications

\* acceptance criteria

\* tests

\* known constraints



The detailed procedure belongs in:



```text

DOCS/AI/task-protocol.md

```



\---



\# 38. Definition of Phase Completion



A phase is not complete because code exists.



A phase is complete when:



```text

Implementation

\+

Tests

\+

Verification

\+

Documentation

\+

Acceptance criteria

```



have been satisfied.



\---



\# 39. Roadmap Change Policy



This roadmap is a living plan.



It may change when:



\* experiments invalidate an assumption

\* platform limitations appear

\* a technical approach proves unreliable

\* competition requirements change

\* testing reveals a better architecture



However, roadmap changes must not silently change architectural decisions.



Architecture changes belong in `decisions.md`.



\---



\# 40. Priority Levels



Every roadmap task should be classified as:



\### P0 — Core Risk



Must happen immediately.



Examples:



\* native scheduling

\* clock synchronization

\* two-device playback



\### P1 — Core Product



Required for MVP.



Examples:



\* QR joining

\* audio transfer

\* playback controls

\* recovery



\### P2 — Quality



Important after core functionality.



Examples:



\* diagnostics

\* performance optimization

\* accessibility refinement



\### P3 — Polish



Useful but not blocking.



Examples:



\* advanced animations

\* additional visual effects



\### P4 — Future



Not part of MVP.



Examples:



\* cloud rooms

\* social features

\* large-scale remote sessions



\---



\# 41. Recommended Immediate Build Sequence



The first implementation sequence should be:



```text

1\. Flutter project

2\. Native bridge

3\. Two-device local networking

4\. Room protocol

5\. QR joining

6\. Audio transfer

7\. Native local playback

8\. Native scheduled playback

9\. Clock synchronization

10\. Two-device synchronized playback

11\. Physical synchronization measurement

12\. Drift monitoring

13\. Drift correction

14\. Playback controls

15\. Three-device testing

16\. Five-device testing

17\. Recovery

18\. Full UI integration

19\. Performance

20\. Competition hardening

```



This order deliberately prioritizes technical risk.



\---



\# 42. The Most Important Milestone



The single most important milestone is:



> \*\*Two real phones playing the same audio at a measured, repeatable, perceptually coherent synchronization level.\*\*



Until this exists, SoundMesh is primarily a hypothesis.



Once this exists, the remaining work becomes progressively more about:



\* reliability

\* scaling

\* recovery

\* UX

\* polish

\* competition presentation



\---



\# 43. Final Roadmap Principle



Do not ask:



> “What feature should we build next?”



Ask:



> \*\*“What is the highest-risk assumption we can prove or disprove next?”\*\*



That question should guide SoundMesh development.



The project should continuously move from:



```text

Unknown

&#x20;↓

Experiment

&#x20;↓

Evidence

&#x20;↓

Decision

&#x20;↓

Implementation

&#x20;↓

Test

&#x20;↓

Reliable feature

```



rather than:



```text

Idea

&#x20;↓

Code

&#x20;↓

Hope

```



\---



\# 44. Final Objective



The roadmap ultimately leads to one simple demonstration:



```text

&#x20;       SOUND MESH



&#x20;    📱      📱

&#x20;      \\    /

&#x20;       \\  /

&#x20;        📱

&#x20;       /  \\

&#x20;      /    \\

&#x20;    📱      📱



&#x20;       🔊🔊🔊

&#x20;  One synchronized system

```



The engineering underneath may be complex.



The roadmap exists to ensure that complexity is introduced \*\*only when it is necessary to make the experience reliable.\*\*



\*\*End of Engineering Roadmap.\*\*



