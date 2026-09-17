# SoundMesh — Mahin Work Plan

**Document Status:** Active
**Workstream Owner:** Mahin
**Role:** Flutter UI/UX, application presentation layer, user-facing integration
**Project:** SoundMesh
**Repository:** `farazkayan/SoundMesh`

---

# 0. Purpose

This document defines Mahin's complete UI/UX workstream for SoundMesh.

Mahin owns the **Flutter presentation layer and user-facing experience**.

Mahin does **not** own:

* Core synchronization algorithms
* Network transport implementation
* Audio capture implementation
* Native audio output implementation
* Clock synchronization
* Drift correction
* Backend architecture
* Native Android platform internals

The UI must represent the real capabilities and state of SoundMesh.

SoundMesh is **not a media player**.

SoundMesh synchronizes live audio captured from an external media application running on the host device.

The user may play media using applications such as:

* YouTube
* Spotify
* VLC
* Browser-based players
* Video players
* Other Android applications that permit audio playback capture

SoundMesh itself does not own:

* Songs
* Videos
* Media libraries
* Playback queues
* Playback controls
* Seeking
* Playback speed
* Subtitles
* Media formats
* External media navigation

The Flutter UI must never imply otherwise.

---

# Phase 0 — UI Foundation

**Status:** COMPLETED — DO NOT MODIFY

Establish the Flutter application foundation:

* Flutter app foundation
* Folder structure
* Navigation foundation
* Theme foundation
* Typography
* Spacing
* Reusable components
* Icon system
* Button components
* Card components
* Input components
* Loading components
* Error components
* State components

Follow:

`DOCS/ui-ux.md`

This phase is already completed and must not be rewritten or reimplemented unless a later phase requires a narrowly scoped compatibility fix.

---

# Phase 1 — SoundMesh Design System

**Status:** COMPLETED — DO NOT MODIFY

The SoundMesh design language should feel:

* Modern
* Calm
* Premium
* Audio-focused
* Minimal
* Technically trustworthy

Design principles:

* Dark-first interface
* System-native typography
* 8pt spacing system
* Touch targets ≥44px
* Consistent corner radii
* Subtle borders
* Controlled elevation
* Purposeful animation
* Accessible contrast
* Clear hierarchy
* Minimal visual noise

The authoritative palette and design rules are defined in:

`DOCS/ui-ux.md`

This phase is already completed and must not be rewritten.

---

# Phase 2 — Navigation Architecture

**Status:** COMPLETED — DO NOT MODIFY

Current conceptual navigation:

```text
Home
 ├── Create Room
 │    └── Room
 │
 └── Join Room
      └── Scan QR
           └── Joining
                └── Room
```

Room flow conceptually contains:

* Devices
* Audio
* Preparation
* Playback
* Sync Status
* Diagnostics

Exact navigation may evolve as the product architecture develops.

Navigation must represent actual application state.

This phase is already completed and must not be rewritten.

---

# Phase 3 — Application State Presentation

**Status:** COMPLETED — DO NOT MODIFY

Build the UI state model accurately representing Core API state.

States include:

```text
IDLE
CREATING_ROOM
JOINING_ROOM
ROOM_READY
PREPARING
READY
PLAYING
PAUSED
STOPPING
ERROR
```

These states should correspond conceptually to the Core system.

The UI must not create contradictory meanings between Core state and displayed state.

This phase is already completed and must not be rewritten.

---

# Phase 3.5 — Product-Pivot UI Cleanup

**Status:** REQUIRED

## Purpose

Remove UI that was created around the previous media-player-oriented concept of SoundMesh.

This is a cleanup/rework phase.

Do **not** redesign Phases 0–3 themselves.

Instead, remove or replace obsolete screens, components, navigation destinations, mock data, and visual concepts that no longer belong to SoundMesh.

The goal is to make the existing Flutter application accurately represent the actual product before continuing with new feature work.

---

## 3.5.1 Remove Media-Player UI

Remove any UI that makes SoundMesh appear to be a music or video player.

Examples include:

* Song title displays
* Album artwork
* Music selection screens
* Media library screens
* Playlist UI
* Play buttons belonging to SoundMesh
* Pause buttons belonging to SoundMesh
* Previous/next controls
* Seek bars
* Playback progress bars
* Playback speed controls
* Volume controls that imply SoundMesh owns playback
* Song queues
* "Now Playing" screens
* Media browsing interfaces
* Fake player timelines
* Mock audio files
* Fake songs
* Fake video controls

SoundMesh does not control the external media application's playback.

---

## 3.5.2 Remove Room History

Remove any UI representing persistent room history if it exists.

Examples:

* Recent Rooms
* Room History
* Previous Rooms
* Saved Rooms
* Recently Joined Rooms
* Recently Created Rooms
* Room history panels
* Room history cards
* Mock historical room data

The new SoundMesh backend does not require a room-history system.

Do not create backend/API requirements to preserve this UI.

If the UI contains room history, remove it completely.

---

## 3.5.3 Remove Obsolete Audio Selection Concepts

Remove concepts such as:

```text
Select Audio
Choose Song
Choose File
Audio Library
My Songs
Pick Track
Select Media
```

SoundMesh does not select the media source.

The host opens the external application of their choice.

---

## 3.5.4 Replace Obsolete Player Concepts

Where appropriate, replace obsolete player UI with truthful SoundMesh concepts.

Examples:

```text
Host
Participant
Connected Devices
Capture Status
Audio Sync
Synchronization Quality
Room Status
Connection Status
External Media
Diagnostics
```

Do not invent backend functionality merely to make a screen look complete.

---

## 3.5.5 Remove Obsolete Mock State

Delete or replace mock states that exist only because SoundMesh was previously treated as a media player.

Examples:

```text
PLAYING
PAUSED
STOPPING
NEXT_TRACK
PREVIOUS_TRACK
SEEKING
SELECTING_AUDIO
```

Do not blindly remove states that are still required by the existing Core API contract.

If a state is ambiguous, inspect the current Core/API contract before changing it.

---

## 3.5.6 Preserve Completed Work

Do not rewrite the completed UI foundation merely because the product architecture changed.

Keep:

* Existing design system
* Existing reusable components
* Existing navigation foundation
* Existing styling foundation
* Existing valid application-state infrastructure

Only remove or modify elements that are now demonstrably incompatible with the SoundMesh product.

---

## Definition of Done

Phase 3.5 is complete when:

* No fake SoundMesh music player remains.
* No fake media library remains.
* No obsolete audio-selection UI remains.
* No room-history UI remains.
* No obsolete mock media data remains.
* No UI claims SoundMesh controls external media playback.
* Existing useful design-system work remains intact.
* The Home and Room experiences accurately describe the new SoundMesh product.
* The Flutter application is ready for new architecture-specific UI work.

---

# Phase 4 — Core API Integration Layer

**Status:** NOT STARTED

Connect the Flutter presentation layer to the actual Core API contracts.

The UI should consume Core functionality rather than recreating business logic inside Flutter.

Mahin should integrate:

* Application state
* Room state
* Device state
* Audio-session state
* Synchronization state
* Error state
* Diagnostics state

The UI should remain a presentation layer.

Do not implement:

* Network algorithms
* Synchronization algorithms
* Clock synchronization
* Audio capture
* Native audio output
* Drift correction

inside Flutter.

---

# Phase 5 — Create Room

**Status:** NOT STARTED

Implement the Create Room experience.

The flow should allow the user to:

1. Open SoundMesh.
2. Create a room.
3. Become the host.
4. Wait for participants.
5. See connected devices.
6. Begin the audio synchronization session.

Display only information actually provided by Core.

Possible UI:

```text
Create Room

Room Ready

You are the Host

Connected Devices
2 devices connected

Waiting for participants...
```

Do not introduce room-history storage.

---

# Phase 6 — Join Room

**Status:** NOT STARTED

Implement joining an existing room.

The flow should support:

```text
Join Room
    ↓
Room Code / QR
    ↓
Joining
    ↓
Connected
    ↓
Room
```

Handle:

* Invalid room
* Room unavailable
* Connection failure
* Timeout
* Successful joining
* Already-connected state

---

# Phase 7 — QR Room Bootstrap UX

**Status:** NOT STARTED

Implement QR-based room joining.

The QR experience should:

* Scan the host's room QR
* Validate the room information
* Start joining
* Show progress
* Show errors
* Transition into the Room screen

Do not put arbitrary application data into the QR unless the Core contract defines it.

---

# Phase 8 — Room Screen

**Status:** NOT STARTED

Build the main room experience.

The Room screen should become the central SoundMesh session interface.

It should communicate:

* Room status
* Host/participant role
* Connected device count
* Device states
* Capture state
* Synchronization state
* Audio session state
* Important errors

Example conceptual structure:

```text
SoundMesh

Room Connected

HOST
Faraz

3 Devices Connected

● Audio Sync Active

Devices
├── Faraz
├── Mahin
└── Phone 3

Sync Quality
Excellent
```

The exact layout is flexible.

The meaning must remain truthful.

---

# Phase 9 — Device UI

**Status:** NOT STARTED

Build the device list and device status presentation.

Each device may display:

* Device name
* Host/participant role
* Connection state
* Audio state
* Synchronization state
* Sync quality
* Error state

Do not display information that Core does not provide.

---

# Phase 10 — Capture Preparation UI

**Status:** NOT STARTED

Create the UI for preparing the host device for external audio capture.

The user should understand:

* SoundMesh needs to capture external application audio.
* Capture permission may be required.
* The host needs to start/continue an external media application.
* SoundMesh will synchronize the resulting audio.

Example:

```text
Prepare Audio

SoundMesh will synchronize audio
from the host's media app.

1. Allow audio capture
2. Return to your media app
3. Start playback

[Continue]
```

Do not make SoundMesh appear to be the media player.

---

# Phase 11 — Audio Capture Permission UX

**Status:** NOT STARTED

Implement the user-facing flow around Android audio-capture permission.

Handle:

* Permission not requested
* Permission prompt
* Permission granted
* Permission denied
* Permission revoked
* Capture unavailable
* Capture stopped

The UI must clearly explain why permission is required.

Never claim that audio is being captured when capture has not actually started.

---

# Phase 12 — External Media Handoff UX

**Status:** NOT STARTED

Create the experience that tells the host to open an external media application.

Example:

```text
Audio Sync Ready

Open YouTube, Spotify, VLC,
your browser, or another
supported media app.

Start the media you want to play.

SoundMesh will synchronize
the captured audio across the room.
```

SoundMesh should not attempt to recreate the external application's controls.

The UI may provide guidance, but not pretend to control the external app.

---

# Phase 13 — Live Audio Session UI

**Status:** NOT STARTED

Create the UI representing an active live audio synchronization session.

The Room should communicate:

```text
Audio Sync Active

Host
Capturing external audio

Participants
3 connected

Synchronization
Active
```

Potential states:

* Waiting
* Preparing
* Capturing
* Streaming
* Synchronizing
* Active
* Interrupted
* Recovering
* Failed

Use actual Core/native state wherever available.

---

# Phase 14 — Synchronization UI

**Status:** NOT STARTED

Present synchronization state without exposing unnecessary implementation details.

Show:

* Sync active
* Sync preparing
* Synchronizing
* Resynchronizing
* Sync unavailable
* Sync failed

The UI should communicate the result rather than pretending the user needs to understand clock algorithms.

---

# Phase 15 — Sync Quality

**Status:** NOT STARTED

Provide a simple human-readable representation of synchronization quality.

Possible categories:

```text
Excellent
Good
Unstable
Poor
Unavailable
```

If numerical metrics are exposed, they may be presented as diagnostics rather than the primary experience.

Do not invent thresholds without a Core contract.

---

# Phase 16 — Resynchronization

**Status:** NOT STARTED

Present resynchronization events.

Examples:

```text
Resynchronizing...

Audio synchronization is being corrected.
```

After recovery:

```text
Synchronized
```

The UI must not claim that synchronization was fixed unless Core confirms recovery.

---

# Phase 17 — Error Handling

**Status:** NOT STARTED

Implement clear user-facing error states.

Examples:

* Room unavailable
* Unable to join
* Host disconnected
* Participant disconnected
* Audio capture unavailable
* Capture permission denied
* External app does not allow capture
* Audio session stopped
* Synchronization failed
* Network unavailable
* Unexpected native error

Errors should explain:

1. What happened.
2. Whether the user needs to act.
3. What action is available.

Avoid exposing raw stack traces or internal exceptions in normal UI.

---

# Phase 18 — Connection and Recovery UI

**Status:** NOT STARTED

Handle temporary network/device failures.

Represent:

```text
Connected
Connecting
Disconnected
Reconnecting
Recovered
Failed
```

A temporary participant disconnect should not necessarily destroy the entire room UI.

The UI should follow actual Core recovery behavior.

---

# Phase 19 — Audio Session Recovery UX

**Status:** NOT STARTED

Handle failures specific to the live audio pipeline.

Examples:

* Capture stopped
* MediaProjection ended
* External application stopped playback
* External application became uncapturable
* Native audio output stopped
* Audio stream interrupted
* Foreground service stopped

Show actionable explanations.

Do not tell the user to restart SoundMesh if Core can recover automatically.

---

# Phase 20 — Diagnostics UI

**Status:** NOT STARTED

Build a diagnostics experience for debugging and competition demonstrations.

Potential information:

```text
Room ID
Device ID
Role
Connection
Audio Capture
Audio Output
Sync State
Sync Quality
Latency
Drift
Recovery State
```

Diagnostics must use real values.

No fake performance numbers.

No fabricated synchronization accuracy.

---

# Phase 21 — UI Mocking and Contract Validation

**Status:** NOT STARTED

Create controlled mock states for UI development.

Mocks may simulate:

* Connected room
* Multiple devices
* Capture ready
* Capture denied
* Sync active
* Sync degraded
* Reconnecting
* Error
* Recovery

Mocking is allowed for presentation development.

However:

> Mocked state must never be confused with real functionality.

Keep mock data clearly separated from production integration.

---

# Phase 22 — Real Backend Integration

**Status:** NOT STARTED

Replace temporary mocks with actual Core integration.

Verify:

* Create room
* Join room
* Room state
* Device state
* Capture state
* Audio session state
* Sync state
* Error state
* Recovery state

The Flutter UI must react to actual system events.

---

# Phase 23 — Two-Device UI Integration

**Status:** NOT STARTED

Test the complete Flutter experience with:

```text
Android Host
     ↕
Android Participant
```

Verify:

* Room creation
* QR/join flow
* Device display
* Capture preparation
* External media handoff
* Live audio session state
* Synchronization state
* Errors
* Recovery

No media-player controls should reappear during integration.

---

# Phase 24 — Real-Device Validation

**Status:** NOT STARTED

Validate the UI on actual Android devices.

Test:

* Host
* Participant
* Permission flows
* Background/foreground transitions
* External media apps
* Capture failures
* Network failures
* Device disconnects
* Reconnection
* Synchronization state transitions

Test both role directions where the architecture supports them.

---

# Phase 25 — Multi-Device UI

**Status:** NOT STARTED

Expand the experience from two devices to multiple participants.

Example:

```text
Room

4 Devices Connected

Host
├── Device 1
├── Device 2
├── Device 3
└── Device 4

Audio Sync
Active
```

The UI must remain understandable as the number of devices increases.

Avoid turning the Room screen into a dense dashboard.

---

# Phase 26 — Accessibility

**Status:** NOT STARTED

Validate:

* Touch target sizes
* Text readability
* Contrast
* Semantic labels
* Screen-reader compatibility
* Error visibility
* Non-color-only status indicators
* Large text behavior
* Interaction clarity

Accessibility must remain compatible with the established design system.

---

# Phase 27 — UI Performance

**Status:** NOT STARTED

Ensure the Flutter UI remains responsive during active synchronization.

Investigate:

* Excessive rebuilds
* Animation overhead
* Large widget trees
* Unnecessary polling
* Memory usage
* Device-list updates
* Diagnostic updates
* Background/foreground transitions

Do not move networking, synchronization, or audio processing into Flutter simply to make the UI implementation easier.

---

# Phase 28 — Competition Polish

**Status:** NOT STARTED

Final polish for the Shipaton demonstration.

Focus on:

* Clean onboarding
* Clear room creation
* Fast joining
* Excellent capture-permission explanation
* Strong host/participant distinction
* Clear synchronization feedback
* Clear recovery states
* Consistent animations
* Minimal visual clutter
* No obsolete media-player concepts
* No fake functionality
* No unnecessary screens

The final UI should immediately communicate:

> **SoundMesh lets multiple nearby phones act as one synchronized audio system while the host continues using their preferred media app.**

---

# AI Task Rules

Any AI agent working on Mahin's branch must follow these rules.

## Rule 1 — Do Not Invent Backend Behavior

The UI must not assume that an API exists unless it is documented or implemented.

If an API is missing:

* Check the interface documentation.
* Check the current implementation.
* Ask/flag the missing contract.
* Do not silently invent one.

---

## Rule 2 — Do Not Rebuild Core

Flutter must not contain:

* Synchronization algorithms
* Clock synchronization
* Drift correction
* Audio transport
* Audio capture
* Native audio output

unless explicitly assigned as a presentation/integration task.

---

## Rule 3 — SoundMesh Is Not a Media Player

Never add:

* Song libraries
* Playlists
* Seek controls
* Next/previous controls
* Media queues
* Video controls
* Subtitles
* Media browsing
* Fake playback state

SoundMesh synchronizes audio from an external media source.

---

## Rule 4 — Do Not Reintroduce Room History

Do not add:

* Room history
* Recent rooms
* Saved rooms
* Previous rooms
* Persistent room lists

unless the backend architecture explicitly introduces such functionality in the future.

---

## Rule 5 — Truthful UI Only

Every important status displayed by Flutter must correspond to a real application state.

Never show:

```text
Synced
```

when synchronization has not been confirmed.

Never show:

```text
Audio Captured
```

when capture has not started.

Never show:

```text
Connected
```

when the device is disconnected.

---

## Rule 6 — External Media Ownership

The external application owns media playback.

SoundMesh owns:

```text
Capture
→ Distribution
→ Synchronization
→ Output
```

The external application owns:

```text
Media
→ Play
→ Pause
→ Seek
→ Track selection
→ Video
→ Subtitles
```

The Flutter UI must respect this boundary.

---

# Stop Conditions

Mahin must stop and report the issue if:

1. A UI feature requires an undocumented API.
2. A screen requires SoundMesh to become a media player.
3. Room history is required for a proposed feature.
4. Audio capture behavior is unclear.
5. Android permission behavior is unclear.
6. Core state and UI state contradict each other.
7. A UI decision requires changing synchronization architecture.
8. A feature requires native implementation outside Mahin's workstream.
9. The external media application's capture compatibility is unknown.
10. A proposed feature exists only because of the old media-player architecture.

Do not solve architectural uncertainty by inventing UI.

---

# Milestones

## M1 — UI Foundation

Phases 0–3 complete.

## M2 — Product-Pivot Cleanup

Phase 3.5 complete.

No obsolete player/history/audio-selection UI remains.

## M3 — Core Integration

Phase 4 complete.

## M4 — Room Experience

Phases 5–9 complete.

Create, join, QR, Room, and device UI functional.

## M5 — External Audio UX

Phases 10–13 complete.

Capture preparation, permission flow, external media handoff, and live audio session UI functional.

## M6 — Synchronization UX

Phases 14–16 complete.

Sync, quality, and resynchronization states represented correctly.

## M7 — Reliability UX

Phases 17–20 complete.

Errors, recovery, audio-session failures, and diagnostics functional.

## M8 — Real Integration

Phases 21–24 complete.

Real Core integration tested on Android devices.

## M9 — Multi-Device

Phase 25 complete.

Multiple participants represented correctly.

## M10 — Competition Ready

Phases 26–28 complete.

Accessible, performant, polished, and demo-ready.

---

# Definition of Done

Mahin's workstream is complete when:

* Flutter accurately represents the SoundMesh architecture.
* Completed Phases 0–3 remain intact.
* Phase 3.5 has removed obsolete media-player UI.
* Room history UI has been removed.
* Audio-selection UI has been removed.
* No fake playback controls remain.
* Create Room works.
* Join Room works.
* QR joining works.
* Room state is visible.
* Device state is visible.
* Audio capture state is visible.
* External media handoff is clear.
* Live audio synchronization state is visible.
* Sync quality is represented truthfully.
* Recovery states are understandable.
* Errors are actionable.
* Diagnostics use real data.
* Real Android devices have been tested.
* Multi-device UI works.
* Accessibility requirements are met.
* UI remains performant.
* Competition presentation is polished.

---

# Final Responsibility

Mahin owns the question:

> **"Does the user understand what SoundMesh is doing and what they need to do next?"**

Faraz owns the underlying technical system that makes those states true.

The Flutter UI must never pretend functionality exists merely because it would make the interface look more complete.

**The UI follows the architecture — not the other way around.**
