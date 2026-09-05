\# SoundMesh — Product Blueprint



> \*\*Document status:\*\* Living specification

> \*\*Document role:\*\* Master product definition

> \*\*Authority:\*\* This document defines what SoundMesh is, why it exists, what the MVP must accomplish, and the boundaries within which engineering decisions are made.

>

> \*\*Important:\*\* Technical implementation details belong primarily in the specialized documents under `DOCS/`. When this document conflicts with a specialized technical specification, the conflict must be resolved explicitly and recorded in `DOCS/decisions.md`. AI agents must not silently choose between conflicting requirements.



\---



\# 1. Product Identity



\## 1.1 Name



\*\*SoundMesh\*\*



\## 1.2 One-Sentence Description



SoundMesh is a local-first mobile application that allows multiple nearby smartphones to synchronize their speakers and play the same audio together, turning a group of phones into a coordinated distributed speaker system.



\## 1.3 Core Concept



A user may have several phones available but no physical speaker.



SoundMesh allows those phones to cooperate so that their built-in speakers reproduce the same audio at approximately the same moment.



The central technical challenge is not simply sending audio to multiple phones.



The central challenge is \*\*coordinating independent mobile devices so that their audio playback remains perceptually synchronized despite differences in device hardware, audio pipelines, clocks, network conditions, buffering, and operating-system behavior.\*\*



\## 1.4 Core Product Statement



> \*\*We had music, we had five phones, and we didn't have a speaker — so we built one.\*\*



This statement captures the origin and intended simplicity of the product.



\---



\# 2. Problem Statement



\## 2.1 User Problem



People sometimes have access to multiple smartphones but do not have access to a physical Bluetooth or wired speaker.



Individually, each phone can produce sound.



Collectively, several phones could potentially produce substantially more audible sound and provide better coverage of a physical space.



However, simply starting the same song on multiple phones does not produce a usable result because even small playback-time differences can produce:



\* echoes

\* flanging

\* phase-related artifacts

\* rhythmic smearing

\* noticeably duplicated sound

\* an unpleasant listening experience



Therefore, the problem is:



> \*\*How can multiple independent smartphones coordinate audio playback closely enough that they are perceived as one distributed speaker system?\*\*



\---



\# 3. Product Goals



\## 3.1 Primary Goal



Create a mobile application that makes it extremely easy for a group of nearby phones to play the same audio together with reliable, perceptually tight synchronization.



\## 3.2 Secondary Goals



SoundMesh should aim to:



1\. Require minimal setup.

2\. Work primarily over local connectivity.

3\. Avoid requiring a cloud service for ordinary playback.

4\. Support a host/device-room model.

5\. Make joining a room fast and understandable.

6\. Automatically handle timing calibration rather than requiring users to manually tune devices.

7\. Continue functioning under realistic local-network conditions.

8\. Provide useful diagnostics when synchronization cannot be achieved.

9\. Make device joining and leaving resilient.

10\. Demonstrate measurable synchronization quality rather than merely claiming that devices are synchronized.



\## 3.3 Engineering Goal



The project should prioritize \*\*synchronization quality and reliability over feature count\*\*.



A smaller application with excellent synchronization is preferable to a feature-rich application with unreliable playback.



\---



\# 4. Non-Goals



The following are not core objectives of the MVP.



\## 4.1 Physical Speaker Replacement



SoundMesh is not intended to reproduce the acoustic quality of a dedicated physical speaker.



The application coordinates existing phone speakers.



\## 4.2 Professional Multi-Room Audio



The MVP is not intended to compete with professional multi-room audio systems.



\## 4.3 Long-Distance Streaming



The MVP is designed for nearby devices participating in a local group.



Internet-based long-distance synchronization is not a core requirement.



\## 4.4 Music Streaming Service



SoundMesh is not intended to become a music catalog or streaming platform.



The application should focus on synchronized playback rather than content licensing or music discovery.



\## 4.5 Social Network



User profiles, followers, messaging, public rooms, feeds, and similar social features are outside the MVP.



\## 4.6 Cloud Dependency



A remote server must not be required for the fundamental local playback experience unless a later architectural decision explicitly determines that a server is necessary.



\## 4.7 Unlimited Device Support



The system should be architected so that multiple devices can participate, but the MVP must establish a realistic tested device-count target rather than claiming unlimited scalability.



\---



\# 5. Target User Experience



\## 5.1 Desired Experience



A user should be able to:



1\. Open SoundMesh.

2\. Create a room.

3\. Receive a simple join mechanism.

4\. Have nearby devices join the room.

5\. Select audio.

6\. Allow SoundMesh to prepare and synchronize participating devices.

7\. Start playback.

8\. Hear the participating phones behave approximately like a single distributed speaker.

9\. Add or remove devices without unnecessarily disrupting the session.



The exact UI and technical mechanism are defined in the appropriate specialized documents.



\## 5.2 Simplicity Requirement



Users should not need to understand:



\* clock synchronization

\* network latency

\* buffering

\* audio timestamps

\* drift correction

\* device clock offsets

\* packet timing

\* sample rates

\* audio session configuration



Those concepts belong to the implementation.



The product should hide technical complexity wherever possible.



\---



\# 6. Core System Model



SoundMesh is conceptually composed of:



```text

&#x20;               ┌──────────────────┐

&#x20;               │      Host        │

&#x20;               │                  │

&#x20;               │ Room Controller  │

&#x20;               └────────┬─────────┘

&#x20;                        │

&#x20;             Local Network / P2P

&#x20;                        │

&#x20;       ┌────────────────┼────────────────┐

&#x20;       │                │                │

&#x20;       ▼                ▼                ▼

&#x20;  ┌─────────┐      ┌─────────┐      ┌─────────┐

&#x20;  │ Device A│      │ Device B│      │ Device C│

&#x20;  │ Speaker │      │ Speaker │      │ Speaker │

&#x20;  └─────────┘      └─────────┘      └─────────┘

```



The exact networking topology is intentionally not fixed by this document.



Possible mechanisms may include local Wi-Fi, a phone hotspot, Wi-Fi Direct, or another platform-supported local communication mechanism.



The final mechanism must be selected through technical investigation and documented in:



\* `DOCS/networking.md`

\* `DOCS/architecture.md`

\* `DOCS/decisions.md`



\---



\# 7. Fundamental Playback Model



The preferred conceptual model is:



> \*\*Distribute the required audio to participating devices first, then synchronize local playback.\*\*



This is preferred over continuously streaming the audio independently to every device if local distribution and storage make that practical.



\## 7.1 Reasoning



If every device possesses the same audio data locally, synchronization becomes primarily a timing problem rather than a continuous network-streaming problem.



This potentially reduces sensitivity to:



\* network jitter

\* packet loss

\* temporary bandwidth changes

\* inconsistent streaming buffers

\* network congestion during playback



However, this is a design hypothesis rather than an unconditional requirement.



The implementation must validate whether local audio distribution provides the best overall architecture.



\## 7.2 Audio Identity



All participating devices must play an equivalent source representation whenever synchronization depends on identical audio content.



The system must define how it identifies and validates that participating devices have compatible audio content.



This should be specified in `DOCS/audio.md`.



\---



\# 8. Synchronization Is the Core Technology



Synchronization is the defining technical problem of SoundMesh.



The system must not assume that issuing a "play" command to several phones simultaneously results in simultaneous audible playback.



Each device has its own:



\* hardware

\* system clock

\* audio subsystem

\* buffering behavior

\* processing latency

\* network latency

\* operating-system scheduling behavior

\* audio output route



Therefore SoundMesh requires an explicit synchronization strategy.



\## 8.1 Synchronization Objectives



The synchronization system should investigate and, where technically feasible, implement:



\* device clock offset estimation

\* network latency measurement

\* timestamp exchange

\* synchronized future playback scheduling

\* startup calibration

\* buffering

\* playback-position monitoring

\* drift detection

\* drift correction

\* recovery after temporary network disruption

\* handling of late-joining devices

\* handling of paused/resumed devices

\* handling of audio-route changes



\## 8.2 Perceptual Synchronization



The product should target synchronization that is sufficiently close for human listeners to perceive the devices as a coordinated sound source.



The project must \*\*not\*\* claim mathematically perfect synchronization without measurements supporting such a claim.



Acceptance thresholds must be experimentally determined and documented in `DOCS/synchronization.md`.



\---



\# 9. Device Roles



\## 9.1 Host



The host is responsible for coordinating the room.



Depending on the final architecture, the host may:



\* create the room

\* coordinate discovery

\* distribute session information

\* coordinate audio distribution

\* establish a shared playback timeline

\* initiate playback

\* monitor participating devices

\* coordinate synchronization corrections



The host should not necessarily perform all work if doing so creates an unnecessary bottleneck.



\## 9.2 Participant



A participant is a phone contributing its speaker to the SoundMesh session.



A participant should:



\* join the room

\* establish communication with the host and/or peers

\* obtain required audio data

\* synchronize its clock/timing state

\* prepare its playback buffer

\* begin playback at the assigned time

\* report relevant synchronization state

\* respond to synchronization corrections

\* handle session termination gracefully



\---



\# 10. Room Model



A SoundMesh session is represented as a room.



A room should have:



\* a unique session identifier

\* a host

\* participating devices

\* synchronization state

\* playback state

\* current audio/session information

\* connection state



The exact room protocol belongs in `DOCS/networking.md`.



\## 10.1 Room Lifecycle



Conceptually:



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

PAUSED / RECOVERING

&#x20;  ↓

PLAYING

&#x20;  ↓

ENDING

&#x20;  ↓

CLOSED

```



The final state machine must be defined technically before implementation of complex session behavior.



\---



\# 11. Joining a Room



Joining should be intentionally simple.



A preferred UX direction is a visual join mechanism such as a QR code.



Conceptually:



```text

Host

&#x20; ↓

Create Room

&#x20; ↓

Display Join Code / QR

&#x20; ↓

Participant Scans

&#x20; ↓

Connect

&#x20; ↓

Synchronize / Calibrate

&#x20; ↓

Ready

```



The exact mechanism must be validated against the chosen networking architecture.



\---



\# 12. Audio Playback



SoundMesh's audio subsystem must be treated as a first-class engineering component.



The system must account for:



\* supported audio formats

\* decoding

\* sample rate

\* channel configuration

\* buffering

\* playback position

\* output-device selection

\* audio focus/session behavior

\* interruptions

\* pause/resume

\* background behavior

\* device-specific audio behavior



These details belong in `DOCS/audio.md`.



The blueprint intentionally does not prescribe a specific audio library or playback engine until the platform and implementation research is complete.



\---



\# 13. Networking Principles



SoundMesh should follow these principles:



\### Local-first



The fundamental experience should work using nearby connectivity whenever technically feasible.



\### Minimal external dependency



A cloud backend should not become a mandatory dependency without a documented architectural reason.



\### Resilience



Temporary network problems should not unnecessarily destroy an entire session.



\### Explicit state



Devices should know whether they are:



\* disconnected

\* connecting

\* connected

\* synchronizing

\* ready

\* playing

\* recovering

\* leaving



\### Measurability



Networking behavior relevant to synchronization should be measurable rather than assumed.



Detailed networking requirements belong in `DOCS/networking.md`.



\---



\# 14. Synchronization Principles



The synchronization system should follow these principles:



1\. Never assume device clocks are identical.

2\. Never assume network latency is zero.

3\. Never assume network latency is constant.

4\. Never assume audio-output latency is identical across devices.

5\. Prefer scheduled playback over simultaneous command arrival.

6\. Measure timing wherever practical.

7\. Correct drift rather than assuming playback remains perfectly aligned forever.

8\. Design for heterogeneous devices.

9\. Make synchronization state observable during development.

10\. Establish measurable acceptance criteria through testing.



Detailed synchronization architecture belongs in `DOCS/synchronization.md`.



\---



\# 15. Heterogeneous Device Requirement



SoundMesh must be designed for phones with different:



\* CPU performance

\* RAM capacity

\* speaker hardware

\* Android versions / supported mobile operating systems

\* audio hardware

\* sample rates

\* audio output latency

\* network hardware

\* Wi-Fi performance

\* battery states

\* thermal conditions



Testing on only one device is insufficient evidence that the synchronization architecture works.



The testing strategy must therefore include multiple physical devices where available.



\---



\# 16. Failure Handling



SoundMesh must assume that failures will happen.



Potential failures include:



\* participant disconnects

\* host disconnects

\* Wi-Fi changes

\* network temporarily becomes unavailable

\* device locks

\* application loses foreground status

\* audio output route changes

\* another application interrupts audio

\* device becomes overloaded

\* audio file transfer fails

\* participant joins too late

\* synchronization calibration fails

\* participant clock estimation becomes stale

\* playback drifts

\* a participant pauses independently



The application must define expected behavior for important failure conditions.



No AI developer should invent failure behavior silently.



If behavior is undecided, it must be marked as `UNDECIDED` and recorded in the appropriate documentation.



\---



\# 17. MVP Definition



The MVP should demonstrate the fundamental SoundMesh thesis.



\## 17.1 Required MVP Capability



The MVP must be capable of:



\* creating a local session

\* joining a local session

\* identifying participating devices

\* providing the required audio to participants using the selected architecture

\* preparing playback

\* synchronizing playback

\* starting playback across multiple devices

\* maintaining synchronization for a meaningful playback period

\* displaying basic connection/session state

\* leaving or ending a session cleanly



\## 17.2 MVP Device Target



The first engineering milestone should prioritize:



\*\*2 physical devices\*\*



before attempting larger groups.



Once two-device synchronization is reliable, testing should expand to:



\*\*3 → 5 → larger tested groups\*\*



The exact maximum target should be determined experimentally.



\## 17.3 MVP Success



The MVP is not successful merely because:



> "The song plays on both phones."



It is successful when:



> "The phones play the same audio closely enough that the result is perceptually coherent and the synchronization remains reliable under realistic conditions."



\---



\# 18. Quality Requirements



SoundMesh should prioritize:



\### Reliability



A normal user session should not require repeated manual reconnection or timing adjustments.



\### Synchronization



The application should maintain synchronization within a measured, documented target.



\### Simplicity



The user should not need technical knowledge to create or join a session.



\### Transparency



When something fails, the application should communicate the state clearly rather than silently appearing broken.



\### Performance



The synchronization system should avoid unnecessary CPU, memory, battery, and network consumption.



\### Maintainability



Architecture should be modular enough that networking, synchronization, audio, and UI can be developed and tested independently.



\---



\# 19. Measurement and Validation



SoundMesh must be treated as an engineering experiment as well as an application.



Important claims should be measurable.



Potential measurements include:



\* estimated inter-device playback offset

\* synchronization error over time

\* synchronization error after startup

\* synchronization error after drift correction

\* network round-trip time

\* calibration duration

\* audio preparation duration

\* join duration

\* recovery time after connection interruption

\* CPU usage

\* memory usage

\* battery impact

\* maximum reliably tested device count



The exact measurement methodology must be defined in:



`DOCS/testing.md`



and, for timing-specific measurements:



`DOCS/synchronization.md`



\---



\# 20. Product Differentiation



The basic idea of synchronizing multiple phones as speakers is not itself novel.



Therefore SoundMesh should not depend on novelty of the basic concept.



The project's differentiation should come from \*\*execution quality\*\*.



Potential differentiation areas include:



\* highly automated synchronization

\* automatic latency calibration

\* robust synchronization across different phones

\* local-first operation

\* easy room creation

\* QR-based onboarding

\* resilient session management

\* synchronization diagnostics

\* measurable synchronization quality

\* graceful handling of drift and temporary network problems

\* an architecture optimized specifically for heterogeneous consumer phones



These are product/engineering hypotheses and must be validated through research and testing.



\---



\# 21. Competitive Awareness



Existing applications and prior projects demonstrate that multi-device synchronized audio is an established concept.



Therefore the development team must not make claims such as:



\* "SoundMesh is the first app to do this."

\* "Nobody has ever built this."

\* "This technology has never been attempted."



Unless such a claim has been specifically researched and verified, it must not appear in product materials.



The project should instead emphasize its implementation, engineering quality, user experience, and measured results.



Competitive research belongs in the appropriate project documentation and should be updated when significant competitors are identified.



\---



\# 22. Security and Privacy Principles



SoundMesh should follow a local-first privacy model where practical.



The MVP should minimize unnecessary collection of:



\* personal information

\* user accounts

\* location information

\* usage analytics

\* cloud-stored audio

\* identifiable device information



Communication protocols should be designed with reasonable protection against unintended room access and unauthorized participation.



Detailed security requirements should be documented once the networking architecture is selected.



\---



\# 23. Architecture Constraints



The implementation should avoid unnecessary complexity.



The team should prefer:



\* simple protocols

\* explicit state machines

\* measurable behavior

\* modular components

\* well-defined interfaces

\* deterministic behavior where possible

\* local processing where practical



The team should avoid:



\* premature microservices

\* unnecessary cloud infrastructure

\* unnecessary authentication systems

\* unnecessary databases

\* feature creep

\* speculative abstractions

\* adding dependencies without a clear reason



\---



\# 24. Technology Decision Policy



The blueprint does \*\*not\*\* permanently mandate a specific framework, networking library, audio engine, synchronization algorithm, or state-management library.



Those decisions must be made after technical investigation.



Every significant architectural decision should document:



1\. The problem.

2\. Candidate approaches.

3\. Evidence.

4\. Advantages.

5\. Disadvantages.

6\. Constraints.

7\. Chosen approach.

8\. Reason for choosing it.

9\. Consequences.

10\. What would cause the decision to be reconsidered.



Record significant decisions in:



`DOCS/decisions.md`



\---



\# 25. Documentation Authority



The project documentation has specialized responsibilities.



| Document              | Responsibility                                        |

| --------------------- | ----------------------------------------------------- |

| `blueprint.md`        | Product definition and overall requirements           |

| `architecture.md`     | System architecture and component relationships       |

| `synchronization.md`  | Timing and synchronization engineering                |

| `networking.md`       | Device communication and networking                   |

| `audio.md`            | Audio acquisition, processing, decoding, and playback |

| `ui-ux.md`            | Interface and user experience                         |

| `testing.md`          | Testing strategy and validation                       |

| `decisions.md`        | Architectural and technical decisions                 |

| `roadmap.md`          | Development phases and milestones                     |

| `AI/ai-context.md`    | High-value project context for AI developers          |

| `AI/rules.md`         | Rules AI developers must follow                       |

| `AI/task-protocol.md` | Standard workflow for AI-generated development tasks  |



The root `AGENTS.md` provides the operational rules that AI coding agents must follow inside the repository.



\---



\# 26. Requirement Status Vocabulary



To prevent AI developers from treating assumptions as facts, requirements should use explicit status terminology.



\### `REQUIRED`



Must be implemented.



\### `PREFERRED`



Strongly desired, but may be changed if technical evidence demonstrates a better approach.



\### `OPTIONAL`



May be implemented if time and architecture permit.



\### `UNDECIDED`



Not yet determined.



AI agents must not silently convert `UNDECIDED` requirements into implementation decisions.



\### `REJECTED`



Explicitly ruled out.



\### `EXPERIMENTAL`



Being investigated or prototyped and not yet part of the stable architecture.



\---



\# 27. Change Management



This blueprint is a living document.



When an important product requirement changes:



1\. Update this document.

2\. Identify affected specialized documentation.

3\. Update affected documents.

4\. Record the decision in `DOCS/decisions.md` when appropriate.

5\. Check whether implementation tasks or roadmap items are now obsolete.

6\. Inform active developers/AI agents of the change.



AI agents must not modify product requirements merely to make their implementation easier.



\---



\# 28. Definition of Done for the Product Blueprint



This document should be considered sufficiently mature when:



\* the core problem is unambiguous

\* the product's purpose is unambiguous

\* MVP boundaries are clear

\* major non-goals are explicit

\* synchronization is identified as a core engineering problem

\* networking responsibilities are clear

\* audio responsibilities are clear

\* failure handling is recognized

\* measurable quality requirements exist

\* important unknowns are explicitly marked

\* specialized documentation responsibilities are defined

\* AI developers can understand the product without guessing its fundamental purpose



\---



\# 29. Current Open Questions



The following questions must be answered through research, experiments, or explicit architectural decisions.



1\. Which mobile platform(s) will be supported for the MVP?

2\. Which framework will be used?

3\. What local networking mechanism provides the best reliability across supported devices?

4\. Can the required communication work reliably without internet access?

5\. How will audio be distributed between devices?

6\. Which audio formats should the MVP support?

7\. Which playback engine provides the required timing control?

8\. How will device clocks be synchronized or related to a shared timeline?

9\. How will network latency be measured?

10\. How will audio-output latency differences be estimated or compensated?

11\. What synchronization error is perceptually acceptable?

12\. How will synchronization be measured objectively?

13\. How will playback drift be detected?

14\. How will drift be corrected without producing audible artifacts?

15\. What happens when a participant joins after playback begins?

16\. What happens when the host disconnects?

17\. What happens when a participant temporarily loses connectivity?

18\. What happens when the operating system interrupts audio?

19\. What happens when a phone switches audio output?

20\. What is the maximum reliably supported device count for the MVP?

21\. How much battery and CPU usage is acceptable?

22\. What restrictions do mobile operating systems impose on background/local networking and audio playback?

23\. What security mechanism should protect room membership?

24\. What synchronization diagnostics should be exposed to developers?

25\. Which technical claims can be experimentally demonstrated for the final submission?



These questions must be resolved in the appropriate technical documents before they become hidden assumptions in implementation.



\---



\# 30. Guiding Principle



SoundMesh should always optimize for this:



> \*\*Make multiple independent phones behave like one coordinated speaker system, while hiding the complexity required to make that happen.\*\*



The product should be simple for the user precisely because the engineering underneath it is rigorous.



\*\*User experience should feel effortless.

Engineering should not be.\*\*



