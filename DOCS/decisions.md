\# SoundMesh — Engineering Decision Log



\*\*Document Status:\*\* REQUIRED

\*\*Document Type:\*\* Engineering Decision Record / Architecture Decision Log

\*\*Applies To:\*\* Entire SoundMesh repository

\*\*Primary Authority:\*\* Engineering and architectural decisions

\*\*Last Updated:\*\* Initial specification



\---



\# 1. Purpose



This document records important engineering, architectural, product, networking, audio, synchronization, and development decisions made for SoundMesh.



Its primary purpose is to prevent:



\* accidental architectural drift

\* repeated debates

\* contradictory implementations

\* AI agents silently changing decisions

\* developers choosing technologies without understanding constraints

\* previously rejected approaches being reintroduced without new evidence

\* `UNDECIDED` questions being treated as decided

\* experiments being mistaken for production architecture



This document is a \*\*decision ledger\*\*, not a general explanation of SoundMesh.



Detailed implementation requirements belong in the other specifications.



\---



\# 2. Decision Authority



When a decision is explicitly marked `DECIDED`, developers and AI agents should treat it as an established project constraint.



A `DECIDED` item must not be changed casually.



Changing a significant decision requires:



1\. identifying the existing decision

2\. explaining why it is no longer appropriate

3\. documenting new evidence

4\. evaluating consequences

5\. recording the replacement decision

6\. updating affected specifications



\---



\# 3. Decision Status Vocabulary



Every decision must have one of the following statuses.



\## DECIDED



The project has committed to this approach.



Implementation should follow it.



\---



\## EXPERIMENTAL



The project is actively testing this approach.



It must not automatically be treated as permanent architecture.



Experimental implementations should be isolated where practical.



\---



\## UNDECIDED



The project has not made a final choice.



AI agents MUST NOT silently choose an option and treat it as an official decision.



\---



\## PREFERRED



One approach is currently favored, but evidence is insufficient for a final commitment.



\---



\## REJECTED



The approach has intentionally been rejected.



It should not be reintroduced unless meaningful new evidence changes the situation.



\---



\## SUPERSEDED



The decision was previously valid but has been replaced by a newer decision.



The historical record should remain.



\---



\# 4. Decision Rules



\## Rule 1 — Do Not Silently Change Decisions



AI agents must not change a `DECIDED` architectural choice because another approach appears easier.



\---



\## Rule 2 — Do Not Resolve UNDECIDED Items Automatically



If a task depends on an undecided choice:



1\. identify the dependency

2\. determine whether a reversible experiment is possible

3\. otherwise stop and request a decision



Do not silently convert:



```text

UNDECIDED

```



into:



```text

DECIDED

```



\---



\## Rule 3 — Evidence Beats Preference



Technical decisions should be based on:



\* real-device testing

\* platform documentation

\* measured performance

\* synchronization measurements

\* compatibility

\* reliability

\* maintainability



rather than:



\* personal preference

\* familiarity

\* hype

\* assumptions

\* what another project uses



\---



\## Rule 4 — MVP Simplicity



If two approaches satisfy the same requirement, prefer the approach with:



\* fewer dependencies

\* fewer moving parts

\* lower maintenance cost

\* clearer failure behavior

\* easier testing

\* easier debugging



\---



\## Rule 5 — Reversibility



When evidence is insufficient, prefer experiments that can be replaced without rewriting unrelated systems.



\---



\# 5. ADR Format



Significant future decisions should follow:



```text

Decision ID:

Title:

Status:

Date:

Category:



Context:

Decision:

Rationale:

Alternatives considered:

Rejected alternatives:

Consequences:

Dependencies:

Evidence:

Affected documents:

Follow-up:

```



\---



\# 6. DEC-001 — Product Concept



\*\*Status:\*\* DECIDED



\*\*Category:\*\* Product



\### Decision



SoundMesh is a mobile application that allows multiple nearby phones to coordinate audio playback so that they behave as one synchronized speaker system.



\### Core user promise



> \*\*Turn nearby phones into one synchronized speaker.\*\*



\### Rationale



The product originated from a real-world situation:



\* multiple people had phones

\* no physical speaker was available

\* the phones collectively had enough speaker hardware to produce useful sound

\* the problem was coordinating them



The product therefore focuses on synchronization rather than simply audio playback.



\### Consequences



The engineering system must prioritize:



\* synchronization

\* latency measurement

\* drift correction

\* reliable local networking

\* simple joining

\* coordinated playback



\---



\# 7. DEC-002 — Product Name



\*\*Status:\*\* DECIDED



\*\*Decision:\*\* The project name is \*\*SoundMesh\*\*.



The name should be used consistently throughout:



\* application UI

\* repository

\* documentation

\* package/module naming where appropriate

\* branding

\* public submission materials



\---



\# 8. DEC-003 — Mobile-First Product



\*\*Status:\*\* DECIDED



\### Decision



SoundMesh is primarily a mobile application.



Primary platforms:



\* Android

\* iOS



\### Rationale



The core product requires multiple physical phones.



Desktop support is not an MVP requirement.



\---



\# 9. DEC-004 — Flutter Application Layer



\*\*Status:\*\* DECIDED



\### Decision



Flutter is the primary cross-platform application framework.



Flutter owns:



\* UI

\* navigation

\* application orchestration

\* high-level room state

\* user interaction

\* design system

\* presentation



\### Rationale



Flutter allows a shared application layer across Android and iOS while still allowing native platform integrations.



\### Consequence



Flutter must not become the realtime audio engine.



\---



\# 10. DEC-005 — Native Timing-Critical Systems



\*\*Status:\*\* DECIDED



\### Decision



Timing-critical audio and networking functionality should be implemented behind native Android/iOS abstractions where required.



Examples include:



\* native audio scheduling

\* low-level playback timing

\* native audio callbacks

\* platform-specific networking

\* platform-specific timing APIs



\### Rationale



SoundMesh's synchronization quality depends on accurate timing.



High-frequency realtime operations should not depend on Flutter widget or message-loop timing.



\---



\# 11. DEC-006 — Platform Integration Boundary



\*\*Status:\*\* DECIDED



\### Decision



Flutter communicates with native platform implementations through a strongly typed interface.



\*\*Pigeon is the preferred mechanism\*\* for platform APIs where practical.



\### Rule



Do not pass high-frequency realtime audio data through Flutter.



Preferred structure:



```text

Flutter

&#x20; ↓

Typed platform interface

&#x20; ↓

Native implementation

&#x20; ↓

Audio / networking subsystem

```



\---



\# 12. DEC-007 — Local-First Architecture



\*\*Status:\*\* DECIDED



\### Decision



Normal SoundMesh playback must not depend on Internet connectivity.



The core session should operate over a local network.



\### Preferred networks



\* existing local Wi-Fi

\* phone hotspot/local network



\### Rationale



The original problem exists specifically in situations where a physical speaker or reliable Internet connection may not be available.



\### Consequence



Internet/cloud infrastructure must not become a hidden dependency of MVP playback.



\---



\# 13. DEC-008 — Cloud Dependency



\*\*Status:\*\* REJECTED for MVP



SoundMesh will not require a cloud backend for ordinary local playback.



Rejected MVP dependencies include:



\* cloud relay servers

\* mandatory accounts

\* mandatory cloud databases

\* mandatory Internet authentication

\* cloud audio streaming



Future features may introduce optional cloud functionality, but that would require a new decision.



\---



\# 14. DEC-009 — Host / Participant Model



\*\*Status:\*\* DECIDED



SoundMesh uses a conceptual room model with:



```text

Host

Participant

Participant

Participant

...

```



The host coordinates the room.



Participants join the room and synchronize with the shared session.



\### Important distinction



The host is a \*\*coordination authority\*\*, not necessarily a continuous audio-streaming server.



\---



\# 15. DEC-010 — Audio Distribution Strategy



\*\*Status:\*\* PREFERRED



\### Decision



The preferred architecture is:



```text

Host selects audio

&#x20;      ↓

Audio distributed to participants

&#x20;      ↓

Each device prepares local audio

&#x20;      ↓

All devices schedule local playback

&#x20;      ↓

Synchronization maintained

```



rather than:



```text

Host

&#x20;↓

continuous audio stream

&#x20;↓

every participant

```



\### Rationale



Once every device has the audio locally, synchronization becomes primarily a timing problem rather than a continuous network-streaming problem.



\### Consequences



The system should optimize:



\* transfer reliability

\* integrity verification

\* preparation

\* buffering

\* scheduled playback



\---



\# 16. DEC-011 — Continuous Audio Streaming



\*\*Status:\*\* REJECTED for MVP



SoundMesh should not continuously stream decoded audio from the host as the default architecture.



\### Reasons



Continuous streaming introduces additional:



\* bandwidth requirements

\* jitter

\* packet-loss handling

\* buffering complexity

\* latency variability

\* synchronization challenges



Local audio playback is preferred.



\---



\# 17. DEC-012 — QR-Based Joining



\*\*Status:\*\* DECIDED



\### Decision



QR scanning is the preferred MVP room-joining mechanism.



\### Rationale



QR removes unnecessary user interaction involving:



\* IP addresses

\* ports

\* room discovery

\* manual codes

\* network configuration



\### Desired flow



```text

Host:

Create Room

&#x20;↓

Show QR



Participant:

Join Room

&#x20;↓

Scan QR

&#x20;↓

Connect

```



\---



\# 18. DEC-013 — QR Payload



\*\*Status:\*\* PREFERRED



A QR payload should contain temporary room bootstrap information rather than permanent credentials.



Conceptual structure:



```text

soundmesh://join

?room=<room-id>

\&host=<bootstrap-address>

\&port=<bootstrap-port>

\&version=<protocol-version>

\&token=<short-lived-join-token>

```



The exact serialization remains implementation-dependent.



\### QR must NOT contain



\* permanent passwords

\* long-lived secrets

\* private keys

\* full audio files

\* permanent account credentials



\---



\# 19. DEC-014 — IP Address Is Not Device Identity



\*\*Status:\*\* DECIDED



An IP address must not be treated as a permanent device identity.



Reasons include:



\* DHCP changes

\* hotspot behavior

\* network transitions

\* reconnection

\* multiple interfaces



Device identity must be represented independently.



\---



\# 20. DEC-015 — Audio Integrity



\*\*Status:\*\* DECIDED



Transferred audio should be verified for integrity.



A content hash should be used to identify/verify the expected asset.



\### Principle



A participant must not begin synchronized playback from an audio asset that has not been verified as correct.



\---



\# 21. DEC-016 — Scheduled Playback



\*\*Status:\*\* DECIDED



SoundMesh must use scheduled playback as the primary synchronization mechanism.



\### Rejected approach



```text

PLAY NOW

```



\### Preferred approach



```text

Current synchronized time

&#x20;       +

Future playback target

&#x20;       ↓

Schedule playback

```



\### Rationale



Commands arriving at different times cannot produce reliable simultaneous playback.



\---



\# 22. DEC-017 — Shared Playback Timeline



\*\*Status:\*\* DECIDED



SoundMesh uses a shared logical playback timeline.



Participants map their local monotonic/native timing systems to the shared timeline.



The shared timeline is not equivalent to wall-clock time.



\---



\# 23. DEC-018 — Monotonic Timing



\*\*Status:\*\* DECIDED



Synchronization calculations should use monotonic timing sources where available.



Wall clocks must not be used as the sole source of realtime playback synchronization.



\### Rationale



Wall clocks can change because of:



\* user adjustments

\* network time synchronization

\* system corrections

\* timezone changes



Monotonic clocks are appropriate for elapsed-time measurement.



\---



\# 24. DEC-019 — Clock Offset Measurement



\*\*Status:\*\* DECIDED



SoundMesh will estimate relationships between host and participant clocks through timestamp exchanges.



A conceptual exchange:



```text

Participant sends t1

Host receives t2

Host sends t3

Participant receives t4

```



Offset estimation can use the documented timestamp relationship under the appropriate network-delay assumptions.



\---



\# 25. DEC-020 — RTT Measurement



\*\*Status:\*\* DECIDED



Round-trip time must be measured independently from clock offset.



Conceptually:



```text

RTT = (t4 - t1) - (t3 - t2)

```



RTT is a network measurement.



It is not equivalent to:



\* clock offset

\* audio latency

\* speaker latency



\---



\# 26. DEC-021 — Synchronization Is Measured



\*\*Status:\*\* DECIDED



SoundMesh must measure synchronization quality rather than assuming that scheduled commands worked.



Important measurements include:



\* startup spread

\* steady-state spread

\* timing uncertainty

\* clock offset

\* drift

\* RTT

\* calibration duration

\* recovery behavior



\---



\# 27. DEC-022 — Perceptual Synchronization Target



\*\*Status:\*\* DECIDED



The product goal is \*\*perceptually coherent synchronization\*\*, not mathematically identical hardware output.



\### Initial engineering targets



Target group playback spread:



```text

≤ 20 ms

```



Preferred stretch:



```text

≤ 10 ms

```



These are engineering targets, not guaranteed specifications.



Actual performance must be experimentally measured.



\---



\# 28. DEC-023 — External Synchronization Validation



\*\*Status:\*\* DECIDED



Software logs alone are insufficient to prove audible synchronization quality.



External validation should eventually use appropriate measurement methods such as:



\* microphones

\* waveform analysis

\* controlled test signals

\* simultaneous recording

\* physical measurement setups



\### Rationale



The actual sound produced by different phone speakers can differ from the timing predicted by software.



\---



\# 29. DEC-024 — Drift Correction



\*\*Status:\*\* DECIDED



SoundMesh must monitor synchronization after playback begins.



If drift is detected, the system should attempt correction.



Preferred correction hierarchy:



```text

Monitor

&#x20;↓

Tiny playback-rate correction

&#x20;↓

Small position correction

&#x20;↓

Controlled resynchronization

&#x20;↓

Recovery/rejoin if necessary

```



Corrections should prioritize inaudibility.



\---



\# 30. DEC-025 — “Play Now” Rejection



\*\*Status:\*\* REJECTED



Sending an immediate play command independently to every device is not an acceptable primary synchronization mechanism.



Reason:



Network arrival times differ.



Therefore:



```text

Command received ≠ identical playback time

```



\---



\# 31. DEC-026 — Native Audio Engine Strategy



\*\*Status:\*\* EXPERIMENTAL



The exact native audio engine implementation remains subject to device testing.



\### Android candidates



\* Oboe

\* AAudio

\* AudioTrack



\### iOS candidates



\* AVAudioEngine

\* AVAudioPlayerNode

\* AVAudioTime

\* AVAudioSession



The final implementation must be selected based on:



\* scheduling accuracy

\* latency

\* device compatibility

\* stability

\* background behavior

\* CPU usage

\* battery usage



\---



\# 32. DEC-027 — Bluetooth



\*\*Status:\*\* EXPERIMENTAL



Bluetooth audio routes are not guaranteed to provide the same synchronization behavior as local device speakers.



Bluetooth support should therefore be tested separately.



It must not be assumed that synchronization targets achieved through built-in speakers automatically apply to Bluetooth.



\---



\# 33. DEC-028 — Wi-Fi Direct / P2P



\*\*Status:\*\* EXPERIMENTAL



Direct peer-to-peer networking is interesting but is not the required MVP networking foundation.



MVP preference:



```text

Local Wi-Fi / hotspot

```



Future experiments may investigate:



\* Android Wi-Fi Direct

\* iOS peer-to-peer mechanisms

\* Wi-Fi Aware

\* other platform-supported local transports



Cross-platform reliability is more important than theoretical networking elegance.



\---



\# 34. DEC-029 — TCP for Reliable Control



\*\*Status:\*\* DECIDED for MVP baseline



Reliable control and audio-file transfer should use a reliable transport such as TCP unless platform experiments demonstrate a specific requirement for another approach.



Appropriate uses include:



\* room messages

\* handshake

\* device information

\* audio transfer

\* playback commands

\* state synchronization

\* recovery messages



\---



\# 35. DEC-030 — UDP



\*\*Status:\*\* EXPERIMENTAL



UDP may be investigated for specialized timing measurements or future realtime transport.



It must not be introduced merely because it sounds more “realtime.”



Any UDP implementation must demonstrate measurable benefit.



\---



\# 36. DEC-031 — Control Plane / Timing Plane Separation



\*\*Status:\*\* DECIDED



SoundMesh should conceptually separate:



\### Control plane



Handles:



\* room state

\* device state

\* audio transfer

\* commands

\* recovery



\### Timing plane



Handles:



\* timestamp exchanges

\* clock relationship

\* timing measurements

\* synchronization



This separation prevents ordinary control traffic from being confused with realtime timing requirements.



\---



\# 37. DEC-032 — Flutter Realtime Boundary



\*\*Status:\*\* DECIDED



High-frequency synchronization/audio callbacks must remain outside Flutter where possible.



Preferred:



```text

Native realtime system

&#x20;       ↓

Aggregated measurements/state

&#x20;       ↓

Flutter

&#x20;       ↓

UI

```



The UI does not need every internal timing event.



\---



\# 38. DEC-033 — Audio Format Strategy



\*\*Status:\*\* UNDECIDED



The final set of supported audio formats remains to be determined through implementation and compatibility testing.



Factors:



\* platform decoder support

\* file size

\* quality

\* decoding performance

\* licensing

\* metadata support

\* consistency



The application must not assume universal format support without testing.



\---



\# 39. DEC-034 — Sample Rate



\*\*Status:\*\* UNDECIDED



SoundMesh has not yet permanently selected:



\* target sample rate

\* resampling strategy

\* channel normalization strategy



These decisions require real-device testing.



\---



\# 40. DEC-035 — Channel Configuration



\*\*Status:\*\* UNDECIDED



Stereo/mono behavior and channel handling require explicit testing.



The application must not assume that every output device has identical:



\* sample rates

\* channels

\* hardware characteristics

\* output latency



\---



\# 41. DEC-036 — Host Failure



\*\*Status:\*\* DECIDED for MVP



The MVP does not require seamless host migration.



If the host fails, the application may perform controlled recovery.



Future seamless host migration would require a separate architectural decision.



\---



\# 42. DEC-037 — Late Joining



\*\*Status:\*\* DECIDED



Late-joining devices must prepare and synchronize before joining active playback.



They must not simply begin playing immediately upon receiving the current audio command.



\---



\# 43. DEC-038 — Playback Generation Numbers



\*\*Status:\*\* DECIDED



Playback-affecting commands should include a generation/version mechanism where appropriate.



Purpose:



Prevent stale commands from affecting the current playback state.



Example:



```text id="6jj7jq"

Generation 12

PLAY



Generation 13

PAUSE



Old Generation 12

PLAY

```



The stale command must not incorrectly restart playback.



\---



\# 44. DEC-039 — UI Technical Complexity



\*\*Status:\*\* DECIDED



Normal users should not be exposed to technical implementation details.



Normal UI should say:



> Getting everyone in sync…



not:



> Measuring clock offset using NTP-style timestamp exchange.



Diagnostics may expose technical information intentionally.



\---



\# 45. DEC-040 — UI Theme



\*\*Status:\*\* DECIDED



SoundMesh uses a dark-first visual design.



Primary background:



```text

\#0B0D10

```



Primary accent:



```text

\#5B8CFF

```



The UI specification is the authority for all visual tokens.



\---



\# 46. DEC-041 — SoundMesh Blue



\*\*Status:\*\* DECIDED



Primary brand accent:



```text

\#5B8CFF

```



Accent variants:



```text

Light: #7DA5FF

Dark:  #3D6FE0

```



Other saturated colors must not become competing brand colors without a documented decision.



\---



\# 47. DEC-042 — Mesh Visual Language



\*\*Status:\*\* DECIDED



Connected devices are represented conceptually through a mesh/node visual language.



The mesh represents:



\* connection

\* participation

\* coordination

\* synchronization



It should remain subtle and performant.



\---



\# 48. DEC-043 — Premium Visual Direction



\*\*Status:\*\* DECIDED



SoundMesh's visual direction is:



> \*\*Dark, minimal, premium, calm, technical, audio-focused.\*\*



It should avoid:



\* gamer RGB aesthetics

\* excessive neon

\* excessive gradients

\* generic AI-dashboard styling

\* excessive glassmorphism

\* excessive animation



\---



\# 49. DEC-044 — Typography



\*\*Status:\*\* DECIDED



The MVP should prioritize high-quality platform-native typography.



Preferred:



\* SF Pro/system UI on iOS

\* Roboto/system UI on Android



A custom font requires a documented reason.



Typography hierarchy must follow `ui-ux.md`.



\---



\# 50. DEC-045 — Accessibility



\*\*Status:\*\* DECIDED



Accessibility is a required product property.



Requirements include:



\* adequate contrast

\* sufficiently large touch targets

\* screen-reader semantics

\* dynamic text support

\* reduced motion

\* non-color-only status communication

\* accessible error messages



Accessibility is not a post-MVP decoration.



\---



\# 51. DEC-046 — Performance Priority



\*\*Status:\*\* DECIDED



Priority order:



```text

Audio stability

&#x20;↓

Synchronization

&#x20;↓

Network reliability

&#x20;↓

Application responsiveness

&#x20;↓

Visual effects

```



Visual effects must never compromise realtime audio.



\---



\# 52. DEC-047 — No Premature Backend



\*\*Status:\*\* REJECTED for MVP



Do not create:



\* microservices

\* cloud APIs

\* cloud databases

\* user-account systems

\* authentication infrastructure

\* remote media servers



unless an actual MVP requirement requires them.



\---



\# 53. DEC-048 — No Feature Creep



\*\*Status:\*\* DECIDED



Features should not be added simply because they are common in music applications.



Potential non-MVP features include:



\* playlists

\* social profiles

\* music discovery

\* streaming-service integrations

\* cloud libraries

\* advanced equalizers

\* accounts

\* remote rooms

\* social sharing systems



The MVP must prove the core synchronization experience first.



\---



\# 54. DEC-049 — Device Scaling Strategy



\*\*Status:\*\* DECIDED



Testing progression:



```text

2 devices

&#x20;↓

3 devices

&#x20;↓

5 devices

&#x20;↓

larger groups

```



Do not optimize for an arbitrary huge device count before proving reliable synchronization with a small group.



\---



\# 55. DEC-050 — Real Devices Over Simulators



\*\*Status:\*\* DECIDED



Synchronization quality must ultimately be validated on physical devices.



Simulators/emulators may be used for:



\* UI development

\* application logic

\* basic flows



but cannot be considered sufficient proof of real-world synchronization quality.



\---



\# 56. DEC-051 — Measurement Before Optimization



\*\*Status:\*\* DECIDED



Do not optimize synchronization based solely on subjective assumptions.



Measure:



\* RTT

\* timing offset

\* jitter/uncertainty

\* startup spread

\* steady-state spread

\* drift

\* recovery time

\* CPU

\* memory

\* battery



before deciding which subsystem requires optimization.



\---



\# 57. DEC-052 — AI Agent Documentation



\*\*Status:\*\* DECIDED



AI coding agents are expected to use repository documentation as engineering context.



Important documentation:



```text id="wmr7ks"

DOCS/blueprint.md

DOCS/architecture.md

DOCS/networking.md

DOCS/synchronization.md

DOCS/audio.md

DOCS/ui-ux.md

DOCS/decisions.md

DOCS/testing.md

DOCS/roadmap.md

DOCS/AI/\*

AGENTS.md

```



Agents must not rely exclusively on the current prompt.



\---



\# 58. DEC-053 — AI Must Respect Decision States



\*\*Status:\*\* DECIDED



AI agents must distinguish:



```text

DECIDED

PREFERRED

EXPERIMENTAL

UNDECIDED

REJECTED

SUPERSEDED

```



An AI agent must not interpret `UNDECIDED` as permission to permanently choose an implementation.



\---



\# 59. DEC-054 — AI Must Not Rewrite Architecture Without Evidence



\*\*Status:\*\* DECIDED



An AI agent encountering an implementation difficulty must first determine whether:



1\. the implementation is incorrect

2\. the documented architecture is being violated

3\. a platform limitation exists

4\. a smaller workaround exists

5\. an architectural decision genuinely needs revision



The agent must not immediately replace the architecture.



\---



\# 60. DEC-055 — Test Before Claiming Completion



\*\*Status:\*\* DECIDED



An AI agent must not claim:



> “Implemented successfully”



without performing the applicable verification.



The exact verification process is defined in:



```text

DOCS/testing.md

DOCS/AI/task-protocol.md

```



\---



\# 61. DEC-056 — Source of Truth Hierarchy



\*\*Status:\*\* DECIDED



When information conflicts, use the following hierarchy:



```text

1\. Explicit current engineering decision

2\. Relevant detailed specification

3\. Architecture specification

4\. Experimental evidence

5\. Repository implementation

6\. General assumptions

```



However, implementation may reveal that documentation is outdated.



In that situation, the discrepancy must be documented rather than silently ignored.



\---



\# 62. DEC-057 — Documentation Consistency



\*\*Status:\*\* DECIDED



When a major architectural decision changes, all affected documentation must be reviewed.



For example:



Changing networking architecture may require updates to:



```text id="v4mtk8"

architecture.md

networking.md

synchronization.md

audio.md

testing.md

roadmap.md

AI/ai-context.md

```



\---



\# 63. DEC-058 — Experimental Code Must Be Identifiable



\*\*Status:\*\* DECIDED



Experimental implementations should be clearly identifiable in code and documentation.



An experiment must not silently become the permanent architecture merely because it exists in the repository.



\---



\# 64. DEC-059 — Prototype Before Overengineering



\*\*Status:\*\* DECIDED



The team should prove the hardest technical assumption as early as possible.



The most important technical risk is not the UI.



It is:



> \*\*Can multiple heterogeneous phones actually produce sufficiently coherent synchronized audio using the chosen local networking and native audio architecture?\*\*



Therefore early prototypes should prioritize:



```text

2 phones

&#x20;↓

local connection

&#x20;↓

audio distribution

&#x20;↓

clock measurement

&#x20;↓

scheduled playback

&#x20;↓

actual synchronization measurement

```



\---



\# 65. DEC-060 — The Core Technical Risk



\*\*Status:\*\* DECIDED



SoundMesh's largest technical risk is achieving reliable perceptual synchronization across different physical devices.



This must guide prioritization.



A beautiful interface cannot compensate for poor synchronization.



\---



\# 66. DEC-061 — UX Must Hide Engineering Complexity



\*\*Status:\*\* DECIDED



The user experience should make the complex distributed system feel simple.



Desired experience:



```text

Create

Join

Choose

Play

```



The application may perform:



```text

Discovery

Handshake

Audio transfer

Integrity verification

Clock measurement

Calibration

Scheduling

Monitoring

Drift correction

Recovery

```



without requiring the user to understand these operations.



\---



\# 67. DEC-062 — Reliability Over Feature Count



\*\*Status:\*\* DECIDED



For the competition MVP, a small number of highly reliable features is preferable to a large feature set with unreliable synchronization.



Priority:



```text

Reliable synchronization

&#x20;>

Reliable joining

&#x20;>

Reliable playback

&#x20;>

Recovery

&#x20;>

Polish

&#x20;>

Additional features

```



\---



\# 68. DEC-063 — Competitive Differentiation



\*\*Status:\*\* DECIDED



SoundMesh should not rely on the claim:



> “Phones can become a speaker.”



That concept already exists in prior products.



The differentiation should come from execution quality, especially:



\* synchronization quality

\* calibration

\* drift correction

\* reliability

\* ease of joining

\* local-first operation

\* heterogeneous-device handling

\* measurable performance

\* diagnostics



\---



\# 69. DEC-064 — Do Not Claim Perfect Synchronization



\*\*Status:\*\* DECIDED



SoundMesh must never claim:



> Perfect synchronization



unless objective testing can justify such a claim.



Preferred language:



> Synchronized playback



or:



> Designed for perceptually coherent synchronized playback.



\---



\# 70. DEC-065 — Engineering Targets Are Not Guarantees



\*\*Status:\*\* DECIDED



Values such as:



```text

≤20 ms startup spread

≤20 ms steady-state spread

≤10 ms preferred stretch

```



are engineering targets.



They must not be represented as universally guaranteed performance.



\---



\# 71. DEC-066 — Failure Is a First-Class Design Concern



\*\*Status:\*\* DECIDED



The system must explicitly design for:



\* device disconnect

\* host disconnect

\* network changes

\* packet loss

\* high latency

\* jitter

\* audio preparation failure

\* decoder failure

\* buffer underrun

\* audio route changes

\* interruption

\* backgrounding

\* device sleep

\* battery/thermal pressure

\* late joining



Failure behavior must be specified rather than improvised.



\---



\# 72. DEC-067 — State Machines



\*\*Status:\*\* DECIDED



Important systems should use explicit state machines rather than scattered boolean flags.



Room state is conceptually:



```text id="p9ih4p"

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

PAUSED / RECOVERING

&#x20;↓

PLAYING

&#x20;↓

ENDING

&#x20;↓

CLOSED

```



Actual implementation may refine these states while preserving their semantics.



\---



\# 73. DEC-068 — Explicit Unknowns



\*\*Status:\*\* DECIDED



Unknown technical behavior must be documented explicitly.



Preferred:



```text

UNDECIDED — requires device testing.

```



or:



```text

EXPERIMENTAL — current implementation is provisional.

```



Do not hide uncertainty behind confident language.



\---



\# 74. DEC-069 — Security by Standard Mechanisms



\*\*Status:\*\* DECIDED



SoundMesh should prefer standard cryptographic and platform security mechanisms rather than custom cryptography.



The application should avoid:



\* custom encryption algorithms

\* permanent secrets inside QR codes

\* unnecessary credential persistence



Security details remain primarily defined in `networking.md`.



\---



\# 75. DEC-070 — Repository Simplicity



\*\*Status:\*\* DECIDED



The repository should remain understandable.



Do not introduce:



\* unnecessary abstraction layers

\* duplicate networking systems

\* duplicate state-management systems

\* unused packages

\* speculative infrastructure



Every major dependency should have a reason.



\---



\# 76. Decision Change Procedure



When proposing a change to a `DECIDED` item:



\### Step 1



Identify the decision.



Example:



```text

DEC-030 — UDP

```



\### Step 2



Explain the problem with the current decision.



\### Step 3



Provide evidence.



Examples:



\* benchmark

\* device test

\* official platform documentation

\* reproducible failure

\* measured performance



\### Step 4



Describe alternatives.



\### Step 5



Describe consequences.



\### Step 6



Update this document.



\### Step 7



Update affected specifications.



\### Step 8



Only then modify implementation architecture.



\---



\# 77. AI Decision-Safety Rule



When an AI agent encounters an architectural uncertainty, it should classify it before acting:



```text

Is this DECIDED?

&#x20;   ↓

Yes → Follow it.



No

&#x20;↓

Is it PREFERRED?

&#x20;   ↓

Yes → Follow unless evidence contradicts it.



No

&#x20;↓

Is it EXPERIMENTAL?

&#x20;   ↓

Yes → Preserve experimental status.



No

&#x20;↓

Is it UNDECIDED?

&#x20;   ↓

Yes → Do not silently finalize it.



No

&#x20;↓

Check whether it is REJECTED/SUPERSEDED.

```



\---



\# 78. Decision Log Maintenance



Every major architectural decision should receive a unique ID.



IDs must never be reused.



If a decision changes:



```text

DEC-012

Status → SUPERSEDED

```



and a new decision receives a new ID.



Historical decisions should remain available for context.



\---



\# 79. Current High-Confidence Decisions



The following areas are currently strongly established:



```text

Product:

SoundMesh



Platform:

Android + iOS



Framework:

Flutter



Architecture:

Flutter UI + native timing-critical systems



Networking:

Local-first



Joining:

QR-first



Room:

Host + participants



Audio:

Prefer local distribution + local playback



Synchronization:

Shared timeline + clock measurement + scheduled playback



Playback:

Measure actual behavior



Drift:

Monitor + correct



UI:

Dark-first + premium minimal design



Brand accent:

\#5B8CFF



Accessibility:

Required



Performance:

Audio/sync before visual effects



Testing:

Real devices required

```



\---



\# 80. Current Experimental / Open Areas



The following areas must remain explicitly open until evidence is available:



```text

Exact Android audio engine

Exact iOS audio engine

Exact supported audio formats

Sample-rate strategy

Channel strategy

Resampling strategy

Bluetooth behavior

Wi-Fi Direct/P2P

UDP timing transport

Exact buffering strategy

Exact audio latency measurement

Background playback behavior

Interruption behavior

Host recovery strategy beyond MVP

Maximum practical device count

Exact synchronization algorithm refinements

```



\---



\# 81. Current Rejected MVP Directions



The following should not be reintroduced casually:



```text

Mandatory cloud backend

Mandatory Internet connectivity

Continuous host-to-device audio streaming

Manual IP-address-based onboarding

“Play Now” as the synchronization mechanism

Large social/music-streaming feature set

Premature microservices

Premature authentication infrastructure

Arbitrary synchronization claims

Feature expansion before core sync reliability

```



\---



\# 82. Final Engineering Principle



SoundMesh should be engineered according to one fundamental rule:



> \*\*Make the simplest system capable of delivering genuinely synchronized multi-device audio, measure whether it works, and only add complexity when evidence requires it.\*\*



The goal is not to create the most complicated architecture.



The goal is to create an architecture that makes the complicated problem \*\*reliably solvable\*\*.



\---



\# 83. Final Product Principle



The user should experience:



> \*\*“We didn't have a speaker, so we made one out of our phones.”\*\*



The engineering team should experience:



> \*\*“We built a distributed synchronization system that makes five independent audio devices behave like one.”\*\*



Both statements describe the same product from different sides.



\*\*End of Decision Log.\*\*



