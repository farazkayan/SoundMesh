\# SoundMesh — AI Engineering Rules



\*\*File:\*\* `DOCS/AI/rules.md`

\*\*Status:\*\* REQUIRED

\*\*Authority:\*\* AI agent operating rules

\*\*Applies to:\*\* All AI coding agents modifying the SoundMesh repository



\---



\## 1. Purpose



This document defines the mandatory rules that every AI coding agent must follow when analyzing, modifying, testing, or documenting SoundMesh.



These rules exist to prevent:



\* accidental architectural drift

\* undocumented decisions

\* fabricated test results

\* unnecessary complexity

\* conflicting implementations

\* destructive changes

\* AI agents misunderstanding experimental areas as settled requirements

\* modifications outside the requested task

\* technically plausible but unverified synchronization behavior



An AI agent is not authorized to treat SoundMesh as a blank project.



The repository documentation is part of the engineering system.



An agent must understand the relevant documentation before making implementation decisions.



\---



\# 2. Core Principle



> \*\*Do not optimize for writing code quickly. Optimize for making the smallest correct change that moves SoundMesh toward a verified system.\*\*



SoundMesh's hardest problem is synchronization.



A feature is not considered successful merely because:



\* the code compiles

\* the UI looks correct

\* two devices appear connected

\* playback starts

\* a metric is displayed



The implementation must satisfy its actual acceptance criteria and be supported by appropriate verification.



\---



\# 3. Authority Hierarchy



When sources disagree, agents must resolve the conflict according to this order:



1\. Explicit user/developer instruction for the current task

2\. `DOCS/decisions.md`

3\. Relevant technical specification



&#x20;  \* `DOCS/synchronization.md`

&#x20;  \* `DOCS/networking.md`

&#x20;  \* `DOCS/audio.md`

&#x20;  \* `DOCS/architecture.md`

&#x20;  \* `DOCS/ui-ux.md`

4\. `DOCS/blueprint.md`

5\. `DOCS/roadmap.md`

6\. `DOCS/AI/ai-context.md`

7\. `DOCS/AI/rules.md`

8\. `DOCS/AI/task-protocol.md`

9\. Existing implementation

10\. Agent assumptions



If two documents conflict, the agent must not silently choose one.



The conflict must be reported and, when appropriate, recorded as an architectural decision.



\---



\# 4. Read Before Writing



Before modifying code, an agent MUST inspect the relevant existing implementation.



At minimum, the agent should understand:



\* repository structure

\* relevant source files

\* relevant interfaces

\* existing state management

\* existing tests

\* relevant documentation

\* current Git branch and working tree

\* dependencies involved in the requested change



For synchronization, networking, and audio tasks, the agent MUST read the relevant technical specification before implementation.



An agent must not implement a feature solely from the task description if the repository documentation provides additional constraints.



\---



\# 5. Never Invent Requirements



Agents MUST NOT invent product requirements.



Examples of prohibited assumptions:



\* assuming the app needs accounts

\* assuming cloud infrastructure is required

\* assuming continuous audio streaming is required

\* assuming Bluetooth must work

\* assuming Wi-Fi Direct must be used

\* assuming a maximum device count without evidence

\* assuming a particular codec is mandatory

\* assuming background playback behavior

\* assuming host migration is required

\* assuming a particular database

\* assuming authentication architecture



If the requirement is genuinely unknown, use:



`UNDECIDED`



or report the question to the human developer.



Do not convert uncertainty into an implementation decision without authorization.



\---



\# 6. Requirement Status



Agents must respect the project's requirement vocabulary:



\* `REQUIRED`

\* `PREFERRED`

\* `OPTIONAL`

\* `UNDECIDED`

\* `REJECTED`

\* `EXPERIMENTAL`



\### REQUIRED



Must be implemented when relevant.



\### PREFERRED



Should normally be implemented unless technical evidence provides a reason not to.



\### OPTIONAL



May be implemented when useful and within scope.



\### UNDECIDED



Must not be silently decided by the agent.



\### REJECTED



Must not be implemented unless explicitly reconsidered.



\### EXPERIMENTAL



May be explored through controlled experiments but must not be presented as established architecture.



\---



\# 7. Scope Control



Agents MUST stay within the requested task.



Do not perform unrelated refactors merely because they appear beneficial.



For example, if asked to implement QR joining:



Do not simultaneously:



\* redesign navigation

\* replace state management

\* rewrite the networking layer

\* introduce authentication infrastructure

\* redesign the database

\* rewrite unrelated UI

\* upgrade every dependency



unless those changes are required for the task.



Small, focused changes are preferred.



\---



\# 8. Minimal Correct Change



Prefer:



> smallest change that correctly satisfies the requirement



over:



> largest refactor that makes the code look cleaner



Do not rewrite functioning systems without a demonstrated reason.



Refactoring is justified when it:



\* removes a concrete blocker

\* fixes a correctness problem

\* enables the required architecture

\* substantially improves testability

\* eliminates dangerous duplication



Cosmetic refactoring should normally be deferred.



\---



\# 9. Architecture Preservation



Agents MUST preserve the established SoundMesh architecture unless explicitly authorized to change it.



Current architectural boundary:



```text

Flutter

│

├── UI

├── Navigation

├── High-level application state

├── User interaction

└── Orchestration

&#x20;       │

&#x20;       │ typed native bridge

&#x20;       ▼

Native Android / iOS

│

├── Timing-critical audio

├── Native playback scheduling

├── Platform networking

├── Clock/timing operations

└── Platform-specific capabilities

```



Flutter must not become the realtime audio engine merely because Dart code is convenient.



Native timing-critical operations must remain native unless testing demonstrates that a different approach is appropriate.



\---



\# 10. Realtime Timing Rule



Agents MUST NOT move high-frequency timing-critical operations through Flutter unnecessarily.



Examples include:



\* audio callbacks

\* sample-level timing

\* high-frequency clock measurements

\* tight playback correction loops

\* realtime audio processing

\* low-level latency-sensitive networking



Flutter may receive summarized state such as:



```text

synchronized

drift = 4 ms

confidence = high

```



rather than receiving thousands of realtime events per second.



\---



\# 11. Synchronization Rules



Synchronization is a core engineering problem.



Agents MUST understand the distinction between:



\* network latency

\* RTT

\* clock offset

\* clock drift

\* audio latency

\* output latency

\* playback position

\* synchronization error



These values must not be treated as interchangeable.



Agents MUST NOT claim that:



> low network latency = synchronized audio



That is false.



\---



\# 12. Scheduled Playback Rule



The primary synchronization mechanism MUST use future-target scheduling.



The conceptual model is:



```text

current synchronized timeline

&#x20;           │

&#x20;           ▼

&#x20;    future target T

&#x20;           │

&#x20;           ▼

each device schedules local playback

&#x20;           │

&#x20;           ▼

&#x20;     playback begins

```



The primary design must NOT rely on:



```text

PLAY NOW

```



because messages do not reach every device simultaneously and device audio pipelines introduce different delays.



\---



\# 13. Clock Rule



Agents MUST prefer monotonic clocks for elapsed-time calculations and synchronization measurements.



Wall-clock time must not be treated as a reliable realtime synchronization mechanism.



When measuring relationships between devices, the implementation must explicitly model:



\* clock offset

\* elapsed time

\* drift

\* measurement uncertainty



\---



\# 14. Measurement Before Optimization



When synchronization behavior is uncertain:



> \*\*Measure it before optimizing it.\*\*



Agents should create experiments when appropriate.



Examples:



\* measure startup spread

\* measure RTT

\* measure clock-offset stability

\* measure drift

\* measure correction effectiveness

\* measure CPU usage

\* measure battery impact

\* measure device scaling



Do not optimize based purely on intuition.



\---



\# 15. No Fake Metrics



Agents MUST NEVER fabricate:



\* synchronization accuracy

\* latency

\* RTT

\* CPU usage

\* battery usage

\* device counts

\* test results

\* benchmark results

\* compatibility

\* performance improvements



If a value has not been measured, say:



`UNMEASURED`



If an experiment has not been performed, say:



`NOT TESTED`



If behavior is theoretical, say:



`THEORETICAL`



\---



\# 16. Testing Truthfulness



An agent MUST distinguish between:



\### Verified



Actually tested and observed.



\### Inferred



Reasonably expected from implementation or platform behavior but not directly tested.



\### Untested



Not verified.



\### Blocked



Could not be tested because of a missing dependency, device, platform, permission, or other constraint.



Example:



```text

Android build: VERIFIED

iOS build: NOT TESTED

Two-device synchronization: UNTESTED

Five-device synchronization: BLOCKED

```



Never convert an inferred result into a verified result.



\---



\# 17. Real Device Rule



SoundMesh cannot be validated entirely through emulators.



For synchronization, audio, networking, and hardware behavior:



> \*\*Real-device testing is authoritative.\*\*



Agents may use emulators for:



\* UI development

\* navigation

\* basic application logic

\* mock networking

\* unit tests



But emulator success does not establish:



\* real audio synchronization

\* real output latency

\* real device drift

\* real Wi-Fi behavior

\* real Bluetooth behavior

\* real hardware differences



\---



\# 18. Physical Synchronization Validation



Software metrics alone are insufficient.



Eventually SoundMesh MUST be validated through physical measurements or controlled listening tests.



Potential instrumentation includes:



\* microphones

\* external recording devices

\* waveform comparison

\* synchronized audio recordings

\* impulse/click tests

\* oscilloscope-style measurements

\* other suitable timing instrumentation



Agents must not claim audible synchronization quality solely from simulated timestamps.



\---



\# 19. Networking Rules



Networking should remain local-first.



Agents MUST NOT introduce an Internet/cloud dependency for ordinary local playback unless explicitly authorized.



The preferred architecture is:



```text

Host

&#x20;│

&#x20;├── control

&#x20;├── synchronization

&#x20;└── audio distribution

&#x20;      │

&#x20;      ├── Participant A

&#x20;      ├── Participant B

&#x20;      ├── Participant C

&#x20;      └── ...

```



Audio should preferably be distributed once and then played locally.



Continuous host-to-device audio streaming should not be introduced without evidence that it is necessary.



\---



\# 20. IP Addresses Are Not Device Identity



An IP address may change.



Therefore:



```text

IP address ≠ participant identity

```



The application must maintain logical device/session identifiers separately from network addressing.



\---



\# 21. QR Security Rules



QR codes may contain temporary room-joining information.



They MUST NOT contain:



\* permanent credentials

\* long-lived secrets

\* private keys

\* user passwords

\* unnecessary personal information



Preferred model:



```text

room ID

\+

bootstrap information

\+

protocol version

\+

short-lived authorization token

```



\---



\# 22. Security Rules



Agents MUST prefer established platform and cryptographic mechanisms over custom cryptography.



Do not invent encryption algorithms.



Do not store secrets unnecessarily.



Do not expose:



\* private keys

\* API keys

\* credentials

\* authentication tokens

\* development secrets



in source control.



If a secret appears in source code accidentally, the agent must flag it immediately.



\---



\# 23. Dependency Rules



Agents MUST NOT add dependencies casually.



Before adding a dependency, determine:



1\. Why is it required?

2\. Can the platform/framework already provide the capability?

3\. Is the dependency actively maintained?

4\. Does it support Android and iOS as required?

5\. Does it introduce unnecessary native complexity?

6\. Does its license fit the project?

7\. Does it create security or supply-chain concerns?



Avoid adding a package merely to save a small amount of code.



\---



\# 24. Platform-Specific Code



Platform-specific behavior belongs behind clear abstractions.



Preferred pattern:



```text

Shared interface

&#x20;     │

&#x20;┌────┴────┐

&#x20;▼         ▼

Android    iOS

implementation

```



Platform-specific implementation must not leak unnecessary details throughout the Flutter application.



Use typed interfaces where practical.



\---



\# 25. Pigeon / Native Bridge Rule



When a typed Flutter/native interface is required, Pigeon or another explicitly typed mechanism should be preferred over loosely structured message passing.



Interfaces should define:



\* request

\* response

\* state

\* error

\* capability



clearly.



Avoid passing arbitrary unstructured maps when a stable typed contract is appropriate.



\---



\# 26. Error Handling



Errors must be explicit.



Avoid:



```text

catch (e) {

&#x20; // ignore

}

```



unless ignoring the error is intentionally documented and safe.



Errors should identify:



\* what failed

\* where it failed

\* whether recovery is possible

\* whether retry is appropriate

\* whether the session must resynchronize

\* whether the user needs to act



Raw technical errors may exist internally, but user-facing errors should remain understandable.



\---



\# 27. State Machines Must Stay Explicit



SoundMesh contains stateful systems.



Agents MUST NOT introduce hidden state transitions.



For important state machines:



```text

state

&#x20;  ↓

event

&#x20;  ↓

validated transition

&#x20;  ↓

new state

```



Invalid transitions should be rejected or handled explicitly.



Examples include:



\* room lifecycle

\* participant lifecycle

\* playback lifecycle

\* synchronization lifecycle

\* connection lifecycle



\---



\# 28. Playback Generation Rule



Playback commands may arrive late or be duplicated.



Agents should use generation/version information to prevent stale commands from modifying current playback.



Conceptually:



```text

generation 10 → current

generation 9  → stale → reject

generation 11 → future/new → accept

```



This principle applies wherever stale commands could create incorrect state.



\---



\# 29. Concurrency Rules



Agents must consider:



\* race conditions

\* duplicate messages

\* reordered messages

\* delayed messages

\* disconnects during operations

\* simultaneous user actions

\* state changes during transfers

\* cancellation



Do not assume that operations happen in a perfect sequence.



Distributed systems must be designed for imperfect timing.



\---



\# 30. UI Truthfulness



The UI must represent actual system state.



Do not display:



```text

Synchronized

```



merely because the user pressed Play.



Display synchronization only when the synchronization subsystem reports an appropriate state.



Likewise:



```text

Connected

```



must not mean merely:



> connection attempt started.



UI states should correspond to actual application states.



\---



\# 31. Diagnostics Rule



Diagnostics should expose measured information.



Examples:



```text

Sync error: 8 ms

RTT: 14 ms

Confidence: High

Devices synchronized: 4/5

Connection: Good

```



Do not display meaningless fake values such as:



```text

Sync: 99%

```



unless that percentage has a defined, measurable meaning.



\---



\# 32. UI Scope Rule



Agents implementing backend or synchronization tasks must not redesign the UI unless the task requires it.



Agents implementing UI tasks must follow:



`DOCS/ui-ux.md`



Do not introduce:



\* random gradients

\* unnecessary neon effects

\* excessive glassmorphism

\* arbitrary colors

\* inconsistent typography

\* excessive animations

\* emoji as primary UI icons



The established SoundMesh visual language is authoritative.



\---



\# 33. Documentation Rule



Code changes that alter documented behavior require documentation updates.



Documentation must be updated when changes affect:



\* architecture

\* networking

\* synchronization

\* audio

\* UI behavior

\* product requirements

\* decisions

\* testing methodology

\* roadmap dependencies



Do not allow implementation and documentation to silently diverge.



\---



\# 34. Architectural Decisions



If implementation requires choosing between meaningful architectural alternatives, the agent must not silently decide when the relevant area is `UNDECIDED`.



Examples:



```text

Wi-Fi Direct vs infrastructure Wi-Fi

Oboe vs AudioTrack

AVAudioEngine vs AVAudioPlayerNode

TCP vs UDP timing

codec choice

clock algorithm

host migration strategy

maximum device count

```



If the decision is important enough to affect architecture, it should be documented in:



`DOCS/decisions.md`



with:



\* context

\* options

\* decision

\* rationale

\* consequences

\* evidence

\* date/status



\---



\# 35. Experimental Work



Experimental implementations must be clearly identified.



An experiment should answer a question.



Bad experiment:



> Build random networking architecture.



Good experiment:



> Determine whether five Android devices connected through one phone hotspot can maintain acceptable synchronization using the current scheduled-playback prototype.



Every significant experiment should define:



```text

Question

Hypothesis

Setup

Procedure

Measurements

Result

Conclusion

Next action

```



\---



\# 36. No Premature Productionization



Do not build production infrastructure around an unproven technical assumption.



For example:



```text

Do not build a polished ten-device UI

before proving two-device synchronization.

```



Similarly:



```text

Do not build cloud infrastructure

before establishing that local networking is insufficient.

```



The roadmap exists to reduce this risk.



\---



\# 37. No Feature Creep



Do not add unrelated features such as:



\* social profiles

\* public rooms

\* music discovery

\* playlists

\* messaging

\* cloud accounts

\* social sharing

\* recommendation systems

\* unnecessary analytics

\* unnecessary databases



unless the product specification explicitly requires them.



SoundMesh's core product is synchronized local audio playback.



\---



\# 38. Git Rules



Agents MUST inspect Git state before making significant changes.



Do not overwrite another developer's uncommitted work.



Do not blindly run destructive commands such as:



```text

git reset --hard

git clean -fd

```



unless explicitly authorized.



Do not rewrite shared history without explicit authorization.



Do not force-push shared branches without explicit authorization.



\---



\# 39. File Ownership



When multiple developers or AI agents are working simultaneously:



> \*\*Two agents MUST NOT independently modify the same critical files at the same time.\*\*



Critical shared areas include:



\* synchronization core

\* networking protocol

\* native audio engine

\* native bridge interfaces

\* shared state models



If simultaneous work is unavoidable, the ownership boundary must be explicit.



\---



\# 40. Branch Rules



Development should occur on task-specific branches.



Preferred structure:



```text

main

├── faraz-foundation

└── mahin-foundation

```



As the project grows, branches may become more task-specific.



Agents must not directly modify `main` unless explicitly instructed.



Before merging:



\* tests should pass

\* diff should be reviewed

\* documentation should be updated

\* acceptance criteria should be checked



\---



\# 41. No Destructive Automation



Agents must be especially careful with commands that:



\* delete files

\* overwrite directories

\* remove dependencies

\* alter Git history

\* modify configuration globally

\* change generated files unexpectedly

\* erase user data



Before destructive operations, verify that the operation is necessary and scoped correctly.



\---



\# 42. Generated Code



If a file is generated:



\* identify its source

\* modify the source rather than the generated output when appropriate

\* regenerate using the project's standard procedure

\* verify generated changes



Do not manually edit generated files if those changes will be overwritten.



\---



\# 43. Configuration Rules



Configuration must remain understandable.



Do not hard-code environment-specific values such as:



\* local IP addresses

\* machine-specific paths

\* private credentials

\* development-only ports

\* user-specific directories



unless explicitly required and clearly isolated.



Use configuration mechanisms appropriate to the platform.



\---



\# 44. Logging Rules



Logs should be useful for debugging without exposing secrets or unnecessary private information.



Do not log:



\* passwords

\* private keys

\* authentication tokens

\* sensitive user data



Prefer structured diagnostic information:



```text

room\_id

participant\_id

event

state

timestamp

error\_code

```



when appropriate.



\---



\# 45. Performance Rules



Do not optimize prematurely.



But do not knowingly introduce obvious performance problems into realtime systems.



Pay particular attention to:



\* audio thread blocking

\* unnecessary allocations in realtime callbacks

\* excessive Flutter rebuilds

\* synchronous network operations on UI threads

\* unbounded buffers

\* memory leaks

\* uncontrolled logging

\* unnecessary file copying



Performance improvements should be supported by measurements whenever practical.



\---



\# 46. Battery and Thermal Awareness



SoundMesh is a mobile application.



Agents must consider:



\* CPU usage

\* wakeups

\* network activity

\* audio processing

\* polling frequency

\* background behavior

\* thermal throttling



A synchronization algorithm that works but consumes unreasonable battery may not be acceptable for the final product.



\---



\# 47. Background and Interruption Behavior



Background execution, screen locking, phone calls, notifications, audio interruptions, and route changes are platform-specific.



Agents MUST NOT assume identical behavior across Android and iOS.



If behavior has not been tested:



`UNTESTED`



must remain the status.



\---



\# 48. Bluetooth Rule



Bluetooth support is experimental unless explicitly promoted to a required capability.



Do not silently redesign the networking architecture around Bluetooth.



Bluetooth introduces additional:



\* latency

\* buffering

\* route behavior

\* device-specific behavior

\* synchronization uncertainty



It must be validated before being treated as reliable.



\---



\# 49. Scaling Rule



Do not claim that SoundMesh supports an arbitrary number of devices.



Device-count claims must be backed by testing.



The development sequence is approximately:



```text

2 devices

&#x20;  ↓

3 devices

&#x20;  ↓

5 devices

&#x20;  ↓

10 devices

&#x20;  ↓

larger only if justified

```



The actual supported limit must be determined by evidence.



\---



\# 50. Acceptance Criteria Rule



A task is not complete because code exists.



Completion requires checking:



```text

Implementation

\+

Tests

\+

Verification

\+

Acceptance criteria

\+

Documentation

```



If a requirement cannot be tested yet, the limitation must be documented.



\---



\# 51. Test Hierarchy



Use the lowest appropriate test level first:



```text

Static analysis

&#x20;     ↓

Unit tests

&#x20;     ↓

Integration tests

&#x20;     ↓

Device tests

&#x20;     ↓

Multi-device tests

&#x20;     ↓

Physical synchronization validation

```



Higher-level testing does not eliminate the value of lower-level tests.



\---



\# 52. Test Failure Rule



If tests fail:



Do not simply remove or weaken the test to make the build pass.



First determine:



1\. Is the implementation wrong?

2\. Is the test wrong?

3\. Is the requirement wrong?

4\. Is the environment broken?

5\. Is the behavior platform-specific?



Only modify the test when the test itself is demonstrably incorrect.



\---



\# 53. Build Verification



After relevant code changes, agents should run appropriate verification such as:



```text

formatter

analyzer

unit tests

integration tests

platform build

```



The exact commands depend on the project configuration.



Never claim:



> build passes



without actually running the build or having reliable evidence from the current task execution.



\---



\# 54. Diff Inspection



Before considering a task complete, inspect the final diff.



Look for:



\* unintended files

\* debug code

\* secrets

\* unnecessary dependencies

\* accidental formatting changes

\* unrelated refactors

\* generated artifacts

\* incomplete TODOs

\* incorrect documentation

\* test modifications that weaken coverage



The final diff should tell a coherent story.



\---



\# 55. Stop Conditions



An agent must stop and report rather than guessing when:



\* requirements conflict

\* architecture is genuinely undecided

\* a necessary API is unavailable

\* platform behavior is unknown and critical

\* required hardware is unavailable

\* tests cannot establish the requested behavior

\* implementation would require a major architectural change

\* another developer's uncommitted work would be overwritten

\* security implications are unclear

\* the requested change contradicts a higher-authority specification



Stopping is preferable to silently creating technical debt.



\---



\# 56. Handling Ambiguity



When ambiguity is minor and does not affect architecture:



> choose the simplest reasonable interpretation and document it if useful.



When ambiguity affects architecture, security, synchronization, networking, or product behavior:



> do not silently choose.



Instead:



```text

Ambiguity

→ identify options

→ explain impact

→ request decision

```



\---



\# 57. AI Hallucination Rule



Agents must distinguish between:



```text

I know

I inspected

I measured

I inferred

I assume

I do not know

```



Never present an assumption as an inspected repository fact.



Never present general platform knowledge as a fact about SoundMesh's current implementation unless the repository confirms it.



\---



\# 58. External Documentation



When platform APIs or behavior are uncertain, consult authoritative documentation when appropriate.



Preferred sources:



\* official Flutter documentation

\* official Android documentation

\* official Apple documentation

\* official library documentation

\* primary technical specifications



Do not rely solely on random tutorials for critical architectural decisions.



External information should not silently override repository decisions.



\---



\# 59. API Version Awareness



Platform APIs change.



When implementing platform-specific functionality, agents should verify:



\* minimum supported OS

\* API availability

\* permission requirements

\* deprecations

\* platform-specific limitations



Do not assume an API available on one OS version exists on all supported versions.



\---



\# 60. Permission Rules



Permissions must be:



\* requested only when necessary

\* documented

\* tied to actual functionality

\* handled gracefully when denied



Do not request broad permissions merely because they might be useful later.



\---



\# 61. Privacy Rule



SoundMesh should remain local-first.



Agents must avoid collecting or transmitting unnecessary information.



The application should not require cloud data collection simply for basic playback.



If telemetry is introduced later, it must have a clearly documented purpose.



\---



\# 62. User Data Rule



Agents must treat local audio files and user-selected media as user data.



Do not:



\* upload them unnecessarily

\* expose them publicly

\* copy them indefinitely

\* retain temporary files without purpose



Temporary audio assets should have defined lifecycle and cleanup behavior.



\---



\# 63. Error Recovery Rule



For recoverable failures:



```text

detect

→ classify

→ recover

→ verify

→ report

```



Do not blindly retry forever.



Retries must have:



\* limits

\* backoff where appropriate

\* cancellation

\* state awareness



\---



\# 64. Network Failure Rule



Network failure does not automatically mean room failure.



Agents should distinguish:



```text

temporary degradation

connection loss

participant recovery

room failure

host failure

```



The correct recovery behavior depends on the room state.



\---



\# 65. Host Failure Rule



Host migration is not assumed to be seamless.



Unless explicitly implemented and tested, host failure should be treated as a controlled recovery condition.



Do not claim automatic seamless host migration.



\---



\# 66. Late Join Rule



A late participant must not simply begin playback immediately.



The participant must:



```text

join

→ obtain audio

→ calibrate

→ prepare

→ determine current timeline

→ schedule appropriate playback position

```



Late joining must preserve the room's synchronization model.



\---



\# 67. Pause / Resume / Seek



Playback controls are distributed operations.



Agents must account for:



\* command latency

\* generation numbers

\* synchronized target times

\* stale commands

\* participant readiness

\* recovery after interruption



A local button press must not automatically mean every device executes the operation at that exact instant.



\---



\# 68. Code Quality



Code should be:



\* readable

\* maintainable

\* appropriately modular

\* testable

\* explicit

\* idiomatic for its language/framework



Avoid:



\* clever abstractions without need

\* massive files

\* hidden global state

\* unnecessary inheritance

\* magic constants

\* unexplained platform workarounds



\---



\# 69. Comments



Comments should explain \*\*why\*\*, not merely restate \*\*what\*\*.



Good:



```text

// Schedule against the shared timeline instead of starting immediately,

// because network delivery time differs between participants.

```



Bad:



```text

// Start playback.

startPlayback();

```



Temporary experimental code should be clearly marked.



\---



\# 70. TODO Rules



TODOs must be meaningful.



Prefer:



```text

TODO(sync): Validate drift model on five heterogeneous Android devices.

```



over:



```text

TODO: fix later

```



If a TODO represents an architectural uncertainty, it should also be represented in the appropriate documentation.



\---



\# 71. No Silent Workarounds



If an implementation uses a workaround because the ideal API or architecture is unavailable, document:



\* why the workaround exists

\* what limitation caused it

\* what risks it introduces

\* whether it is temporary

\* what would allow its removal



\---



\# 72. Experimental Flags



Experimental behavior should be isolated behind clear boundaries or feature flags when practical.



This makes it possible to compare:



```text

stable implementation

vs

experimental implementation

```



without contaminating the main architecture.



\---



\# 73. Documentation Consistency



Terminology must remain consistent across the project.



For example, do not alternate randomly between:



```text

device

phone

participant

client

speaker

node

```



when those terms have different technical meanings.



Use:



\* \*\*host\*\* for the coordinating room device

\* \*\*participant\*\* for another device in the room

\* \*\*device\*\* when referring generically

\* \*\*room\*\* for a SoundMesh playback session



\---



\# 74. Source of Truth



When a value or behavior has a defined source of truth, do not duplicate it unnecessarily.



Examples:



\* synchronization architecture → `synchronization.md`

\* networking protocol → `networking.md`

\* audio behavior → `audio.md`

\* visual design → `ui-ux.md`

\* architecture → `architecture.md`

\* product definition → `blueprint.md`

\* development order → `roadmap.md`

\* architectural decisions → `decisions.md`



Code should implement the specification rather than becoming the only place where the behavior is understood.



\---



\# 75. Reporting Requirements



At the end of a task, the AI agent should report:



```text

\## Summary

What changed.



\## Files Changed

List of modified files.



\## Implementation

Important technical details.



\## Tests

Commands/tests actually executed.



\## Verification

What was actually verified.



\## Not Tested

Anything that could not be verified.



\## Decisions

Any decisions made or requested.



\## Risks

Known limitations or concerns.



\## Next Step

The smallest logical next action.

```



Do not report irrelevant implementation details.



\---



\# 76. Example Final Report



```text

\## Summary



Implemented two-device room handshake.



\## Files Changed



\- lib/...

\- native/android/...

\- DOCS/networking.md



\## Implementation



\- Added HELLO/WELCOME handshake.

\- Added protocol version validation.

\- Added participant ID assignment.

\- Added duplicate message protection.



\## Tests



\- Unit tests: PASS

\- Android build: PASS



\## Verification



\- Host and participant handshake verified on two Android devices.



\## Not Tested



\- iOS

\- Five-device scaling

\- Network interruption recovery



\## Decisions



No architectural decisions were required.



\## Risks



Reconnect behavior remains incomplete.



\## Next Step



Implement QR-based room joining.

```



\---



\# 77. What Agents Must Never Do



An AI agent MUST NOT:



\* fabricate test results

\* fabricate performance numbers

\* claim unsupported device compatibility

\* silently make major architecture decisions

\* ignore documented requirements

\* modify `main` without authorization

\* destroy uncommitted work

\* expose secrets

\* add unnecessary cloud dependencies

\* replace local-first architecture without evidence

\* make Flutter responsible for timing-critical realtime operations without justification

\* use `PLAY NOW` as the primary synchronization mechanism

\* claim mathematical-perfect synchronization

\* fake synchronization metrics

\* weaken tests to hide failures

\* introduce unrelated feature creep

\* silently change documented product behavior

\* treat experimental behavior as production-ready

\* assume emulator behavior equals real-device behavior



\---



\# 78. Priority When Rules Conflict



When several valid goals conflict, prioritize approximately:



```text

Correctness

&#x20;   ↓

Safety / security

&#x20;   ↓

Architectural integrity

&#x20;   ↓

Synchronization reliability

&#x20;   ↓

Testability

&#x20;   ↓

Maintainability

&#x20;   ↓

Performance

&#x20;   ↓

UX quality

&#x20;   ↓

Convenience

&#x20;   ↓

Code brevity

```



This ordering is not absolute, but correctness and architectural integrity should not be sacrificed merely to make implementation easier.



\---



\# 79. The SoundMesh AI Mindset



Every AI agent should think in this sequence:



```text

What is the actual requirement?

&#x20;       ↓

What does the specification say?

&#x20;       ↓

What is already implemented?

&#x20;       ↓

What is actually unknown?

&#x20;       ↓

What is the smallest correct change?

&#x20;       ↓

How will it be tested?

&#x20;       ↓

What evidence will prove it works?

&#x20;       ↓

What documentation must change?

```



Not:



```text

What code can I generate?

```



\---



\# 80. Final Rule



> \*\*An AI agent is a developer operating inside an existing engineering system, not an autonomous product designer.\*\*



The agent's job is to:



\* understand the specification

\* preserve architecture

\* make focused changes

\* measure uncertain behavior

\* test honestly

\* document decisions

\* protect existing work

\* report limitations clearly



When uncertain:



> \*\*Do not guess. Inspect, measure, document, or ask.\*\*



When something works:



> \*\*Prove it.\*\*



When something is untested:



> \*\*Say so.\*\*



When something is undecided:



> \*\*Do not silently decide it.\*\*



When something is unnecessary:



> \*\*Do not build it.\*\*



When something is difficult:



> \*\*Measure the difficulty instead of hiding it.\*\*



\*\*SoundMesh should become impressive because its engineering is real—not because the AI claims that it is.\*\*



