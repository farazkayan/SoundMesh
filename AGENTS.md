\# SoundMesh — AI Agent Instructions



\*\*Repository:\*\* SoundMesh

\*\*Purpose:\*\* Instructions for AI coding agents working in this repository.



\---



\# 1. Mission



SoundMesh is a Flutter-based mobile application that allows multiple nearby phones to coordinate audio playback so they behave like one synchronized speaker system.



The difficult part of SoundMesh is not simply playing audio on multiple phones.



The difficult part is making independently operating devices behave like one coordinated playback system despite differences in:



\* clocks

\* network latency

\* network jitter

\* audio pipelines

\* output latency

\* hardware

\* operating systems

\* scheduling behavior

\* clock drift

\* interruptions

\* connection failures



AI agents must therefore prioritize \*\*measurable synchronization reliability\*\* over superficial feature development.



\---



\# 2. Read These Before Coding



Before making meaningful changes, read:



```text id="cx3z78"

DOCS/AI/ai-context.md

DOCS/AI/rules.md

DOCS/AI/task-protocol.md

```



Then read the specification relevant to the task.



\### Architecture



```text

DOCS/architecture.md

```



\### Product



```text

DOCS/blueprint.md

```



\### Networking



```text

DOCS/networking.md

```



\### Synchronization



```text

DOCS/synchronization.md

```



\### Audio



```text

DOCS/audio.md

```



\### UI / UX



```text

DOCS/ui-ux.md

```



\### Development order



```text

DOCS/roadmap.md

```



\### Architectural decisions



```text

DOCS/decisions.md

```



When in doubt, read the relevant specification instead of guessing.



\---



\# 3. Authority



Follow this authority order:



```text id="aqb9a4"

Current user/developer instruction

&#x20;       ↓

DOCS/decisions.md

&#x20;       ↓

Relevant technical specification

&#x20;       ↓

DOCS/blueprint.md

&#x20;       ↓

DOCS/roadmap.md

&#x20;       ↓

DOCS/AI/ai-context.md

&#x20;       ↓

DOCS/AI/rules.md

&#x20;       ↓

DOCS/AI/task-protocol.md

&#x20;       ↓

Existing implementation

&#x20;       ↓

Agent assumptions

```



Never silently override a documented architectural decision.



If important documentation conflicts, stop and report the conflict.



\---



\# 4. Core Architecture



SoundMesh uses:



```text id="7y6o8b"

Flutter

│

├── UI

├── Navigation

├── High-level application state

└── Application orchestration

&#x20;       │

&#x20;       │ typed native bridge

&#x20;       ▼

Android / iOS native layer

│

├── Timing-critical audio

├── Native playback scheduling

├── Platform networking

├── Timing / clock operations

└── Platform-specific capabilities

```



Flutter is the primary application framework.



Android and iOS native code handle platform-specific and timing-critical operations.



Do not move realtime audio or timing-critical operations into Flutter merely for convenience.



\---



\# 5. Core Networking Model



SoundMesh is \*\*local-first\*\*.



Ordinary playback must not require the Internet or cloud infrastructure.



The preferred model is:



```text id="vccg8d"

Host

&#x20;│

&#x20;├── control

&#x20;├── synchronization

&#x20;└── audio distribution

&#x20;      │

&#x20;      ├── Participant

&#x20;      ├── Participant

&#x20;      └── Participant

```



Audio should preferably be distributed to participants first and then played locally using synchronized scheduling.



Do not introduce continuous host-to-participant audio streaming unless technical evidence demonstrates that it is necessary.



\---



\# 6. Core Synchronization Model



SoundMesh is a distributed timing system.



The synchronization system should reason about:



```text id="q8q5r2"

monotonic clocks

clock offset

clock drift

RTT

network jitter

timing uncertainty

audio latency

output latency

playback position

synchronization error

```



These are different concepts.



Do not treat network latency as audio synchronization.



The primary playback model is:



```text id="9d4b5u"

measure

&#x20;  ↓

calibrate

&#x20;  ↓

create shared timeline

&#x20;  ↓

prepare audio

&#x20;  ↓

choose future target time

&#x20;  ↓

schedule native playback

&#x20;  ↓

measure actual playback

&#x20;  ↓

monitor drift

&#x20;  ↓

correct when necessary

```



Do not use `PLAY NOW` as the primary synchronization mechanism.



Do not claim mathematically perfect synchronization.



\---



\# 7. Real Device Testing



Emulators are useful for:



\* UI

\* navigation

\* basic logic

\* mocks

\* unit tests



But real-device testing is required for validating:



\* audio synchronization

\* actual playback latency

\* network behavior

\* device differences

\* drift

\* background behavior

\* hardware behavior



Never claim real-device compatibility without testing it.



\---



\# 8. Evidence Rules



Agents MUST distinguish:



```text id="xknc1h"

VERIFIED

INFERRED

UNTESTED

BLOCKED

```



Never fabricate:



\* test results

\* synchronization measurements

\* latency

\* performance

\* battery usage

\* device compatibility

\* supported device counts



If something was not tested, say so.



\---



\# 9. Experimental Areas



The following are not automatically settled production decisions:



\* exact Android audio engine

\* exact iOS audio engine

\* audio format/codec

\* sample rate

\* channel configuration

\* resampling strategy

\* Bluetooth support

\* Wi-Fi Direct/P2P

\* UDP timing

\* buffering strategy

\* maximum device count

\* host migration

\* background behavior

\* exact physical synchronization measurement method



Treat these as experimental or undecided according to the specifications.



Do not silently turn an experiment into permanent architecture.



\---



\# 10. UI / UX Direction



SoundMesh uses a:



\* dark-first

\* modern

\* calm

\* premium

\* minimal

\* audio-focused



visual language.



Primary visual direction:



```text id="m0e1qk"

Background:       #0B0D10

Surface:          #181D23

Elevated surface: #20262D

Primary text:     #F5F7FA

Secondary text:   #A7AFB9

Muted text:       #6F7883

SoundMesh Blue:   #5B8CFF

Success:          #39D98A

Warning:          #FFB84D

Error:            #FF5C6C

```



Follow `DOCS/ui-ux.md`.



Do not introduce random gradients, neon effects, excessive glassmorphism, arbitrary colors, or inconsistent typography.



\---



\# 11. Scope Control



Only change what is necessary for the requested task.



Do not use a feature request as an excuse to:



\* rewrite unrelated systems

\* redesign the entire UI

\* replace dependencies unnecessarily

\* introduce cloud infrastructure

\* add accounts

\* add social features

\* create unnecessary databases

\* refactor unrelated code



Prefer the smallest correct change.



\---



\# 12. Git Safety



Before modifying significant code:



1\. Inspect the current branch.

2\. Inspect the working tree.

3\. Identify existing uncommitted changes.

4\. Avoid overwriting another developer's work.



Do not blindly execute destructive commands such as:



```text id="4ndqzr"

git reset --hard

git clean -fd

```



Do not force-push or rewrite shared history without explicit authorization.



Do not directly modify `main` unless explicitly instructed.



\---



\# 13. Multi-Agent Safety



Multiple AI agents may work on SoundMesh.



Do not have two agents independently modify the same critical subsystem simultaneously.



Critical shared areas include:



\* synchronization

\* networking protocol

\* native audio

\* native bridge interfaces

\* shared state models



Use clear ownership boundaries.



\---



\# 14. Code Rules



Code should be:



\* readable

\* maintainable

\* testable

\* explicit

\* idiomatic

\* appropriately modular



Avoid:



\* unnecessary abstractions

\* magic constants

\* hidden global state

\* giant files

\* clever code without justification

\* unrelated refactoring



Comments should explain \*\*why\*\*, especially when dealing with synchronization, platform behavior, or workarounds.



\---



\# 15. Error Handling



Do not implement only the happy path.



Consider:



```text id="4a2x8c"

timeouts

disconnects

reconnects

invalid input

duplicate messages

stale messages

permission denial

unsupported capabilities

network changes

audio failures

synchronization failures

drift

interruption

cancellation

```



Recover where appropriate.



Do not retry forever.



\---



\# 16. State Correctness



Important SoundMesh state transitions must remain explicit.



The UI must reflect actual system state.



For example:



```text id="c72h9d"

Connection attempt started

≠

Connected

```



and:



```text id="h8m5de"

Playback command sent

≠

Playback synchronized

```



Do not display success states merely because an operation was requested.



\---



\# 17. Security



Never commit:



\* API keys

\* passwords

\* private keys

\* authentication secrets

\* long-lived room credentials



QR codes should contain only appropriate temporary room-joining information.



Do not invent cryptography.



Prefer established platform security mechanisms.



\---



\# 18. Dependencies



Before adding a dependency, determine whether the capability already exists in:



\* Flutter

\* Android

\* iOS

\* an existing project dependency



New dependencies must have a clear justification.



Consider:



\* maintenance

\* platform support

\* security

\* license

\* size

\* native complexity



\---



\# 19. Documentation



When behavior changes, update the appropriate documentation.



Examples:



```text id="3ftm3v"

Architecture      → architecture.md

Product behavior  → blueprint.md

Networking        → networking.md

Synchronization   → synchronization.md

Audio             → audio.md

UI/UX             → ui-ux.md

Development       → roadmap.md

Architecture decisions → decisions.md

AI behavior       → DOCS/AI/\*

```



Documentation and implementation must not silently diverge.



\---



\# 20. When to Stop



Stop and report instead of guessing when:



\* requirements conflict

\* an architectural decision is required

\* critical platform behavior is unknown

\* required hardware is unavailable

\* testing cannot establish the requested behavior

\* another developer's work could be overwritten

\* security implications are unclear

\* the task would require an unauthorized architectural change



Use evidence rather than assumptions.



\---



\# 21. Required Task Workflow



For meaningful tasks, follow:



```text id="7z3j3d"

1\. Understand the task

2\. Inspect the repository

3\. Read relevant documentation

4\. Check Git state

5\. Identify authority

6\. Identify unknowns

7\. Define scope

8\. Plan the smallest change

9\. Validate the plan against architecture

10\. Implement

11\. Add/update tests

12\. Run static checks

13\. Run tests

14\. Test on real devices when required

15\. Inspect actual behavior

16\. Inspect the final diff

17\. Update documentation

18\. Verify acceptance criteria

19\. Report results

```



For the full procedure, read:



```text

DOCS/AI/task-protocol.md

```



\---



\# 22. Required Final Report



Meaningful tasks should end with:



```text id="0z8h4x"

\## Summary



\## Files Changed



\## Implementation



\## Tests



\## Verification



\## Not Tested



\## Decisions



\## Risks / Limitations



\## Next Step

```



The report must contain actual evidence.



Do not claim something was tested if it was not.



\---



\# 23. SoundMesh Non-Negotiables



The following principles should be treated as foundational:



```text id="8c5p1a"

Flutter is the primary app framework.



Android and iOS are first-class targets.



Timing-critical audio remains native.



Timing-critical networking remains native where required.



SoundMesh is local-first.



QR joining is preferred.



The host coordinates the room.



Audio is preferably distributed before synchronized playback.



Playback uses future-target scheduling.



Monotonic timing is preferred for synchronization.



Synchronization must be measured.



Drift must be monitored.



Real devices are required for meaningful audio/sync validation.



Physical synchronization validation is required before claiming audible-quality synchronization.



Unverified behavior must be labeled unverified.



Architectural uncertainty must not be silently resolved.

```



\---



\# 24. The Most Important Rule



When deciding what to do next, ask:



> \*\*What is the highest-risk assumption we can prove or disprove next?\*\*



Not:



> \*\*What feature would be the most fun to build next?\*\*



The goal is to progressively turn SoundMesh from an idea into a verified engineering system.



\---



\# 25. Final Instruction



Before writing code, understand the system.



Before changing architecture, understand the decision.



Before claiming success, run the test.



Before claiming synchronization, measure it.



Before adding complexity, prove that it is necessary.



Before changing someone else's work, inspect Git.



Before guessing, investigate.



Before declaring completion, inspect the diff.



\*\*Build what SoundMesh needs.

Measure what SoundMesh does.

Document what SoundMesh actually supports.\*\*



