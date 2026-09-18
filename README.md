\# SoundMesh



<p align="center">

&#x20; <strong>Turn nearby phones into one synchronized speaker.</strong>

</p>



<p align="center">

&#x20; A local-first mobile audio synchronization system built with Flutter and native Android/iOS audio and networking.

</p>



\---



\## What is SoundMesh?



SoundMesh lets multiple nearby phones work together as a synchronized speaker system.



No physical speaker.



No cloud server.



No Internet dependency for ordinary playback.



Just nearby phones working together.



The idea came from a simple real-world problem:



> \*\*We had music. We had five phones. We didn't have a speaker. So we built one.\*\*



SoundMesh turns that problem into an engineering challenge:



\*\*How do you make several independent phones behave like one audio system?\*\*



\---



\## Why Is This Hard?



Playing the same audio file on five phones is easy.



Playing it \*\*at the same time\*\* is not.



Every phone has its own:



\* hardware

\* audio pipeline

\* clock

\* operating system

\* network conditions

\* processing delays

\* output latency

\* clock drift



If one phone starts even slightly earlier than another, the result can sound like an echo or multiple separate speakers instead of one coherent sound source.



SoundMesh therefore treats synchronization as a distributed-systems problem.



The system measures the relationships between devices, creates a shared playback timeline, schedules playback against a future target, monitors actual playback, and corrects drift when necessary.



\---



\# Core Concept



```text

&#x20;                   SoundMesh Room



&#x20;                        HOST

&#x20;                         │

&#x20;             ┌───────────┼───────────┐

&#x20;             │           │           │

&#x20;             ▼           ▼           ▼

&#x20;        PARTICIPANT  PARTICIPANT  PARTICIPANT

&#x20;             │           │           │

&#x20;             ▼           ▼           ▼

&#x20;         Local Audio  Local Audio  Local Audio

&#x20;             │           │           │

&#x20;             └───────────┼───────────┘

&#x20;                         ▼

&#x20;                 Coordinated Playback

```



The phones do not need to behave as identical hardware.



Instead, SoundMesh measures and compensates for differences between them.



\---



\# How It Works



At a high level:



```text

Create Room

&#x20;    ↓

Join Room

&#x20;    ↓

Discover / Connect Devices

&#x20;    ↓

Transfer Audio

&#x20;    ↓

Prepare Local Playback

&#x20;    ↓

Measure Timing Relationships

&#x20;    ↓

Calibrate Devices

&#x20;    ↓

Create Shared Timeline

&#x20;    ↓

Schedule Future Playback

&#x20;    ↓

Play

&#x20;    ↓

Monitor Synchronization

&#x20;    ↓

Correct Drift

```



The important design decision is that SoundMesh does \*\*not\*\* primarily depend on sending a `PLAY NOW` command to every phone.



Instead, devices are given a future target on a shared logical timeline and schedule playback locally.



\---



\# Local-First



SoundMesh is designed around nearby-device communication.



The ordinary playback experience should not require:



\* cloud servers

\* user accounts

\* remote databases

\* Internet access

\* external streaming infrastructure



The preferred model is:



```text

Audio

&#x20; ↓

Distributed to participants

&#x20; ↓

Prepared locally

&#x20; ↓

Scheduled locally

&#x20; ↓

Played locally

```



This reduces unnecessary network dependency during actual playback.



The network primarily coordinates the system rather than carrying every audio sample continuously.



\---



\# Joining a Room



The preferred onboarding flow is QR-based.



A host creates a room and displays a QR code.



A participant scans it.



```text

HOST

&#x20; │

&#x20; │ creates room

&#x20; ▼

QR CODE

&#x20; │

&#x20; │ scan

&#x20; ▼

PARTICIPANT

&#x20; │

&#x20; │ connect

&#x20; ▼

ROOM

```



The QR code is intended to contain temporary room-joining information rather than permanent credentials or secrets.



Manual joining may exist as a fallback.



\---



\# Synchronization



Synchronization is the heart of SoundMesh.



The system considers several different timing concepts:



| Concept           | Meaning                                            |

| ----------------- | -------------------------------------------------- |

| Clock offset      | Difference between device timing references        |

| RTT               | Round-trip network time                            |

| Jitter            | Variation in network timing                        |

| Audio latency     | Delay introduced by the audio pipeline             |

| Output latency    | Delay before sound physically reaches the listener |

| Playback position | Where a device actually is in the audio            |

| Drift             | How synchronization changes over time              |

| Sync error        | Difference between devices' playback timing        |



These values are related, but they are \*\*not interchangeable\*\*.



For example:



> Low network latency does not automatically mean synchronized audio.



\---



\# Scheduled Playback



SoundMesh prefers future-target scheduling.



Conceptually:



```text

Current shared timeline

&#x20;       │

&#x20;       │

&#x20;       ▼

&#x20;  Future target

&#x20;       │

&#x20;  ┌────┴────┐

&#x20;  ▼         ▼

Phone A   Phone B

&#x20;  │         │

&#x20;  │ schedule locally

&#x20;  ▼         ▼

Playback  Playback

&#x20;  │         │

&#x20;  └────┬────┘

&#x20;       ▼

&#x20;synchronized output

```



This allows each device to account for its own local timing instead of assuming that a network command will reach every device simultaneously.



\---



\# Drift Correction



Synchronization does not end when playback starts.



Two devices can slowly diverge over time because their clocks and audio systems are not identical.



SoundMesh therefore monitors playback after startup.



Conceptually:



```text

PLAYING

&#x20;  ↓

MONITOR

&#x20;  ↓

DRIFT DETECTED?

&#x20;  │

&#x20;┌─┴──────────┐

NO            YES

&#x20;│             │

&#x20;▼             ▼

Continue    Correct

&#x20;              │

&#x20;              ▼

&#x20;          Monitor again

```



Corrections should be gradual whenever possible to avoid audible artifacts.



If synchronization becomes sufficiently degraded, controlled resynchronization may be required.



\---



\# Architecture



SoundMesh uses Flutter for the shared application layer while keeping platform-specific and timing-critical operations native.



```text

┌──────────────────────────────────────┐

│              Flutter                 │

│                                      │

│  UI                                  │

│  Navigation                           │

│  Application State                    │

│  User Interaction                    │

│  High-Level Orchestration            │

└──────────────────┬───────────────────┘

&#x20;                  │

&#x20;            Typed Native Bridge

&#x20;                  │

&#x20;       ┌──────────┴──────────┐

&#x20;       ▼                     ▼

┌───────────────┐     ┌───────────────┐

│    Android    │     │      iOS      │

│               │     │               │

│ Native Audio  │     │ Native Audio  │

│ Networking    │     │ Networking    │

│ Timing        │     │ Timing        │

│ Scheduling    │     │ Scheduling    │

└───────────────┘     └───────────────┘

```



Flutter should not be used as the realtime audio engine.



High-frequency timing-critical operations remain on the native side.



\---



\# Technology



| Layer                 | Technology                              |

| --------------------- | --------------------------------------- |

| Application framework | Flutter                                 |

| Language              | Dart                                    |

| Android               | Kotlin / native Android APIs            |

| iOS                   | Swift / native iOS APIs                 |

| UI                    | Flutter                                 |

| Local networking      | Platform-native networking              |

| Audio                 | Platform-native audio                   |

| Synchronization       | Custom SoundMesh synchronization system |

| Source control        | Git                                     |

| Repository            | GitHub                                  |



Exact native audio engines, transport details, and some platform-specific mechanisms remain subject to experimentation and validation.



\---



\# Design Philosophy



SoundMesh follows several principles.



\### Local first



Nearby devices should communicate directly whenever practical.



\### Measure, don't guess



Synchronization behavior should be measured rather than assumed.



\### Schedule, don't shout



Future-target playback is preferred over `PLAY NOW`.



\### Native where timing matters



Realtime audio and timing-critical operations belong close to the platform audio system.



\### Simple on the surface



The engineering underneath may be complicated.



The user experience should not be.



\### Evidence over claims



A feature is not considered reliable simply because the code compiles.



\### Real devices matter



Audio synchronization must eventually be validated on physical devices.



\---



\# Current Development Status



SoundMesh is an active engineering project.



The project is being developed incrementally, with the highest-risk technical assumptions tested before extensive product development.



The development sequence broadly follows:



```text

Foundation

&#x20;   ↓

Technical Spikes

&#x20;   ↓

Two-Device Synchronization

&#x20;   ↓

Reliable Room System

&#x20;   ↓

Audio Pipeline

&#x20;   ↓

Multi-Device Scaling

&#x20;   ↓

Recovery

&#x20;   ↓

Premium UX

&#x20;   ↓

Diagnostics

&#x20;   ↓

Physical Validation

&#x20;   ↓

Competition Hardening

```



The most important early milestone is:



> \*\*Two real phones playing the same audio with measured, repeatable synchronization.\*\*



\---



\# Development Roadmap



The project roadmap is documented in:



```text

DOCS/roadmap.md

```



The broad progression is:



1\. Repository foundation

2\. Flutter application shell

3\. Native platform bridge

4\. Local networking

5\. Room protocol

6\. QR joining

7\. Audio asset pipeline

8\. Native audio playback

9\. Playback scheduling

10\. Clock synchronization

11\. Two-device synchronized playback

12\. Sync monitoring

13\. Drift correction

14\. Multi-device scaling

15\. Device heterogeneity

16\. Failure recovery

17\. Production room state

18\. SoundMesh UI

19\. Diagnostics

20\. Performance optimization

21\. Physical synchronization validation

22\. Competition hardening



The order is intentional.



The project prioritizes proving difficult technical assumptions before investing heavily in polish.



\---



\# Repository Structure



```text

SoundMesh/

│

├── DOCS/

│   ├── blueprint.md

│   ├── roadmap.md

│   ├── architecture.md

│   ├── synchronization.md

│   ├── networking.md

│   ├── audio.md

│   ├── ui-ux.md

│   ├── decisions.md

│   ├── testing.md

│   │

│   └── AI/

│       ├── ai-context.md

│       ├── rules.md

│       └── task-protocol.md

│

├── AGENTS.md

├── CONTRIBUTING.md

├── LICENSE

└── README.md

```



The documentation is treated as part of the engineering system rather than optional project notes.



\---



\# Documentation



The most important documents are:



| Document              | Purpose                         |

| --------------------- | ------------------------------- |

| `blueprint.md`        | Product definition and goals    |

| `architecture.md`     | System architecture             |

| `synchronization.md`  | Synchronization system          |

| `networking.md`       | Networking and room protocol    |

| `audio.md`            | Audio architecture and behavior |

| `ui-ux.md`            | Visual and interaction system   |

| `roadmap.md`          | Development sequence            |

| `decisions.md`        | Architectural decisions         |

| `testing.md`          | Testing and validation strategy |

| `AI/ai-context.md`    | Context for AI developers       |

| `AI/rules.md`         | AI development rules            |

| `AI/task-protocol.md` | AI task execution procedure     |



Start with `AGENTS.md` when using an AI coding agent.



\---



\# Testing Philosophy



SoundMesh cannot be validated entirely through unit tests or emulators.



Testing progresses through several levels:



```text

Static Analysis

&#x20;     ↓

Unit Tests

&#x20;     ↓

Integration Tests

&#x20;     ↓

Platform Tests

&#x20;     ↓

Real Device Tests

&#x20;     ↓

Multi-Device Tests

&#x20;     ↓

Physical Synchronization Validation

```



Synchronization claims require evidence.



Important measurements include:



\* startup synchronization spread

\* steady-state synchronization spread

\* drift

\* correction behavior

\* RTT

\* calibration duration

\* join duration

\* recovery time

\* CPU usage

\* memory usage

\* battery impact

\* supported device count



Measured targets are documented in the relevant specifications.



They are targets, not guarantees.



\---



\# What SoundMesh Is Not



SoundMesh is not intended to be:



\* a music streaming service

\* a social network

\* a cloud music platform

\* a replacement for professional multi-room audio systems

\* a long-distance audio streaming system

\* a mandatory Internet service

\* a permanent cloud infrastructure project

\* an unlimited-device audio system



The focus is narrow:



> \*\*Make nearby independent phones behave like one coordinated speaker system.\*\*



\---



\# Security and Privacy



SoundMesh is designed with a local-first privacy model.



The application should avoid unnecessary collection or transmission of user information.



Room joining should use temporary authorization where required.



QR codes should not contain permanent credentials.



Audio selected for local playback should not be uploaded to a remote service merely to coordinate nearby playback.



Security mechanisms should use established platform and cryptographic primitives rather than custom cryptography.



\---



\# Contributing



Contributions should follow the project's engineering rules and documentation.



Before making significant changes:



1\. Read `AGENTS.md`.

2\. Read the relevant documentation.

3\. Inspect the existing implementation.

4\. Check Git state.

5\. Define the scope of the change.

6\. Implement the smallest correct change.

7\. Test the change.

8\. Inspect the final diff.

9\. Update documentation when behavior changes.

10\. Report what was actually verified.



See:



```text

CONTRIBUTING.md

```



for the complete contribution process.



\---



\# AI-Assisted Development



SoundMesh is intentionally designed to work well with AI coding agents.



AI agents are expected to operate inside the project's engineering system rather than independently redesigning the application.



The AI documentation defines:



```text

ai-context.md

&#x20;   ↓

What SoundMesh is



rules.md

&#x20;   ↓

How AI must behave



task-protocol.md

&#x20;   ↓

How AI must execute tasks

```



AI agents must never fabricate test results, silently make major architectural decisions, or claim support that has not been verified.



\---



\# Project Status Philosophy



SoundMesh uses evidence-based status.



A capability may be:



```text

PLANNED

EXPERIMENTAL

IMPLEMENTED

TESTED

VERIFIED

```



These terms should not be treated as interchangeable.



In particular:



```text

Implemented ≠ Tested

Tested ≠ Verified across all platforms

Works once ≠ Reliable

```



\---



\# The Goal



The goal is not simply to make several phones play the same file.



The goal is to make the user forget that there are several phones.



Ideally, the experience becomes:



```text

Create.

Join.

Choose.

Play.

```



And underneath those four simple actions is a carefully engineered distributed timing system.



\---



\# License



See `LICENSE` for the project's current license.



\---



\# SoundMesh



\*\*Multiple phones. One sound.\*\*



Built to answer one simple question:



> \*\*Can a handful of phones become a speaker when you don't have one?\*\*



We're building the answer.



