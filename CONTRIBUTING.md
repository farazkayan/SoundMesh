# Contributing to SoundMesh

Thanks for your interest in contributing to **SoundMesh**.

SoundMesh is an Android-first Flutter project exploring a simple idea:

> **Can nearby phones work together like one speaker?**

The user experience is intentionally simple, but the system underneath involves networking, audio processing, timing, synchronization, and device lifecycle management.

Because of that, contributions should favor **small, understandable, testable changes** over large rewrites.

---

## Before You Start

SoundMesh is currently developed as an **Android-only application**.

Please keep contributions focused on the supported platform.

The project is built primarily with:

* Flutter
* Dart
* Native Android
* Kotlin / Java
* Riverpod

Before making a change, inspect the existing implementation around the feature you are modifying.

Do not assume that a component is isolated just because it appears to belong to one screen. SoundMesh has several systems where UI, state, networking, and native Android behavior interact.

---

# What We Welcome

We welcome improvements such as:

* bug fixes
* UI improvements
* accessibility improvements
* responsive-layout fixes
* test coverage
* performance improvements
* Android compatibility fixes
* networking reliability improvements
* room lifecycle improvements
* audio pipeline improvements
* synchronization improvements
* developer tooling
* documentation improvements

For larger changes, open an issue first so the scope can be discussed before implementation.

---

# What to Avoid

Please avoid:

* unnecessary rewrites
* replacing working architecture for stylistic reasons
* introducing unrelated dependencies
* changing multiple subsystems for a single bug
* platform implementations that SoundMesh does not use
* fake or simulated functionality presented as real functionality
* removing tests simply because they are inconvenient
* changing synchronization behavior without understanding its timing model

A smaller correct fix is usually preferable to a larger clever one.

---

# Project Structure

The main application lives under `app/`.

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
│   ├── pubspec.yaml
│   └── pubspec.lock
│
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

### Application

High-level application behavior, providers, room flows, and orchestration.

### Core

Shared models, routing, configuration, and design/system-level code.

### Infrastructure

Discovery, networking, platform integration, and other implementation details.

### Presentation

Screens, components, UI state, and user-facing interaction.

### Android

Native Android functionality, including timing-sensitive and audio-related platform work.

### Third-party

Repository-local dependencies that have been intentionally customized for SoundMesh.

---

# Development Setup

You will need:

* Flutter SDK compatible with the project
* Android SDK
* Android build tools
* Android Studio or equivalent Android tooling
* an Android emulator or physical Android device

For meaningful SoundMesh testing, physical Android devices are strongly recommended.

---

# Running SoundMesh

From the `app/` directory:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

Build a debug APK:

```bash
flutter build apk --debug
```

Build a release APK:

```bash
flutter build apk --release
```

---

# Testing

Before submitting a contribution, run:

```bash
flutter analyze
flutter test
```

For changes that affect Android behavior, also build the application:

```bash
flutter build apk --debug
```

For changes that affect release behavior, verify the release build:

```bash
flutter build apk --release
```

Do not report a test or build as successful unless you actually ran it.

---

# Physical Device Testing

SoundMesh is a distributed audio application, so automated tests cannot validate everything.

Whenever a change affects:

* audio
* synchronization
* networking
* room lifecycle
* permissions
* background behavior
* Android-specific behavior
* device discovery
* playback

test it on real Android hardware when possible.

For multi-device changes, test with multiple physical devices connected to the same local network.

A useful baseline setup is:

```text
             HOST
              │
        ┌─────┴─────┐
        │           │
   PARTICIPANT  PARTICIPANT
```

Document any hardware-specific behavior you discover.

---

# Making UI Changes

SoundMesh's interface follows a dark, minimal visual system.

When changing UI:

* preserve the existing visual hierarchy
* keep layouts responsive
* support different Android screen sizes
* avoid hard-coded dimensions when they are not necessary
* check for overflow and clipping
* consider text scaling
* respect safe areas
* keep interactive elements usable on both phones and tablets

Do not solve a responsive-layout problem by placing a phone-sized UI inside a tablet-sized frame.

When modifying a shared component, check its other usages before changing its behavior globally.

---

# Working With Audio

Audio is one of the most sensitive parts of SoundMesh.

Do not casually change:

* capture behavior
* audio packetization
* playback scheduling
* buffer handling
* timing calculations
* native audio lifecycle
* synchronization behavior

Audio changes should be accompanied by focused tests and, where practical, physical-device validation.

A change that makes one device sound better but breaks synchronization across devices is not an improvement.

---

# Working With Synchronization

Synchronization is based on measured timing relationships between devices.

Keep these concepts distinct:

* clock offset
* round-trip time
* jitter
* buffering
* playback position
* drift
* synchronization state

Do not replace monotonic timing with wall-clock time for synchronization logic.

Do not introduce timing assumptions based only on UI frame timing.

When modifying synchronization behavior, explain:

1. what timing relationship changed
2. why the change is necessary
3. how it was tested
4. whether physical-device validation was performed

---

# Working With Networking

SoundMesh uses nearby-device communication for room coordination and audio-related transport.

When modifying networking:

* preserve existing protocol behavior unless the change intentionally updates it
* handle disconnects cleanly
* avoid leaking sockets or connections
* consider repeated room creation and teardown
* isolate participant-specific failures where possible
* test both host and participant paths

Do not assume that a successful connection once means the lifecycle is correct.

Also test:

```text
connect
→ use
→ disconnect
→ reconnect
```

and, where relevant:

```text
create room
→ end room
→ create another room
```

---

# Working With Room Lifecycle

Room state must be safe across repeated sessions.

A valid lifecycle should support:

```text
Create
  ↓
Use
  ↓
End
  ↓
Create again
```

without requiring an application restart.

When changing lifecycle code, inspect:

* provider state
* network cleanup
* discovery state
* timers
* listeners
* connection handles
* asynchronous cleanup
* cached room information

Do not fix lifecycle bugs by blindly resetting unrelated state.

Find the resource or state transition that is actually wrong.

---

# RevenueCat

SoundMesh includes RevenueCat integration.

The project currently uses the **RevenueCat Test Store** for simulated purchase flows.

The repository contains a local customized `purchases_flutter` dependency under:

```text
app/third_party/purchases_flutter/
```

This dependency is intentionally part of the repository.

### Important

Do not replace the repository-local package with an arbitrary hosted version.

Do not remove the Android Test Store release-build configuration.

Do not commit RevenueCat secret keys.

Public SDK keys may be present in client applications, but secret credentials must never be committed.

---

# Dependencies

Before adding a dependency, ask whether the existing project can solve the problem without one.

When a dependency is necessary:

1. choose a maintained package
2. confirm Android compatibility
3. keep the addition narrowly scoped
4. verify it does not introduce unnecessary platform requirements
5. run the full test suite afterward

Avoid adding packages for problems that can be solved with existing Flutter or Android APIs.

---

# Commits

Keep commits focused.

Good:

```text
Fix room recreation after host teardown
```

```text
Improve tablet room layout
```

```text
Add failed-join recovery test
```

Avoid commits that mix unrelated changes such as UI redesign + networking rewrite + dependency upgrades.

---

# Pull Requests

A good pull request should explain:

### What changed?

Describe the change in a few sentences.

### Why?

Explain the problem or motivation.

### How was it tested?

Include the actual commands/results.

For example:

```text
flutter analyze
flutter test
flutter build apk --release
```

If physical testing was performed, mention:

* device type
* Android version
* host/participant setup
* relevant scenario tested

Do not claim physical validation when only automated tests were run.

---

# Bug Reports

When reporting a bug, include:

* what you expected
* what actually happened
* steps to reproduce
* Android version
* device model when relevant
* whether it happens consistently
* relevant logs if available

For distributed-system bugs, also mention whether the problem occurred on:

* host
* participant
* both

and how many devices were involved.

---

# Security

Please do not commit:

* passwords
* private tokens
* secret API keys
* service credentials
* signing keys
* `.env` files containing secrets

If you accidentally expose a credential, revoke or rotate it immediately.

For security issues that should not be public, use GitHub's private security-reporting mechanism where available rather than opening a public issue.

---

# Evidence Matters

SoundMesh distinguishes between code existing and code actually being validated.

These are not equivalent:

```text
Implemented
    ≠
Tested
    ≠
Physically validated
```

When describing a change, be precise about what was actually verified.

For example:

```text
✅ Unit tests pass
✅ Release APK builds
⚠️ Physical multi-device testing not performed
```

is better than claiming the feature is fully verified.

---

# Review Philosophy

When reviewing a contribution, we care about:

* correctness
* clarity
* minimal scope
* maintainability
* testability
* Android compatibility
* lifecycle safety
* evidence of verification

A contribution does not need to be large to be valuable.

A small fix that prevents a difficult production bug can be more important than a large feature.

---

# Final Checklist

Before opening a pull request:

```text
[ ] Change is focused
[ ] Existing behavior was inspected
[ ] No unnecessary dependencies added
[ ] No unrelated architecture changed
[ ] flutter analyze passes
[ ] flutter test passes
[ ] APK builds when relevant
[ ] Physical testing performed when relevant
[ ] No secrets committed
[ ] Final diff reviewed
[ ] PR description explains what changed
```

---

# Thank You

SoundMesh started with a simple problem:

> **We had music. We had phones. We didn't have a speaker.**

Contributions help turn that simple idea into a genuinely interesting piece of software.

Thanks for building with us.
