# SoundMesh

<p align="center">
  <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/FOR_APP_ICON.png" alt="SoundMesh logo" width="180">
</p>

<p align="center">
  <strong>Multiple phones. One sound.</strong>
</p>

<p align="center">
  Turn nearby Android phones into a synchronized speaker system.
</p>

<p align="center">
  No dedicated speaker. No cloud audio backend. Just the devices you already have.
</p>

<p align="center">
  <a href="https://github.com/farazkayan/SoundMesh">Repository</a>
  ·
  <a href="https://github.com/farazkayan/SoundMesh/issues">Issues</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/Flutter-3.47.2-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12%2B-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/github/license/farazkayan/SoundMesh?style=flat-square" alt="License">
</p>

---

# The problem

You have music.

You have several phones.

You don't have a speaker.

So what if the phones **could become the speaker**?

That's SoundMesh.

SoundMesh is a local-first Android application that coordinates nearby phones into a shared audio session, allowing multiple independent devices to contribute to one synchronized playback experience.

The idea is simple.

The engineering is not.

---

# Why this is difficult

Playing the same audio file on five devices is trivial.

Playing it so those five devices **behave like one system** is a distributed-systems problem.

Every phone has its own:

* clock
* processor
* audio pipeline
* buffering
* speaker hardware
* network conditions
* operating-system behavior
* processing latency
* clock drift

A tiny timing difference can turn a synchronized session into an obvious collection of separate speakers.

SoundMesh therefore doesn't treat synchronization as:

> "Send the same command to every phone."

It treats synchronization as:

> **Measure the devices, build a shared timing model, and schedule playback against it.**

---

# The experience

At the surface, SoundMesh is intentionally simple:

```text
┌───────────────┐
│ Create a Room │
└───────┬───────┘
        ↓
┌───────────────┐
│    Join       │
│  with QR code │
└───────┬───────┘
        ↓
┌───────────────┐
│     Play      │
└───────────────┘
```

Underneath:

```text
Create Room
     ↓
Display QR
     ↓
Participant Scans
     ↓
Connect
     ↓
Exchange Room State
     ↓
Distribute Audio
     ↓
Prepare Devices
     ↓
Calibrate Timing
     ↓
Build Shared Timeline
     ↓
Schedule Playback
     ↓
Play Locally
     ↓
Monitor
     ↓
Recover When Necessary
```

The complexity should stay underneath the experience.

---

# The key idea

## Schedule, don't shout.

A naive system could send:

```text
PLAY NOW
```

to every phone.

That sounds reasonable until you remember that network messages don't arrive at every device at exactly the same time.

Instead, SoundMesh works toward a **future playback target**.

```text
                    SHARED TIMELINE

                         │
                         ▼
                   Future Target
                    /    |    \
                   /     |     \
                  ▼      ▼      ▼
              Phone A Phone B Phone C
                  │      │      │
                  │ local scheduling
                  ▼      ▼      ▼
              Playback Playback Playback
                  │      │      │
                  └──────┼──────┘
                         ▼
                  Coordinated Output
```

Each device schedules its own local playback against the shared timeline.

That makes timing part of the system's model instead of assuming the network can deliver simultaneous commands.

---

# Synchronization

Synchronization is the heart of SoundMesh.

The system keeps different timing concepts separate:

| Concept           | Meaning                                       |
| ----------------- | --------------------------------------------- |
| Clock offset      | Difference between devices' timing references |
| RTT               | Round-trip communication time                 |
| Jitter            | Variation in network timing                   |
| Audio latency     | Delay introduced by the audio pipeline        |
| Playback position | Current location in the audio stream          |
| Drift             | Timing divergence over time                   |
| Sync state        | Current synchronization condition             |

These aren't interchangeable measurements.

For example:

> **Low network latency does not automatically mean synchronized audio.**

---

## Clock calibration

Devices exchange timing information to estimate their relationship.

Conceptually:

```text
Participant                         Host

   t1 ───── TIME_SYNC_REQUEST ─────►

       ◄──── TIME_SYNC_RESPONSE ──── t3

   t4
```

The exchange is used to estimate:

* round-trip time
* clock offset
* timing uncertainty

SoundMesh uses monotonic timing for synchronization rather than relying on a device's displayed wall-clock time.

---

# Shared playback timeline

Once devices are calibrated, audio frames can be mapped onto a shared logical timeline.

```text
Shared timeline
──────────────────────────────────────────────────────►

        Prepare
           │
           ▼
       Audio Ready
           │
           ▼
      Future Target
           │
      ┌────┴────┐
      ▼         ▼
   Device A   Device B
      │         │
      ▼         ▼
Local Schedule Local Schedule
      │         │
      └────┬────┘
           ▼
       Playback
```

The result is a coordinated playback model where every device knows **when** it should play rather than merely receiving a command telling it to start.

---

# Audio pipeline

SoundMesh keeps timing-sensitive work close to the native Android audio stack.

```text
System / External Audio
          │
          ▼
       Capture
          │
          ▼
      PCM Frames
          │
          ▼
     Packetization
          │
          ▼
   Local Network Transport
          │
          ▼
      Participant
          │
          ▼
    Receive / Buffer
          │
          ▼
 Shared Timeline Mapping
          │
          ▼
 Scheduled Native Playback
          │
          ▼
       AudioTrack
          │
          ▼
      Phone Speaker
```

Flutter handles the application experience and orchestration.

Android handles the timing-sensitive machinery.

---

# Local-first

SoundMesh is designed around nearby-device communication.

Ordinary playback is not built around a cloud media server or permanent remote infrastructure.

The intended architecture is:

```text
                    LOCAL NETWORK

               ┌───────────────────┐
               │       HOST        │
               │         │         │
               │    ┌────┴────┐    │
               │    ▼         ▼    │
               │  PHONE     PHONE  │
               │                   │
               └───────────────────┘
```

The local network coordinates the room and distributes session data.

The devices themselves perform playback.

---

# Joining a room

The host creates a room and presents a QR code.

A participant scans it and connects.

```text
HOST
  │
  │ Create Room
  ▼
QR CODE
  │
  │ Scan
  ▼
PARTICIPANT
  │
  │ Connect
  ▼
ROOM
```

The QR payload contains temporary information required to establish the room connection.

It is designed for joining a session, not as a permanent account credential.

---

# Multi-device rooms

SoundMesh is built around a host with multiple participants.

```text
                       HOST
                        │
          ┌─────────────┼─────────────┐
          │             │             │
          ▼             ▼             ▼
       Phone A       Phone B       Phone C
      Participant   Participant   Participant
```

Participant connections are tracked independently so room membership and connection failures can be handled per device.

The goal is for one problematic participant to be isolated rather than destabilizing the entire room.

---

# Room lifecycle

A SoundMesh room has a real lifecycle.

```text
Create
  ↓
Discoverable
  ↓
Participants Join
  ↓
Ready
  ↓
Playing
  ↓
Paused / Ready
  ↓
Closed
```

Closing a room is treated as a lifecycle transition, not merely "drop the socket."

That matters because a room may later need to be created again without restarting the application.

The intended invariant is:

> **Ending a room should leave the application ready to start another one.**

---

# Recovery

Distributed systems fail.

Phones disconnect.

Networks change.

Users leave.

Rooms close.

SoundMesh treats recovery as part of the product.

Examples:

```text
Join fails
   ↓
Retry
   ↓
New attempt
```

```text
Participant disconnects
   ↓
Remove participant
   ↓
Room continues
```

```text
Host ends room
   ↓
Participants are informed
   ↓
Return to normal app flow
```

A good failure state should recover the user.

It should not require:

```text
"Force close the app and try again."
```

---

# Android-first

SoundMesh is intentionally **Android-only**.

The project focuses its engineering effort on the platform capabilities required for synchronized device audio rather than maintaining application layers for platforms that aren't part of the project.

That means the native side is built around Android capabilities such as:

* `MediaProjection`
* `AudioRecord`
* `AudioTrack`
* system audio capture
* native networking
* monotonic timing
* Android lifecycle behavior
* background execution requirements
* Android permissions and settings

---

# Architecture

SoundMesh uses Flutter for the application layer and native Android for platform-critical work.

```text
┌────────────────────────────────────────────┐
│                  FLUTTER                  │
│                                            │
│  UI                                        │
│  Navigation                                │
│  Application State                         │
│  Room Experience                           │
│  User Interaction                          │
│  High-Level Orchestration                  │
│                                            │
└──────────────────────┬─────────────────────┘
                       │
                  Typed bridge
                       │
                       ▼
┌────────────────────────────────────────────┐
│              NATIVE ANDROID               │
│                                            │
│  Audio Capture                             │
│  Audio Playback                            │
│  Networking                                │
│  Timing                                    │
│  Scheduling                                │
│  Connection Lifecycle                      │
│  Platform Services                         │
│                                            │
└────────────────────────────────────────────┘
```

The architectural principle is:

> **Flutter runs the experience. Android runs the time-critical machinery.**

---

# Technology stack

| Layer                    | Technology                 |
| ------------------------ | -------------------------- |
| Application              | Flutter                    |
| Language                 | Dart                       |
| Android                  | Native Android             |
| Native code              | Kotlin / Java              |
| State management         | Riverpod                   |
| Audio capture            | Android audio capture APIs |
| Audio playback           | `AudioTrack`               |
| Networking               | Native Android networking  |
| QR generation            | `qr_flutter`               |
| QR scanning              | `mobile_scanner`           |
| Local preferences        | `shared_preferences`       |
| Monetization integration | RevenueCat                 |
| Purchase testing         | RevenueCat Test Store      |
| Source control           | Git / GitHub               |

---

# RevenueCat

SoundMesh includes RevenueCat as part of its application integration.

The current implementation uses the **RevenueCat Test Store** so the purchase and entitlement flow can be exercised without relying on real-money transactions.

Conceptually:

```text
RevenueCat Test Store
        │
        ▼
 Simulated Purchase
        │
        ▼
    Entitlement
        │
        ▼
   SoundMesh UI
```

This keeps the integration testable while avoiding unnecessary real payment infrastructure during development.

For Android internal release builds, the repository contains the local RevenueCat plugin modification required to allow the Test Store in a release build.

---

# UI

SoundMesh uses a dark, minimal interface built around a **Midnight Teal** visual language.

The design emphasizes:

* strong hierarchy
* restrained color
* clear typography
* responsive layouts
* subtle surfaces
* compact navigation
* useful feedback
* minimal visual noise

The goal is for the technical complexity of SoundMesh to disappear behind a simple experience.

```text
Create.
Join.
Play.
```

---

# Design philosophy

### Local first

Prefer direct nearby-device communication whenever practical.

### Measure, don't guess

Timing behavior should be based on measurements rather than assumptions.

### Schedule, don't shout

Future-target playback is preferred over blindly broadcasting a `PLAY NOW` command.

### Native where timing matters

Realtime audio and timing-sensitive work belongs close to the Android audio system.

### Simple on the surface

The implementation can be complicated.

The user experience should not be.

### Recover instead of restart

A failure should return the user to a valid state whenever practical.

### Evidence over claims

A feature is not reliable merely because it compiles.

---

# What makes SoundMesh interesting

SoundMesh combines several difficult areas in one project:

```text
               ┌───────────────────────┐
               │      SoundMesh        │
               └───────────┬───────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
   Distributed        Audio Systems     Networking
     Timing
          │                │                │
          └────────────────┼────────────────┘
                           │
                           ▼
                   Device Lifecycle
                           │
                           ▼
                    One Experience
```

The project isn't just about sending audio between phones.

It's about coordinating **independent machines with independent clocks, networks, and audio systems**.

---

# Testing

SoundMesh is validated at multiple levels.

```text
Static Analysis
      ↓
Unit Tests
      ↓
Widget Tests
      ↓
Flow / Integration Tests
      ↓
Android Build
      ↓
Physical Device Testing
      ↓
Multi-Device Testing
```

Automated tests are valuable.

They are not enough to prove synchronized physical sound.

Real hardware is essential for evaluating:

* timing
* speaker behavior
* capture behavior
* latency
* device-specific quirks
* background execution
* network conditions
* lifecycle behavior

---

# Current status

SoundMesh is in **pre-submission hardening and physical validation**.

The project currently contains the major systems required for its Android experience, including:

* room creation
* room joining
* QR-based joining
* local discovery
* multi-participant rooms
* audio capture
* audio transport
* synchronized playback scheduling
* clock synchronization
* participant-scoped synchronization
* room lifecycle handling
* recovery flows
* responsive UI
* RevenueCat integration

The current focus is not endless feature expansion.

It is making the existing system:

**stable, reproducible, understandable, and ready to demonstrate.**

---

# Getting started

## Requirements

* Flutter SDK compatible with this repository
* Android SDK
* Android build tools
* Android Studio or equivalent Android tooling
* Android device or emulator

SoundMesh is Android-only.

---

## Clone

```bash
git clone https://github.com/farazkayan/SoundMesh.git
cd SoundMesh/app
```

---

## Install dependencies

```bash
flutter pub get
```

---

## Run

```bash
flutter run
```

---

# Build a release APK

```bash
flutter build apk --release
```

The generated APK is located at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Install it with:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Check connected Android devices with:

```bash
adb devices
```

Or target a specific device:

```bash
adb -s DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-release.apk
```

---

# Physical multi-device testing

SoundMesh is fundamentally a multi-device system.

A basic test setup looks like:

```text
              HOST PHONE
                   │
          ┌────────┴────────┐
          │                 │
          ▼                 ▼
    PARTICIPANT        PARTICIPANT
       PHONE               PHONE
```

For meaningful synchronization testing, use real Android devices connected to the same local network.

Real hardware can expose differences that simulators and automated tests cannot reproduce.

---

# Performance

SoundMesh contains several timing-sensitive paths.

The architecture therefore avoids placing realtime work in Flutter UI-frame timing where it can be avoided.

Important areas include:

* monotonic clocks
* buffering
* packet scheduling
* native playback scheduling
* participant isolation
* room lifecycle
* connection cleanup
* background execution
* repeated room creation and teardown

Performance should be evaluated on the actual Android hardware being used.

---

# Privacy

SoundMesh is designed around local communication.

Ordinary nearby-device playback does not require a cloud media backend.

The project is designed to avoid unnecessary collection or remote transmission of user information.

Room information is session-oriented rather than intended to function as a permanent user identity system.

---

# Limitations

SoundMesh cannot guarantee identical behavior across every Android device.

Real-world behavior can vary with:

* Android version
* manufacturer modifications
* processor load
* speaker hardware
* audio pipeline characteristics
* network conditions
* background restrictions
* thermal behavior
* device-specific latency

Physical validation is therefore an important part of evaluating the system.

---

# Repository structure

```text
SoundMesh/
│
├── app/
│   ├── android/
│   ├── assets/
│   ├── lib/
│   │   ├── application/
│   │   ├── core/
│   │   ├── infrastructure/
│   │   └── presentation/
│   │
│   ├── test/
│   ├── third_party/
│   │   └── purchases_flutter/
│   │
│   ├── pubspec.yaml
│   └── pubspec.lock
│
├── .github/
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

The repository-local RevenueCat plugin keeps the Android Test Store release configuration reproducible rather than depending on a developer's local Pub Cache.

---

# Contributing

Contributions are welcome.

For meaningful changes:

1. Inspect the existing implementation.
2. Keep the scope focused.
3. Preserve existing behavior unless intentionally changing it.
4. Avoid unnecessary architectural rewrites.
5. Run analysis and tests.
6. Inspect the final diff.
7. Document important behavioral changes.

Prefer the smallest correct change over a broad rewrite.

---

# The engineering challenge

At first glance, SoundMesh looks like:

```text
Play the same audio on several phones.
```

Underneath:

```text
Independent clocks
        +
Independent audio pipelines
        +
Network delay
        +
Jitter
        +
Buffering
        +
Device-specific behavior
        +
Lifecycle failures
        +
Clock drift
        +
Real hardware
        │
        ▼
Distributed synchronization problem
```

That's the real project.

---

# The goal

The goal isn't simply to make several phones play the same file.

The goal is to make the user **forget there are several phones**.

Ideally:

```text
          CREATE
             ↓
            JOIN
             ↓
            PLAY

     ┌────────────────────┐
     │   Multiple phones  │
     │                    │
     │     ONE SOUND      │
     └────────────────────┘
```

A speaker is normally one device.

SoundMesh asks:

> **What if the speaker could be the devices you already have?**

---

# Made by

<p align="center">
  <a href="https://github.com/farazkayan">
    <strong>Faraz Kayan</strong>
  </a>
  &nbsp;&nbsp;·&nbsp;&nbsp;
  <a href="https://github.com/mahinite">
    <strong>Arifeen Mahin</strong>
  </a>
</p>

<p align="center">
  Built together as an Android-first exploration of synchronized multi-device audio.
</p>

---

# License

SoundMesh is licensed under the MIT License.

See [`LICENSE`](LICENSE) for the complete license text.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/FOR_APP_ICON.png" alt="SoundMesh" width="80">
</p>

<p align="center">
  <strong>SoundMesh</strong><br>
  Multiple phones. One sound.
</p>
