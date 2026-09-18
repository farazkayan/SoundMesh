\# SoundMesh — AI Task Protocol



\*\*File:\*\* `DOCS/AI/task-protocol.md`

\*\*Status:\*\* REQUIRED

\*\*Authority:\*\* AI task execution procedure

\*\*Applies to:\*\* All AI coding agents working on SoundMesh



\---



\# 1. Purpose



This document defines the mandatory workflow an AI coding agent should follow when performing a development task in SoundMesh.



The objective is to make AI-assisted development:



\* predictable

\* auditable

\* reproducible

\* safe

\* architecture-aware

\* test-driven

\* documentation-aware

\* resistant to hallucination

\* resistant to unnecessary changes



The agent should follow this protocol from task intake through final reporting.



\---



\# 2. Core Workflow



Every development task follows this general pipeline:



```text

TASK RECEIVED

&#x20;    ↓

UNDERSTAND

&#x20;    ↓

INSPECT REPOSITORY

&#x20;    ↓

READ RELEVANT DOCUMENTATION

&#x20;    ↓

CHECK GIT STATE

&#x20;    ↓

CLASSIFY TASK

&#x20;    ↓

IDENTIFY AUTHORITY

&#x20;    ↓

IDENTIFY UNKNOWNs

&#x20;    ↓

DEFINE SCOPE

&#x20;    ↓

CREATE IMPLEMENTATION PLAN

&#x20;    ↓

IMPLEMENT

&#x20;    ↓

TEST

&#x20;    ↓

INSPECT DIFF

&#x20;    ↓

UPDATE DOCUMENTATION

&#x20;    ↓

FINAL VERIFICATION

&#x20;    ↓

REPORT

```



The agent should not skip stages merely because the task appears simple.



For extremely small tasks, stages may be lightweight, but the underlying checks still apply.



\---



\# 3. Stage 1 — Receive the Task



First determine exactly what the user is asking for.



Extract:



```text

Objective

Scope

Constraints

Expected behavior

Files/components involved

Acceptance criteria

```



Do not immediately start coding.



The first question is:



> \*\*What does success actually mean?\*\*



\---



\# 4. Stage 2 — Normalize the Task



Translate the request into a concrete engineering objective.



Example:



User request:



> Add QR joining.



Engineering objective:



```text

Implement QR-based room joining that allows a participant

to obtain valid room bootstrap information and establish

a session with the host without requiring manual IP entry.

```



Do not expand the task beyond what is required.



\---



\# 5. Stage 3 — Classify the Task



Classify the task before implementation.



Possible classifications:



```text

BUG FIX

FEATURE

REFACTOR

EXPERIMENT

TEST

DOCUMENTATION

UI

NETWORKING

AUDIO

SYNCHRONIZATION

PLATFORM

BUILD / TOOLING

SECURITY

PERFORMANCE

```



A task may have multiple classifications.



Example:



```text

FEATURE + NETWORKING + SECURITY

```



Classification determines which documentation must be read.



\---



\# 6. Stage 4 — Inspect Repository Structure



Before changing code, inspect the repository.



Determine:



\* application entry points

\* source directories

\* platform directories

\* test directories

\* configuration files

\* generated code

\* documentation

\* dependency files



Do not assume the repository structure.



Inspect it.



\---



\# 7. Stage 5 — Read Relevant Documentation



Read the documentation relevant to the task.



\### UI task



Read:



```text

DOCS/ui-ux.md

DOCS/blueprint.md

```



\### Networking task



Read:



```text

DOCS/networking.md

DOCS/architecture.md

DOCS/blueprint.md

```



\### Audio task



Read:



```text

DOCS/audio.md

DOCS/synchronization.md

DOCS/architecture.md

```



\### Synchronization task



Read:



```text

DOCS/synchronization.md

DOCS/audio.md

DOCS/networking.md

DOCS/architecture.md

```



\### Architectural task



Read:



```text

DOCS/architecture.md

DOCS/decisions.md

DOCS/blueprint.md

DOCS/roadmap.md

```



\### General AI context



Read:



```text

DOCS/AI/ai-context.md

DOCS/AI/rules.md

```



If the task involves a documented decision, inspect `DOCS/decisions.md`.



\---



\# 8. Stage 6 — Inspect Existing Implementation



Find the code responsible for the requested behavior.



Determine:



\* what already exists

\* what interfaces already exist

\* what state already exists

\* what tests already exist

\* what assumptions the implementation currently makes

\* whether another implementation is already partially complete



Do not recreate functionality that already exists.



\---



\# 9. Stage 7 — Check Git State



Before modifying files, inspect:



```text

current branch

working tree

uncommitted changes

recent relevant commits

```



The agent must know whether existing modifications are present.



If another developer has uncommitted changes in the files that need modification:



> \*\*Do not overwrite them.\*\*



Determine whether the task can be performed safely around those changes.



\---



\# 10. Stage 8 — Identify the Authority



Determine which document defines the requested behavior.



For example:



```text

QR format

→ networking.md



Playback scheduling

→ synchronization.md + audio.md



Colors

→ ui-ux.md



Development order

→ roadmap.md



Architectural choice

→ decisions.md

```



The implementation must follow the authoritative source.



If the source does not define the behavior and the decision is architecturally significant, stop and report the ambiguity.



\---



\# 11. Stage 9 — Identify Unknowns



Separate known facts from assumptions.



Create an internal distinction:



```text

KNOWN

INFERRED

UNKNOWN

UNTESTED

BLOCKED

```



Example:



```text

KNOWN:

Flutter project exists.



KNOWN:

Android native module exists.



UNKNOWN:

Whether current Android audio engine exposes the required timestamp.



UNTESTED:

Actual synchronization on two physical devices.



BLOCKED:

iOS test because no iPhone is currently available.

```



This prevents assumptions from silently becoming architecture.



\---



\# 12. Stage 10 — Determine Whether the Task Is Safe to Implement



Before coding, ask:



1\. Is the requirement clear?

2\. Is the architecture clear?

3\. Are required APIs available?

4\. Is the task within scope?

5\. Could this overwrite another developer's work?

6\. Could it introduce a security problem?

7\. Does it require an architectural decision?

8\. Can success be tested?



If the answer to a critical question is unknown, investigate before implementation.



If investigation cannot resolve it, report the blocker.



\---



\# 13. Stage 11 — Define File Scope



Identify the files that should change.



Use:



```text

Allowed files

Potentially affected files

Do-not-touch files

```



Example:



```text

Allowed:

\- lib/room/...

\- lib/network/...

\- test/room/...



Potentially affected:

\- DOCS/networking.md



Do not touch:

\- native audio engine

\- UI theme

\- unrelated settings

```



This prevents scope creep.



\---



\# 14. Stage 12 — Build the Smallest Plan



Before implementation, form a concise plan.



Example:



```text

1\. Add room join model.

2\. Parse QR payload.

3\. Validate protocol version.

4\. Establish connection.

5\. Perform HELLO/WELCOME handshake.

6\. Register participant.

7\. Add tests.

8\. Update networking documentation if behavior changed.

```



The plan should be implementation-oriented but not unnecessarily detailed.



\---



\# 15. Stage 13 — Validate the Plan Against Architecture



Before writing code, ask:



> Does this plan fit SoundMesh's architecture?



Check:



```text

Flutter vs native boundary

Networking architecture

Audio architecture

Synchronization model

State machines

Security model

Testing strategy

```



If the plan violates an established architectural principle, revise the plan before coding.



\---



\# 16. Stage 14 — Implement Incrementally



Implement the smallest coherent piece first.



Prefer:



```text

model

→ interface

→ implementation

→ integration

→ tests

```



rather than writing a huge amount of code and testing only at the end.



Keep changes easy to inspect.



\---



\# 17. Stage 15 — Preserve Existing Interfaces



Do not break existing interfaces unnecessarily.



If an interface must change:



1\. identify every caller

2\. update affected implementations

3\. update tests

4\. update documentation

5\. verify the entire dependency chain



Do not modify an interface simply because another design looks cleaner.



\---



\# 18. Stage 16 — Handle Platform Differences Explicitly



When implementing Android and iOS functionality, do not assume they behave identically.



Separate:



```text

shared behavior

```



from:



```text

platform-specific behavior

```



Document meaningful differences.



If a platform cannot support the same behavior, expose capability information rather than pretending both platforms are identical.



\---



\# 19. Stage 17 — Implement Error Paths



Do not implement only the successful path.



Consider:



```text

timeout

disconnect

invalid input

duplicate request

stale request

permission denied

unsupported capability

corrupted data

network change

cancellation

interruption

resource exhaustion

```



For SoundMesh specifically, also consider:



```text

participant leaves

host disappears

audio transfer fails

audio preparation fails

synchronization fails

drift exceeds tolerance

playback becomes invalid

```



\---



\# 20. Stage 18 — Add Tests Alongside Implementation



Tests should be added as the behavior is implemented.



Choose the appropriate level:



```text

unit

integration

platform

device

multi-device

physical

```



Do not create tests that merely confirm implementation details if behavior is what actually matters.



\---



\# 21. Stage 19 — Run Static Verification



Run relevant static checks.



Depending on the project, this may include:



```text

formatter

linter

analyzer

type checker

compiler

```



Fix genuine errors before moving forward.



Do not suppress warnings merely to obtain a clean output unless suppression is justified.



\---



\# 22. Stage 20 — Run Automated Tests



Run the relevant test suite.



Record actual results.



Example:



```text

Unit tests: PASS

Integration tests: PASS

Android build: PASS

```



If something fails:



```text

Unit tests: FAIL

Reason: ...

```



Never hide failures.



\---



\# 23. Stage 21 — Run Real-Device Tests When Required



For features involving:



\* audio

\* synchronization

\* networking

\* permissions

\* device discovery

\* hardware

\* background behavior



test on physical devices when available.



Record:



```text

device

OS version

app version/build

network configuration

test scenario

result

```



This makes results reproducible.



\---



\# 24. Stage 22 — Test the Failure Cases



A feature is not adequately tested if only the happy path works.



For networking:



```text

connect

disconnect

reconnect

timeout

invalid message

network change

```



For synchronization:



```text

startup

drift

temporary network degradation

late join

pause

resume

seek

participant disappearance

```



For audio:



```text

prepare

play

pause

resume

seek

stop

interruption

route change

buffer underrun

```



\---



\# 25. Stage 23 — Inspect Actual Behavior



Do not rely solely on logs.



When appropriate, verify actual observable behavior.



Examples:



```text

Did both phones actually play?

Did the participant actually join?

Did playback remain synchronized?

Did the QR scanner actually establish a room?

Did the UI actually reflect the state?

```



For SoundMesh, observable behavior matters more than merely successful method calls.



\---



\# 26. Stage 24 — Inspect the Diff



After implementation and tests:



```text

git diff

```



or the equivalent repository diff mechanism should be inspected.



Check for:



\* unintended changes

\* debug statements

\* accidental files

\* secrets

\* unrelated formatting

\* temporary code

\* unnecessary dependencies

\* weakened tests

\* generated files

\* documentation inconsistencies



\---



\# 27. Stage 25 — Re-check Scope



Compare the final changes with the original task.



Ask:



> Did I change anything that was not necessary?



If yes:



\* revert unrelated changes when safe

\* or explain why they were necessary



The final implementation should remain focused.



\---



\# 28. Stage 26 — Update Documentation



If the implementation changes documented behavior, update the relevant documentation.



Examples:



```text

new protocol message

→ networking.md



new sync algorithm

→ synchronization.md



new audio behavior

→ audio.md



new architecture boundary

→ architecture.md



new product behavior

→ blueprint.md



new decision

→ decisions.md



new completed roadmap milestone

→ roadmap.md

```



Do not update documentation merely to make it appear complete.



Document actual behavior.



\---



\# 29. Stage 27 — Record Architectural Decisions



If the task required a meaningful architectural choice, record it in:



```text

DOCS/decisions.md

```



A decision record should contain:



```text

Decision

Context

Alternatives considered

Chosen approach

Reason

Consequences

Evidence

Status

```



If the agent is not authorized to make the decision, stop before implementing the architectural choice.



\---



\# 30. Stage 28 — Final Verification



Before reporting completion, verify:



```text

Requirement satisfied?

Tests passing?

Build passing?

Relevant platform tested?

Documentation correct?

No accidental files?

No secrets?

No unrelated changes?

No unreported limitations?

```



If any answer is no, either fix it or report it honestly.



\---



\# 31. Completion States



Every task should end in one of these states:



\### COMPLETE



Implementation and required verification succeeded.



\### COMPLETE WITH LIMITATIONS



Implementation works, but some required environments or tests remain unverified.



\### BLOCKED



The task cannot be completed without resolving an external or architectural blocker.



\### PARTIAL



Some requested functionality is complete, but the entire task is not.



\### EXPERIMENTAL



A prototype or experiment was implemented, but production readiness has not been established.



\---



\# 32. Never Claim More Than Was Verified



Use precise language.



Bad:



> Synchronization is perfect.



Good:



> Two Android devices were tested and showed a measured startup spread of X ms under the documented test conditions.



Bad:



> Works on iOS.



Good:



> The iOS implementation builds successfully. Physical iOS playback synchronization has not yet been tested.



Bad:



> Supports ten phones.



Good:



> Ten-device support has not yet been validated.



\---



\# 33. Synchronization Task Protocol



Synchronization tasks require additional discipline.



Before implementation:



```text

Read synchronization.md

Read audio.md

Read networking.md

Inspect native audio implementation

Inspect timing interfaces

```



Then identify:



```text

clock source

clock relationship

timestamp exchange

latency estimate

offset estimate

uncertainty

shared timeline

playback scheduling

measurement

correction

```



Never implement synchronization as merely:



```text

send PLAY

wait

play

```



\---



\# 34. Synchronization Experiment Protocol



When testing a synchronization algorithm, record:



```text

Experiment ID

Date

App/build version

Host device

Participant devices

OS versions

Network topology

Network conditions

Audio asset

Sample rate

Playback configuration

Calibration method

Target time

Measured startup spread

Measured steady-state spread

Drift

Correction behavior

Failures

Observations

Conclusion

```



This creates reproducible engineering evidence.



\---



\# 35. Networking Task Protocol



For networking changes:



```text

Inspect protocol

Inspect connection lifecycle

Inspect room state machine

Inspect participant identity

Inspect error handling

Inspect versioning

```



Verify:



```text

connect

handshake

message validation

ordering

duplicates

disconnect

reconnect

timeouts

state recovery

```



Do not assume reliable delivery simply because the current network appears reliable.



\---



\# 36. Audio Task Protocol



For audio changes:



```text

Inspect audio.md

Inspect synchronization.md

Inspect native audio abstraction

Inspect playback state

```



Verify:



```text

audio preparation

decoder initialization

buffer readiness

scheduled playback

actual playback state

pause

resume

seek

stop

interruption

route changes

```



Do not assume that successful decoding means synchronized playback.



\---



\# 37. UI Task Protocol



For UI changes:



```text

Read ui-ux.md

Inspect existing design system

Inspect current navigation

Inspect current state model

```



Verify:



```text

visual hierarchy

typography

spacing

touch targets

accessibility

dark theme

loading states

error states

actual system state

```



Do not create UI that claims a system state that has not actually occurred.



\---



\# 38. Bug Fix Protocol



For bugs:



```text

Reproduce

&#x20;   ↓

Observe

&#x20;   ↓

Identify root cause

&#x20;   ↓

Implement smallest fix

&#x20;   ↓

Add regression test

&#x20;   ↓

Verify original failure is gone

&#x20;   ↓

Check for regressions

```



Do not patch symptoms blindly.



If reproduction is impossible, say so.



\---



\# 39. Performance Task Protocol



For performance work:



```text

Measure baseline

&#x20;   ↓

Identify bottleneck

&#x20;   ↓

Change implementation

&#x20;   ↓

Measure again

&#x20;   ↓

Compare

```



Do not claim improvement without before/after evidence.



Example:



```text

Before: 42 MB

After: 31 MB

Measurement method: ...

Test device: ...

Scenario: ...

```



\---



\# 40. Security Task Protocol



For security-sensitive tasks:



```text

Identify asset

&#x20;   ↓

Identify threat

&#x20;   ↓

Identify trust boundary

&#x20;   ↓

Minimize exposure

&#x20;   ↓

Use established primitives

&#x20;   ↓

Test failure cases

&#x20;   ↓

Review for accidental leakage

```



Never invent cryptography.



Never commit credentials.



\---



\# 41. Dependency Addition Protocol



Before adding a dependency:



```text

Requirement

&#x20;   ↓

Existing platform/framework capability?

&#x20;   ↓

Existing dependency sufficient?

&#x20;   ↓

New dependency justified?

&#x20;   ↓

License checked

&#x20;   ↓

Maintenance checked

&#x20;   ↓

Platform support checked

&#x20;   ↓

Security considerations checked

```



Only then add it.



\---



\# 42. Refactoring Protocol



Refactoring should preserve behavior unless behavior change is explicitly intended.



Before refactoring:



```text

Identify behavior

Identify tests

Identify dependencies

```



After refactoring:



```text

Run tests

Compare behavior

Inspect diff

```



Do not combine a large refactor with an unrelated feature unless necessary.



\---



\# 43. Experiment vs Production Protocol



If the task is experimental:



Use an isolated implementation where practical.



Clearly label:



```text

EXPERIMENTAL

```



Do not allow an experiment to silently become the production architecture.



When the experiment finishes:



```text

Result

Evidence

Decision

Next action

```



should be recorded.



\---



\# 44. Handling Blockers



When blocked, report:



```text

Blocker

Why it blocks progress

What was investigated

Evidence

Possible options

Recommended next action

```



Do not create a speculative workaround that fundamentally changes the architecture just to avoid reporting a blocker.



\---



\# 45. Handling Multiple AI Agents



When multiple agents are working:



```text

Agent A

→ networking



Agent B

→ audio



Agent C

→ UI

```



is safer than:



```text

Agent A → entire repository

Agent B → entire repository

```



Each agent should have an explicit scope.



If another agent is already modifying a critical subsystem:



> coordinate before changing that subsystem.



\---



\# 46. Handoff Protocol



When handing work to another AI agent, provide:



```text

Task completed

Files changed

Current branch

Tests run

Tests passed

Tests not run

Known limitations

Important decisions

Remaining work

```



The receiving agent should not have to reconstruct the entire situation from the code.



\---



\# 47. Resume Protocol



When continuing partially completed work:



1\. inspect Git state

2\. inspect recent changes

3\. inspect relevant documentation

4\. inspect existing implementation

5\. determine what is actually complete

6\. determine what remains

7\. continue from the verified state



Do not assume previous AI work was correct merely because it exists.



\---



\# 48. Recovery From Bad AI Changes



If previous AI-generated code is incorrect:



Do not blindly preserve it because it already exists.



Instead:



```text

Identify incorrect behavior

&#x20;   ↓

Determine intended behavior from specifications

&#x20;   ↓

Determine whether existing tests catch it

&#x20;   ↓

Fix or revert appropriately

&#x20;   ↓

Add regression coverage

```



The repository specification takes precedence over previous AI output.



\---



\# 49. Final Report Format



Every meaningful task should end with:



```text

\## Summary



<what changed>



\## Files Changed



<files>



\## Implementation



<important technical details>



\## Tests



<actual commands/results>



\## Verification



<what was actually verified>



\## Not Tested



<what remains unverified>



\## Decisions



<decisions made or required>



\## Risks / Limitations



<known limitations>



\## Next Step



<smallest logical next action>

```



\---



\# 50. Final Checklist



Before declaring a task complete:



```text

\[ ] Requirement understood

\[ ] Repository inspected

\[ ] Relevant docs read

\[ ] Git state checked

\[ ] Authority identified

\[ ] Unknowns identified

\[ ] Scope defined

\[ ] Architecture checked

\[ ] Implementation completed

\[ ] Error paths considered

\[ ] Tests added where appropriate

\[ ] Static checks run

\[ ] Automated tests run

\[ ] Real-device tests run when required

\[ ] Actual behavior verified

\[ ] Diff inspected

\[ ] Scope rechecked

\[ ] Documentation updated

\[ ] Decisions recorded

\[ ] No secrets exposed

\[ ] No unrelated changes

\[ ] Limitations reported

\[ ] Final status determined

```



\---



\# 51. The Task Protocol in One Sentence



> \*\*Understand → inspect → verify authority → define scope → implement minimally → test honestly → inspect the diff → document reality → report evidence.\*\*



\---



\# 52. Final Principle



An AI agent should never measure its success by:



> “How much code did I write?”



It should measure success by:



> \*\*“Did I make the smallest correct change, prove what works, clearly identify what does not, and leave the repository more reliable than I found it?”\*\*



For SoundMesh, correctness is more important than speed.



Evidence is more important than confidence.



Architecture is more important than convenience.



And a clearly reported limitation is better than a confidently fabricated success.



