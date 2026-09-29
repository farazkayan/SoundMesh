# SoundMesh

<p align="center">
  <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/FOR_APP_ICON.png" alt="SoundMesh logo" width="180">
</p>

<p align="center">
  <strong>Multiple phones. One sound.</strong>
</p>

<p align="center">
  Turn nearby Android phones into a synchronized speaker system — without a cloud server or dedicated speaker.
</p>

<p align="center">
  <a href="https://github.com/farazkayan/SoundMesh/releases">
    <img src="https://img.shields.io/github/v/release/farazkayan/SoundMesh?style=flat-square" alt="Latest release">
  </a>
  <img src="https://img.shields.io/badge/platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/Flutter-3.47.2-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12%2B-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/github/license/farazkayan/SoundMesh?style=flat-square" alt="License">
</p>

---

## The problem

You have music.

You have five phones.

You don't have a speaker.

What if the phones could become the speaker?

That's SoundMesh.

SoundMesh is a local-first Android application that coordinates nearby phones so they can contribute to the same audio session as a distributed speaker system.

The idea sounds simple.

The engineering isn't.

---

## Why synchronized audio is hard

Playing the same audio on several phones is easy.

Getting several independent phones to behave like **one** is a completely different problem.

Every device has its own:

* clock
* processor
* audio pipeline
* speaker hardware
* operating-system behavior
* network conditions
* buffering
* latency
* timing drift

Even a small difference in when playback begins can turn a synchronized session into several noticeably separate speakers.

SoundMesh therefore approaches the problem as a **distributed timing system**, not simply a multi-device media player.

---

# How SoundMesh works

At the user level, the experience is intentionally simple:

```text
Create
  ↓
Join
  ↓
Play
```

Underneath that simple flow:

```text
Create Room
      ↓
Display QR
      ↓
Participant Joins
      ↓
Discover / Connect
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
Schedule Future Playback
      ↓
Play Locally
      ↓
Monitor Session
      ↓
Recover When Necessary
```

---

# The key idea: schedule, don't shout

A naive multi-device player might tell every phone:

```text
"PLAY NOW"
```

But a network message does not arrive at every device at exactly the same instant.

Instead, SoundMesh works toward a future playback target:

```text
                 Shared timeline

                        │
                        ▼
                  Future target
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
                 coordinated output
```

Each device schedules playback against the shared logical timeline using its own local audio system.

That distinction is at the center of SoundMesh.

---

# Synchronization

SoundMesh treats synchronization as a measurable engineering problem.

The system works with concepts including:

| Concept           | What it represents                          |
| ----------------- | ------------------------------------------- |
| Clock offset      | Difference between device timing references |
| RTT               | Round-trip communication time               |
| Jitter            | Variation in network timing                 |
| Audio latency     | Delay introduced by the audio pipeline      |
| Playback position | Current position within the audio stream    |
| Drift             | Change in timing alignment over time        |
| Sync state        | Current quality of synchronization          |

These values are related, but they are not interchangeable.

For example:

> **Low network latency does not automatically mean synchronized audio.**

---

## Clock calibration

Devices exchange timing information to estimate their timing relationship.

Conceptually:

```text
Participant                         Host

    t1 ───── TIME_SYNC_REQUEST ─────►

        ◄──── TIME_SYNC_RESPONSE ──── t3

    t4
```

The exchange provides information used to estimate:

* round-trip time
* clock offset
* timing uncertainty

SoundMesh relies on monotonic timing for synchronization rather than the device's user-facing wall clock.

This matters because a phone's displayed clock can change while elapsed monotonic time continues moving forward consistently.

---

# Shared playback timeline

Once devices are calibrated, audio frames can be mapped onto a shared logical timeline.

```text
Shared timeline
────────────────────────────────────────────────►

        preparation
             │
             ▼
          audio ready
             │
             ▼
        future target
             │
       ┌─────┴─────┐
       ▼           ▼
    Device A    Device B
       │           │
       ▼           ▼
 local schedule  local schedule
       │           │
       └─────┬─────┘
             ▼
         playback
```

This gives SoundMesh a common temporal reference without requiring the phones to share identical hardware.

---

# Audio pipeline

SoundMesh keeps timing-sensitive audio work close to the native Android audio stack.

The simplified pipeline looks like:

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

Flutter handles application logic and UI.

Android handles the timing-critical platform work.

---

# Local-first by design

SoundMesh is built around nearby-device communication.

Ordinary playback does not require a cloud backend, remote database, or media server.

The intended model is:

```text
                LOCAL NETWORK

             ┌──────────────────┐
             │                  │
             │      HOST        │
             │      / \         │
             │     /   \        │
             │    ▼     ▼       │
             │ Phone   Phone    │
             │                  │
             └──────────────────┘
```

The network coordinates the room and distributes the session data.

Each phone ultimately performs playback locally.

---

# QR-based joining

Joining a room is designed to be fast.

The host creates a room and presents a QR code.

A participant scans it.

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

The QR payload contains the temporary information required to establish the local room connection.

It is designed for session joining, not as a permanent account credential.

---

# Multi-device rooms

SoundMesh is built around a host and multiple participants.

```text
                       HOST
                        │
          ┌─────────────┼─────────────┐
          │             │             │
          ▼             ▼             ▼
       Phone A       Phone B       Phone C
      Participant   Participant   Participant
```

The architecture maintains participant-specific connections and room membership so devices can be managed independently.

A problem with one participant should not unnecessarily destabilize the entire room.

---

# Room lifecycle and recovery

A room is more than a connection.

It has a lifecycle:

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

SoundMesh also treats recovery as part of the product.

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

A fundamental goal is:

> **A failed room should not require restarting the application.**

---

# Android-first

SoundMesh is intentionally **Android-only**.

The project focuses its engineering effort on the platform features required to make synchronized device audio possible instead of maintaining unused desktop or iOS application layers.

That includes Android-specific capabilities such as:

* system audio capture
* `MediaProjection`
* `AudioRecord`
* `AudioTrack`
* native networking
* monotonic timing
* Android lifecycle handling
* background execution requirements
* Android permissions and settings

---

# Architecture

The application is split between Flutter and native Android responsibilities.

```text
┌──────────────────────────────────────────┐
│                  Flutter                 │
│                                          │
│  UI                                      │
│  Navigation                              │
│  Application State                       │
│  Room UX                                 │
│  User Interaction                        │
│  High-level orchestration                │
│                                          │
└────────────────────┬─────────────────────┘
                     │
                Typed bridge
                     │
                     ▼
┌──────────────────────────────────────────┐
│             Native Android              │
│                                          │
│  Audio Capture                           │
│  Audio Playback                          │
│  Networking                              │
│  Timing                                  │
│  Scheduling                              │
│  Connection Lifecycle                    │
│  Platform Services                       │
│                                          │
└──────────────────────────────────────────┘
```

The principle is simple:

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

SoundMesh includes RevenueCat integration using the **RevenueCat Test Store**.

The goal is to exercise a real RevenueCat integration and entitlement flow while keeping the project independent from real-money purchases during development and testing.

Conceptually:

```text
RevenueCat Test Store
        │
        ▼
Simulated Purchase
        │
        ▼
Customer Entitlement
        │
        ▼
SoundMesh UI
```

The project does not require real payment transactions for this test flow.

For Android release builds, the repository includes the required local RevenueCat plugin modification so the Test Store can continue functioning in an internal release build.

---

# UI

SoundMesh uses a dark, minimal interface built around a **Midnight Teal** visual language.

The design emphasizes:

* strong hierarchy
* restrained color
* subtle surfaces
* clear typography
* responsive layouts
* compact navigation
* useful feedback
* minimal visual noise

The complexity belongs underneath the interface.

The experience should not feel complicated.

---

# Design philosophy

### Local first

Prefer direct nearby-device communication whenever practical.

### Measure, don't guess

Timing behavior should be based on measurements instead of assumptions.

### Schedule, don't shout

Future-target playback is preferred over blindly broadcasting "play now".

### Native where timing matters

Realtime audio and timing-sensitive work should stay close to the platform audio system.

### Simple on the surface

The technology can be complicated.

The experience should not be.

### Recover instead of restart

Failures should return the user to a valid state whenever practical.

### Evidence over claims

A feature is not considered reliable simply because it compiles.

---

# What makes the project interesting

SoundMesh sits at the intersection of several engineering problems:

```text
                 SoundMesh

      ┌──────── Distributed Systems ────────┐
      │                                      │
      │  Clock Synchronization               │
      │  Network Timing                     │
      │  Audio Scheduling                   │
      │  Buffering                          │
      │  Device Heterogeneity               │
      │  Lifecycle Recovery                 │
      │                                      │
      └──────────────────────────────────────┘
                       │
                       ▼
                One User Experience
```

The user doesn't need to think about any of this.

They just need to:

```text
Create.
Join.
Play.
```

---

# Testing

SoundMesh uses multiple layers of validation:

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

Automated tests can verify software behavior.

They cannot completely prove what synchronized audio sounds like across different physical speakers.

That's why real hardware matters.

Important validation areas include:

* room creation
* room joining
* QR joining
* room teardown
* repeated room creation
* participant recovery
* lifecycle transitions
* background behavior
* audio capture
* audio transport
* playback scheduling
* synchronization
* multi-device membership

---

# Current status

SoundMesh is currently in **pre-submission hardening and physical validation**.

The project has implemented the core systems required for its current Android demo:

* room creation and joining
* QR-based joining
* local device discovery
* multi-participant rooms
* audio capture
* audio distribution
* synchronized playback scheduling
* clock synchronization
* participant-scoped synchronization
* lifecycle recovery
* responsive UI
* RevenueCat integration

The current focus is stability, reproducibility, and real-device validation rather than continuously adding features.

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

# Build the release APK

```bash
flutter build apk --release
```

The APK will be generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Install it with:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Check connected devices with:

```bash
adb devices
```

Or target a specific device:

```bash
adb -s DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-release.apk
```

---

# Physical multi-device testing

SoundMesh is fundamentally a multi-device application.

A basic setup:

```text
             HOST PHONE
                  │
          ┌───────┴───────┐
          │               │
          ▼               ▼
    PARTICIPANT      PARTICIPANT
       PHONE             PHONE
```

For meaningful synchronization testing, use multiple physical Android devices connected to the same local network.

Real hardware exposes timing, audio, networking, and lifecycle behavior that automated tests cannot fully reproduce.

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
├── LICENSE
└── README.md
```

The repository-local `purchases_flutter` package contains the Android-specific integration required for the project's RevenueCat Test Store release configuration.

---

# Performance

SoundMesh has several timing-sensitive paths, so the architecture avoids relying on Flutter UI-frame timing for realtime work.

Particular attention is given to:

* monotonic timing
* audio buffering
* packet scheduling
* connection lifecycle
* participant isolation
* room teardown
* repeated room creation
* native playback scheduling

Performance and synchronization behavior should ultimately be evaluated on real hardware.

---

# Privacy

SoundMesh is designed around local communication.

Ordinary nearby-device playback does not require a cloud media backend.

The project is designed to avoid unnecessary collection or remote transmission of user information.

Room information is session-oriented rather than intended as a permanent user identity system.

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

# Contributing

Contributions are welcome.

For meaningful changes:

1. Inspect the existing implementation.
2. Keep the scope focused.
3. Preserve existing behavior unless the change intentionally modifies it.
4. Avoid unnecessary architectural rewrites.
5. Run analysis and tests.
6. Inspect the final diff.
7. Document important behavioral changes.

Please prefer the smallest correct change over a broad rewrite.

---

# The engineering challenge

At first glance, SoundMesh looks like this:

```text
Play audio on several phones.
```

In reality:

```text
Independent clocks
        +
Independent audio systems
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
Timing drift
        +
Real hardware
        │
        ▼
Distributed synchronization problem
```

That's what SoundMesh is really about.

---

# The goal

The goal isn't simply to make several phones play the same file.

The goal is to make the user **forget that there are several phones**.

The ideal experience is:

```text
        Create
           ↓
          Join
           ↓
          Play

    ┌─────────────────┐
    │ Multiple phones │
    │                 │
    │    One sound    │
    └─────────────────┘
```

A speaker is usually one device.

SoundMesh asks a different question:

> **What if the speaker could be the devices you already have?**

---

# License

See [`LICENSE`](LICENSE) for the current project license.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/FOR_APP_ICON.png" alt="SoundMesh" width="90">
</p>

<p align="center">
  <strong>SoundMesh</strong><br>
  Multiple phones. One sound.
</p>
