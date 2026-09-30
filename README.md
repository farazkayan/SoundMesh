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
  <a href="https://getsoundmesh.pages.dev">Website</a>
  ·
  <a href="https://github.com/farazkayan/SoundMesh/releases">Latest Release</a>
  ·
  <a href="https://github.com/farazkayan/SoundMesh/issues">Issues</a>
</p>

<p align="center">
  <a href="https://github.com/farazkayan/SoundMesh/releases">
    <img src="https://img.shields.io/github/v/release/farazkayan/SoundMesh?style=flat-square&label=latest%20release" alt="Latest release">
  </a>
  <img src="https://img.shields.io/badge/Android-172126?style=flat-square&logo=android&logoColor=3DDC84&labelColor=172126" alt="Android">
  <img src="https://img.shields.io/badge/Flutter-3.47.2-172126?style=flat-square&logo=flutter&logoColor=54C5F8" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12%2B-172126?style=flat-square&logo=dart&logoColor=54C5F8" alt="Dart">
  <img src="https://img.shields.io/badge/license-MIT-172126?style=flat-square" alt="MIT License">
</p>

---

## The Problem

You have music.

You have several phones.

You don't have a speaker.

**So what if the phones could become the speaker?**

That's SoundMesh.

SoundMesh is a local-first Android application that coordinates nearby phones into a shared audio session, allowing multiple independent devices to contribute to one synchronized playback experience.

The idea is simple.

The engineering is not.

---

# The Experience

At the surface, SoundMesh is intentionally simple:

**Create a room → Join nearby → Connect → Play together**

Underneath that simple experience:

```text
Create Room
     ↓
Display QR
     ↓
Participant Scans
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

The complexity stays underneath the interface.

---

## SoundMesh in Action

The interface is intentionally simple on the surface — the difficult parts happen underneath.

<details>
<summary><strong>View SoundMesh screenshots</strong></summary>

<br>

<table>
  <tr>
    <td align="center" width="50%">
      <strong>Home</strong><br><br>
      <a href="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/home_screen.png">
        <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/home_screen.png" alt="SoundMesh Home Screen" width="100%">
      </a>
    </td>
    <td align="center" width="50%">
      <strong>Create Room</strong><br><br>
      <a href="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/create_room.png">
        <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/create_room.png" alt="SoundMesh Create Room Screen" width="100%">
      </a>
    </td>
  </tr>
  <tr>
    <td align="center">
      <strong>Join Room</strong><br><br>
      <a href="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/join_room.png">
        <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/join_room.png" alt="SoundMesh Join Room Screen" width="100%">
      </a>
    </td>
    <td align="center">
      <strong>QR Code</strong><br><br>
      <a href="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/qrcode_modal_popup.png">
        <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/qrcode_modal_popup.png" alt="SoundMesh QR Code Modal" width="100%">
      </a>
    </td>
  </tr>
  <tr>
    <td align="center">
      <strong>Room Dashboard</strong><br><br>
      <a href="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/room_dashboard.png">
        <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/room_dashboard.png" alt="SoundMesh Room Dashboard" width="100%">
      </a>
    </td>
    <td align="center">
      <strong>Connected Devices</strong><br><br>
      <a href="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/room_devices_screen.png">
        <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/room_devices_screen.png" alt="SoundMesh Connected Devices Screen" width="100%">
      </a>
    </td>
  </tr>
</table>

</details>

---

# Why Synchronized Audio Is Hard

Playing the same audio file on several phones is easy.

Getting several independent phones to behave like **one system** is a distributed-systems problem.

Every phone has its own:

* clock
* processor
* audio pipeline
* buffering
* speaker hardware
* network conditions
* operating-system behavior
* processing latency
* timing drift

A tiny difference in playback timing can turn one intended sound into several obvious speakers.

SoundMesh therefore doesn't treat synchronization as:

> "Send the same command to every phone."

It treats synchronization as:

> **Measure the devices, build a shared timing model, and schedule playback against it.**

---

# The Key Idea

## Schedule, Don't Shout.

A naive multi-device player might send:

```text
PLAY NOW
```

to every device.

That doesn't guarantee synchronized playback.

Network messages don't arrive at every phone at precisely the same moment.

Instead, SoundMesh works toward a future playback target:

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

Each device schedules its own local playback against the shared logical timeline.

That makes timing a property of the system's model rather than a side effect of packet arrival time.

---

# Synchronization

Synchronization is the heart of SoundMesh.

The system keeps several timing concepts separate:

| Concept           | Meaning                                     |
| ----------------- | ------------------------------------------- |
| Clock offset      | Difference between device timing references |
| RTT               | Round-trip communication time               |
| Jitter            | Variation in network timing                 |
| Audio latency     | Delay introduced by the audio pipeline      |
| Playback position | Current position in the audio stream        |
| Drift             | Change in timing alignment over time        |
| Sync state        | Current synchronization condition           |

These measurements are related, but they are not interchangeable.

For example:

> **Low network latency does not automatically mean synchronized audio.**

---

## Clock Calibration

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

SoundMesh uses monotonic timing for synchronization rather than relying on the device's displayed wall-clock time.

---

# Shared Playback Timeline

Once devices are calibrated, audio frames can be mapped onto a shared logical timeline.

```text
Shared timeline
────────────────────────────────────────────────────►

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

The important part is that each device knows **when** it should play, not merely **that** it should play.

---

# Audio Pipeline

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

Flutter handles application logic and the user experience.

Android handles the timing-sensitive machinery.

---

# Local-First by Design

SoundMesh is designed around nearby-device communication.

Ordinary playback does not depend on a cloud media server or permanent remote infrastructure.

The intended model is:

```text
                    LOCAL NETWORK

                 ┌───────────────┐
                 │     HOST      │
                 │       │       │
                 │   ┌───┴───┐   │
                 │   ▼       ▼   │
                 │ Phone   Phone │
                 └───────────────┘
```

The local network coordinates the room and distributes session data.

Each device performs playback locally.

---

# Joining a Room

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

It is intended for joining a session, not as a permanent account credential.

---

# Multi-Device Rooms

SoundMesh is designed around a host with multiple participants.

```text
                       HOST
                        │
          ┌─────────────┼─────────────┐
          │             │             │
          ▼             ▼             ▼
       Phone A       Phone B       Phone C
      Participant   Participant   Participant
```

Room membership and participant connections are maintained as part of the room lifecycle.

The architecture is designed to treat devices individually rather than as one undifferentiated connection.

---

# Room Lifecycle

A SoundMesh room has a real lifecycle:

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

Closing a room is a lifecycle transition, not simply dropping a socket.

That distinction matters.

After a session ends, the application should be capable of starting a completely new room without requiring an app restart.

```text
Create
  ↓
End
  ↓
Create again
  ↓
End
  ↓
Create again
```

---

# Recovery

Distributed systems fail.

Phones disconnect.

Networks change.

Users leave.

Rooms close.

SoundMesh treats recovery as part of the product.

### Join failure

```text
Join fails
   ↓
Retry
   ↓
New attempt
```

### Participant disconnect

```text
Participant disconnects
   ↓
Remove participant
   ↓
Room continues
```

### Host ends room

```text
Host ends room
   ↓
Participants are informed
   ↓
Return to normal app flow
```

The intended experience is not:

```text
"Force close the app and try again."
```

The intended experience is recovery.

---

# Android-First

SoundMesh is intentionally **Android-only**.

The project focuses its engineering effort on the platform capabilities required to make synchronized device audio possible rather than maintaining unused application layers for other platforms.

That includes Android capabilities such as:

* `MediaProjection`
* `AudioRecord`
* `AudioTrack`
* system audio capture
* native networking
* monotonic timing
* Android lifecycle handling
* background execution behavior
* Android permissions and settings

---

# Architecture

SoundMesh divides responsibilities between Flutter and native Android.

```text
┌────────────────────────────────────────────┐
│                  FLUTTER                   │
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

# Technology Stack

| Layer                  | Technology                 |
| ---------------------- | -------------------------- |
| Application            | Flutter                    |
| Language               | Dart                       |
| Android                | Native Android             |
| Native code            | Kotlin / Java              |
| State management       | Riverpod                   |
| Audio capture          | Android audio capture APIs |
| Audio playback         | `AudioTrack`               |
| Networking             | Native Android networking  |
| QR generation          | `qr_flutter`               |
| QR scanning            | `mobile_scanner`           |
| Local preferences      | `shared_preferences`       |
| RevenueCat integration | RevenueCat                 |
| Purchase testing       | RevenueCat Test Store      |
| Source control         | Git / GitHub               |

---

# RevenueCat

SoundMesh includes RevenueCat as part of its application integration.

The current implementation uses the **RevenueCat Test Store** for simulated purchase and entitlement flows rather than real-money transactions.

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

This keeps the RevenueCat integration testable without requiring real purchase transactions during development.

---

# UI & Design

SoundMesh uses a dark, minimal interface built around a **Midnight Teal** visual language.

The visual system emphasizes:

* strong hierarchy
* restrained color
* clear typography
* responsive layouts
* subtle surfaces
* compact navigation
* useful feedback
* minimal visual noise

The interface intentionally hides the distributed-system complexity underneath it.

The user experience should feel like:

```text
Create.
Join.
Play.
```

---

# What Makes SoundMesh Interesting

SoundMesh brings together several difficult engineering problems:

```text
             ┌──────────────────────┐
             │       SoundMesh      │
             └──────────┬───────────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
         ▼              ▼              ▼
 Distributed        Audio          Networking
   Timing          Systems
         │              │              │
         └──────────────┼──────────────┘
                        │
                        ▼
                 Device Lifecycle
                        │
                        ▼
                 One Experience
```

It's not simply:

> "Send audio from one phone to another."

It's about coordinating **independent machines with independent clocks, networks, audio systems, and failure modes**.

---

# Testing

SoundMesh uses multiple levels of validation:

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

Automated tests are important.

They are not enough to prove synchronized physical audio.

Real hardware matters because it exposes:

* device-specific audio behavior
* speaker differences
* timing differences
* capture behavior
* network conditions
* background execution behavior
* lifecycle edge cases

---

# Current Status

SoundMesh is in **pre-submission hardening and physical validation**.

The current Android implementation includes:

* room creation
* room joining
* QR-based joining
* local discovery
* multi-participant rooms
* audio capture
* audio transport
* synchronized playback scheduling
* clock synchronization
* room lifecycle handling
* recovery flows
* responsive UI
* RevenueCat integration

The current focus is stability, reproducibility, and validation rather than endless feature expansion.

---

# Getting Started

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

## Install Dependencies

```bash
flutter pub get
```

---

## Run

```bash
flutter run
```

---

# Build the Release APK

```bash
flutter build apk --release
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Install it with:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Check connected Android devices:

```bash
adb devices
```

Or install to a specific device:

```bash
adb -s DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-release.apk
```

---

# Physical Multi-Device Testing

SoundMesh is fundamentally a multi-device application.

A basic setup:

```text
              HOST PHONE
                   │
          ┌────────┴────────┐
          │                 │
          ▼                 ▼
    PARTICIPANT        PARTICIPANT
       PHONE               PHONE
```

For meaningful synchronization testing, use multiple real Android devices connected to the same local network.

Physical hardware can expose behavior that emulators and automated tests cannot reproduce.

---

# Performance

SoundMesh contains timing-sensitive paths, so realtime work is kept away from Flutter UI-frame timing where practical.

Important areas include:

* monotonic clocks
* audio buffering
* packet scheduling
* native playback scheduling
* participant isolation
* connection lifecycle
* room teardown
* repeated room creation
* background execution

Performance should ultimately be evaluated on the Android hardware on which SoundMesh is expected to run.

---

# Privacy

SoundMesh is designed around local communication.

Ordinary nearby-device playback does not require a cloud media backend.

The project is designed to minimize unnecessary collection or remote transmission of user information.

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

Physical validation remains an important part of evaluating the system.

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

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contribution guide.

---

# The Engineering Challenge

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

# The Goal

The goal isn't simply to make several phones play the same file.

The goal is to make the user **forget there are several phones**.

```text
          CREATE
             ↓
            JOIN
             ↓
            PLAY

     ┌────────────────────┐
     │  Multiple phones   │
     │                    │
     │     ONE SOUND      │
     └────────────────────┘
```

A speaker is normally one device.

SoundMesh asks:

> **What if the speaker could be the devices you already have?**

---

# Website

Explore the SoundMesh website:

**https://getsoundmesh.pages.dev**

---

# Made By

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

<a href="https://github.com/farazkayan/SoundMesh/blob/main/LICENSE">
  View the full MIT License
</a>

---

<p align="center">
  <img src="https://raw.githubusercontent.com/farazkayan/SoundMesh/main/app/assets/images/FOR_APP_ICON.png" alt="SoundMesh" width="80">
</p>

<p align="center">
  <strong>SoundMesh</strong><br>
  Multiple phones. One sound.
</p>
