# SoundMesh

<p align="center">
  <strong>Turn nearby Android phones into one synchronized speaker.</strong>
</p>

<p align="center">
  <em>Multiple phones. One sound.</em>
</p>

<p align="center">
  A local-first Android app that coordinates nearby phones into a synchronized multi-device speaker system.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android-0B0D10?style=for-the-badge&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/Flutter-3.47.2-0B0D10?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12+-0B0D10?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/License-Open%20Source-0B0D10?style=for-the-badge" alt="License">
</p>

---

## The idea

We had music.

We had several phones.

We didn't have a speaker.

So we built one.

SoundMesh lets a group of nearby Android phones work together as a coordinated speaker system.

Instead of asking every phone to simply "play this now", SoundMesh builds a shared timing model between devices, distributes audio, prepares local playback, and schedules playback against a shared future timeline.

The goal is simple:

> **Make several independent phones feel like one audio system.**

---

## Why SoundMesh?

A phone already has:

* a speaker
* a microphone/audio subsystem
* a clock
* processing power
* a network connection

What it doesn't have is a way to naturally coordinate those things with several other phones.

If five phones all start the same audio at slightly different times, the result can sound like:

* echo
* flamming
* phase-like separation
* obvious device-to-device timing differences

The challenge isn't playing audio.

The challenge is **coordinating independent devices well enough that the separation becomes difficult to notice**.

SoundMesh treats that as a distributed-systems problem.

---

# How it works

At a high level:

```text
                     SOUND MESH ROOM

                           HOST
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
        PARTICIPANT    PARTICIPANT    PARTICIPANT
             │              │              │
             └──────────────┼──────────────┘
                            │
                            ▼
                    Shared Timing Model
                            │
                            ▼
                     Scheduled Playback
                            │
                            ▼
                     Coordinated Output
```

The normal flow is:

```text
Create Room
     ↓
Display QR Code
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
Synchronize Timing
     ↓
Create Shared Timeline
     ↓
Schedule Playback
     ↓
Play
     ↓
Monitor
     ↓
Recover / Resynchronize when needed
```

---

# The core technical idea

## Don't just send "PLAY NOW"

A naive implementation might do this:

```text
HOST
  │
  │ "PLAY"
  ├──────────────► Phone A
  ├──────────────► Phone B
  └──────────────► Phone C
```

That doesn't guarantee synchronized physical output.

Network transmission times differ.

Device processing times differ.

Audio pipelines differ.

Clock references differ.

Instead, SoundMesh prefers:

```text
          Shared logical timeline

                    │
                    ▼
             Future target T
             /       |       \
            /        |        \
           ▼         ▼         ▼
       Phone A    Phone B    Phone C
           │         │         │
           │ schedule locally  │
           ▼         ▼         ▼
       AudioTrack AudioTrack AudioTrack
           │         │         │
           └─────────┼─────────┘
                     ▼
              Coordinated output
```

Each device schedules against a future target using its own local playback system.

That makes timing a property of the **shared timeline**, not of whether three network packets happened to arrive in the same millisecond.

---

# Synchronization

Synchronization is the heart of SoundMesh.

The system distinguishes between several different timing concepts.

| Concept           | Meaning                                              |
| ----------------- | ---------------------------------------------------- |
| Clock offset      | Difference between device timing references          |
| RTT               | Round-trip network communication time                |
| Jitter            | Variation in packet/network timing                   |
| Audio latency     | Delay introduced by the audio pipeline               |
| Playback position | Where a device currently is in the audio stream      |
| Drift             | Change in synchronization over time                  |
| Sync error        | Difference between devices' intended playback timing |

These values are related, but they are not interchangeable.

For example:

> Low network latency does **not** automatically mean synchronized audio.

---

## Clock synchronization

SoundMesh exchanges timing information between devices using multiple timestamps.

Conceptually:

```text
Participant                         Host

   t1  ─────── TIME_SYNC_REQUEST ───────►

       ◄────── TIME_SYNC_RESPONSE ──────  t3

   t4
```

The system uses the exchange to estimate:

* round-trip time
* clock offset
* uncertainty

The calibration process is based on a monotonic timing source rather than wall-clock time.

On Android, monotonic timing is used so synchronization isn't affected by changes to the device's displayed clock.

---

# Shared playback timeline

After timing relationships are established, SoundMesh maps audio frames onto a shared timeline.

Conceptually:

```text
Shared timeline
─────────────────────────────────────────────►

        preparation
             │
             ▼
         audio ready
             │
             ▼
       future target
             │
      ┌──────┴──────┐
      ▼             ▼
   Device A       Device B
      │             │
      ▼             ▼
 local schedule  local schedule
      │             │
      └──────┬──────┘
             ▼
        synchronized
          playback
```

This is why SoundMesh is fundamentally different from simply sending identical files to multiple phones.

---

# Audio pipeline

SoundMesh separates application orchestration from timing-critical native audio work.

The simplified pipeline is:

```text
External Audio
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
Network Transport
      │
      ▼
Participant Receive
      │
      ▼
Jitter / Buffer Preparation
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

The high-frequency playback path stays close to the native Android audio stack.

Flutter handles the application and user-facing orchestration.

---

# Local-first architecture

SoundMesh is designed around nearby-device communication.

Normal operation does not depend on:

* a cloud backend
* a remote database
* a central media server
* user accounts
* streaming infrastructure
* permanent Internet access

The intended model is:

```text
                  LOCAL NETWORK

        ┌────────────────────────────┐
        │                            │
        │   HOST ◄──────────────►    │
        │    │        nearby         │
        │    ├──────────────► PHONE  │
        │    └──────────────► PHONE  │
        │                            │
        └────────────────────────────┘
```

The network exists primarily to coordinate and distribute the session.

The final playback happens locally on each device.

---

# Room system

A SoundMesh room represents one synchronized playback session.

## Host

The host:

* creates the room
* exposes join information
* distributes room state
* distributes audio
* coordinates synchronization
* manages connected participants
* can end the session

## Participants

Participants:

* join through the room QR code or join flow
* connect directly to the host
* receive room state
* receive audio
* calibrate timing
* prepare playback
* schedule local output

---

# QR joining

Joining is designed to be simple.

```text
HOST
  │
  │ Create Room
  ▼
ROOM CODE + QR
  │
  │ Scan
  ▼
PARTICIPANT
  │
  │ Connect
  ▼
ROOM
```

The QR payload contains temporary room-joining information required to establish the local session.

It is not intended to act as a permanent account credential.

---

# Multi-device support

SoundMesh is designed around a host with multiple participants rather than a single fixed peer.

Conceptually:

```text
                  HOST

          ┌────────┼────────┐
          │        │        │
          ▼        ▼        ▼
       Phone A  Phone B  Phone C
          │        │        │
          ▼        ▼        ▼
       Audio A  Audio B  Audio C
```

The architecture isolates participant connections so that one problematic connection should not unnecessarily destabilize the others.

The room state also tracks membership explicitly.

---

# Failure handling

Distributed systems fail.

Phones disconnect.

Networks change.

Users leave rooms.

A host can intentionally end a session.

SoundMesh therefore treats recovery as part of the product rather than an afterthought.

Examples include:

```text
Join failure
    ↓
Retry / recover
```

```text
Participant disconnect
    ↓
Remove participant
    ↓
Continue remaining session
```

```text
Host ends room
    ↓
Participants receive intentional termination
    ↓
Return to normal app flow
```

The intended invariant is:

> **A failed room should not require restarting the application.**

---

# Android-first

SoundMesh is currently an **Android-only application**.

The production codebase is intentionally focused on Android rather than maintaining unused iOS, macOS, Windows, or Linux application implementations.

This lets the project focus engineering effort on the platform capabilities SoundMesh actually needs, including:

* AudioPlaybackCapture
* MediaProjection
* AudioRecord
* AudioTrack
* Android lifecycle behavior
* Android background execution requirements
* Android networking
* Android settings and permissions

---

# Architecture

SoundMesh uses Flutter for the application layer and native Android for platform-critical functionality.

```text
┌─────────────────────────────────────────────┐
│                 FLUTTER                     │
│                                             │
│  UI                                         │
│  Navigation                                 │
│  Application state                          │
│  User interaction                           │
│  High-level orchestration                   │
│                                             │
└───────────────────┬─────────────────────────┘
                    │
              Typed bridge
                    │
                    ▼
┌─────────────────────────────────────────────┐
│                ANDROID                      │
│                                             │
│  Audio capture                              │
│  Audio playback                             │
│  Networking                                 │
│  Connection lifecycle                       │
│  Monotonic timing                            │
│  Scheduling                                 │
│  Platform services                          │
│                                             │
└─────────────────────────────────────────────┘
```

Timing-critical operations should remain close to the native Android audio system rather than being driven by Flutter frame timing.

---

# Technology stack

| Layer                    | Technology                |
| ------------------------ | ------------------------- |
| UI / application         | Flutter                   |
| Language                 | Dart                      |
| Android native           | Kotlin / Java             |
| Native audio             | Android audio APIs        |
| Audio playback           | `AudioTrack`              |
| Audio capture            | Android capture APIs      |
| Networking               | Native Android networking |
| State management         | Riverpod                  |
| QR generation            | `qr_flutter`              |
| QR scanning              | `mobile_scanner`          |
| Monetization integration | RevenueCat                |
| RevenueCat testing       | RevenueCat Test Store     |
| Local persistence        | `shared_preferences`      |
| Source control           | Git / GitHub              |

---

# RevenueCat

SoundMesh includes RevenueCat integration as part of the project.

The current implementation uses **RevenueCat's Test Store** for simulated purchase flows rather than real-money purchases.

That allows the project to exercise the RevenueCat integration without requiring a Google Play production billing setup.

The intended development model is:

```text
RevenueCat Test Store
        │
        ▼
Simulated purchase
        │
        ▼
Entitlement
        │
        ▼
SoundMesh UI
```

No real-money transaction is required for the development/test flow.

---

# UI

SoundMesh uses a dark, minimal visual system built around a **Midnight Teal** aesthetic.

The interface focuses on:

* clear hierarchy
* restrained color
* compact information density
* subtle surfaces
* strong contrast
* responsive layouts
* minimal navigation
* functional feedback

The UI is intentionally designed to hide the complexity of the distributed system underneath it.

The user experience should feel like:

```text
Create.
Join.
Choose.
Play.
```

---

# Design philosophy

### Local first

Prefer nearby direct communication whenever practical.

### Measure, don't guess

Synchronization behavior should be derived from timing measurements rather than assumptions.

### Schedule, don't shout

Future-target scheduling is preferred over blindly broadcasting "play now".

### Native where timing matters

Audio and timing-critical operations belong close to the platform audio system.

### Simple on the surface

The implementation may be complex.

The user experience should not be.

### Recover instead of restart

A failed operation should return the user to a valid state whenever possible.

### Evidence over claims

A feature isn't considered reliable merely because it compiles.

---

# Testing

SoundMesh is tested at multiple levels.

```text
Static analysis
      ↓
Unit tests
      ↓
Widget tests
      ↓
Integration / flow tests
      ↓
Android build
      ↓
Physical-device validation
      ↓
Multi-device validation
```

Automated tests are important, but they cannot completely prove synchronized physical audio behavior.

The most meaningful validation happens on real Android hardware.

Important areas include:

* room creation
* room joining
* reconnect/recovery
* room teardown
* multi-device membership
* background behavior
* audio capture
* audio transport
* scheduled playback
* synchronization
* lifecycle transitions

---

# Current status

SoundMesh is an actively developed Android project with the core room, networking, audio, synchronization, multi-device, recovery, RevenueCat, and responsive UI systems implemented.

The project is currently in **pre-submission hardening and physical validation**.

The focus at this stage is not adding random features.

It is making the existing experience:

* stable
* reproducible
* understandable
* visually polished
* recoverable
* testable on real hardware

---

# Repository structure

```text
SoundMesh/
│
├── app/
│   ├── android/
│   ├── lib/
│   │   ├── application/
│   │   ├── core/
│   │   ├── infrastructure/
│   │   └── presentation/
│   │
│   ├── test/
│   ├── third_party/
│   │   └── purchases_flutter/
│   ├── pubspec.yaml
│   └── pubspec.lock
│
├── LICENSE
└── README.md
```

The `third_party/purchases_flutter` directory contains the repository-local RevenueCat Flutter plugin used to keep the Android Test Store release-build behavior reproducible.

---

# Getting started

## Requirements

You need:

* Flutter SDK compatible with the project
* Android SDK
* Android Studio / Android tooling
* an Android device or emulator
* USB debugging enabled for physical-device testing

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

## Run in development

```bash
flutter run
```

---

## Build a release APK

```bash
flutter build apk --release
```

The generated APK is located at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## Install on a connected Android device

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

To see connected devices:

```bash
adb devices
```

To target a specific device:

```bash
adb -s DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-release.apk
```

---

# Physical testing

Because SoundMesh is a distributed audio system, the most meaningful test setup is multiple real Android phones on the same local network.

A basic session looks like:

```text
Phone A
  Host
    │
    ├────────► Phone B
    │           Participant
    │
    └────────► Phone C
                Participant
```

For serious synchronization validation, use multiple physical devices rather than relying exclusively on emulators.

---

# Performance considerations

SoundMesh contains several timing-sensitive paths.

The architecture therefore avoids pushing realtime work into the Flutter UI thread where possible.

Particular care is taken around:

* monotonic clocks
* audio buffering
* packet scheduling
* connection lifecycle
* participant isolation
* background execution
* repeated room creation/teardown
* native playback scheduling

Performance should be evaluated on the devices SoundMesh is actually expected to run on.

---

# Privacy

SoundMesh follows a local-first model.

The application is designed to minimize unnecessary remote communication and does not require a cloud backend for ordinary nearby-device playback.

Audio used by the local session is intended to remain within the local SoundMesh environment rather than being uploaded to a remote media service solely for synchronization.

Room information is session-oriented rather than intended to function as a permanent identity system.

---

# What SoundMesh is not

SoundMesh is not intended to be:

* a music streaming platform
* a social network
* a cloud music service
* a professional multi-room audio replacement
* a long-distance audio transport system
* an always-online service
* an unlimited-device audio infrastructure

Its focus is intentionally narrow:

> **Make nearby independent phones behave like one coordinated speaker system.**

---

# Limitations

SoundMesh is an engineering project, not a claim that every Android phone will behave identically.

Real-world behavior can vary with:

* Android version
* device hardware
* speaker hardware
* audio pipeline characteristics
* network conditions
* background restrictions
* device load
* thermal conditions
* manufacturer-specific Android behavior

Some capabilities require physical-device validation to establish reliable behavior across hardware.

---

# Contributing

Contributions are welcome.

Before changing core functionality:

1. Inspect the existing implementation.
2. Understand the current state flow.
3. Keep the scope focused.
4. Preserve existing behavior unless the change intentionally modifies it.
5. Test the change.
6. Run static analysis.
7. Inspect the final diff.
8. Document important behavioral changes.

Please avoid large architectural rewrites when a smaller correct change is sufficient.

---

# Project philosophy

SoundMesh exists because a surprisingly difficult engineering problem can hide inside a very simple idea.

At first glance:

```text
Play the same audio on several phones.
```

Underneath that:

```text
Independent clocks
       +
Independent audio pipelines
       +
Network delay
       +
Jitter
       +
Device-specific behavior
       +
Lifecycle failures
       +
Clock drift
       +
Real-world hardware
       =
Distributed synchronization problem
```

That is the interesting part.

---

# The goal

The goal isn't merely to make several phones play the same audio.

The goal is to make the user **forget there are several phones**.

Ideally:

```text
Create.
Join.
Play.

Multiple phones.

One sound.
```

---

# License

See [`LICENSE`](LICENSE) for the current project license.

---

<p align="center">
  <strong>SoundMesh</strong><br>
  Multiple phones. One sound.
</p>

<p align="center">
  Built to answer one simple question:
</p>

<p align="center">
  <em>Can a handful of phones become a speaker when you don't have one?</em>
</p>
