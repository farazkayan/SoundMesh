# SoundMesh — UI/UX Specification

**Document Status:** REQUIRED
**Document Type:** Product/UI/UX Source of Truth
**Applies To:** SoundMesh mobile application
**Primary Platform:** Android
**Future Platform:** iOS may be considered separately; it is not an MVP requirement
**Design Direction:** Dark-first, premium, minimal, audio-focused, technically sophisticated without exposing technical complexity

---

# 1. Purpose

This document defines the complete user-interface and user-experience system for SoundMesh.

It establishes:

* visual identity
* color system
* contrast requirements
* typography
* spacing
* sizing
* layout
* navigation
* information hierarchy
* components
* room states
* capture states
* synchronization feedback
* connection feedback
* recovery behavior
* accessibility
* responsive behavior
* diagnostics
* onboarding
* interaction rules
* design tokens
* UI acceptance criteria

This document exists to prevent individual developers or AI coding agents from making arbitrary visual decisions.

If an implementation decision conflicts with this document, this document is the UI/UX authority unless a newer documented decision explicitly supersedes it.

---

# 2. Product Model

SoundMesh is a **live audio synchronization layer**.

It is not:

* a music player
* a media library
* a file-sharing application
* a streaming-content service
* a replacement for YouTube, Spotify, VLC, or another media player

The external media application remains responsible for actual media playback.

The SoundMesh experience is:

```text
Create / Join
      ↓
Connect devices
      ↓
Prepare audio capture
      ↓
Grant capture permission
      ↓
Start SoundMesh session
      ↓
Open external media app
      ↓
External app plays audio
      ↓
SoundMesh captures host audio
      ↓
SoundMesh synchronizes participating devices
      ↓
Everyone hears the same live audio
```

The user should not need to understand the underlying capture, networking, buffering, clock synchronization, or drift-correction systems.

---

# 3. Core UX Principle

SoundMesh performs technically complex operations involving:

* device discovery
* local networking
* Android audio capture
* MediaProjection permission
* live audio transport
* buffering
* timing measurement
* clock synchronization
* latency estimation
* scheduled audio output
* drift detection
* recovery

The user should not need to understand these systems.

The fundamental UX principle is:

> **Hide technical complexity behind simple, trustworthy interactions.**

The intended mental model is:

```text
Create
   ↓
Join
   ↓
Connect
   ↓
Get ready
   ↓
Open your media app
   ↓
Play
   ↓
Everyone hears it together
```

Not:

```text
Configure transport
   ↓
Configure buffers
   ↓
Configure clock offset
   ↓
Configure capture
   ↓
Configure latency
   ↓
Configure audio frames
```

Engineering complexity belongs underneath the interface.

---

# 4. Product Personality

SoundMesh should feel:

* premium
* calm
* modern
* technically capable
* trustworthy
* fast
* effortless
* focused
* intentional

SoundMesh should NOT feel:

* childish
* excessively futuristic
* gamer-oriented
* RGB-heavy
* cyberpunk
* cluttered
* corporate
* overly playful
* like a generic music streaming application
* like an AI-generated template

The interface should communicate:

> **“This is serious technology that is extremely easy to use.”**

---

# 5. Visual Identity

The primary visual metaphor is a **mesh of connected devices**.

Conceptually:

```text
       ●
     /   \
   ●───────●
    \     /
      ●
```

The production UI should use a refined interpretation of this concept.

The mesh represents:

* connected phones
* shared audio
* synchronization
* coordinated activity

It should not resemble a technical network diagram during normal use.

Normal users should perceive:

> “My phones are connected.”

Advanced users may perceive:

> “These devices are synchronized.”

The mesh is a brand element and interaction element, not merely decoration.

---

# 6. Color Philosophy

SoundMesh uses a dark neutral foundation with a single strong blue accent.

The color system is intentionally restrained.

Visual richness should come primarily from:

* luminance
* hierarchy
* typography
* spacing
* subtle surfaces
* controlled accent usage

The UI must not rely on large gradients or excessive saturated colors.

---

# 7. Primary Color Palette

## 7.1 Background

```text
#0B0D10
```

Purpose:

* application background
* full-screen surfaces
* major empty areas

Pure `#000000` should not be the default background.

---

## 7.2 Secondary Background

```text
#12161B
```

Purpose:

* secondary sections
* grouped content
* large contained regions

---

## 7.3 Surface

```text
#181D23
```

Purpose:

* cards
* list containers
* input fields
* controls

---

## 7.4 Elevated Surface

```text
#20262D
```

Purpose:

* dialogs
* menus
* active cards
* strongly elevated controls

---

## 7.5 Primary Text

```text
#F5F7FA
```

Purpose:

* titles
* important values
* primary labels
* primary buttons

---

## 7.6 Secondary Text

```text
#A7AFB9
```

Purpose:

* descriptions
* supporting labels
* metadata
* secondary information

---

## 7.7 Muted Text

```text
#6F7883
```

Purpose:

* tertiary information
* inactive metadata
* placeholders

Muted text must never be used for information required to operate the application.

---

# 8. Primary Accent

## SoundMesh Blue

```text
#5B8CFF
```

Use for:

* primary buttons
* active controls
* selected states
* progress indicators
* synchronization activity
* important interactive elements
* mesh activity
* links
* focus indicators where appropriate

Blue must be used deliberately.

It must not dominate every screen.

---

# 9. Accent Variants

## Accent Light

```text
#7DA5FF
```

Use for:

* selected emphasis
* light accent elements
* mesh hierarchy
* appropriate pressed/active-derived states

## Accent Dark

```text
#3D6FE0
```

Use for:

* pressed states
* deeper emphasis
* controlled contrast

---

# 10. Semantic Colors

## Success

```text
#39D98A
```

Meaning:

* connected
* synchronized
* ready
* healthy
* successful

Success must never be represented by color alone.

Example:

```text
● Synchronized
```

---

## Warning

```text
#FFB84D
```

Meaning:

* calibrating
* degraded
* uncertain
* recovering
* attention required

---

## Error

```text
#FF5C6C
```

Meaning:

* disconnected
* failed
* unavailable
* unrecoverable operation

---

## Informational

Use SoundMesh Blue.

Do not introduce unnecessary semantic colors.

---

# 11. Color Science and Contrast

The UI hierarchy should generally be:

```text
Background
    ↓
Secondary Background
    ↓
Surface
    ↓
Elevated Surface
```

Hierarchy should preferably be communicated through:

1. luminance
2. spacing
3. typography
4. shape
5. subtle borders
6. shadow/elevation

The UI must not depend on borders everywhere.

All user-facing text and important controls must meet applicable accessibility contrast requirements.

Important pairings include:

* primary text/background
* secondary text/background
* text/surface
* accent/dark surface
* button text/accent
* status text/status surface
* focused controls

If a treatment fails contrast requirements, adjust luminance before adding decorative effects.

---

# 12. Accent Usage Ratio

The primary blue should function as a visual signal.

A screen should remain primarily:

* dark neutral
* off-white
* subtle surface colors

with blue directing attention.

Avoid:

```text
BLUE EVERYTHING
```

---

# 13. No Decorative Color Noise

Do not introduce:

* random purple
* cyan gradients
* pink highlights
* rainbow effects
* neon green
* decorative red
* arbitrary gradients

unless explicitly documented later.

Semantic colors communicate state rather than decoration.

---

# 14. Gradients

Gradients are optional and rare.

The MVP should primarily use flat colors.

Any future gradient must:

* preserve readability
* preserve contrast
* support hierarchy
* remain subtle
* not become the primary visual identity

The mesh may use extremely subtle luminance transitions where useful.

---

# 15. Typography Philosophy

Typography is a major part of SoundMesh's premium appearance.

Premium typography comes from:

* appropriate font selection
* restrained weights
* optical hierarchy
* line height
* whitespace
* consistent scale

The interface should feel engineered rather than decorative.

---

# 16. Font Strategy

Use platform-native system fonts.

## Android

Preferred:

**Roboto / Android system UI font**

The MVP should not add a custom font merely for branding.

A correctly rendered platform font is preferable to a poor custom font.

---

# 17. Typography Scale

## Display

```text
32 px
Weight: 700
Line height: 38–40 px
```

Use sparingly.

---

## Large Title

```text
28 px
Weight: 700
Line height: 34 px
```

Use for:

* screen titles
* major session states

---

## Title

```text
22 px
Weight: 600–700
Line height: 28 px
```

Use for:

* major sections
* dialogs
* important room information

---

## Heading

```text
18 px
Weight: 600
Line height: 24 px
```

Use for:

* card headings
* device names
* grouped sections

---

## Body

```text
16 px
Weight: 400
Line height: 22–24 px
```

Primary body text.

---

## Body Emphasis

```text
16 px
Weight: 500–600
```

Use for:

* important labels
* selected values
* device states

---

## Caption

```text
14 px
Weight: 400–500
Line height: 18–20 px
```

Use for:

* supporting information
* metadata
* explanations

---

## Small Metadata

```text
12 px
Weight: 500
Line height: 16 px
```

Use sparingly.

Never use this size for critical instructions.

---

# 18. Typography Weight Rules

Preferred:

```text
400 — regular
500 — medium
600 — semibold
700 — bold
```

Avoid making everything bold.

Hierarchy should come from a combination of:

* size
* weight
* luminance
* spacing

---

# 19. Letter Spacing

Avoid manually increasing tracking for normal text.

Large titles may use slightly negative tracking where appropriate.

Small uppercase diagnostic labels may use modest positive tracking.

Never use extreme tracking as a substitute for hierarchy.

---

# 20. Numerals

SoundMesh diagnostics may display:

* milliseconds
* percentages
* device counts
* buffer levels
* packet loss
* data rates
* drift measurements

Diagnostic values should preferably use tabular or monospaced numerals where available.

Example:

```text
  7.2 ms
 18.4 ms
102.1 ms
```

should remain visually aligned.

---

# 21. Spacing System

Use an 8-point base spacing system.

Primary values:

```text
4
8
12
16
20
24
32
40
48
64
```

Do not invent arbitrary values unless required for platform-native rendering or optical correction.

---

# 22. Screen Margins

Default mobile horizontal content margin:

```text
16–20 px
```

Preferred:

```text
20 px
```

Larger displays should increase usable content width rather than creating excessive margins.

---

# 23. Touch Targets

Important interactive controls should target:

```text
≥ 44 × 44 px
```

Small icons may visually occupy less space, but their interactive hit area should remain sufficiently large.

---

# 24. Corner Radius

Recommended:

```text
8 px  — small controls
12 px — inputs/cards
16 px — major cards
20 px — prominent sheets
24 px — special hero surfaces
```

Do not use pill shapes for everything.

Pills may be used for:

* compact status indicators
* tags
* specific controls

---

# 25. Borders

Borders should be subtle.

Use them for:

* ambiguous boundaries
* inputs
* selected cards
* necessary separators

Do not outline every card.

---

# 26. Elevation

SoundMesh uses subtle depth.

Preferred model:

```text
Background
    ↓
Surface
    ↓
Elevated Surface
```

Luminance separation is preferred over heavy shadows.

---

# 27. Iconography

Use a coherent icon family.

Icons should be:

* simple
* geometric
* recognizable
* consistent
* platform appropriate

Do not mix unrelated icon families.

Production UI should primarily use vector/system icons.

---

# 28. Navigation Philosophy

SoundMesh is task-oriented.

The MVP does not require permanent multi-tab navigation.

Primary flow:

```text
Home
├── Create Room
│   └── Room
│
└── Join Room
    └── Scan QR
        └── Room
```

Within a room:

```text
Room
├── Session
├── Devices
├── Sync Status
├── Diagnostics
└── Room Settings
```

The external media application is intentionally outside the SoundMesh navigation hierarchy.

---

# 29. Home Screen

The home screen should immediately communicate the product.

Preferred:

```text
SoundMesh

Make your phones
one speaker.

[ Create Room ]

    Join Room
```

Optional supporting text:

```text
Connect nearby phones
and hear audio together.
```

The user should understand the product within seconds.

---

# 30. Home Screen Primary Action

**Create Room** is the primary action.

It receives:

* strongest contrast
* largest action surface
* primary blue treatment

---

# 31. Home Screen Secondary Action

**Join Room** is secondary.

It should remain obvious but less dominant.

Possible treatments:

* text button
* outlined button
* secondary surface

Create and Join should not appear visually identical.

---

# 32. Create Room Flow

Flow:

```text
Home
 ↓
Create Room
 ↓
Room created
 ↓
Room screen
```

Avoid unnecessary configuration before room creation.

Room creation should feel immediate.

---

# 33. Room Naming

Room naming is optional.

Possible default:

```text
Faraz's Room
```

or:

```text
SoundMesh Room
```

The user should not be forced to name a room.

---

# 34. QR Joining

QR joining is the preferred MVP onboarding mechanism.

The host displays temporary room-join information.

The participant scans it.

Users should not need to understand:

* IP addresses
* ports
* network protocols
* authentication tokens

---

# 35. QR Screen

Preferred:

```text
Join this room

      [ QR CODE ]

Faraz's Room

Waiting for devices…
```

The QR code must have:

* sufficient contrast
* sufficient quiet space
* reliable sizing

Do not decorate it in a way that compromises scanning.

---

# 36. Join Screen

Preferred:

```text
Join a Room

[ Scan QR Code ]

──────── OR ────────

Enter Room Code

[ __________ ]

[ Join ]
```

QR scanning is primary.

Manual joining is a fallback.

---

# 37. Camera Permission

Request camera access only when the user chooses:

**Scan QR Code**

Do not request camera permission during initial launch.

Explanation:

> SoundMesh uses your camera to scan a room QR code.

---

# 38. Room Screen

The room screen is the central SoundMesh experience.

It must communicate:

1. room identity
2. connected device count
3. session state
4. capture readiness
5. synchronization state
6. primary session action
7. device health

The room screen must not pretend SoundMesh is playing a local media file.

---

# 39. Room Visualization

The room visualization represents connected devices as nodes.

Example:

```text
       ●
     /   \
   ●       ●
     \   /
       ●
```

Each node may contain a minimal device representation.

Do not turn this into a complicated technical graph.

---

# 40. Mesh Animation

When devices connect:

* node appears
* connection line forms
* status changes

When synchronization occurs:

* subtle coordinated pulse
* connection lines may briefly animate

During an active session:

* subtle low-frequency visual activity

Animation must never distract from important session state.

---

# 41. Device Count

Use plain language.

Preferred:

```text
5 devices connected
```

Not:

```text
NODES: 5
```

unless inside diagnostics.

---

# 42. Device Status

Preferred user-facing states:

```text
Connecting…
Getting ready…
Calibrating…
Ready
Synchronized
Degraded
Disconnected
Recovering…
```

Never expose internal enum names in normal UI.

---

# 43. Device List

Example:

```text
Devices

● Faraz's Phone
  Synchronized

● Mahin's Phone
  Synchronized

● Galaxy A52
  Calibrating…

● Pixel
  Connection lost
```

Each device should be individually identifiable.

---

# 44. Device Status Semantics

## Synchronized

The device is currently within the acceptable synchronization threshold.

## Calibrating

SoundMesh is measuring timing and preparing synchronized output.

## Getting Ready

The device is connected and preparing its audio session.

## Degraded

The device remains connected but synchronization quality has fallen.

## Disconnected

The active connection is unavailable.

## Recovering

SoundMesh is attempting to restore the device.

---

# 45. Capture Preparation

The host needs to prepare SoundMesh for live external-audio capture.

The normal UX should describe the goal rather than implementation details.

Preferred:

```text
Get audio ready

SoundMesh needs permission
to capture audio from your device.

[ Allow Audio Capture ]
```

Do not expose:

```text
MediaProjection initialization
AudioPlaybackCaptureConfiguration
```

in normal UI.

---

# 46. Audio Capture Permission

Android capture permission must be requested contextually.

Preferred explanation:

> SoundMesh needs permission to capture audio playing on this phone so the other connected phones can hear it too.

The user must explicitly approve the system permission.

SoundMesh must never imply that permission was granted when it was denied.

---

# 47. Capture Permission States

The UI must distinguish:

```text
Permission Required
      ↓
Requesting Permission
      ↓
Permission Granted
      ↓
Capture Ready
```

If denied:

```text
Audio capture permission wasn't granted.

SoundMesh can't share audio
from this phone without it.

[ Try Again ]
```

---

# 48. Capture Availability

Some external applications may not permit their audio to be captured.

Normal UI:

```text
Audio source unavailable

This app doesn't allow SoundMesh
to capture its audio.
```

Possible action:

```text
[ Try Another Source ]
```

Do not expose Android API terminology to normal users.

---

# 49. External Media Handoff

Once SoundMesh is ready to capture, the user should be clearly told what to do next.

Preferred:

```text
You're ready.

Open any supported media app
and play your audio.

SoundMesh will share the sound
with the connected phones.

[ Open Media App ]
```

If Android cannot safely launch a specific external application, provide a generic instruction instead.

SoundMesh does not need to know what media is being played.

---

# 50. External Media Ownership

The external media application owns:

* play
* pause
* seek
* playback position
* media selection
* track selection
* subtitles
* video
* playback speed
* media library

SoundMesh does not reproduce these controls as its own media-player controls.

The UI must never imply otherwise.

---

# 51. Active Audio Session

During an active session, SoundMesh should show that it is sharing live audio.

Preferred:

```text
Live audio session

● Sharing audio

5 devices connected
5 devices synchronized
```

Optional supporting information:

```text
Open your media app
to play audio.
```

The UI should remain useful after the user switches away from SoundMesh.

---

# 52. Background Session UX

SoundMesh is expected to remain active while the user uses another application.

Where Android requires a foreground service and persistent notification, the UX should make this understandable.

Notification example:

```text
SoundMesh

Sharing audio with 5 devices
```

The notification should communicate active status without exposing implementation details.

---

# 53. Persistent Session Indicator

While SoundMesh is actively capturing/sharing audio, the application should clearly indicate:

```text
● Sharing audio
```

Possible states:

```text
Preparing audio…
Sharing audio
Audio interrupted
Reconnecting…
```

The exact wording must correspond to actual native state.

---

# 54. Session State

The primary user-facing session lifecycle is:

```text
Room Ready
    ↓
Capture Permission Required
    ↓
Preparing
    ↓
Capture Ready
    ↓
Waiting for External Audio
    ↓
Sharing Audio
    ↓
Degraded / Recovering
    ↓
Ended
```

SoundMesh should not use a traditional media-player state model.

---

# 55. Waiting for External Audio

If capture is ready but no eligible external audio is currently being captured:

```text
Ready to share

Open your media app
and start playing audio.
```

This is preferable to displaying:

```text
Paused
```

because SoundMesh did not pause the external media application.

---

# 56. Active Session Primary Action

The primary action during an active session is **session management**, not media playback.

Possible actions:

```text
[ End Session ]
```

or:

```text
[ End Room ]
```

depending on the current room/session model.

There should not be a SoundMesh-owned play/pause/seek control.

---

# 57. Volume UX

SoundMesh may expose appropriate device output volume controls.

However, normal system volume remains the authoritative mechanism for each physical device.

If a future SoundMesh-wide volume feature is implemented, it must not imply that SoundMesh controls external media playback.

Per-device volume may exist as an advanced capability.

---

# 58. Synchronization UX

Synchronization should be visible but understandable.

Preferred:

```text
Getting everyone in sync…

● ● ● ● ●

Calibrating 5 devices
```

Then:

```text
✓ Everyone is synchronized
```

The user should feel that SoundMesh is actively making the system reliable.

---

# 59. Synchronization Confidence

Normal users should see:

```text
● Synchronized
```

Advanced diagnostics may show:

```text
Sync offset: +7.2 ms
RTT: 18.4 ms
Confidence: High
```

Technical information must not clutter the primary experience.

---

# 60. Preparation Barrier

Before synchronized output begins, required devices should reach the appropriate readiness state.

Example:

```text
3 of 5 devices ready

Waiting for 2 devices…
```

If degraded operation is supported, the user must be informed before proceeding.

---

# 61. Host Output vs Participant Output

The host's external media application may continue producing direct audio through the host device's normal output route.

Participants receive captured and replayed audio.

These paths may have different latency.

The UI must therefore never promise perfect synchronization before the system has measured and calibrated the relevant timing.

Normal UI may simply say:

```text
Calibrating…
```

rather than exposing implementation details.

Diagnostics may expose relevant measured latency.

---

# 62. Synchronization Recovery

If synchronization quality degrades:

```text
Sync quality reduced

Resynchronizing…
```

The system should attempt automatic recovery where possible.

The user should not be required to manually restart the entire room for a transient synchronization issue.

---

# 63. Device Connection Loss

If a participant disconnects:

```text
1 device disconnected

Reconnecting…
```

If the remaining session can safely continue, playback/sharing should continue.

Do not immediately terminate the room because one participant disappeared.

---

# 64. Participant Recovery

When a participant reconnects:

```text
Reconnecting…

Getting back in sync…
```

The participant may need to:

* reconnect
* re-establish timing
* refill its audio buffer
* synchronize to a future audio target

The user should see one coherent recovery experience rather than these technical steps.

---

# 65. Host Failure

MVP behavior may be controlled recovery rather than seamless host migration.

If the host becomes unavailable:

```text
Room connection lost

The host device is unavailable.

[ Return Home ]
```

Future host migration requires an explicit architectural and UX decision.

---

# 66. Capture Interruption

If capture stops unexpectedly:

```text
Audio sharing interrupted

SoundMesh can no longer capture
audio from this device.

[ Try Again ]
```

The UI should distinguish capture failure from network failure.

---

# 67. Audio Route Change

If the host changes an audio route, such as connecting or disconnecting a Bluetooth device:

```text
Audio output changed

SoundMesh is checking synchronization…
```

Timing may need recalibration.

The system should handle this automatically where possible.

---

# 68. Error Philosophy

Every user-facing error should answer:

1. What happened?
2. Does it matter?
3. What can the user do?

Example:

> **Couldn't connect to this device.**
> Make sure both phones are on the same local network.

```text
[ Try Again ]
```

Avoid:

```text
NETWORK_HANDSHAKE_TIMEOUT_1042
```

in normal UI.

---

# 69. Technical Error Details

Advanced users may access diagnostics.

Example:

```text
Connection failed

Code:
NET_HANDSHAKE_TIMEOUT

Retry count:
3

RTT:
—

Transport:
—
```

Raw technical details belong in diagnostics.

---

# 70. Diagnostics

Diagnostics should be accessible but secondary.

Potential information:

* device ID
* connection state
* RTT
* clock offset
* estimated sync error
* calibration confidence
* packet loss
* jitter
* audio buffer state
* buffer fill
* underruns
* stream statistics
* capture state
* capture format
* audio route
* drift rate
* recovery events
* reconnect count

---

# 71. Diagnostic Visual Hierarchy

Diagnostics should prioritize:

```text
Overall Health
      ↓
Synchronization
      ↓
Connections
      ↓
Audio Capture
      ↓
Audio Output
      ↓
Raw Technical Data
```

Raw logs should not dominate the interface.

---

# 72. Status Indicators

Status must use:

* icon/shape
* text
* color

not color alone.

Example:

```text
● Synchronized
```

rather than:

```text
●
```

---

# 73. Accessibility

Accessibility is REQUIRED.

The application must consider:

* contrast
* dynamic text sizing
* screen readers
* touch targets
* reduced motion
* non-color status communication
* accessible labels
* focus behavior
* readable errors
* clear state transitions

---

# 74. Dynamic Text

Layouts must tolerate increased system font sizes.

Text must not:

* overlap
* clip
* disappear
* become unreadable
* push critical controls beyond usable areas

---

# 75. Screen Reader Semantics

Important controls require descriptive labels.

Examples:

```text
Create Room
Join Room
Scan QR Code
Show Room QR Code
Allow Audio Capture
Open Media App
End Session
End Room
Open Diagnostics
Device status
Synchronization status
```

The mesh visualization should have an accessible summary.

Example:

> “Five devices connected. Four synchronized. One calibrating.”

---

# 76. Reduced Motion

When reduced-motion preferences are enabled:

* disable unnecessary mesh animation
* reduce transition movement
* remove decorative pulsing
* preserve state communication through static visuals

Functionality must remain identical.

---

# 77. Animation Philosophy

Animations communicate state.

They do not exist merely because animation is possible.

Every animation should answer:

> **“What changed?”**

If an animation communicates nothing, remove it.

---

# 78. Animation Duration

Suggested ranges:

```text
Micro interaction: 100–150 ms
Normal transition: 150–250 ms
Major transition: 250–350 ms
```

SoundMesh should feel responsive.

---

# 79. Mesh Animation Timing

Mesh animations should be:

* subtle
* coordinated
* low amplitude
* visually calm

The animation must never imply synchronization precision greater than the actual system can guarantee.

---

# 80. Loading States

Never show a blank screen during asynchronous work.

Use meaningful states:

```text
Creating room…
```

```text
Connecting…
```

```text
Getting audio ready…
```

```text
Calibrating…
```

```text
Reconnecting…
```

---

# 81. Empty States

Example:

```text
No active room

Create a room to connect
nearby phones.

[ Create Room ]
```

Avoid:

```text
Nothing here.
```

---

# 82. Permission UX

Permissions should be requested only when necessary.

MVP-relevant permissions may include:

* camera permission for QR scanning
* local-network/nearby-device permissions where required by Android implementation
* audio capture permission through Android's system capture flow

Do not request every permission on first launch.

---

# 83. Onboarding

The MVP should avoid a long onboarding carousel.

The first screen should communicate the product directly.

Preferred:

```text
SoundMesh

Make your phones
one speaker.

[ Create Room ]

    Join Room
```

Optional:

> Connect nearby phones and hear audio together.

---

# 84. First Successful Session

The first successful session is the most important onboarding experience.

Target:

```text
Open
 ↓
Create Room
 ↓
Friend scans QR
 ↓
Devices connect
 ↓
Allow audio capture
 ↓
SoundMesh gets ready
 ↓
Open media app
 ↓
Play audio
 ↓
Everyone hears it together
```

The technical system should become progressively more impressive without becoming progressively more complicated.

---

# 85. External Media App Handoff

When the session is ready:

```text
You're ready.

Open your media app
and play something.

SoundMesh will handle
the synchronized sharing.

[ Open Media App ]
```

The app should make it obvious that the user is leaving SoundMesh temporarily without ending the session.

---

# 86. Backgrounding

When the user switches to another app:

* SoundMesh session state remains active where Android permits
* capture continues through the native capture/session system
* the foreground service remains active where required
* a persistent notification communicates active sharing

The visual SoundMesh UI does not need to remain foregrounded.

---

# 87. Feedback During Technical Operations

Use concise human language.

Examples:

```text
Connecting…
```

```text
Getting everyone ready…
```

```text
Calibrating…
```

```text
Ready to share
```

```text
Sharing audio
```

```text
Sync quality reduced
```

```text
Resynchronizing…
```

```text
Audio sharing interrupted
```

---

# 88. State Truthfulness

The UI must represent actual system state.

Do not display:

```text
Synchronized
```

before synchronization succeeds.

Do not display:

```text
Sharing audio
```

before capture and audio transport are actually active.

Do not display:

```text
Connected
```

while a connection is only being attempted.

UI state must derive from authoritative application/native state.

---

# 89. Optimistic UI

Optimistic UI should be used cautiously.

Actions affecting:

* capture
* networking
* synchronization
* session state

must not falsely imply success.

The interface may immediately acknowledge that the user pressed a button, but the actual state must only change when the underlying system confirms it.

---

# 90. Responsive Design

The UI must adapt to:

* screen sizes
* aspect ratios
* safe areas
* font sizes
* orientation

Do not hardcode layouts around one phone.

---

# 91. Safe Areas

Content must respect:

* status bars
* camera cutouts
* navigation areas
* gesture areas
* rounded corners

Use platform-safe-area mechanisms.

---

# 92. Orientation

Portrait is the primary MVP orientation.

Landscape may be considered for:

* tablets
* expanded diagnostics
* future layouts

No core feature should become unusable because of orientation changes where the platform permits them.

---

# 93. Large Screens

On larger displays:

* preserve comfortable reading width
* optionally use two-column layouts
* avoid stretching cards across the entire screen
* preserve mobile-like hierarchy where appropriate

---

# 94. UI Component Architecture

Reusable components should include:

```text
PrimaryButton
SecondaryButton
IconButton
TextButton

Card
StatusBadge
DeviceRow
DeviceStatus

RoomMesh

CapturePermissionCard
CaptureStatus
SessionStatus
SyncStatus
ConnectionStatus

ProgressIndicator
LoadingState
ErrorState
EmptyState

Dialog
BottomSheet
Snackbar

DiagnosticMetric
DiagnosticSection
```

The application should not create media-player-specific components such as:

```text
PlaybackControls
SeekBar
TrackList
AudioPicker
NowPlayingCard
```

unless a future documented product decision explicitly introduces such functionality.

---

# 95. Design Tokens

Colors, typography, spacing, radii, and dimensions must be centralized.

Conceptually:

```text
colors.background.primary
colors.background.secondary
colors.surface.default
colors.surface.elevated

colors.text.primary
colors.text.secondary
colors.text.muted

colors.accent.primary
colors.accent.light
colors.accent.dark

colors.status.success
colors.status.warning
colors.status.error
```

Do not scatter raw values throughout the application.

---

# 96. Tokenized Typography

Centralize:

```text
typography.display
typography.largeTitle
typography.title
typography.heading
typography.body
typography.bodyEmphasis
typography.caption
typography.metadata
```

---

# 97. Tokenized Spacing

Use:

```text
spacing.xs
spacing.sm
spacing.md
spacing.lg
spacing.xl
spacing.xxl
```

mapped to the documented spacing scale.

---

# 98. Platform Conventions

Respect Android conventions where appropriate.

Examples:

* system permission dialogs
* navigation gestures
* accessibility behavior
* keyboard behavior
* system sharing
* camera permission
* MediaProjection capture permission
* foreground-service notification behavior

Do not recreate system permission dialogs.

---

# 99. Flutter UI Boundary

Flutter owns:

* visual UI
* navigation
* user interaction
* high-level room/session state presentation
* design system
* accessibility semantics
* non-realtime animations

Native Android code owns timing-critical operations.

This includes:

* audio capture
* realtime audio buffering
* audio transport
* native output
* timing measurements
* synchronization scheduling
* foreground service lifecycle where required

---

# 100. Realtime UI Constraint

High-frequency audio or synchronization callbacks must not continuously drive Flutter widget rebuilds.

Preferred:

```text
Native realtime system
        ↓
Aggregated state
        ↓
Flutter
        ↓
UI
```

Flutter should display meaningful state updates rather than every internal timing event.

---

# 101. Session UI Update Frequency

The session UI should update at human-useful frequencies.

Do not rebuild:

* device lists
* mesh visualization
* navigation
* static content

for every audio frame or timing measurement.

---

# 102. Mesh Performance

The mesh must remain lightweight.

Avoid:

* particle systems
* expensive blur
* GPU-heavy effects
* unnecessary redraws
* dozens of animated widgets

It must perform comfortably on supported lower-end Android devices.

---

# 103. Battery Awareness

Decorative animation should reduce or stop when:

* the screen is inactive
* the room is stable
* the application is backgrounded

Audio synchronization and capture always take priority over visual effects.

---

# 104. Audio-First UX

SoundMesh is fundamentally a realtime audio application.

Visual effects must never compromise:

* capture stability
* audio output
* synchronization
* CPU
* battery
* responsiveness

If an animation conflicts with realtime audio performance, remove the animation.

---

# 105. Error Recovery UX

Recovery should be progressive:

```text
Detect
  ↓
Attempt automatic recovery
  ↓
Inform user if needed
  ↓
Retry
  ↓
Request intervention only if necessary
```

Transient problems should not unnecessarily interrupt the user.

---

# 106. Notifications / Snackbars

Use snackbars for:

* minor temporary information
* recoverable warnings
* successful minor actions

Do not use snackbars for critical session state that must remain visible.

---

# 107. Dialogs

Dialogs should be reserved for:

* destructive actions
* important decisions
* critical errors
* situations requiring explicit user intervention

Do not turn every action into a confirmation dialog.

---

# 108. Destructive Actions

Ending a room may require confirmation.

Example:

> **End this room?**
> Audio sharing will stop for all connected devices.

```text
Cancel

End Room
```

---

# 109. Room Lifecycle UX

Map technical states into human-readable states.

```text
CREATED
→ Creating room…

DISCOVERABLE
→ Waiting for devices…

JOINING
→ Connecting…

READY
→ Getting ready…

CAPTURE_PERMISSION_REQUIRED
→ Audio permission required

CAPTURING
→ Audio capture ready

STREAMING
→ Sharing audio

SYNCHRONIZING
→ Getting everyone in sync…

DEGRADED
→ Sync quality reduced

RECOVERING
→ Resynchronizing…

ENDING
→ Ending room…

CLOSED
→ Room ended

ERROR
→ Something went wrong
```

Internal enum names must never appear in normal production UI.

---

# 110. Sync Quality Presentation

Normal:

```text
● Synchronized
```

Degraded:

```text
● Sync quality reduced
```

Recovering:

```text
↻ Resynchronizing…
```

Failed:

```text
Couldn't synchronize this device.
```

---

# 111. No False Precision

Normal UI should not display meaningless precision.

Avoid:

```text
Synchronization: 98.371%
```

unless the metric has a clearly defined meaning.

Advanced diagnostics may display measured values with appropriate uncertainty.

---

# 112. Premium Feel Through Restraint

Premium appearance should come from:

* consistent spacing
* typography
* controlled color
* hierarchy
* smooth transitions
* alignment
* whitespace
* stable components

Not:

* gradients everywhere
* glassmorphism everywhere
* huge shadows
* neon effects
* excessive animation

---

# 113. Glassmorphism

Glassmorphism is not the default design language.

Translucent or blurred surfaces may be used selectively if performance and readability permit.

The base UI must remain attractive without blur.

---

# 114. Shadows

Shadows should be:

* subtle
* soft
* low opacity
* used primarily for separation

Luminance separation is preferred on dark backgrounds.

---

# 115. Background Treatment

The primary background should remain mostly flat.

Optional subtle tonal variation may be used around major areas.

Do not create animated backgrounds.

---

# 116. Brand Mark

The SoundMesh logo should conceptually represent:

* connected devices
* sound
* coordination
* synchronization

It should work in:

* app icon
* splash screen
* header
* QR presentation
* GitHub/README branding

The logo must remain recognizable without color.

---

# 117. App Icon

The app icon should be:

* simple
* high contrast
* recognizable at small sizes
* based on the mesh concept
* compatible with SoundMesh Blue and the dark identity

Avoid text inside the app icon.

---

# 118. Splash Screen

Keep it minimal.

Preferred:

```text
SoundMesh
```

with the logo/mesh mark.

Do not create a long animated splash sequence.

---

# 119. Interaction Priority

When multiple actions are available:

```text
Primary task
    ↓
Secondary task
    ↓
Supporting information
    ↓
Advanced controls
    ↓
Diagnostics
```

Diagnostics must never compete with the primary session action.

---

# 120. MVP User Flow

Complete intended MVP flow:

```text
Launch
  ↓
Home
  ↓
Create Room
  ↓
Room Created
  ↓
Show QR
  ↓
Participant Scans
  ↓
Connection
  ↓
Devices Ready
  ↓
Host Grants Audio Capture Permission
  ↓
Capture Ready
  ↓
Synchronization
  ↓
Ready to Share
  ↓
Open External Media App
  ↓
Play Audio
  ↓
SoundMesh Captures Live Audio
  ↓
Participants Receive Audio
  ↓
Synchronized Audio Output
  ↓
Monitor Session
  ↓
Recover if Necessary
  ↓
End Session / End Room
```

SoundMesh does not select or control the media being played.

---

# 121. Join Flow

```text
Home
  ↓
Join Room
  ↓
Scan QR
  ↓
Request Camera Permission if necessary
  ↓
QR Validated
  ↓
Connect
  ↓
Join Handshake
  ↓
Device Identified
  ↓
Prepare Audio Session
  ↓
Calibration
  ↓
Ready
```

The user should not need to see protocol details.

---

# 122. Host Capture Flow

```text
Room Ready
  ↓
Audio Capture Permission
  ↓
Permission Granted
  ↓
Capture Ready
  ↓
Open External Media App
  ↓
External App Produces Audio
  ↓
SoundMesh Detects Captured Audio
  ↓
Live Audio Session Active
```

---

# 123. Participant Flow

```text
Join Room
  ↓
Connect
  ↓
Receive Session Configuration
  ↓
Timing Calibration
  ↓
Prepare Audio Output
  ↓
Fill Buffer
  ↓
Wait for Synchronization Target
  ↓
Synchronized Output
```

The participant should experience this as one simple “getting ready” process.

---

# 124. Device State Presentation

Every device may internally have detailed states.

Normal UI should reduce them to:

```text
Connecting…
Getting ready…
Calibrating…
Ready
Synchronized
Degraded
Recovering…
Disconnected
```

Technical state names belong only in diagnostics.

---

# 125. Major Component States

Every major component should consider:

```text
Default
Pressed
Focused
Disabled
Loading
Success
Warning
Error
Selected
Unavailable
```

Not every component requires every visual state.

---

# 126. Button States

Primary button:

```text
Default → Accent
Pressed → Accent Dark
Disabled → Muted surface/text
Loading → Accent + progress indicator
```

Button state must accurately reflect the underlying operation.

---

# 127. Inputs

Inputs should distinguish:

```text
Default
Focused
Filled
Error
Disabled
```

Focus should use the SoundMesh accent while preserving contrast.

Errors require textual explanation.

---

# 128. QR Scanner UX

Scanner should:

* open quickly
* clearly show scan region
* handle camera permission
* indicate successful detection
* reject invalid codes gracefully

Invalid QR:

> **That isn't a SoundMesh room code.**

Do not expose parsing errors.

---

# 129. Offline Philosophy

SoundMesh should never imply that Internet access is required for local operation.

If the Internet is unavailable but local connectivity works:

> SoundMesh can continue communicating locally.

Internet availability should not be presented as a prerequisite for the MVP.

---

# 130. Network Problem UX

If the room cannot be reached:

> **Couldn't find the room.**

Supporting explanation:

> Make sure the devices are connected to the same local network.

The interface should guide the user toward the likely cause.

---

# 131. Network Permission UX

If Android requires a relevant permission:

> SoundMesh needs local network access to connect nearby phones.

Do not expose API names or implementation terminology.

---

# 132. Device Naming

Use human-readable names:

```text
Faraz's Phone
Mahin's Phone
Galaxy A52
Pixel
```

Technical identifiers remain hidden except in diagnostics.

---

# 133. Device Identity

Device names are presentation identity.

They are not authentication identity.

The UI must never imply that a device name is a security credential.

---

# 134. Security UX

Normal UI should not expose security implementation details.

Room joining should feel effortless.

If host approval is introduced later:

```text
Mahin wants to join

[ Allow ]

[ Deny ]
```

Security should be understandable without exposing protocol mechanics.

---

# 135. Room Privacy

Do not expose permanent room credentials in normal UI.

QR codes should contain temporary join information according to the networking specification.

---

# 136. Loading Progress

Progress indicators should reflect actual measurable progress.

If progress cannot be accurately measured, use an indeterminate indicator.

Never fake progress.

---

# 137. Time Perception

The interface should acknowledge actions immediately.

Instead of appearing frozen:

```text
Preparing…
```

```text
Connecting…
```

```text
Calibrating…
```

should appear as soon as appropriate.

---

# 138. Microcopy Rules

Use:

* short sentences
* human language
* active voice
* clear verbs
* minimal technical terminology

Preferred:

> Getting everyone in sync…

Avoid:

> Synchronization subsystem initialization in progress.

Preferred:

> Couldn't connect to this device.

Avoid:

> Connection establishment procedure failed.

---

# 139. Capitalization

Use sentence case for most UI.

Preferred:

```text
Create Room
```

or:

```text
Create a room
```

Avoid unnecessary ALL CAPS.

---

# 140. Punctuation

UI labels generally should not end with periods.

Explanatory sentences may use punctuation.

Example:

```text
Create Room
```

versus:

> Make sure both phones are on the same network.

---

# 141. Accessibility Language

Instructions should be explicit.

Bad:

```text
Try again.
```

Better:

```text
Try connecting again.
```

Best where context matters:

```text
Make sure both phones are on the same network,
then try connecting again.
```

---

# 142. Visual Hierarchy of the Room

Prioritize:

```text
1. Current session state
2. Primary session action
3. Synchronization state
4. Device health
5. Room identity
6. Secondary controls
7. Diagnostics
```

The room should emphasize what SoundMesh is doing now.

---

# 143. Visual Hierarchy of Home

```text
1. SoundMesh identity
2. Core value proposition
3. Create Room
4. Join Room
5. Supporting information
6. Settings/About
```

---

# 144. Visual Hierarchy of Diagnostics

```text
1. Overall health
2. Synchronization
3. Device states
4. Network
5. Audio capture
6. Audio output
7. Detailed measurements
```

---

# 145. Design Anti-Patterns

AI agents and developers MUST NOT introduce:

* random gradients
* neon backgrounds
* excessive glassmorphism
* excessive rounded cards
* giant text everywhere
* emoji as primary UI icons
* arbitrary colors
* inconsistent corner radii
* arbitrary spacing
* multiple competing accent colors
* excessive animation
* permanent bottom navigation
* unnecessary onboarding
* fake loading progress
* fake synchronization metrics
* technical jargon in primary UI
* raw error codes in normal UI
* IP addresses in normal onboarding
* configuration-heavy first-run flow
* media-player controls that SoundMesh does not own
* fake track metadata
* fake playback progress
* fake audio-library screens
* file-transfer progress as a primary UX
* language implying that SoundMesh selects or controls external media

---

# 146. Design Decision: Blue Identity

The primary SoundMesh brand color is:

```text
#5B8CFF
```

Do not replace it without updating the design decision documentation.

---

# 147. Design Decision: Dark-First

SoundMesh MVP is dark-first.

Primary background:

```text
#0B0D10
```

A future light theme may be considered separately.

---

# 148. Design Decision: Minimal Navigation

The MVP does not require a permanent multi-tab navigation system.

The primary experience is:

```text
Home → Room → Active Session
```

The external media application exists outside SoundMesh's navigation hierarchy.

---

# 149. Design Decision: Diagnostics Are Secondary

Diagnostics are important for development and advanced users but must not dominate normal UX.

---

# 150. Design Decision: Technical Complexity Is Hidden

The interface must not require users to understand:

* clock synchronization
* network latency
* jitter buffers
* audio packetization
* audio timestamps
* capture APIs
* transport protocols
* drift correction
* device clocks

unless they intentionally enter diagnostics.

---

# 151. Design Decision: Mesh Is the Visual Language

The connected-device mesh is SoundMesh's primary visual metaphor.

It may appear in:

* room visualization
* connection states
* synchronization states
* branding

It should not become repetitive decoration on every screen.

---

# 152. Design Decision: SoundMesh Is Not a Media Player

SoundMesh does not own:

* media selection
* media libraries
* track lists
* playback controls
* seeking
* subtitles
* playback speed
* external media state

The external application remains the source of truth for media playback.

---

# 153. Design Decision: Live Audio Is the Primary Data Experience

During an active session, the primary audio experience is:

```text
External App
     ↓
Audio Capture
     ↓
Live Audio Stream
     ↓
Synchronized Output
```

The UI must not represent audio as a file being copied between devices.

---

# 154. Design Decision: Performance Before Visual Effects

If a visual effect causes:

* dropped frames
* excessive GPU usage
* battery drain
* audio instability
* synchronization problems

remove or simplify the effect.

Functional reliability always outranks visual spectacle.

---

# 155. UI/UX Acceptance Criteria

The MVP UI is acceptable only when:

## Navigation

* user can create a room without unnecessary configuration
* user can join using QR
* navigation is predictable
* back behavior is correct

## Visual

* colors are centralized
* typography uses the documented scale
* spacing follows the spacing system
* no arbitrary decorative colors exist
* SoundMesh Blue is used consistently

## Room

* room identity is obvious
* device count is visible
* device status is understandable
* session state is visible
* synchronization state is visible
* primary session action is obvious

## Capture

* capture permission is requested contextually
* permission state is truthful
* unsupported sources are clearly explained
* capture readiness is visible
* the user understands when to open the external media application

## Active Session

* live audio sharing state is visible
* synchronization state is visible
* device health is visible
* background operation is understandable
* SoundMesh does not pretend to control external media playback

## Errors

* errors are human-readable
* recovery actions are provided where possible
* raw technical details remain secondary

## Accessibility

* important text has adequate contrast
* touch targets are sufficiently large
* status is not communicated by color alone
* screen-reader labels exist
* increased text sizes do not destroy layout
* reduced motion is respected

## Performance

* animations do not interfere with audio
* mesh visualization remains lightweight
* unnecessary rebuilds are avoided
* realtime audio remains the highest performance priority

---

# 156. UI/UX Verification

The MVP should be tested on:

* at least one lower-end Android device
* at least one modern Android device
* different screen sizes
* different system text-size settings
* reduced-motion settings where available
* portrait orientation
* network failure states
* device disconnection
* synchronization recovery
* audio capture permission denial
* unsupported capture sources
* capture interruption
* audio route changes
* background operation
* foreground-service behavior

iOS is not required for MVP UI verification.

---

# 157. Visual QA Checklist

Before a UI feature is considered complete:

```text
[ ] Correct background
[ ] Correct surface hierarchy
[ ] Correct typography
[ ] Correct spacing
[ ] Correct corner radius
[ ] Correct iconography
[ ] Correct button states
[ ] Correct loading state
[ ] Correct error state
[ ] Correct capture state
[ ] Correct session state
[ ] Correct sync state
[ ] Correct accessibility labels
[ ] Correct contrast
[ ] Correct safe-area handling
[ ] Correct dynamic text behavior
[ ] Correct reduced-motion behavior
[ ] No arbitrary colors
[ ] No arbitrary spacing
[ ] No unnecessary animation
[ ] No technical jargon in primary UX
[ ] No fake synchronization information
[ ] No fake playback controls
[ ] No media-player ownership implied
```

---

# 158. Relationship to Other Specifications

This document does not define:

* synchronization algorithms
* networking protocols
* audio engine implementation
* Android capture implementation
* native timing architecture

Those are defined by:

```text
DOCS/synchronization.md
DOCS/networking.md
DOCS/audio.md
DOCS/architecture.md
```

This document defines how those systems are **experienced and represented by the user**.

---

# 159. Cross-System Rule

The UI must never contradict underlying engineering state.

For example:

```text
Networking:
DISCONNECTED

UI:
Synchronized
```

is invalid.

Similarly:

```text
Capture:
NOT_CAPTURING

UI:
Sharing audio
```

is invalid.

Similarly:

```text
Synchronization:
NOT_READY

UI:
Synchronized
```

is invalid.

The UI is a representation of actual system state, not an independent simulation.

---

# 160. MVP Screen Inventory

The initial application should contain approximately these primary screens/states:

```text
1. Home
2. Create Room
3. Room — Waiting
4. QR Display
5. Join Room
6. QR Scanner
7. Room — Devices
8. Audio Capture Permission
9. Capture Ready
10. Waiting for External Audio
11. Synchronizing
12. Active Audio Session
13. Device Details
14. Diagnostics
15. Settings
16. Error / Recovery States
```

Several should be implemented as states within a screen rather than completely separate routes where appropriate.

There should be no required:

* track-selection screen
* music library
* Now Playing screen
* seek interface
* SoundMesh-owned playback timeline

---

# 161. Preferred Core Experience

The ideal SoundMesh session should feel like:

```text
OPEN

SoundMesh

Make your phones
one speaker.

       Create Room

         Join Room
```

Then:

```text
CREATE

Room created.

       ◉
     /   \
   📱     📱
     \   /
       📱

Waiting for devices…
```

Then:

```text
JOIN

Scan the QR.

      [ QR ]
```

Then:

```text
CONNECT

3 devices connected.

Getting everyone ready…
```

Then:

```text
CAPTURE

Audio capture permission

SoundMesh needs permission
to share audio from this phone.

[ Allow ]
```

Then:

```text
READY

Everyone is ready.

Open your media app
and play something.

[ Open Media App ]
```

Then:

```text
SHARING

● Sharing audio

5 devices synchronized
```

Then:

```text
RECOVER

Sync quality reduced.

Resynchronizing…
```

Then:

```text
END

End Room?

Audio sharing will stop
for all connected devices.

Cancel     End Room
```

The user should experience this as one simple process.

---

# 162. Ultimate Design Principle

SoundMesh should create a deliberate contrast.

## Under the hood

```text
Distributed systems
Android audio capture
Live audio transport
Clock synchronization
Latency estimation
Jitter buffering
Audio scheduling
Drift correction
Recovery algorithms
Native audio engines
```

## On the screen

```text
Create
Join
Get ready
Play
```

The engineering should be impressive.

The interface should make it feel effortless.

---

# 163. Final UX Principle

> **SoundMesh should feel like the complexity disappeared.**

The user should not think:

> “How are these phones synchronizing?”

They should think:

> **“Holy shit, they're all playing together.”**

That moment is the product.

The interface exists to reach that moment as quickly, clearly, reliably, and beautifully as possible.

---

# 164. Definition of Done

`ui-ux.md` is considered implemented when:

* the documented color system is centralized
* typography is centralized
* spacing is tokenized
* major screens follow the specified hierarchy
* room/device states have explicit UI representations
* capture states have explicit UI representations
* synchronization states have clear user-facing language
* active audio-session UI is implemented
* external-media handoff UX is implemented
* error and recovery states exist
* accessibility requirements are addressed
* responsive behavior is implemented
* animations are purposeful and lightweight
* technical state is accurately represented
* no SoundMesh-owned media-player model remains
* no file-distribution UX is required
* no major UI decisions are left to arbitrary implementation preference

**Source of truth:** This document governs SoundMesh's visual and interaction design unless superseded by an explicit documented decision.
