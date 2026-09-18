\# Contributing to SoundMesh



\## 1. Purpose



This document defines how contributors work on SoundMesh safely and consistently.



SoundMesh is developed by a small human team with assistance from AI coding agents. Because multiple developers and AI agents may work on the project concurrently, contribution rules must protect:



\* code correctness

\* architectural consistency

\* Git history

\* documentation accuracy

\* synchronization correctness

\* platform-specific behavior

\* reproducibility

\* contributor ownership boundaries



This document is a workflow specification.



For AI-specific behavior, see:



\* `AGENTS.md`

\* `DOCS/AI/ai-context.md`

\* `DOCS/AI/rules.md`

\* `DOCS/AI/task-protocol.md`



For technical architecture and requirements, consult the relevant documents under `DOCS/`.



\---



\# 2. Project Philosophy



SoundMesh is not developed by adding features as quickly as possible.



The project prioritizes:



1\. proving the difficult technical assumptions

2\. maintaining a clear architecture

3\. measuring synchronization behavior

4\. testing on real devices

5\. keeping the user experience simple

6\. documenting important decisions

7\. avoiding unnecessary complexity



A contribution is successful when it improves the system without weakening its architecture, reliability, measurability, or maintainability.



\---



\# 3. Before Contributing



Before making a meaningful change, contributors must:



1\. understand the requested task

2\. inspect the repository

3\. check the current Git state

4\. read the relevant documentation

5\. identify affected subsystems

6\. check whether another contributor is modifying the same area

7\. determine whether the task is already covered by an existing requirement

8\. identify unresolved technical questions



AI agents must additionally follow the workflow in:



`DOCS/AI/task-protocol.md`



Do not begin implementation merely because a feature sounds useful.



\---



\# 4. Documentation Authority



When documents disagree, use this general authority order:



1\. current explicit human instruction

2\. `DOCS/decisions.md`

3\. relevant technical specification

4\. `DOCS/blueprint.md`

5\. `DOCS/roadmap.md`

6\. `DOCS/AI/ai-context.md`

7\. `DOCS/AI/rules.md`

8\. `DOCS/AI/task-protocol.md`

9\. implementation

10\. assumptions



If an important conflict cannot be resolved from existing documentation, stop and ask for clarification.



Do not silently choose an architectural direction.



\---



\# 5. Git Repository



The Git repository is the source of truth for code and tracked project files.



Contributors should keep the repository in a recoverable state.



Before starting work:



```bash

git status

```



Review:



\* current branch

\* uncommitted changes

\* untracked files

\* unexpected modifications



Do not overwrite another contributor's uncommitted work.



\---



\# 6. Branch Strategy



The repository uses a simple branch model.



\## Main branch



`main`



Purpose:



\* stable shared baseline

\* integration branch

\* competition-ready code when appropriate



Contributors should not directly perform large experimental changes on `main`.



\---



\## Developer branches



Each contributor should normally work on their own branch.



Examples:



```text

faraz-foundation

mahin-foundation

```



For focused work, branches may use:



```text

faraz/<area>

mahin/<area>

```



Examples:



```text

faraz/networking

mahin/audio-engine

faraz/ui-room

mahin/sync-spike

```



Do not create dozens of unnecessary branches for trivial edits.



\---



\# 7. Branch Ownership



A branch represents a contributor's working area.



A contributor is responsible for:



\* understanding their changes

\* testing their changes

\* reviewing their diff

\* resolving conflicts

\* documenting relevant architectural changes

\* communicating dependencies with other contributors



Ownership does not mean permanent control over a file.



It means contributors should coordinate before making overlapping changes.



\---



\# 8. AI Agent Branches



AI coding agents should normally operate on the branch belonging to the human directing them.



An AI agent must not:



\* switch branches without authorization

\* reset another contributor's branch

\* delete another contributor's work

\* force-push without explicit authorization

\* rewrite unrelated commits

\* modify unrelated subsystems

\* create architectural changes silently



If an AI agent discovers changes that appear to belong to another contributor, it should stop before overwriting them.



\---



\# 9. Multi-Agent Collaboration



Multiple AI agents may be used during development.



However:



> Two agents must not independently modify the same critical subsystem at the same time unless the work has been explicitly divided.



High-risk shared areas include:



\* synchronization engine

\* native audio engine

\* networking protocol

\* room state machine

\* platform bridge

\* playback scheduling

\* shared protocol models



Safer parallelization uses explicit ownership.



Example:



```text

Agent A

├── Flutter UI

└── navigation



Agent B

├── Android native audio

└── Android timing



Agent C

├── networking protocol

└── room connection logic

```



Each agent must know:



\* allowed files

\* forbidden files

\* interface dependencies

\* expected outputs

\* acceptance criteria



\---



\# 10. Live Collaboration



Real-time collaboration tools may be used when useful.



However:



\* Git remains the source of truth.

\* Live editing does not replace commits.

\* Shared editing does not remove ownership boundaries.

\* Contributors must communicate before changing shared critical files.



Live collaboration is a convenience, not the project's version-control system.



\---



\# 11. Task Scope



Every implementation task should have a clearly defined scope.



A good task identifies:



\* objective

\* reason

\* affected subsystem

\* allowed files

\* dependencies

\* acceptance criteria

\* tests

\* known limitations



Contributors should avoid unrelated cleanup while implementing a focused task.



For example, if the task is:



> Implement QR room joining.



Do not simultaneously:



\* redesign the entire navigation system

\* replace the networking library

\* rewrite the audio engine

\* introduce authentication

\* reorganize unrelated folders



unless those changes are necessary and explicitly approved.



\---



\# 12. Architecture Changes



Architecture changes require additional care.



Examples include:



\* changing the networking topology

\* replacing the audio engine

\* changing the Flutter/native boundary

\* introducing a new synchronization algorithm

\* changing the room state machine

\* changing the protocol

\* introducing cloud infrastructure

\* changing device identity semantics



These should not be treated as ordinary implementation details.



If an architectural decision changes, update:



`DOCS/decisions.md`



and any affected technical specification.



\---



\# 13. Requirement Status



SoundMesh uses explicit requirement statuses:



```text

REQUIRED

PREFERRED

OPTIONAL

UNDECIDED

REJECTED

EXPERIMENTAL

```



Contributors must respect these meanings.



In particular:



> `UNDECIDED` does not mean "choose whatever seems easiest."



If implementation requires an undecided architectural choice, document the alternatives and obtain a decision before committing to a permanent direction.



\---



\# 14. Experimental Work



Experimental work is encouraged when it reduces uncertainty.



Examples:



\* testing Android audio latency

\* comparing audio engines

\* measuring clock offset

\* testing Wi-Fi hotspot behavior

\* testing Wi-Fi Direct

\* testing Bluetooth

\* measuring playback drift

\* testing 5 or 10 devices

\* testing background behavior



Experiments should be isolated from production architecture where practical.



An experiment should record:



\* hypothesis

\* setup

\* devices

\* software versions

\* procedure

\* measurements

\* observations

\* conclusion

\* limitations

\* next action



Do not convert an experiment into a permanent architecture decision without evidence.



\---



\# 15. Commit Guidelines



Commits should represent coherent units of work.



Good examples:



```text

feat: add room creation state machine

feat: add QR room join flow

fix: handle participant reconnect

test: add clock offset estimation tests

docs: clarify playback scheduling requirements

refactor: isolate native audio adapter

```



Avoid vague commits such as:



```text

stuff

changes

fixed things

update

lol

```



A commit should ideally answer:



> What changed, and why?



\---



\# 16. Commit Size



Prefer focused commits.



Good:



```text

feat: add timestamp exchange protocol

test: add timestamp exchange validation

docs: document timestamp exchange

```



Less desirable:



```text

feat: build networking, audio, UI, sync, settings, diagnostics,

and refactor the whole project

```



Large commits make:



\* review harder

\* debugging harder

\* conflict resolution harder

\* rollback harder

\* AI-assisted development less reliable



\---



\# 17. Pull Requests



When using pull requests, a PR should contain:



\### Summary



What changed?



\### Motivation



Why was it needed?



\### Scope



What files/subsystems were affected?



\### Testing



What was tested?



\### Evidence



What results were observed?



\### Limitations



What remains unverified?



\### Documentation



What documentation changed?



\### Breaking changes



Does the change alter an interface, protocol, state machine, or architecture?



\---



\# 18. Pull Request Review



Reviewers should check:



\* correctness

\* scope

\* architecture

\* tests

\* error handling

\* concurrency

\* platform behavior

\* synchronization implications

\* performance

\* security

\* documentation

\* unnecessary complexity



For synchronization-related changes, reviewers should additionally ask:



\* What clock is being used?

\* Is it monotonic?

\* How is offset measured?

\* How is uncertainty handled?

\* Is network RTT being confused with audio latency?

\* How is actual playback position determined?

\* What happens when the network degrades?

\* What happens when a device drifts?

\* What happens when a participant disconnects?

\* Has this been tested on real devices?



\---



\# 19. Testing Requirements



A contribution should have the strongest applicable testing level.



\## Level 1 — Static verification



Examples:



\* formatting

\* linting

\* type checking

\* compilation

\* static analysis



\## Level 2 — Automated tests



Examples:



\* unit tests

\* protocol tests

\* state-machine tests

\* serialization tests

\* synchronization calculations



\## Level 3 — Integration tests



Examples:



\* room creation

\* device joining

\* audio transfer

\* playback coordination

\* reconnect behavior



\## Level 4 — Real-device testing



Required for behavior involving:



\* audio

\* networking

\* timing

\* permissions

\* Bluetooth

\* background behavior

\* hardware

\* battery

\* thermal behavior



A real-device claim must not be made from simulator/emulator results alone.



\---



\# 20. Test Evidence



Testing reports must distinguish:



```text

VERIFIED

INFERRED

UNTESTED

BLOCKED

```



Example:



```text

Android room creation: VERIFIED

iOS room creation: UNTESTED

Two-device synchronization: VERIFIED on Pixel + iPhone

Five-device synchronization: BLOCKED

Bluetooth route recovery: EXPERIMENTAL

```



Do not write:



> Works everywhere.



unless it has actually been demonstrated across the relevant supported configurations.



\---



\# 21. Synchronization Changes



Synchronization is a high-risk subsystem.



Changes affecting synchronization must consider:



\* clock source

\* clock offset

\* RTT

\* network jitter

\* timing uncertainty

\* audio latency

\* output latency

\* playback position

\* drift

\* correction behavior

\* startup scheduling

\* late joining

\* pause/resume

\* seek

\* recovery



Never optimize synchronization using a single unexplained magic number.



If a threshold is introduced, document:



\* what it represents

\* why it exists

\* how it was selected

\* whether it is measured or provisional

\* how it can be validated



\---



\# 22. Audio Changes



Audio changes must consider:



\* decoder behavior

\* sample rate

\* channel count

\* buffering

\* native scheduling

\* playback position

\* output route

\* hardware latency

\* interruptions

\* background behavior

\* CPU usage

\* battery usage



Do not move high-frequency audio timing work into Flutter merely for implementation convenience.



\---



\# 23. Networking Changes



Networking changes must preserve:



\* local-first operation

\* explicit protocol versions

\* message identity

\* session identity

\* participant identity

\* generation numbers

\* reliable control behavior

\* timeout handling

\* reconnection behavior

\* malformed-message handling



Do not use IP addresses as persistent device identity.



Do not put permanent secrets in QR codes.



Do not introduce Internet/cloud requirements into the MVP without an explicit architectural decision.



\---



\# 24. Security



Contributors must consider security even though SoundMesh is primarily a local application.



Important principles:



\* validate incoming messages

\* validate protocol versions

\* validate room membership

\* use short-lived join authorization

\* avoid permanent secrets in QR codes

\* avoid trusting arbitrary local-network traffic

\* use standard cryptographic primitives

\* do not invent custom cryptography

\* avoid logging secrets

\* avoid logging unnecessary personal data



Security decisions should be documented when they materially affect architecture.



\---



\# 25. Flutter and Native Code



SoundMesh uses Flutter for:



\* UI

\* navigation

\* high-level application state

\* user interaction

\* orchestration



Native Android/iOS code handles timing-sensitive platform behavior such as:



\* audio scheduling

\* low-level audio playback

\* timing

\* platform networking

\* platform-specific capabilities



Pigeon is preferred for strongly typed Flutter/native interfaces where appropriate.



Avoid sending high-frequency realtime timing data through Flutter if the operation can remain native.



\---



\# 26. UI Contributions



UI contributions must follow `DOCS/ui-ux.md`.



The interface should remain:



\* dark-first

\* minimal

\* premium

\* calm

\* audio-focused

\* readable

\* accessible



Core visual direction:



```text

Background:        #0B0D10

Surface:            #181D23

Elevated surface:   #20262D

Primary text:       #F5F7FA

Secondary text:     #A7AFB9

Muted text:         #6F7883

SoundMesh Blue:     #5B8CFF

Success:            #39D98A

Warning:            #FFB84D

Error:              #FF5C6C

```



Do not introduce random colors, excessive gradients, neon effects, or unrelated visual styles.



\---



\# 27. Documentation Contributions



Documentation is part of implementation.



Update documentation when a change affects:



\* architecture

\* protocol

\* synchronization

\* audio behavior

\* networking

\* UI behavior

\* requirements

\* testing methodology

\* important technical decisions



Do not allow implementation to become the only source of truth for important behavior.



\---



\# 28. Dependency Changes



Adding a dependency requires justification.



Before adding one, consider:



\* Is it actually necessary?

\* Does Flutter already provide the capability?

\* Can platform APIs provide it?

\* Is it maintained?

\* Is the license compatible?

\* Does it increase app size?

\* Does it affect performance?

\* Does it introduce network/cloud requirements?

\* Does it complicate iOS/Android compatibility?

\* Does it affect synchronization or audio timing?



Avoid adding dependencies simply because they make a small task easier.



\---



\# 29. Generated Files



Do not manually edit generated files unless the generation system explicitly requires it.



When generated code changes:



1\. modify the source definition

2\. regenerate

3\. verify generated output

4\. review the diff

5\. commit the appropriate files according to project conventions



\---



\# 30. Configuration and Secrets



Never commit:



\* API keys

\* passwords

\* private tokens

\* personal credentials

\* signing secrets

\* private certificates

\* production credentials



Use appropriate local configuration mechanisms.



Example:



```text

.env

local configuration

platform-specific secret storage

```



Never put secrets inside:



\* QR payloads

\* screenshots

\* logs

\* source code

\* public documentation



\---



\# 31. Formatting and Code Quality



Code should follow the conventions of the language and framework being used.



Before submitting:



\* format code

\* run available static checks

\* remove debug code

\* remove unused imports

\* remove dead code

\* inspect warnings

\* inspect the final diff



Do not perform unrelated formatting across the repository unless intentionally requested.



\---



\# 32. Error Handling



Errors should be explicit and actionable.



Good:



```text

Audio transfer failed.

Check that both devices are still connected and try again.

```



Bad:



```text

Error 0x8293

```



Internal error codes may exist for diagnostics, but users should receive understandable messages.



Errors should distinguish:



\* expected user action

\* temporary failure

\* recoverable system failure

\* unrecoverable session failure

\* developer/configuration error



\---



\# 33. State Machines



Important distributed behavior should use explicit states rather than scattered boolean flags.



Examples:



```text

DISCOVERABLE

JOINING

CALIBRATING

READY

PLAYING

DEGRADED

RECOVERING

ENDING

CLOSED

```



When modifying a state machine:



\* identify valid transitions

\* identify invalid transitions

\* define recovery behavior

\* update documentation if the state model changes

\* add tests for important transitions



\---



\# 34. Distributed-System Safety



SoundMesh consists of multiple independently executing devices.



Contributors must assume:



\* messages can be delayed

\* messages can be duplicated

\* messages can arrive out of order

\* devices can disconnect

\* clocks differ

\* network conditions change

\* devices can sleep

\* audio output can behave differently



Do not write distributed code as if all devices share one perfect clock or reliable instantaneous communication.



\---



\# 35. Playback Commands



Playback commands should use explicit session/playback generations where required.



Examples:



```text

PLAY

PAUSE

RESUME

SEEK

STOP

```



A stale command must not accidentally control a newer playback generation.



Do not use “play immediately on receipt” as the primary synchronization mechanism.



Future-target scheduling is the preferred model.



\---



\# 36. Reproducibility



When reporting a bug or performance issue, provide enough information to reproduce it.



Useful information includes:



\* device model

\* operating system version

\* app version

\* build/version identifier

\* network topology

\* number of devices

\* audio asset

\* reproduction steps

\* expected behavior

\* actual behavior

\* logs/diagnostics

\* frequency of occurrence



For synchronization experiments, include timing measurements where available.



\---



\# 37. Performance



Performance work should be evidence-driven.



Do not optimize solely because code "looks slow."



Measure where possible:



\* CPU

\* memory

\* startup time

\* join time

\* audio preparation time

\* synchronization time

\* network throughput

\* RTT

\* battery impact

\* thermal behavior

\* playback drift



Document the baseline before claiming improvement.



\---



\# 38. Battery and Thermal Behavior



SoundMesh may require simultaneous audio playback and networking on several devices.



Contributors must consider:



\* CPU utilization

\* audio processing cost

\* network activity

\* wake locks/background execution

\* device temperature

\* battery drain



Do not trade significant battery life for tiny synchronization improvements without measurement.



\---



\# 39. Platform Differences



Android and iOS are not assumed to behave identically.



Platform-specific behavior must be tested independently.



Examples:



\* local-network permissions

\* service discovery

\* background execution

\* audio sessions/routes

\* audio latency

\* clock APIs

\* Wi-Fi behavior

\* Bluetooth behavior

\* lifecycle events



Shared interfaces are desirable.



Identical internal implementations are not required.



\---



\# 40. Conflict Resolution



If Git reports conflicts:



1\. stop and inspect the conflict

2\. understand both changes

3\. determine whether the changes are compatible

4\. preserve intended behavior from both sides where possible

5\. run tests after resolution

6\. inspect the resulting diff



Do not blindly choose:



```bash

git checkout --theirs

```



or:



```bash

git checkout --ours

```



for important files.



Never resolve a conflict by deleting functionality simply because it is easier.



\---



\# 41. Protecting Work



Before risky operations, ensure work is recoverable.



Useful actions include:



```bash

git status

git diff

git add

git commit

```



For especially risky work, create a checkpoint commit before experimentation.



Do not use destructive commands such as:



```bash

git reset --hard

git clean -fd

git push --force

```



unless the consequences are understood and the operation is explicitly authorized.



\---



\# 42. Code Review Checklist



Reviewers should ask:



\### Correctness



\* Does the implementation actually satisfy the requirement?

\* Are edge cases handled?



\### Architecture



\* Does it respect the Flutter/native boundary?

\* Does it preserve the local-first design?

\* Does it fit the existing state model?



\### Synchronization



\* Are timing assumptions explicit?

\* Is behavior measured?



\### Networking



\* Are messages validated?

\* Are reconnects and failures handled?



\### Audio



\* Is playback scheduled correctly?

\* Are hardware differences considered?



\### Testing



\* Are appropriate tests present?

\* Were real devices used where necessary?



\### Security



\* Are secrets protected?

\* Is input validated?



\### Scope



\* Did the contribution modify only what was necessary?



\### Documentation



\* Is the relevant documentation still accurate?



\---



\# 43. Definition of Done



A contribution is considered complete when applicable requirements have been satisfied and:



\* implementation is complete

\* tests are added or updated

\* relevant checks pass

\* real-device testing is performed when required

\* the final diff is reviewed

\* no unrelated changes remain

\* documentation is updated

\* known limitations are recorded

\* architectural decisions are documented

\* Git state is clean or intentionally understood



"Code compiles" is not automatically equivalent to "done."



\---



\# 44. AI-Assisted Development



AI agents are first-class development tools in SoundMesh, but they operate under the same engineering standards as human contributors.



AI-generated code must be:



\* inspected

\* tested

\* reviewed

\* integrated intentionally



AI agents must not be trusted merely because generated code looks plausible.



Agents must follow:



`AGENTS.md`



and:



```text

DOCS/AI/ai-context.md

DOCS/AI/rules.md

DOCS/AI/task-protocol.md

```



An AI agent must report:



\* what it changed

\* why

\* what it tested

\* what it could not test

\* what remains uncertain

\* what files changed

\* whether documentation changed



\---



\# 45. AI Task Boundaries



When assigning an AI agent a task, provide:



```text

Objective:

Scope:

Allowed files:

Relevant documentation:

Constraints:

Acceptance criteria:

Tests:

Expected output:

```



Example:



```text

Objective:

Implement the initial room handshake.



Scope:

Networking protocol only.



Allowed files:

lib/network/\*\*

native/network/\*\*



Relevant documentation:

DOCS/networking.md

DOCS/AI/rules.md



Constraints:

Do not implement audio transfer.

Do not change synchronization.

Do not introduce cloud services.



Acceptance criteria:

Host accepts HELLO.

Participant receives WELCOME.

Protocol version is validated.

Invalid sessions are rejected.



Tests:

Unit tests for valid and invalid handshakes.

```



This keeps AI work bounded and reviewable.



\---



\# 46. AI Agent Handoff



When an AI agent finishes a task, it should leave a clear handoff.



Example:



```text

Status: COMPLETE WITH LIMITATIONS



Implemented:

\- Room HELLO/WELCOME handshake

\- Protocol version validation

\- Session ID validation



Tests:

\- Unit tests pass

\- Android build passes



Not tested:

\- iOS networking

\- Real-device Wi-Fi behavior



Known limitation:

\- Reconnection is not implemented yet



Files changed:

\- ...

```



The next agent should be able to continue without reconstructing the entire history.



\---



\# 47. When to Stop



A contributor or AI agent should stop and request clarification when:



\* requirements conflict

\* architecture is ambiguous

\* an `UNDECIDED` decision blocks implementation

\* a security-sensitive choice is unclear

\* multiple valid architectures have materially different consequences

\* testing is impossible and the result would otherwise be presented as verified

\* another contributor's work would be overwritten

\* a task expands beyond its defined scope



Stopping is preferable to silently making a permanent wrong decision.



\---



\# 48. What SoundMesh Contributors Should Optimize For



Do not optimize primarily for:



```text

lines of code

number of features

number of commits

speed of implementation

AI token efficiency

```



Optimize for:



```text

correctness

measurability

reliability

simplicity

maintainability

user experience

evidence

```



\---



\# 49. Final Contribution Principle



SoundMesh is a distributed realtime system disguised as a simple mobile app.



The user should experience:



```text

Create

Join

Choose

Play

```



while the engineering underneath handles:



```text

Networking

Clock relationships

Latency

Audio preparation

Scheduling

Drift

Recovery

Platform differences

```



Contributors should preserve that separation.



The goal is not to make the codebase look complicated.



The goal is to make the complexity \*\*disappear for the user\*\*.



> \*\*Build carefully. Measure honestly. Keep the architecture understandable.\*\*

>

> \*\*Multiple phones. One sound.\*\*



