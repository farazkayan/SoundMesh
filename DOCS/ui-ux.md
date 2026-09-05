\# SoundMesh — UI/UX Specification



\*\*Document Status:\*\* REQUIRED

\*\*Document Type:\*\* Product/UI/UX Source of Truth

\*\*Applies To:\*\* SoundMesh mobile application

\*\*Primary Platforms:\*\* iOS and Android

\*\*Design Direction:\*\* Dark-first, premium, minimal, audio-focused, technically sophisticated without exposing technical complexity



\---



\# 1. Purpose



This document defines the complete user-interface and user-experience system for SoundMesh.



It establishes:



\* visual identity

\* color system

\* color science and contrast requirements

\* typography

\* spacing

\* sizing

\* layout

\* navigation

\* information hierarchy

\* components

\* states

\* animations

\* transitions

\* accessibility

\* responsive behavior

\* room visualization

\* playback UI

\* synchronization feedback

\* error handling

\* onboarding

\* diagnostics

\* interaction rules

\* design tokens

\* UI acceptance criteria



This document is intended to prevent individual developers or AI coding agents from making arbitrary visual decisions.



If an implementation decision conflicts with this document, this document is the UI/UX authority unless a newer documented decision explicitly supersedes it.



\---



\# 2. Core UX Principle



SoundMesh performs technically complex operations involving:



\* local networking

\* device discovery

\* audio transfer

\* buffering

\* clock synchronization

\* latency measurement

\* scheduled playback

\* drift detection

\* playback correction

\* connection recovery



The user should not need to understand any of those systems.



The fundamental UX principle is:



> \*\*Hide technical complexity behind simple, trustworthy interactions.\*\*



The intended mental model is:



```text

Create

&#x20; ↓

Join

&#x20; ↓

Choose audio

&#x20; ↓

Everyone gets ready

&#x20; ↓

Play

```



Not:



```text

Create

&#x20; ↓

Configure network

&#x20; ↓

Configure latency

&#x20; ↓

Synchronize clocks

&#x20; ↓

Configure buffers

&#x20; ↓

Start playback

```



The engineering complexity should exist underneath the interface, not inside it.



\---



\# 3. Product Personality



SoundMesh should feel:



\* premium

\* calm

\* modern

\* technically capable

\* trustworthy

\* fast

\* effortless

\* focused

\* intentional



SoundMesh should NOT feel:



\* childish

\* excessively futuristic

\* gamer-oriented

\* RGB-heavy

\* cyberpunk

\* cluttered

\* corporate

\* overly playful

\* like a generic music streaming application

\* like an AI-generated template



The interface should communicate:



> “This is a serious piece of technology that is extremely easy to use.”



\---



\# 4. Visual Identity



The primary visual metaphor is a \*\*mesh of connected devices\*\*.



Each phone participating in a room can be represented as a node.



Conceptually:



```text

&#x20;            ●

&#x20;          /   \\

&#x20;        ●───────●

&#x20;         \\     /

&#x20;          \\   /

&#x20;            ●

```



The production UI must use a refined interpretation of this concept.



The mesh should never resemble a technical network diagram unless the user enters diagnostics.



Normal users should perceive it as:



> “My phones are connected.”



Advanced users may perceive it as:



> “These devices are communicating and synchronizing.”



The mesh is a brand element, not merely decoration.



\---



\# 5. Color Philosophy



SoundMesh uses a dark neutral foundation with a single strong blue accent.



The color system is intentionally restrained.



The UI should derive visual richness primarily from:



\* luminance

\* hierarchy

\* depth

\* typography

\* spacing

\* subtle surfaces

\* controlled accent usage



It must not rely on large gradients or excessive saturated colors.



\---



\# 6. Primary Color Palette



\## 6.1 Background



\### `Background / Primary`



```text

\#0B0D10

```



RGB:



```text

11, 13, 16

```



Purpose:



\* application background

\* full-screen surfaces

\* major empty areas



This is intentionally not pure black.



Pure `#000000` should not be the default application background because the slightly lifted neutral background provides better perceived depth and reduces the harshness of pure-black/white contrast.



\---



\## 6.2 Secondary Background



```text

\#12161B

```



Purpose:



\* secondary sections

\* navigation areas

\* large contained regions

\* grouped content



\---



\## 6.3 Surface



```text

\#181D23

```



Purpose:



\* cards

\* list containers

\* input fields

\* elevated controls



\---



\## 6.4 Elevated Surface



```text

\#20262D

```



Purpose:



\* modal surfaces

\* active cards

\* menus

\* dialogs

\* strongly elevated controls



\---



\## 6.5 Primary Text



```text

\#F5F7FA

```



Purpose:



\* titles

\* primary labels

\* important values

\* primary buttons



This is intentionally slightly softer than pure white.



\---



\## 6.6 Secondary Text



```text

\#A7AFB9

```



Purpose:



\* descriptions

\* supporting labels

\* metadata

\* secondary navigation text



\---



\## 6.7 Muted Text



```text

\#6F7883

```



Purpose:



\* tertiary information

\* inactive metadata

\* placeholders where appropriate



Muted text must never be used for information that is required to understand or operate the application.



\---



\# 7. Primary Accent



\## SoundMesh Blue



```text

\#5B8CFF

```



RGB:



```text

91, 140, 255

```



This is the primary brand/action color.



Use it for:



\* primary buttons

\* active controls

\* selected states

\* progress indicators

\* important interactive elements

\* mesh activity

\* synchronization activity

\* links

\* focus indicators where appropriate



Blue should be used deliberately.



It must NOT cover large portions of every screen simply because it is the brand color.



\---



\# 8. Accent Variants



\## Accent Light



```text

\#7DA5FF

```



Use for:



\* pressed/hover-derived visual states where appropriate

\* selected emphasis

\* light accent elements on dark surfaces

\* visual hierarchy within the mesh



\## Accent Dark



```text

\#3D6FE0

```



Use for:



\* pressed states

\* deeper emphasis

\* controlled contrast against bright accent states



\---



\# 9. Semantic Colors



\## Success



```text

\#39D98A

```



Meaning:



\* connected

\* synchronized

\* ready

\* successful

\* healthy



Success must never be represented by color alone.



Example:



```text

● Synchronized

```



not:



```text

●

```



\---



\## Warning



```text

\#FFB84D

```



Meaning:



\* calibrating

\* degraded

\* uncertain

\* recovering

\* attention required



\---



\## Error



```text

\#FF5C6C

```



Meaning:



\* disconnected

\* failed

\* unavailable

\* unrecoverable operation



\---



\## Informational



Use SoundMesh Blue.



Do not introduce unnecessary additional semantic colors.



\---



\# 10. Color Science Requirements



Color selection must be based on perceptual hierarchy rather than arbitrary hex values.



The application uses a dark UI, therefore luminance separation between surfaces is particularly important.



Surfaces should generally differ through relatively small luminance steps.



The hierarchy should be:



```text

Background

&#x20;  ↓

Secondary Background

&#x20;  ↓

Surface

&#x20;  ↓

Elevated Surface

```



The UI must not rely on borders everywhere to communicate hierarchy.



Where possible, hierarchy should be communicated through:



1\. luminance

2\. spacing

3\. typography

4\. shape

5\. subtle borders

6\. shadow/elevation



in that order.



\---



\# 11. Contrast



All user-facing text and important controls must meet appropriate accessibility contrast requirements.



Do not assume that a color is accessible simply because it visually appears bright enough.



Contrast must be evaluated using the actual foreground/background pairing.



Important pairings include:



\* primary text on background

\* secondary text on background

\* primary text on surfaces

\* accent text on dark surfaces

\* button text on accent backgrounds

\* status text on status surfaces

\* disabled-state text

\* focused controls



Normal text should target WCAG AA contrast at minimum.



Large text and UI components must also be checked according to applicable WCAG criteria.



If a proposed visual treatment fails contrast requirements, adjust luminance before adding visual effects.



\---



\# 12. Accent Usage Ratio



The primary blue should function as a visual signal.



It should not become the background of every component.



A screen should generally remain visually dominated by:



\* dark neutrals

\* white/off-white text

\* subtle surfaces



with blue used to direct attention.



Preferred visual hierarchy:



```text

████████████████████

Dark neutral foundation



&#x20;     WHITE

&#x20;     Primary content



&#x20;         BLUE

&#x20;     Main action

```



Avoid:



```text

████████████████████

BLUE EVERYTHING

```



\---



\# 13. No Decorative Color Noise



Do not introduce:



\* random purple

\* cyan gradients

\* pink highlights

\* rainbow effects

\* neon green

\* decorative red

\* arbitrary gradients



unless a future documented design decision explicitly introduces them.



Semantic colors should communicate state, not decorate the interface.



\---



\# 14. Gradients



Gradients are OPTIONAL and should be rare.



The MVP should primarily use flat colors.



If gradients are introduced later, they must:



\* support hierarchy

\* preserve readability

\* not reduce contrast

\* not overpower content

\* not become the primary visual identity



The mesh visualization may use extremely subtle luminance transitions if necessary.



\---



\# 15. Typography Philosophy



Typography is a major part of SoundMesh's premium appearance.



The application should not rely on oversized text everywhere.



Premium typography comes from:



\* excellent font selection

\* appropriate weight

\* optical hierarchy

\* restrained tracking

\* line height

\* consistent scale

\* whitespace



Typography should feel engineered rather than decorative.



\---



\# 16. Font Strategy



Use the platform-native system font by default.



\## iOS



Preferred:



\*\*SF Pro / system UI font\*\*



\## Android



Preferred:



\*\*Roboto / system UI font\*\*



If a custom cross-platform font is introduced, it must provide:



\* excellent Latin character quality

\* broad Unicode support

\* multiple weights

\* strong readability at small sizes

\* consistent numerals

\* good rendering on both platforms



The MVP should not add a custom font merely for branding.



A platform-native font rendered correctly is preferable to a poor custom font.



\---



\# 17. Typography Scale



The following logical scale should be used.



\## Display



```text

32 px

Weight: 700

Line height: 38–40 px

```



Use sparingly.



Examples:



\* major empty-state headline

\* important onboarding statement



\---



\## Large Title



```text

28 px

Weight: 700

Line height: 34 px

```



Use for:



\* screen titles

\* major room states



\---



\## Title



```text

22 px

Weight: 650–700

Line height: 28 px

```



Use for:



\* major sections

\* playback title

\* dialogs



\---



\## Heading



```text

18 px

Weight: 600

Line height: 24 px

```



Use for:



\* card headings

\* device names

\* grouped sections



\---



\## Body



```text

16 px

Weight: 400

Line height: 22–24 px

```



Primary body text.



\---



\## Body Emphasis



```text

16 px

Weight: 500–600

```



Use for:



\* important labels

\* selected values

\* device status



\---



\## Caption



```text

14 px

Weight: 400–500

Line height: 18–20 px

```



Use for:



\* supporting information

\* metadata

\* descriptions



\---



\## Small Metadata



```text

12 px

Weight: 500

Line height: 16 px

```



Use sparingly.



Never use this size for critical instructions.



\---



\# 18. Typography Weight Rules



Preferred weights:



```text

400 — regular

500 — medium

600 — semibold

700 — bold

```



Avoid excessive use of 700.



A premium interface should not make every element bold.



Hierarchy should come from a combination of:



\* size

\* weight

\* luminance

\* spacing



\---



\# 19. Letter Spacing



Avoid manually increasing letter spacing for normal text.



Large titles may use slightly negative tracking if the platform font renders well.



Small uppercase labels may use modest positive tracking.



Never use extreme tracking as a substitute for hierarchy.



\---



\# 20. Numerals



Numbers matter heavily in SoundMesh because diagnostics may display:



\* milliseconds

\* percentages

\* device counts

\* playback time

\* network latency



Use fonts/platform settings that provide clear numerals.



Diagnostic numerical displays should preferably use tabular/monospaced numerals if available so values do not visually shift when changing.



Example:



```text

&#x20; 7.2 ms

&#x20;18.4 ms

102.1 ms

```



should remain visually aligned.



\---



\# 21. Spacing System



Use an 8-point base spacing system.



Primary spacing values:



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



Use 4 px increments only for small optical adjustments.



Do not invent arbitrary values such as:



```text

17 px

23 px

31 px

```



unless required for platform-native rendering or optical correction.



\---



\# 22. Screen Margins



Default mobile horizontal content margin:



```text

16–20 px

```



Preferred default:



```text

20 px

```



Large-screen layouts may increase the maximum content width rather than continuously increasing margins.



\---



\# 23. Touch Targets



Interactive controls should provide sufficiently large touch targets.



Target:



```text

≥ 44 × 44 px

```



for important interactive controls.



Small icons may visually occupy less space, but their interactive hit area should remain sufficiently large.



\---



\# 24. Corner Radius



Use restrained rounded corners.



Recommended scale:



```text

8 px   — small controls

12 px  — inputs/cards

16 px  — major cards

20 px  — prominent sheets

24 px  — special hero surfaces

```



Do not use extreme pill shapes for every component.



Pills should be reserved for:



\* compact status indicators

\* tags

\* segmented controls

\* specific action buttons



\---



\# 25. Borders



Borders should be subtle.



Preferred border color is a low-contrast neutral derived from the surface/background relationship.



Borders are for:



\* defining ambiguous boundaries

\* inputs

\* selected cards

\* separators where needed



Do not outline every card.



\---



\# 26. Elevation



SoundMesh should use subtle depth.



Avoid traditional heavy shadows.



Preferred depth model:



```text

Background

↓

Surface

↓

Elevated Surface

```



Use luminance and subtle shadows together where appropriate.



The application should still look coherent if shadows are removed.



\---



\# 27. Iconography



Use a single coherent icon family.



Icons should be:



\* simple

\* geometric

\* consistent in stroke weight

\* recognizable

\* platform appropriate



Do not mix:



\* outlined icons

\* filled icons

\* 3D icons

\* emoji

\* unrelated icon families



for the same visual hierarchy.



Emoji may be used only where explicitly intentional.



The production UI should primarily use vector/system icons.



\---



\# 28. Navigation Philosophy



SoundMesh is task-oriented.



The MVP should not use a large five-tab navigation system simply because many mobile applications do.



Primary flow:



```text

Home

├── Create Room

│   └── Room

│

└── Join Room

&#x20;   └── Room

```



Within a room:



```text

Room

├── Playback

├── Devices

├── Diagnostics

└── Room Settings

```



Navigation should preserve context.



\---



\# 29. Home Screen



The home screen should immediately communicate the product.



Preferred structure:



```text

SoundMesh



Make your phones

one speaker.



\[ Create Room ]



&#x20;     Join Room



Recent Rooms

```



The user should understand the app within seconds.



\---



\# 30. Home Screen Primary Action



\*\*Create Room\*\* is the primary action.



It should receive:



\* strongest contrast

\* largest action surface

\* primary blue treatment



\---



\# 31. Home Screen Secondary Action



\*\*Join Room\*\* is secondary.



It should remain visually obvious but less dominant.



Preferred treatment:



\* text button

\* outlined button

\* secondary surface



Do not make Create Room and Join Room visually identical.



\---



\# 32. Create Room Flow



Flow:



```text

Home

&#x20;↓

Create Room

&#x20;↓

Room creation

&#x20;↓

Room screen

```



The room should be created quickly.



Avoid unnecessary configuration before creation.



\---



\# 33. Room Naming



Optional room naming can exist.



Default names may be generated.



Example:



```text

Faraz's Room

```



or:



```text

SoundMesh Room

```



The user should not be forced to name the room before starting.



\---



\# 34. QR Joining



QR joining is the preferred MVP onboarding mechanism.



The host can display:



```text

Show QR Code

```



A participant scans it.



The participant should not need to manually understand:



\* IP addresses

\* ports

\* network protocols

\* tokens

\* host addresses



\---



\# 35. QR Screen



The QR screen should include:



```text

Join this room



\[ QR CODE ]



Room name

Faraz's Room



Waiting for devices...

```



The QR itself should have sufficient contrast and quiet space.



Do not decorate the QR code in a way that compromises scanning reliability.



\---



\# 36. Join Screen



Preferred:



```text

Join a Room



\[ Scan QR Code ]



──────── OR ────────



Enter Room Code



\[ \_\_\_\_\_\_\_\_\_ ]



\[ Join ]

```



QR scanning is primary.



Manual joining is a fallback.



\---



\# 37. Camera Permission



Permission requests must be contextual.



Do not request camera access immediately on app launch.



Request it when the user explicitly chooses:



\*\*Scan QR Code\*\*



The permission explanation should clearly communicate why the camera is needed.



\---



\# 38. Room Screen



The room screen is the central SoundMesh experience.



It must communicate:



1\. room identity

2\. connected device count

3\. current audio

4\. synchronization state

5\. primary playback action

6\. device health



\---



\# 39. Room Visualization



The room visualization should show connected devices as nodes.



Example:



```text

&#x20;          ●

&#x20;       ╱     ╲

&#x20;     ●         ●

&#x20;       ╲     ╱

&#x20;          ●

```



Each node may contain a minimal device representation.



Do not turn the visualization into a complicated graph.



\---



\# 40. Mesh Animation



When devices connect:



\* node appears

\* connection line forms

\* status changes



When synchronization occurs:



\* subtle coordinated pulse

\* connection lines may briefly animate



When playing:



\* subtle low-frequency visual activity



Animation must never distract from playback controls.



\---



\# 41. Device Count



Use plain language.



Preferred:



> \*\*5 devices connected\*\*



Not:



> `NODES: 5`



unless inside diagnostics.



\---



\# 42. Device Status



Preferred states:



```text

Connecting…

Calibrating…

Ready

Synchronized

Degraded

Disconnected

Recovering…

```



Do not expose raw internal state-machine names to normal users.



\---



\# 43. Device List



Example:



```text

Devices



● Faraz's Phone

&#x20; Synchronized



● Mahin's Phone

&#x20; Synchronized



● Galaxy A52

&#x20; Calibrating…



● Pixel

&#x20; Connection lost

```



Each device should be individually identifiable.



\---



\# 44. Device Status Semantics



\### Synchronized



The device is within the application's acceptable synchronization threshold.



\### Calibrating



The system is actively measuring or preparing timing.



\### Degraded



The device is connected but synchronization confidence or quality has fallen.



\### Disconnected



The active connection is unavailable.



\### Recovering



The application is attempting to restore synchronization.



\---



\# 45. Audio Selection



The audio picker should be deliberately simple.



Preferred:



```text

Choose Audio



\[ + Add Audio ]



Recently Used



song.mp3

recording.m4a

track.wav

```



Do not attempt to recreate Spotify.



SoundMesh is a synchronized playback system, not a music-streaming service.



\---



\# 46. Audio Transfer UX



When an audio file is being distributed:



```text

Preparing audio…



Sending to 4 devices



████████████░░░



3 of 5 ready

```



The UI should communicate progress without exposing implementation details.



Avoid:



> TCP transfer chunk 184/512



\---



\# 47. Audio Preparation



The user-facing state should be:



> \*\*Preparing everyone…\*\*



rather than:



> Decoding PCM buffers.



\---



\# 48. Synchronization UX



Synchronization should be visible but understandable.



Preferred:



```text

Getting everyone in sync…



● ● ● ● ●



Calibrating 5 devices

```



Then:



```text

✓ Everyone is ready

```



The user should feel that SoundMesh is actively making the system reliable.



\---



\# 49. Synchronization Confidence



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



\---



\# 50. Preparation Barrier



Playback should not begin until required participants have reached the appropriate readiness state.



The interface should make this explicit:



```text

3 of 5 devices ready

```



If the room requires all devices:



```text

Waiting for 2 devices…

```



If SoundMesh supports degraded playback later, the user must be informed before proceeding.



\---



\# 51. Primary Play Action



The play action should be visually dominant once the room is ready.



Preferred:



```text

&#x20;       ▶

```



or a large labeled action:



```text

\[ Play Together ]

```



The first implementation should favor clarity over cleverness.



\---



\# 52. Playback Screen



Preferred structure:



```text

Now Playing



&#x20;       Artwork / Audio Icon



Track Name

Artist / Source



━━━━━━━━━━━━━━━

1:32             3:47



● 5 devices synchronized



&#x20;       ⏮   ▶   ⏭

```



Controls should remain minimal.



\---



\# 53. Playback Progress



Progress must be:



\* visually clear

\* easy to interact with

\* sufficiently large

\* accessible



The displayed time should update smoothly.



Do not update visible text at unnecessarily high frequencies.



\---



\# 54. Playback Controls



MVP controls:



\* play

\* pause

\* seek

\* stop/end room

\* volume



Potential later controls:



\* previous

\* next

\* queue



Do not implement features simply because standard music apps contain them.



\---



\# 55. Volume



Master volume should be the primary volume control.



Per-device volume is an advanced capability.



The normal experience should not force users to manage five separate volume sliders.



\---



\# 56. Device Volume



If implemented:



```text

Device Volumes



Faraz        ━━━━━━━●

Mahin        ━━━━━━●━

Phone 3      ━━━━━━━●

Phone 4      ━━━━━●━━

```



It should live behind a secondary control.



\---



\# 57. Pause



When the host pauses:



1\. playback pauses according to the synchronization system

2\. room state becomes paused

3\. UI reflects paused state

4\. participants remain connected



The UI should not imply that the devices independently paused at unrelated times.



\---



\# 58. Resume



Resume should use scheduled synchronization rather than an immediate “play now” action.



User experience:



> \*\*Resuming…\*\*



followed by:



> \*\*Playing\*\*



if preparation is required.



\---



\# 59. Seek



Seeking is a coordinated operation.



The UI should:



1\. temporarily indicate seeking

2\. coordinate the new playback position

3\. resynchronize if necessary

4\. resume coordinated playback



Avoid showing an apparent normal playback state while devices are actually resynchronizing.



\---



\# 60. Stop / End Room



Stopping playback and ending the room are different actions.



Preferred:



```text

Stop Playback

```



does not necessarily destroy the room.



```text

End Room

```



closes the active session.



\---



\# 61. Connection Loss



If a participant disconnects:



Normal UI:



```text

1 device disconnected



Playback continues.

```



if the system can safely continue.



Otherwise:



```text

A device lost connection.



Reconnecting…

```



Do not immediately expose technical errors.



\---



\# 62. Host Failure



MVP behavior may be controlled recovery rather than seamless host migration.



If host failure occurs:



```text

Room connection lost.



The host device is unavailable.



\[ Return Home ]

```



If future host migration exists, this document must be updated.



\---



\# 63. Error Philosophy



Errors must answer:



1\. What happened?

2\. Does it matter?

3\. What can the user do?



Example:



> \*\*Couldn't connect to this device.\*\*

> Make sure both phones are on the same network.



```text

\[ Try Again ]

```



Avoid:



> `NETWORK\_HANDSHAKE\_TIMEOUT\_1042`



in the normal UI.



\---



\# 64. Technical Error Details



Advanced users may access diagnostics.



Example:



```text

Connection failed



Code:

NET\_HANDSHAKE\_TIMEOUT



Retry count:

3



RTT:

—



Transport:

TCP

```



This is useful for development and debugging without polluting normal UX.



\---



\# 65. Diagnostics



Diagnostics should be accessible but not central.



Potential diagnostic information:



\* device ID

\* connection state

\* RTT

\* clock offset

\* estimated sync error

\* calibration confidence

\* packet/connection statistics

\* audio buffer status

\* playback position

\* drift rate

\* recovery events



\---



\# 66. Diagnostic Visual Hierarchy



Diagnostics should prioritize:



```text

Health

&#x20;↓

Synchronization

&#x20;↓

Networking

&#x20;↓

Audio

&#x20;↓

Raw technical data

```



The user should not need to interpret raw logs.



\---



\# 67. Status Indicators



Status indicators must use:



\* icon/shape

\* text

\* color



not color alone.



Example:



```text

● Synchronized

```



rather than:



```text

●

```



\---



\# 68. Accessibility



Accessibility is REQUIRED.



The application must consider:



\* contrast

\* dynamic text sizing

\* screen readers

\* touch targets

\* reduced motion

\* non-color status communication

\* accessible labels

\* focus behavior

\* readable error messages



\---



\# 69. Dynamic Text



Layouts must tolerate increased system font sizes.



Text must not:



\* overlap

\* disappear

\* clip important information

\* become unreadable

\* force controls off-screen without a usable alternative



\---



\# 70. Screen Reader Semantics



Important controls require descriptive labels.



Examples:



```text

Create Room

Join Room

Scan QR Code

Show Room QR Code

Play

Pause

Seek

Volume

Device status

Open Diagnostics

End Room

```



A mesh visualization should have an accessible summary.



Example:



> “Five devices connected. Four synchronized. One calibrating.”



\---



\# 71. Reduced Motion



When reduced-motion preferences are enabled:



\* disable unnecessary mesh animation

\* reduce transition movement

\* remove decorative pulsing

\* preserve state communication through static visuals



Functionality must remain identical.



\---



\# 72. Animation Philosophy



Animations communicate state.



They do not exist merely because animation is possible.



Every animation should answer:



> “What changed?”



If an animation communicates nothing, remove it.



\---



\# 73. Animation Duration



Suggested ranges:



```text

Micro interaction: 100–150 ms

Normal transition: 150–250 ms

Major transition: 250–350 ms

```



Avoid unnecessarily slow UI.



SoundMesh should feel responsive.



\---



\# 74. Easing



Use platform-appropriate easing curves.



Avoid:



\* excessive bounce

\* elastic effects

\* dramatic overshoot



SoundMesh is not intended to feel like an arcade interface.



\---



\# 75. Mesh Animation Timing



Mesh animations should be:



\* slow

\* subtle

\* coordinated

\* low amplitude



The mesh should never visually imply that audio is synchronized more precisely than the actual system can guarantee.



\---



\# 76. Loading States



Never show an empty screen while waiting for asynchronous work.



Use meaningful states.



Examples:



```text

Connecting…

```



```text

Preparing audio…

```



```text

Calibrating devices…

```



```text

Reconnecting…

```



\---



\# 77. Skeleton Loading



Skeleton loading is optional.



It should only be used where content structure is known.



For short operations, a simple progress indicator with clear text is preferable.



\---



\# 78. Empty States



Empty states should be useful.



Example:



```text

No rooms yet



Create a room to turn nearby phones

into one synchronized speaker.



\[ Create Room ]

```



Avoid empty states containing only:



> Nothing here.



\---



\# 79. Permission UX



Permissions should be requested only when necessary.



Examples:



Camera permission:



> SoundMesh uses your camera to scan a room QR code.



Local network permission:



> SoundMesh needs access to your local network to connect nearby devices.



The application should never request all permissions during initial launch.



\---



\# 80. Onboarding



The MVP should avoid a long onboarding carousel.



The product's value proposition is simple enough to communicate through the first screen.



Preferred:



```text

SoundMesh



Make your phones

one speaker.



\[ Create Room ]



Join Room

```



Optional first-run explanation:



> Connect nearby phones and play audio together.



\---



\# 81. First Successful Session



The first successful session is the most important onboarding experience.



Target flow:



```text

Open

&#x20;↓

Create Room

&#x20;↓

Friend scans QR

&#x20;↓

Audio selected

&#x20;↓

Preparing

&#x20;↓

Calibrating

&#x20;↓

Everyone ready

&#x20;↓

Play

```



The application should feel progressively more impressive as the technical system activates.



\---



\# 82. Feedback During Technical Operations



Each technical operation should have visible user-facing feedback.



Examples:



```text

Connecting…

```



```text

Connected

```



```text

Preparing audio…

```



```text

Calibrating…

```



```text

Ready

```



```text

Playing

```



```text

Recovering…

```



\---



\# 83. State Truthfulness



The UI must represent actual system state.



Do not display:



> Synchronized



before synchronization has actually succeeded.



Do not display:



> Playing



when the native audio engine has not started.



Do not display:



> Connected



when the connection is only being attempted.



UI state must derive from authoritative application/native state.



\---



\# 84. Optimistic UI



Optimistic UI should be used cautiously.



Actions that can affect synchronization must not falsely imply success.



For example:



Pressing Play may immediately change the button appearance, but the room status should not claim successful synchronized playback until the playback system confirms the appropriate state.



\---



\# 85. Responsive Design



The UI must adapt to different:



\* screen sizes

\* aspect ratios

\* safe areas

\* font sizes

\* orientation states



Do not hardcode layouts around a single phone.



\---



\# 86. Safe Areas



Content must respect:



\* status bar

\* camera cutouts

\* navigation areas

\* gesture areas

\* rounded display corners



The application must use platform-safe-area mechanisms.



\---



\# 87. Landscape



Portrait is the primary orientation for the MVP.



Landscape should be considered for:



\* playback

\* tablets

\* future expanded layouts



No core feature should become unusable if the platform permits orientation changes.



\---



\# 88. Large Screens



If the application runs on larger screens:



\* increase content width

\* preserve comfortable reading width

\* optionally use two-column layouts

\* avoid stretching cards across the entire screen



The interface should feel intentionally designed rather than like a stretched phone screen.



\---



\# 89. UI Component Architecture



Reusable components should be created for:



```text

PrimaryButton

SecondaryButton

IconButton

TextButton

Card

StatusBadge

DeviceRow

DeviceStatus

ProgressBar

VolumeControl

PlaybackControls

RoomMesh

Dialog

BottomSheet

Toast/Snackbar

ErrorState

EmptyState

LoadingState

```



Components should derive visual values from centralized design tokens.



\---



\# 90. Design Tokens



Colors, typography, spacing, radii and dimensions must be centralized.



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



Do not scatter raw hex values throughout the application.



\---



\# 91. Tokenized Typography



Typography should similarly be centralized:



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



\---



\# 92. Tokenized Spacing



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



\---



\# 93. Platform Conventions



SoundMesh should respect platform conventions where doing so does not conflict with the product identity.



Examples:



\* system permission dialogs

\* navigation gestures

\* accessibility behavior

\* keyboard behavior

\* native pickers

\* native sharing

\* camera permissions



Do not recreate platform permission dialogs.



\---



\# 94. Flutter UI Boundary



Flutter should own:



\* visual UI

\* navigation

\* user interaction

\* high-level room state presentation

\* design system

\* accessibility semantics where supported

\* animations that do not require realtime audio timing



Native code should own timing-critical operations.



This follows the architecture defined in `architecture.md` and `audio.md`.



\---



\# 95. Realtime UI Constraint



High-frequency synchronization or audio callbacks must not continuously drive Flutter widget rebuilds.



Instead:



```text

Native realtime system

&#x20;       ↓

Aggregated state

&#x20;       ↓

Flutter

&#x20;       ↓

UI

```



The UI should display meaningful updates rather than every internal timing event.



\---



\# 96. Playback UI Update Frequency



Playback progress should feel smooth without unnecessarily rebuilding the entire screen.



Only the relevant playback components should update.



Avoid rebuilding:



\* device lists

\* room visualization

\* navigation

\* static content



for every playback-position update.



\---



\# 97. Mesh Performance



The mesh visualization must remain lightweight.



Avoid:



\* excessive particle systems

\* continuous expensive blur

\* large GPU-heavy effects

\* unnecessary redraws

\* dozens of animated widgets per device



The visualization should work comfortably on lower-end supported devices.



\---



\# 98. Battery Awareness



Visual animation must not unnecessarily consume battery.



When:



\* the screen is inactive

\* the room is stable

\* the application is backgrounded where permitted



decorative animations should reduce or stop.



Synchronization and playback requirements take priority over visual effects.



\---



\# 99. Audio-First UX



SoundMesh is fundamentally an audio application.



Visual effects must never compromise:



\* playback stability

\* synchronization

\* CPU budget

\* battery

\* responsiveness



If an animation conflicts with realtime audio performance, the animation loses.



\---



\# 100. Error Recovery UX



Recovery should be progressive.



Preferred hierarchy:



```text

Detect

&#x20;↓

Attempt automatic recovery

&#x20;↓

Inform user if needed

&#x20;↓

Retry

&#x20;↓

Request intervention only if necessary

```



Do not interrupt the user for every transient network problem.



\---



\# 101. Notifications / Snackbars



Use snackbars/toasts for:



\* non-critical temporary information

\* successful minor actions

\* recoverable warnings



Do not use them for critical state changes that the user needs to understand.



Critical errors should be persistent enough to be noticed.



\---



\# 102. Dialogs



Dialogs should be reserved for:



\* destructive actions

\* permission explanations where applicable

\* important decisions

\* critical errors



Do not turn every action into a confirmation dialog.



\---



\# 103. Destructive Actions



Ending a room may require confirmation if it would unexpectedly disconnect participants.



Example:



> \*\*End this room?\*\*

> Playback will stop for all connected devices.



```text

Cancel

End Room

```



\---



\# 104. Room Lifecycle UX



Map technical room states into human-readable UI:



```text

CREATED

→ Creating room…



DISCOVERABLE

→ Waiting for devices…



JOINING

→ Connecting…



CALIBRATING

→ Getting everyone in sync…



READY

→ Everyone is ready



PLAYING

→ Playing



PAUSED

→ Paused



RECOVERING

→ Recovering connection…



ENDING

→ Ending room…



CLOSED

→ Room ended

```



Never expose internal enum names in production UI.



\---



\# 105. Sync Quality Presentation



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



\---



\# 106. No False Precision



Normal UI should not display:



```text

Synchronization: 98.371%

```



unless that metric has a clearly defined meaning.



SoundMesh should not manufacture precision simply to appear technical.



Advanced diagnostics may display measured values with appropriate uncertainty.



\---



\# 107. Premium Feel Through Restraint



The premium appearance must come primarily from:



\* consistent spacing

\* excellent typography

\* controlled color

\* visual hierarchy

\* smooth transitions

\* correct alignment

\* intentional whitespace

\* stable component behavior



Not from:



\* gradients everywhere

\* glassmorphism everywhere

\* huge shadows

\* neon effects

\* excessive animation



\---



\# 108. Glassmorphism



Glassmorphism is NOT the default design language.



Blurred translucent surfaces may be used selectively if platform performance and readability permit them.



The base design must remain attractive without blur.



\---



\# 109. Shadows



Shadows must be:



\* subtle

\* soft

\* low opacity

\* used primarily for separation



Avoid large black shadows on dark backgrounds.



Luminance separation is usually preferable.



\---



\# 110. Background Treatment



The primary background should remain mostly flat.



Optional extremely subtle tonal variation may be used around major areas.



Do not create animated backgrounds.



\---



\# 111. Brand Mark



The SoundMesh logo should be based conceptually on connected nodes/audio coordination.



It should work in:



\* app icon

\* splash screen

\* header

\* QR room presentation

\* GitHub/README branding



The logo must remain recognizable without color.



\---



\# 112. App Icon



The app icon should be:



\* simple

\* high contrast

\* recognizable at small sizes

\* based on the mesh concept

\* consistent with SoundMesh Blue and the dark identity



Avoid putting text inside the app icon.



\---



\# 113. Splash Screen



Keep it minimal.



Preferred:



```text

SoundMesh

```



with the logo/mesh mark.



Do not create a long animated splash sequence.



The application should enter the usable interface as quickly as possible.



\---



\# 114. Interaction Priority



When multiple actions are available, hierarchy should follow:



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



Never allow settings or diagnostics to visually compete with the main playback action.



\---



\# 115. User Flow — MVP



Complete intended MVP flow:



```text

Launch

&#x20;↓

Home

&#x20;↓

Create Room

&#x20;↓

Room Created

&#x20;↓

Show QR

&#x20;↓

Participant Scans

&#x20;↓

Connection

&#x20;↓

Device Identified

&#x20;↓

Audio Selected

&#x20;↓

Audio Prepared

&#x20;↓

Synchronization

&#x20;↓

Ready

&#x20;↓

Play

&#x20;↓

Playback Monitoring

&#x20;↓

Pause / Seek / Resume

&#x20;↓

Stop

&#x20;↓

End Room

```



\---



\# 116. Join Flow — MVP



```text

Home

&#x20;↓

Join Room

&#x20;↓

Scan QR

&#x20;↓

Request Camera Permission if necessary

&#x20;↓

QR Validated

&#x20;↓

Connect

&#x20;↓

Join Handshake

&#x20;↓

Device Name

&#x20;↓

Audio Preparation

&#x20;↓

Calibration

&#x20;↓

Ready

```



The user should never see IP addresses or protocol details during this flow.



\---



\# 117. Design States Required for Every Major Component



Every important component should consider:



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



Not every component needs every state visually, but state behavior must be deliberately defined.



\---



\# 118. Button States



Primary button:



```text

Default → Accent

Pressed → Accent Dark

Disabled → Muted surface/text

Loading → Accent + progress indicator

```



Text and icon contrast must remain accessible.



\---



\# 119. Inputs



Inputs should clearly distinguish:



```text

Default

Focused

Filled

Error

Disabled

```



Focus should use the SoundMesh accent while preserving sufficient contrast.



Error state should include textual explanation.



\---



\# 120. QR Scanner UX



Scanner should:



\* open quickly

\* clearly show scan region

\* provide camera permission handling

\* indicate successful detection

\* handle invalid QR codes gracefully



Invalid QR:



> \*\*That isn't a SoundMesh room code.\*\*



Do not expose parsing errors.



\---



\# 121. Offline Philosophy



The UI should never imply Internet dependency for normal local playback.



If the device has no Internet but the local network works:



> SoundMesh should continue to communicate locally.



Internet availability should not be presented as a prerequisite unless a future feature requires it.



\---



\# 122. Network Problem UX



If devices are not reachable:



> \*\*Couldn't find the room.\*\*



Supporting explanation:



> Make sure the devices are connected to the same local network.



The interface should guide the user toward the actual likely cause.



\---



\# 123. First-Time Network Permission



If local-network permission is required, explain it in context.



Do not display:



> Enable NSLocalNetworkUsageDescription.



Display:



> SoundMesh needs local network access to connect nearby phones.



\---



\# 124. Device Naming



Use human-readable names.



Examples:



```text

Faraz's Phone

Mahin's Phone

Galaxy A52

iPhone

```



Technical identifiers should remain hidden except in diagnostics.



\---



\# 125. Device Identity



Device names are presentation identity.



They are not authentication identity.



The UI must not imply that a device name is a unique security credential.



\---



\# 126. Security UX



The normal interface should not expose security implementation details.



Room joining should feel effortless.



If a join request requires host approval in a future version:



```text

Mahin wants to join



\[ Allow ]

\[ Deny ]

```



Security should be understandable without exposing protocol mechanics.



\---



\# 127. Room Privacy



Do not show permanent room credentials in normal UI.



QR codes should represent temporary join information according to the networking specification.



\---



\# 128. Loading Progress



Progress indicators should reflect real progress when measurable.



If progress cannot be accurately measured, use an indeterminate indicator.



Never fake progress merely to make an operation appear faster.



\---



\# 129. Time Perception



The UI should provide feedback immediately after a user action.



Even if the underlying operation takes several seconds, the interface should transition quickly into a meaningful state such as:



> Preparing…



This prevents the application from appearing frozen.



\---



\# 130. Microcopy Rules



Use:



\* short sentences

\* human language

\* active voice

\* clear verbs

\* minimal technical terminology



Preferred:



> Getting everyone in sync…



Avoid:



> Synchronization subsystem initialization in progress.



Preferred:



> Couldn't connect to this device.



Avoid:



> Connection establishment procedure failed.



\---



\# 131. Capitalization



Use sentence case for most UI.



Preferred:



> Create Room



or:



> Create a room



Do not use unnecessary ALL CAPS.



Uppercase may be used for tiny diagnostic labels if visually justified.



\---



\# 132. Punctuation



UI labels generally should not end with periods.



Full explanatory sentences may use punctuation.



Examples:



```text

Create Room

```



but:



> Make sure both devices are connected to the same network.



\---



\# 133. Accessibility Language



Avoid ambiguous instructions.



Bad:



> Try again.



Better:



> Try connecting again.



Best where context is needed:



> Make sure both phones are on the same network, then try connecting again.



\---



\# 134. Visual Hierarchy of the Room



The room screen should prioritize:



```text

1\. Playback state

2\. Primary playback action

3\. Device health

4\. Room identity

5\. Secondary controls

6\. Diagnostics

```



\---



\# 135. Visual Hierarchy of Home



```text

1\. SoundMesh identity

2\. Core value proposition

3\. Create Room

4\. Join Room

5\. Recent rooms

6\. Settings/about

```



\---



\# 136. Visual Hierarchy of Diagnostics



```text

1\. Overall health

2\. Sync quality

3\. Device states

4\. Network

5\. Audio

6\. Detailed measurements

```



\---



\# 137. Design Anti-Patterns



AI agents and developers MUST NOT introduce the following without an explicit decision:



\* random gradients

\* neon backgrounds

\* excessive glassmorphism

\* excessive rounded cards

\* giant text everywhere

\* emoji as primary UI icons

\* arbitrary colors

\* inconsistent corner radii

\* arbitrary spacing

\* multiple competing accent colors

\* excessive animations

\* permanent bottom navigation

\* unnecessary onboarding

\* fake loading progress

\* fake synchronization metrics

\* technical jargon in primary UI

\* raw error codes in normal UI

\* IP addresses in normal onboarding

\* configuration-heavy first-run flow



\---



\# 138. Design Decision: Blue Identity



The primary SoundMesh brand color is:



```text

\#5B8CFF

```



This is a deliberate product decision.



Do not replace it with:



\* purple

\* cyan

\* green

\* red

\* arbitrary gradients



without updating the design decision documentation.



\---



\# 139. Design Decision: Dark-First



SoundMesh MVP is dark-first.



Primary experience:



```text

\#0B0D10

```



A future light theme may be considered separately.



Developers must not automatically create a light theme during MVP unless required by platform behavior or explicitly requested.



\---



\# 140. Design Decision: Minimal Navigation



The MVP does not require a permanent multi-tab navigation system.



The application is primarily a flow:



```text

Home → Room → Playback

```



\---



\# 141. Design Decision: Diagnostics Are Secondary



Diagnostics are important for development and advanced users but must not dominate normal UX.



SoundMesh should be approachable to someone who knows nothing about networking or synchronization.



\---



\# 142. Design Decision: Technical Complexity Is Hidden



The interface must not require users to understand:



\* clock synchronization

\* network latency

\* buffering

\* audio decoding

\* drift

\* transport protocols

\* device clocks

\* calibration algorithms



unless they intentionally enter diagnostics.



\---



\# 143. Design Decision: Mesh Is the Visual Language



The connected-device mesh is SoundMesh's primary visual metaphor.



It should appear in:



\* room visualization

\* connection states

\* synchronization states

\* potentially branding



but should not become repetitive decoration on every screen.



\---



\# 144. Design Decision: No Spotify Clone



SoundMesh should not attempt to become a music streaming platform.



Audio selection should remain intentionally simple.



\---



\# 145. Design Decision: Performance Before Visual Effects



If a visual effect causes:



\* dropped frames

\* excessive GPU usage

\* increased battery drain

\* audio instability

\* synchronization problems



remove or simplify the effect.



Functional reliability always outranks visual spectacle.



\---



\# 146. UI/UX Acceptance Criteria



The MVP UI is acceptable only when:



\### Navigation



\* user can create a room without unnecessary configuration

\* user can join using QR

\* navigation is predictable

\* back behavior is correct



\### Visual



\* all colors come from centralized tokens

\* typography uses the documented scale

\* spacing follows the spacing system

\* no arbitrary decorative colors exist

\* primary accent is consistently SoundMesh Blue



\### Room



\* room identity is obvious

\* device count is visible

\* device status is understandable

\* synchronization state is visible

\* primary playback action is obvious



\### Playback



\* play/pause state is truthful

\* playback progress is understandable

\* volume is accessible

\* synchronized playback state is visible



\### Errors



\* errors are human-readable

\* recovery actions are provided where possible

\* raw technical details remain secondary



\### Accessibility



\* important text has adequate contrast

\* touch targets are sufficiently large

\* statuses are not communicated by color alone

\* screen-reader labels exist for important controls

\* increased text sizes do not destroy the layout

\* reduced motion is respected



\### Performance



\* animations do not interfere with audio

\* mesh visualization remains lightweight

\* unnecessary rebuilds are avoided

\* playback remains the highest performance priority



\---



\# 147. UI/UX Verification



UI implementation should be tested on:



\* at least one low-end Android device

\* at least one modern Android device

\* at least one iPhone

\* different screen sizes

\* different text-size settings

\* reduced-motion settings where available

\* portrait orientation

\* network failure states

\* device disconnection

\* synchronization recovery

\* audio preparation failure

\* permission denial



\---



\# 148. Visual QA Checklist



Before a UI feature is considered complete:



```text

\[ ] Correct background

\[ ] Correct surface hierarchy

\[ ] Correct typography

\[ ] Correct spacing

\[ ] Correct corner radius

\[ ] Correct iconography

\[ ] Correct button states

\[ ] Correct loading state

\[ ] Correct error state

\[ ] Correct accessibility labels

\[ ] Correct contrast

\[ ] Correct safe-area handling

\[ ] Correct dynamic text behavior

\[ ] Correct reduced-motion behavior

\[ ] No arbitrary colors

\[ ] No arbitrary spacing

\[ ] No unnecessary animation

\[ ] No technical jargon in primary UX

```



\---



\# 149. Relationship to Other Specifications



This document does not define:



\* synchronization algorithms

\* networking protocols

\* audio engine implementation

\* native timing architecture



Those are defined by:



```text

DOCS/synchronization.md

DOCS/networking.md

DOCS/audio.md

DOCS/architecture.md

```



This document defines how those systems are \*\*experienced and represented by the user\*\*.



\---



\# 150. Cross-System Rule



The UI must never contradict the underlying engineering state.



For example:



```text

Networking says:

DISCONNECTED



UI:

Synchronized

```



is invalid.



Similarly:



```text

Audio engine says:

NOT\_PLAYING



UI:

Playing

```



is invalid.



The UI is a representation of actual system state, not an independent simulation.



\---



\# 151. MVP Screen Inventory



The initial application should contain approximately these primary screens/states:



```text

1\. Home

2\. Create Room

3\. Room — Waiting

4\. Room — Devices

5\. QR Display

6\. Join Room

7\. QR Scanner

8\. Preparing Audio

9\. Synchronizing

10\. Ready

11\. Playback

12\. Device Details

13\. Diagnostics

14\. Settings

15\. Error/Recovery States

```



Some of these should be implemented as states within a screen rather than completely separate routes where appropriate.



\---



\# 152. Preferred Core Experience



The ideal SoundMesh session should feel like:



```text

OPEN



SoundMesh



Make your phones one speaker.



&#x20;       Create Room



&#x20;         Join Room





CREATE



Room created.



&#x20;       ◉

&#x20;     /   \\

&#x20;   📱     📱

&#x20;     \\   /

&#x20;       📱



Waiting for devices…





JOIN



Scan the QR.



&#x20;       \[ QR ]





PREPARE



Preparing audio…



3 of 5 devices ready.





SYNC



Getting everyone in sync…



● ● ● ● ●



Calibrating…





READY



✓ Everyone is ready.



&#x20;       ▶ Play





PLAY



Now Playing



Track Name



━━━━━━━━━━━━●━━



● 5 devices synchronized





RECOVER



One device disconnected.



Reconnecting…





END



End Room?

```



The user experience should be this simple even though the engineering beneath it is highly sophisticated.



\---



\# 153. Ultimate Design Principle



SoundMesh should create a deliberate contrast:



\### Under the hood



```text

Distributed systems

Clock synchronization

Network measurement

Audio scheduling

Latency estimation

Drift correction

Recovery algorithms

Native audio engines

```



\### On the screen



```text

Create

Join

Choose

Play

```



That contrast is fundamental to the product.



The engineering should be impressive.



The interface should make it feel effortless.



\---



\# 154. Final UI/UX Principle



> \*\*SoundMesh should feel like the complexity disappeared.\*\*



A user should never think:



> “How are these phones synchronizing?”



They should think:



> \*\*“Holy shit, they're all playing together.”\*\*



That moment is the product.



The interface exists to get the user to that moment as quickly, clearly, reliably, and beautifully as possible.



\---



\# 155. Definition of Done



`ui-ux.md` is considered implemented when:



\* the documented color system is centralized

\* typography is centralized

\* spacing is tokenized

\* major screens follow the specified hierarchy

\* room/device states have explicit UI representations

\* synchronization states have clear user-facing language

\* playback controls are implemented

\* error and recovery states exist

\* accessibility requirements are addressed

\* responsive behavior is implemented

\* animations are purposeful and lightweight

\* technical state is accurately represented

\* no major UI decisions are left to arbitrary implementation preference



\*\*Source of truth:\*\* This document governs SoundMesh's visual and interaction design unless superseded by an explicit documented decision.



