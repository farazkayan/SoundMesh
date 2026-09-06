\# SoundMesh Audio API Contract



\*\*File:\*\* `DOCS/interfaces/audio-api.md`

\*\*Status:\*\* EXPERIMENTAL

\*\*Owner:\*\* Faraz

\*\*Primary Consumers:\*\* Core API, Playback API, Device API, Synchronization System, Networking System, Integration Tests



\---



\# 1. Purpose



The Audio API defines the authoritative interface for preparing, validating, loading, and describing audio used by SoundMesh.



Its purpose is to ensure that audio handling remains independent from:



\* UI implementation

\* room management

\* network transport

\* synchronization algorithms

\* playback scheduling

\* platform-specific audio engines



The Audio API establishes the boundary through which the rest of SoundMesh interacts with audio resources.



The core principle is:



> \*\*Consumers request audio operations through the Audio API rather than directly manipulating platform audio engines or audio-processing internals.\*\*



\---



\# 2. Scope



The Audio API is responsible for:



\* audio resource identification

\* audio selection

\* audio metadata

\* audio validation

\* audio availability

\* audio preparation

\* local audio readiness

\* audio integrity

\* audio loading

\* audio resource lifecycle

\* audio-related errors



The Audio API does \*\*not\*\* own:



\* room membership

\* network transport

\* QR joining

\* clock synchronization

\* drift estimation

\* playback scheduling

\* UI rendering

\* synchronization correction

\* platform-specific playback timing



Those responsibilities belong to their respective systems.



\---



\# 3. Authority



The Audio API follows the SoundMesh authority hierarchy:



1\. Approved architectural decisions

2\. Interface contracts

3\. Core architecture specification

4\. Audio/networking/synchronization specifications

5\. Approved integration tests

6\. Existing implementation

7\. AI assumptions



When documentation conflicts with implementation, AI agents must not silently choose the implementation.



\---



\# 4. Audio Mental Model



SoundMesh should preferably distribute an audio resource to participating devices before playback.



Conceptually:



```text id="9c5m1a"

&#x20;                   Audio Resource

&#x20;                         │

&#x20;                         ▼

&#x20;                  Audio Preparation

&#x20;                         │

&#x20;                         ▼

&#x20;                Local Device Storage

&#x20;                         │

&#x20;                         ▼

&#x20;                Local Audio Pipeline

&#x20;                         │

&#x20;                         ▼

&#x20;             Scheduled Synchronized Playback

```



The goal is to avoid continuously streaming the audio from the host during normal playback.



This separates two problems:



```text id="3v3s7x"

Audio Distribution

&#x20;       +

Playback Synchronization

```



The synchronization system primarily needs to coordinate \*\*when\*\* each device plays the same prepared audio.



\---



\# 5. Audio Resource Identity



Every audio resource used by SoundMesh must have an identifiable representation.



Conceptual:



```text id="h0r5u3"

audioId

```



The exact format is:



\*\*UNDECIDED\*\*



The audio ID must not be confused with:



\* filename

\* local filesystem path

\* network URL

\* database row ID

\* user-visible title



The exact persistence scope is:



\*\*UNDECIDED\*\*



\---



\# 6. Audio Metadata



An audio resource may expose metadata such as:



```text id="p9cz0v"

AudioMetadata

├── audioId

├── filename

├── duration

├── format

├── size

├── sampleRate

├── channels

└── integrityHash

```



Exact schema:



\*\*UNDECIDED\*\*



Metadata must describe the actual audio resource.



AI agents must not fabricate metadata.



\---



\# 7. Supported Audio Formats



SoundMesh may support common formats such as:



```text id="7xq2tm"

MP3

AAC

M4A

WAV

FLAC

```



The final supported-format list is:



\*\*UNDECIDED\*\*



Platform differences must be explicitly considered.



A format supported on one platform must not automatically be assumed to work identically on another.



The implementation should prefer formats that provide reliable cross-platform decoding and predictable playback behavior.



\---



\# 8. Audio Selection



The Audio API may receive an audio resource selected by the user.



Conceptual operation:



```text id="9z2f2b"

selectAudio()

```



Selection may originate from:



\* local file picker

\* application library

\* imported file

\* future supported source



The exact source model is:



\*\*UNDECIDED\*\*



The Audio API must not assume that audio comes from a network URL unless the contract explicitly allows it.



\---



\# 9. `selectAudio()`



Conceptual input:



```text id="h4k6jw"

AudioSelectionRequest

```



Conceptual result:



```text id="l7w0q4"

AudioResource

```



Potential failures:



```text id="m4m1pd"

AUDIO\_NOT\_FOUND

AUDIO\_ACCESS\_DENIED

AUDIO\_FORMAT\_UNSUPPORTED

AUDIO\_INVALID

AUDIO\_SELECTION\_CANCELLED

INTERNAL\_ERROR

```



Final error names are:



\*\*UNDECIDED\*\*



\---



\# 10. Audio Validation



Before an audio resource becomes eligible for synchronized playback, it should be validated.



Validation may include:



```text id="7q8u3n"

Resource exists

Resource is readable

Format is supported

Audio can be decoded

Metadata is valid

Duration is known

Integrity information is available

```



The exact validation requirements are:



\*\*UNDECIDED\*\*



A resource that fails validation must not be reported as ready.



\---



\# 11. Audio Preparation



Audio preparation converts an audio resource into a form suitable for local playback.



Conceptual:



```text id="x7q3sd"

Audio Resource

&#x20;     ↓

Validation

&#x20;     ↓

Decode / Prepare

&#x20;     ↓

Local Playback Representation

&#x20;     ↓

READY

```



Preparation may include:



\* decoding

\* buffering

\* caching

\* resampling

\* format conversion

\* loading into a native playback pipeline



Exact preparation behavior is:



\*\*EXPERIMENTAL\*\*



AI agents must not assume that preparation means fully decoding an entire file into memory.



\---



\# 12. `prepareAudio()`



Conceptual operation:



```text id="f4t2sq"

prepareAudio(audioId)

```



Conceptual result:



```text id="q8j4ka"

AudioPreparationResult

```



Possible result states:



```text id="0j7f8m"

PREPARING

READY

FAILED

```



Exact schema:



\*\*UNDECIDED\*\*



Preparation must be asynchronous where required.



Large audio files must not block the UI thread.



\---



\# 13. Local Audio Availability



For synchronized playback, each participating device should have access to the required audio resource locally whenever possible.



Conceptual state:



```text id="4r6zqk"

NOT\_AVAILABLE

DOWNLOADING

VERIFYING

AVAILABLE

INVALID

FAILED

```



Exact state model:



\*\*UNDECIDED\*\*



A device must not report `AVAILABLE` merely because a file exists.



Integrity and usability may also need to be established.



\---



\# 14. Audio Integrity



Distributed audio must be verified to ensure that participating devices are playing equivalent content.



A cryptographic or content hash may be used.



Conceptual:



```text id="1c3r9a"

Audio Resource

&#x20;      │

&#x20;      ▼

&#x20;  Hash / Digest

&#x20;      │

&#x20;      ▼

Compare Across Devices

```



The exact algorithm is:



\*\*UNDECIDED\*\*



Potential candidates include modern cryptographic hashes.



The system must not rely solely on:



```text

filename

file size

duration

```



to establish content equality.



\---



\# 15. `verifyAudioIntegrity()`



Conceptual operation:



```text id="h6s0aa"

verifyAudioIntegrity(audioId, expectedHash)

```



Conceptual result:



```text id="8j3xq0"

{

&#x20;   valid: true

}

```



Exact request and result types:



\*\*UNDECIDED\*\*



Possible failures:



```text id="0m4b0n"

AUDIO\_NOT\_FOUND

HASH\_UNAVAILABLE

HASH\_MISMATCH

READ\_FAILED

INTERNAL\_ERROR

```



Final error taxonomy remains:



\*\*UNDECIDED\*\*



\---



\# 16. Audio Readiness



Audio readiness must be distinguished from playback readiness.



A device may have:



```text id="b8q2pf"

Audio: READY

Sync: NOT\_READY

Playback: NOT\_READY

```



Therefore:



> \*\*Audio readiness does not imply synchronized playback readiness.\*\*



The Audio API reports audio readiness only.



The Playback and Sync systems determine whether playback can begin.



\---



\# 17. Audio Resource State



Conceptual state machine:



```text id="f3d7rm"

UNAVAILABLE

&#x20;   │

&#x20;   ▼

SELECTED

&#x20;   │

&#x20;   ▼

VALIDATING

&#x20;   │

&#x20;   ├──────► INVALID

&#x20;   │

&#x20;   ▼

PREPARING

&#x20;   │

&#x20;   ├──────► FAILED

&#x20;   │

&#x20;   ▼

READY

```



This is a conceptual model.



Exact state transitions remain:



\*\*UNDECIDED\*\*



No AI agent may invent additional lifecycle transitions without updating the contract.



\---



\# 18. Audio Loading



The Audio API may provide an operation for loading prepared audio into the local audio pipeline.



Conceptual:



```text id="d1j5c4"

loadAudio(audioId)

```



Possible states:



```text id="h9c2s8"

NOT\_LOADED

LOADING

LOADED

FAILED

```



Exact semantics are:



\*\*UNDECIDED\*\*



Loading must not be confused with starting playback.



\---



\# 19. Playback Separation



The Audio API must not expose a shortcut that bypasses synchronized scheduling.



Incorrect:



```text id="w8f4zq"

audio.play()

```



if this immediately starts playback on the device.



Correct conceptual flow:



```text id="k3t8v1"

Audio API

&#x20;  │

&#x20;  ▼

Audio prepared

&#x20;  │

&#x20;  ▼

Playback API

&#x20;  │

&#x20;  ▼

Synchronization system determines timing

&#x20;  │

&#x20;  ▼

Scheduled local playback

```



The Audio API provides the prepared audio.



The Playback API controls execution.



\---



\# 20. Actual Playback Position



Actual playback position is primarily a Playback concern.



The Audio API may expose low-level information required by the Playback System.



However, it must not redefine playback state.



For example:



```text id="5c1p9k"

Audio API:

"What audio resource is loaded?"



Playback API:

"Where is playback currently?"



Sync API:

"How far is this device from the shared timeline?"

```



This separation must remain intact.



\---



\# 21. Sample Rate



Sample rate is potentially critical to synchronization and audio correctness.



Potential values:



```text id="v2e8qa"

44100 Hz

48000 Hz

96000 Hz

```



Actual supported rates vary by platform and hardware.



The Audio API may expose the actual effective sample rate.



The exact representation is:



\*\*UNDECIDED\*\*



AI agents must not assume that all devices use the same sample rate.



If resampling is required, ownership must be explicitly defined.



\---



\# 22. Channel Configuration



Potential channel configurations include:



```text id="8k4r2m"

Mono

Stereo

Multi-channel

```



SoundMesh MVP requirements are:



\*\*UNDECIDED\*\*



The implementation must not silently convert channel layouts in a way that changes the intended audio without documenting the behavior.



\---



\# 23. Resampling



Different devices may expose different native sample rates.



Conceptually:



```text id="j5n8q3"

Source Audio

&#x20;    │

&#x20;    ▼

Target Device Format

&#x20;    │

&#x20;    ▼

Resampling

&#x20;    │

&#x20;    ▼

Playback

```



Whether SoundMesh performs resampling itself or delegates it to platform audio systems is:



\*\*UNDECIDED\*\*



Resampling behavior must be considered when evaluating synchronization accuracy.



\---



\# 24. Audio Output Routing



A device may have multiple possible output routes:



```text id="q0y6s9"

Built-in Speaker

Wired Headphones

Bluetooth

External Audio Device

```



The Audio API may expose the current route.



Exact representation:



\*\*UNDECIDED\*\*



Bluetooth audio is currently considered:



\*\*EXPERIMENTAL\*\*



Bluetooth introduces additional and potentially variable latency.



It must not be assumed to behave like a built-in speaker.



\---



\# 25. Audio Interruptions



Audio playback may be interrupted by the operating system or another application.



Examples:



```text id="s4g7e2"

Incoming call

Alarm

Other audio application

System audio interruption

Audio route change

Headphone disconnect

Bluetooth disconnect

```



The Audio API may report such conditions.



The policy for responding to them belongs primarily to Playback/Core.



Exact interruption state model:



\*\*UNDECIDED\*\*



\---



\# 26. Background Behavior



Background audio behavior differs between Android and iOS.



The Audio API must not assume identical platform behavior.



Background playback requirements are:



\*\*UNDECIDED\*\*



Platform-specific implementation must remain behind the platform abstraction boundary.



\---



\# 27. Native Audio Boundary



SoundMesh timing-critical audio functionality may require native implementations.



\### Android



Potential technologies include:



```text id="2r8xk9"

Oboe

AAudio

AudioTrack

```



\### iOS



Potential technologies include:



```text id="q4n5x1"

AVAudioEngine

AVAudioPlayerNode

AVAudioTime

AVAudioSession

```



These are implementation technologies, not part of the public Audio API.



The final implementation may differ.



Flutter code must not directly depend on low-level native audio internals.



\---



\# 28. Flutter Boundary



The Flutter layer should interact with audio through the defined abstraction.



Conceptually:



```text id="n3p8t4"

Flutter UI

&#x20;   │

&#x20;   ▼

Core / Audio API

&#x20;   │

&#x20;   ▼

Platform Abstraction

&#x20;   │

&#x20;   ├── Android Native Audio

&#x20;   │

&#x20;   └── iOS Native Audio

```



Timing-sensitive operations should remain close to the native audio engine.



High-frequency realtime callbacks across the Flutter/native boundary should be avoided unless demonstrated to be safe.



\---



\# 29. Audio Events



Potential audio events include:



```text id="v7k2m0"

AUDIO\_SELECTED

AUDIO\_VALIDATED

AUDIO\_PREPARATION\_STARTED

AUDIO\_PREPARATION\_COMPLETED

AUDIO\_PREPARATION\_FAILED

AUDIO\_AVAILABILITY\_CHANGED

AUDIO\_INTEGRITY\_VERIFIED

AUDIO\_INTEGRITY\_FAILED

AUDIO\_ROUTE\_CHANGED

AUDIO\_INTERRUPTED

```



The event architecture is:



\*\*UNDECIDED\*\*



Event payloads must be explicitly defined before implementation.



\---



\# 30. Errors



Audio errors should use structured error codes.



Potential examples:



```text id="u2f6s9"

AUDIO\_NOT\_FOUND

AUDIO\_ACCESS\_DENIED

AUDIO\_INVALID

AUDIO\_FORMAT\_UNSUPPORTED

AUDIO\_DECODE\_FAILED

AUDIO\_PREPARATION\_FAILED

AUDIO\_NOT\_READY

AUDIO\_NOT\_AVAILABLE

AUDIO\_INTEGRITY\_FAILED

AUDIO\_HASH\_MISMATCH

AUDIO\_OUTPUT\_UNAVAILABLE

AUDIO\_ROUTE\_CHANGED

AUDIO\_INTERRUPTED

INTERNAL\_ERROR

```



These are candidate errors only.



Final names and semantics:



\*\*UNDECIDED\*\*



AI agents must not create competing error systems.



\---



\# 31. Concurrency



Audio operations may occur concurrently with:



\* room changes

\* network transfers

\* playback preparation

\* synchronization calibration

\* user interaction



The implementation must prevent:



\* simultaneous conflicting preparation

\* stale preparation results

\* outdated audio replacing newer selected audio

\* playback using invalidated resources

\* race conditions between selection and preparation



Exact concurrency semantics:



\*\*UNDECIDED\*\*



\---



\# 32. Generation Awareness



Audio preparation must be aware of the possibility that the active playback generation changes.



Example:



```text id="w0j7qp"

Generation 1:

Song A



Generation 2:

Song B

```



A delayed preparation result for Song A must not overwrite the active state for Song B.



Generation semantics are shared with the Playback and Synchronization systems.



\---



\# 33. Caching



SoundMesh may cache prepared audio resources.



Potential benefits:



\* faster replay

\* reduced network transfer

\* reduced preparation time

\* improved resilience



Caching policy is:



\*\*UNDECIDED\*\*



The implementation must define how stale or invalid cached resources are detected.



A cached file must not be assumed valid indefinitely.



Integrity verification remains authoritative where required.



\---



\# 34. Audio Distribution



When audio must be distributed to participants, the Networking System handles transport.



The Audio API should provide the information necessary for transfer, such as:



```text id="z8q5mc"

resource identity

metadata

size

integrity information

availability

```



The Audio API must not directly implement:



```text id="m5s8r3"

TCP transfer

UDP transfer

socket management

QR networking

peer discovery

```



Those belong to Networking.



\---



\# 35. Distribution Flow



The conceptual flow is:



```text id="c8v3y5"

Host selects audio

&#x20;       │

&#x20;       ▼

Audio validation

&#x20;       │

&#x20;       ▼

Audio metadata + integrity information

&#x20;       │

&#x20;       ▼

Networking distributes resource

&#x20;       │

&#x20;       ▼

Participant receives resource

&#x20;       │

&#x20;       ▼

Participant verifies integrity

&#x20;       │

&#x20;       ▼

Participant prepares audio

&#x20;       │

&#x20;       ▼

All required devices report audio READY

&#x20;       │

&#x20;       ▼

Playback system proceeds toward synchronized scheduling

```



This flow must remain compatible with:



\* `networking.md`

\* `playback-api.md`

\* `sync-api.md`



\---



\# 36. UI Consumption



The UI may display:



```text id="n9r4u1"

Selected song

Filename

Duration

Preparation state

Download state

Audio availability

Audio errors

```



The UI must not directly manipulate:



\* native audio engines

\* audio buffers

\* decoding pipelines

\* synchronization timing

\* audio integrity state



The UI consumes authoritative state.



\---



\# 37. Contract Testing



The Audio API must have contract tests covering at minimum:



\### Selection



```text id="a8m3y7"

Valid audio can be selected

Invalid resources are rejected

Unsupported formats are rejected

Cancellation is represented correctly

```



\### Validation



```text id="f2q7s1"

Unreadable resources fail validation

Invalid audio fails validation

Valid audio passes validation

```



\### Preparation



```text id="m4c8v0"

Preparation produces a valid result

Preparation failures are observable

Stale preparation cannot overwrite newer state

```



\### Integrity



```text id="k7d3p2"

Correct audio passes integrity verification

Modified audio fails integrity verification

Missing integrity information is handled explicitly

```



\### Availability



```text id="r5x9n4"

Audio availability is truthful

Missing audio is not reported as available

```



\### Separation



```text id="b6q1t8"

Audio operations do not start unscheduled playback

Audio API does not modify room membership

Audio API does not implement network transport

Audio API does not calculate synchronization metrics

```



\---



\# 38. Real-Device Testing



Audio behavior must eventually be tested on physical devices.



Minimum target:



```text id="q3m7x2"

2 physical phones

```



Testing should include:



\* same audio on both devices

\* different device hardware

\* different speaker hardware

\* different sample rates where applicable

\* audio preparation

\* audio integrity verification

\* output routing

\* interruption behavior

\* playback preparation

\* long-duration playback

\* synchronization interaction



For SoundMesh, simulated audio behavior is not sufficient for final synchronization validation.



\---



\# 39. AI Implementation Rules



AI agents implementing Audio API functionality MUST:



1\. Read this contract before modifying audio abstraction code.

2\. Read `audio.md`.

3\. Read `architecture.md`.

4\. Read `playback-api.md` when playback behavior is involved.

5\. Read `sync-api.md` when timing behavior is involved.

6\. Read `networking.md` when audio distribution is involved.

7\. Preserve the distinction between audio preparation and playback.

8\. Never fabricate audio metadata.

9\. Never fabricate readiness.

10\. Never bypass scheduled playback.

11\. Never silently change supported-format behavior.

12\. Never directly expose platform-specific implementation details to unrelated consumers.

13\. Add or update contract tests when behavior changes.

14\. Document new behavior.

15\. Stop when required semantics are undefined.



\---



\# 40. AI Stop Conditions



The agent MUST STOP and report a blocker when:



1\. The required audio resource schema is undefined.

2\. Supported-format behavior is unclear.

3\. Audio readiness semantics are unclear.

4\. Integrity requirements are unclear.

5\. Resampling behavior is required but undefined.

6\. Channel behavior is required but undefined.

7\. Audio route behavior conflicts between platforms or documents.

8\. A requested feature requires modifying Playback semantics.

9\. A requested feature requires modifying Sync semantics.

10\. A requested feature requires modifying Networking semantics.

11\. Existing code contradicts this contract.

12\. A new public operation is required but unspecified.

13\. The agent would need to invent metadata.

14\. The agent would need to fabricate readiness.

15\. The agent would need to bypass the synchronized playback architecture.



The agent must not resolve these conditions by guessing.



\---



\# 41. Contract Change Procedure



Any breaking or cross-subsystem Audio API change must be documented before implementation.



Use:



```text id="u6y3p9"

Current Contract:

<existing behavior>



Proposed Change:

<new behavior>



Reason:

<why the change is necessary>



Affected Systems:

<Audio / Playback / Sync / Networking / Core / UI>



Compatibility Impact:

<breaking or non-breaking>



Required Updates:

<implementation / tests / documentation>



Decision:

UNDECIDED

```



Cross-subsystem changes require coordination with the affected subsystem owners.



\---



\# 42. Dependency Map



```text id="0x5r8n"

&#x20;                    ┌──────────────┐

&#x20;                    │   Core API   │

&#x20;                    └──────┬───────┘

&#x20;                           │

&#x20;                           ▼

&#x20;                    ┌──────────────┐

&#x20;                    │  Audio API   │

&#x20;                    └──────┬───────┘

&#x20;                           │

&#x20;             ┌─────────────┼─────────────┐

&#x20;             ▼             ▼             ▼

&#x20;        Networking      Playback        Device

&#x20;             │             │

&#x20;             │             ▼

&#x20;             │           Sync

&#x20;             │             │

&#x20;             └─────────────┼─────────────┘

&#x20;                           ▼

&#x20;                    Integration Tests

```



The Audio API provides audio resources and preparation state.



It does not become the owner of network transfer, playback timing, or synchronization.



\---



\# 43. Relationship to Other Contracts



This contract must remain consistent with:



```text id="p2v8q4"

DOCS/interfaces/core-api.md

DOCS/interfaces/room-api.md

DOCS/interfaces/device-api.md

DOCS/interfaces/playback-api.md

DOCS/interfaces/sync-api.md

DOCS/interfaces/README.md

DOCS/audio.md

DOCS/networking.md

DOCS/synchronization.md

DOCS/architecture.md

DOCS/testing.md

DOCS/contract-testing.md

DOCS/AI/rules.md

DOCS/AI/task-protocol.md

DOCS/AI/integration-protocol.md

```



\---



\# 44. Current Open Questions



The following remain intentionally unresolved:



```text id="m8c4z1"

1\. Exact AudioResource schema

2\. Exact audioId format

3\. Supported audio formats

4\. Maximum supported file size

5\. Metadata schema

6\. Integrity hash algorithm

7\. Local storage strategy

8\. Cache strategy

9\. Preparation semantics

10\. Decode strategy

11\. Sample-rate normalization

12\. Resampling ownership

13\. Channel configuration requirements

14\. Audio route model

15\. Bluetooth behavior

16\. Background playback requirements

17\. Interruption state model

18\. Event architecture

19\. Audio transfer integration

20\. Native audio abstraction details

21\. Flutter/native data representation

22\. Exact error taxonomy

23\. Generation handling details

24\. Audio library/import sources

25\. Audio persistence lifecycle

```



These questions must remain visible until explicitly resolved.



\---



\# 45. Definition of Done



Audio API implementation is complete only when:



```text id="s9x2k7"

□ Audio resource identity is defined

□ Audio metadata is defined

□ Supported formats are defined

□ Validation behavior is implemented

□ Preparation behavior is implemented

□ Audio readiness is truthful

□ Integrity verification is implemented where required

□ Audio distribution boundary is respected

□ Playback is not started directly by Audio API

□ Platform-specific implementation remains behind the abstraction

□ Structured errors are implemented

□ Contract tests exist

□ Integration tests exist

□ Real-device audio testing has been performed

□ Documentation matches implementation

□ No undocumented public behavior exists

□ No fake metadata or readiness exists

□ Git diff has been reviewed

```



\---



\# 46. Final Principle



The Audio API answers:



> \*\*“What audio resource are we using, is it valid, and is it prepared and available for playback?”\*\*



It does not answer:



> “When should it play?”



That belongs to Playback and Synchronization.



It does not answer:



> “How do we transfer it?”



That belongs to Networking.



It does not answer:



> “Which devices are members?”



That belongs to Room.



It does not answer:



> “How synchronized are the devices?”



That belongs to Sync.



\*\*Audio provides the material.

Networking distributes it.

Playback executes it.

Synchronization determines when it executes.\*\*



The boundaries must remain explicit so independently developed AI components cannot silently build incompatible systems.



