# Mahin UI Forensic Recovery Plan

## Executive Summary

Recover **all** of Mahin's UI/UX work from `origin/mahin-foundation` (commit `44aa84d`) and integrate it with the current Faraz backend architecture (`faraz-foundation`). The final app = Mahin's visual design + Faraz's backend providers.

**Key Principle**: Mahin's original UI is the visual source of truth. If current screen differs, recover Mahin's version and adapt the integration layer only.

---

## Forensic Audit Results

### What Mahin Built (Complete Inventory)

| Category | Files | Status in Current |
|----------|-------|-------------------|
| **Design System** | `colors.dart`, `typography.dart`, `spacing.dart`, `elevation.dart`, `animation.dart`, `theme.dart` | Partially recovered (simplified) |
| **Components** | `button.dart`, `surface.dart`, `text_input.dart`, `loading_indicator.dart`, `empty_state.dart`, `icon_wrapper.dart`, `debug_state_controls.dart` | Partially recovered (different APIs) |
| **Screens** | `home_screen.dart`, `create_room_screen.dart`, `join_room_screen.dart`, `qr_scan_screen.dart` | **Significantly different** |
| **Room Shell** | `room_shell.dart` (ShellRoute + NavigationBar) | Exists but broken (no ShellRoute) |
| **Room Screens** | `room_dashboard_screen.dart`, `room_devices_screen.dart`, `room_playback_screen.dart`, `room_preparation_screen.dart`, `room_diagnostics_screen.dart` | Partially recovered (have AppBars, no persistent shell) |
| **Router** | GoRouter with ShellRoute + page transitions | Simple MaterialPageRoute |

### Critical Losses

1. **Create Room**: Current uses AppBar + IP:port display; Mahin's uses no AppBar, shows join code, proper state machine (idle/creating/roomReady/error)
2. **Join Room**: Current uses IP+port fields; Mahin's uses 6-digit code + QR scan card
3. **Room Bottom Nav**: Current RoomShell is a component wrapped in each screen's Scaffold → bottom nav **rebuilds on every tab switch**. Mahin's used GoRouter ShellRoute → persistent shell
4. **Room Screens**: Current screens have individual AppBars; Mahin's screens are ShellRoute children (no AppBar, Shell provides it)
6. **Design System**: Mahin's has surface ladder, disabled states, input decoration theme, navigation bar theme, proper elevation system

---

## Recovery Strategy

### Architecture Decision: Keep Current Router (No GoRouter)

Per AGENTS.md: *"Do NOT introduce GoRouter... Adapt the shell to the current router architecture."*

**Solution**: Implement RoomShell as a single `StatefulWidget` with `IndexedStack` for tab content. The shell owns the Scaffold, AppBar, and bottom NavigationBar. Tab screens become stateless content widgets (no Scaffold, no AppBar).

### State Mapping: Mahin SMAppState → Current Providers

| Mahin State | Current Provider Mapping |
|-------------|--------------------------|
| `idle` | `CreateRoomFlowStatus.idle` / `JoinRoomFlowStatus.idle` |
| `creatingRoom` | `CreateRoomFlowStatus.creating` / `hosting` / `listening` |
| `joiningRoom` | `JoinRoomFlowStatus.connecting` / `handshaking` |
| `roomReady` | `CreateRoomFlowStatus.ready` / `JoinRoomFlowStatus.ready` |
| `preparing` | `RoomLifecycleState.preparing` (syncState='preparing') |
| `ready` | `RoomLifecycleState.ready` + sync.synchronized |
| `playing` | `RoomLifecycleState.ready` + capture active |
| `paused` | `RoomLifecycleState.ready` + capture paused |
| `stopping` | `RoomLifecycleState.closed` (transitional) |
| `error` | `CreateRoomFlowStatus.failed` / `JoinRoomFlowStatus.failed` |

---

## Implementation Tasks

### Phase 1: Design System Recovery (Foundation)

**1.1 Replace `soundmesh_theme.dart` with Mahin's complete design system**
- Move to `app/lib/core/design_system/` (new location matching current architecture)
- Files: `colors.dart`, `typography.dart`, `spacing.dart`, `elevation.dart`, `animation.dart`, `theme.dart`, `index.dart`
- **Adapt**: Use current `SoundMeshColors` color values where they match, add Mahin's missing tokens (surface ladder, disabled states, outline variants, scrim, loading colors)
- **Preserve**: Geist font family, all spacing/radius/elevation/animation values exactly

**1.2 Update `pubspec.yaml` fonts**
- Ensure Geist fonts are registered (already present in assets/fonts/)

### Phase 2: Component Recovery

**2.1 `SMButton` → `SoundMeshButton`**
- Match Mahin's variants: `primary`, `secondary`, `danger`
- Match Mahin's filled treatments (secondary = surfaceContainer fill, danger = surfaceHigh fill)
- Match Mahin's loading indicator (circular with foreground color)
- Match Mahin's sizing (touchTarget 44, padding xl/md)
- **Adapt**: Use current theme color tokens

**2.2 `SMCard` → `SoundMeshSurface`**
- Match Mahin's surfaceLow background, outlineVariant border (alpha 0.2)
- Match Mahin's elevated flag → SMElevation.card shadow
- Match Mahin's padding (xxl default) and borderRadius (medium)
- **Adapt**: Keep current flexible API (backgroundColor, borderColor params)

**2.3 `SMTextField` → `SoundMeshTextField`**
- Match Mahin's InputDecorationTheme exactly (filled surfaceLow, borders, label/hint/error styles)
- Remove current Container wrapper; use Theme's InputDecorationTheme
- **Adapt**: Keep current controller/keyboardType params

**2.4 `SMLoadingIndicator` → `SoundMeshLoadingIndicator`**
- Match Mahin's size (loadingSize 24), strokeWidth (3), color (loadingActive = soundmeshBlue)
- **Adapt**: Keep current size parameter

**2.5 `SMEmptyState` → `SoundMeshEmptyState`**
- Match Mahin's icon sizing (emptyIconSize 48), spacing, typography
- Match Mahin's error/empty kind styling
- **Adapt**: Keep current constructor pattern

**2.6 `SMIcon` → `SoundMeshIconWrapper`**
- Match Mahin's touchTarget (44), radius (small=8), background handling
- Match Mahin's accent background → onAccent color logic
- **Adapt**: Keep current size parameter

**2.7 `DebugStateControls`** - Keep as inert placeholder (already correct)

### Phase 3: Screen Recovery

**3.1 HomeScreen**
- **Recover**: Mahin's layout exactly (brand container with elevatedSurface + shadow-2xl, title, tagline, buttons, DebugStateControls)
- **Remove**: AppBar, CustomScrollView/SliverFillRemaining
- **Integrate**: Buttons → `Navigator.pushNamed` to current routes
- **State**: No StateBuilder needed (home has no backend state)

**3.2 CreateRoomScreen**
- **Recover**: Mahin's complete state machine UI (idle form, creating loading, roomReady success with join code, error)
- **Remove**: AppBar, connection info card, IP:port display
- **Integrate**:
  - Idle form: "Create Room" button → `createRoomFlowProvider.createRoom()`
  - Creating: listen to `createRoomFlowProvider` status changes
  - RoomReady: show `flowState.roomId`/`sessionId` as join code, "Enter Room" → `Navigator.pushReplacementNamed(AppRouter.roomDashboard)`
  - Error: show `flowState.errorMessage`, retry → `createRoomFlowProvider.reset()`
  - Back button → `createRoomFlowProvider.reset()` + `Navigator.pop()`

**3.3 JoinRoomScreen**
- **Recover**: Mahin's layout (eyebrow "SOUNDMESH CONNECT", QR scan card, OR divider, 6-digit code field)
- **Remove**: AppBar, IP address + port fields
- **Integrate**:
  - QR scan card tap → `Navigator.pushNamed(AppRouter.qrScan)`
  - Code field: 6-digit input → `joinRoomFlowProvider.setHostIpAddress(code)` (repurpose) or add `setRoomCode`
  - Join button → `joinRoomFlowProvider.joinRoom()`
  - Loading states from `joinRoomFlowProvider` status
  - Ready state: show session info, "Enter Room" → `Navigator.pushReplacementNamed(AppRouter.roomDashboard)`
  - Error: show error, retry → `joinRoomFlowProvider.reset()`

**3.4 QRScanScreen**
- **Recover**: Mahin's placeholder UI (no AppBar, centered content, back to Join Room)
- **Adapt**: Keep current AppBar-less design

### Phase 4: Room Shell & Navigation (Critical)

**4.1 New RoomShell Implementation**
```dart
// app/lib/presentation/components/room_shell.dart
class RoomShell extends StatefulWidget {
  final Widget child; // IndexedStack of tab screens
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final PreferredSizeWidget? appBar; // Optional, for Room tab
}
```
- Single Scaffold with persistent bottom NavigationBar
- `IndexedStack` for 3 tabs (Room, Devices, Session) — preserves state
- Glassmorphism backdrop filter (blur 24) exactly per Mahin
- NavigationBarTheme matching Mahin: height 64, indicatorColor accent/0.2, pill indicator (radius full), icon/label colors
- Tabs: Room (surround_sound), Devices (router), Session (graphic_eq)

**4.2 Refactor Room Screens to Content Widgets**
- `RoomDashboardContent`, `RoomDevicesContent`, `RoomSessionContent` — **no Scaffold, no AppBar**
- Each consumes `roomLifecycleProvider` via `ConsumerWidget`
- Room tab: optional AppBar passed to RoomShell (for host address, actions)
- Devices/Session tabs: no AppBar (clean content)

**4.3 Router Updates**
- `AppRouter.roomDashboard` → `RoomShell` with `currentIndex=0`
- `AppRouter.roomDevices` → `RoomShell` with `currentIndex=1`
- `AppRouter.roomSession` → `RoomShell` with `currentIndex=2`
- All three routes return the **same RoomShell instance** with different `currentIndex`
- Use `Navigator.pushReplacementNamed` for tab switching (or better: single route with query param, but pushReplacementNamed works with current router)

**4.4 Remove Legacy `RoomScreen`** (chat-like screen) — not part of Mahin's design

### Phase 5: Room Content Screens Recovery

**5.1 RoomDashboardContent**
- **Recover**: Mahin's `_roomReadyContent`, `_readyContent`, `_sessionStatusContent`, `_preparingContent`, `_notInRoomContent`
- **Integrate**: Map `RoomLifecycleStateData` to Mahin's state logic
  - `lifecycleState.lifecycleState` → determines content
  - `lifecycleState.sync` → sync status card
  - `lifecycleState.role` → host/participant actions
- **Actions**:
  - Prepare button → `roomLifecycleProvider.prepare()`
  - Leave Room → `roomLifecycleProvider.leaveRoom()` + `Navigator.pushNamedAndRemoveUntil(home)`
  - QR button → `Navigator.pushNamed(AppRouter.qrScan)`

**5.2 RoomDevicesContent**
- **Recover**: Mahin's `_devicesContent`, `_preparingContent`, `_stoppingContent`
- **Integrate**: `lifecycleState.sync` for sync status, calibrate button → `roomLifecycleProvider.prepare()`
- **Back to Room** button → `Navigator.pushReplacementNamed(AppRouter.roomDashboard)` (switches tab via RoomShell)

**5.3 RoomSessionContent** (renamed from Playback per product rule)
- **Recover**: Mahin's `_buildSessionStatus`, `_buildSyncStatusCard`
- **Integrate**: `lifecycleState.lifecycleState` + `lifecycleState.sync`
- **NO media controls** — SoundMesh is not a media player

**5.4 RoomPreparationScreen**
- **Recover**: Mahin's preparation steps UI (_PreparationStep widget)
- **Integrate**: Currently placeholder; connect to real preparation flow when backend ready
- Use `RoomShell` (already done in current)

**5.5 DiagnosticsScreen**
- **Recover**: Mahin's diagnostic sections + confidence badges (Measured/Estimated/Unknown/Unavailable)
- **Integrate**: Keep current real data fetching (DeviceInfoRepository, TimingInfoRepository, capture state) — this is Faraz's backend work
- **UI**: Use Mahin's `_DiagnosticsSection`, `_DiagnosticRow`, `_ConfidenceBadge` components
- **Route**: Standalone (not in RoomShell), accessed from HomeScreen AppBar

### Phase 6: Integration & Validation

**6.1 Update Main App**
- Ensure `SoundMeshTheme.darkTheme` uses recovered design system
- Register all routes in `AppRouter`
- Remove unused `RoomScreen` and its provider

**6.2 Run Static Checks**
```powershell
flutter analyze
flutter test
flutter build apk --debug
```

**6.3 Runtime Validation (Real Device)**
- Home → Create Room → Room Shell (Room tab visible)
- Room tab → Devices tab → Session tab (bottom nav persists, state preserved)
- Join Room → Room Shell
- Back navigation works correctly
- No duplicate architectures (`lib/ui`, `lib/state`, `lib/core_adapter`, `lib/app` not restored)

---

## File Mapping Summary

| Mahin Original | Current Target | Action |
|----------------|----------------|--------|
| `lib/ui/theme/colors.dart` | `lib/core/design_system/colors.dart` | **Recover + adapt** |
| `lib/ui/theme/typography.dart` | `lib/core/design_system/typography.dart` | **Recover + adapt** |
| `lib/ui/theme/spacing.dart` | `lib/core/design_system/spacing.dart` | **Recover + adapt** |
| `lib/ui/theme/elevation.dart` | `lib/core/design_system/elevation.dart` | **Recover + adapt** |
| `lib/ui/theme/animation.dart` | `lib/core/design_system/animation.dart` | **Recover + adapt** |
| `lib/ui/theme/theme.dart` | `lib/core/design_system/theme.dart` | **Recover + adapt** |
| `lib/ui/components/button.dart` | `lib/presentation/components/soundmesh_button.dart` | **Recover + adapt** |
| `lib/ui/components/surface.dart` | `lib/presentation/components/soundmesh_surface.dart` | **Recover + adapt** |
| `lib/ui/components/text_input.dart` | `lib/presentation/components/soundmesh_text_field.dart` | **Recover + adapt** |
| `lib/ui/components/loading_indicator.dart` | `lib/presentation/components/soundmesh_loading_indicator.dart` | **Recover + adapt** |
| `lib/ui/components/empty_state.dart` | `lib/presentation/components/soundmesh_empty_state.dart` | **Recover + adapt** |
| `lib/ui/components/icon_wrapper.dart` | `lib/presentation/components/soundmesh_icon_wrapper.dart` | **Recover + adapt** |
| `lib/ui/screens/home_screen.dart` | `lib/presentation/screens/home_screen.dart` | **Recover + adapt** |
| `lib/ui/screens/create_room_screen.dart` | `lib/presentation/screens/create_room_screen.dart` | **Recover + adapt** |
| `lib/ui/screens/join_room_screen.dart` | `lib/presentation/screens/join_room_screen.dart` | **Recover + adapt** |
| `lib/ui/screens/qr_scan_screen.dart` | `lib/presentation/screens/qr_scan_screen.dart` | **Recover + adapt** |
| `lib/ui/screens/room/room_shell.dart` | `lib/presentation/components/room_shell.dart` | **Rewrite (IndexedStack)** |
| `lib/ui/screens/room/room_dashboard_screen.dart` | `lib/presentation/screens/room_dashboard_screen.dart` | **Recover as Content widget** |
| `lib/ui/screens/room/room_devices_screen.dart` | `lib/presentation/screens/room_devices_screen.dart` | **Recover as Content widget** |
| `lib/ui/screens/room/room_playback_screen.dart` | `lib/presentation/screens/room_session_screen.dart` | **Recover as Content widget** |
| `lib/ui/screens/room/room_preparation_screen.dart` | `lib/presentation/screens/room_preparation_screen.dart` | **Recover + adapt** |
| `lib/ui/screens/room/room_diagnostics_screen.dart` | `lib/presentation/screens/diagnostics_screen.dart` | **Merge: Mahin UI + Faraz data** |
| `lib/app/router.dart` | `lib/core/router/app_router.dart` | **Adapt routes for RoomShell** |

---

## Acceptance Criteria

### Visual Fidelity (Mahin's Design)
- [ ] HomeScreen: Brand container with elevatedSurface + shadow-2xl, no AppBar
- [ ] CreateRoomScreen: Join code display (not IP:port), no AppBar, proper state views
- [ ] JoinRoomScreen: 6-digit code field, QR scan card, eyebrow label, no AppBar
- [ ] RoomShell: Persistent bottom nav (Room/Devices/Session) with glassmorphism blur
- [ ] Room tabs: No individual AppBars (except Room tab optional host AppBar)
- [ ] Typography: Geist, exact sizes/weights/letter-spacing from Mahin
- [ ] Colors: Surface ladder, disabled states, outline variants, accent blue
- [ ] Spacing/Radii/Elevation: Exact Mahin values
- [ ] Animations: Page transitions (if using), loading indicators

### Functional Integration (Faraz's Backend)
- [ ] Create Room flow works via `createRoomFlowProvider`
- [ ] Join Room flow works via `joinRoomFlowProvider`
- [ ] Room lifecycle via `roomLifecycleProvider` (prepare, leave, close)
- [ ] Diagnostics shows real device/timing/capture data
- [ ] Navigation: Create Room → RoomShell(Room) → Devices → Session → back works
- [ ] No crashes, no missing providers

### Architecture Compliance
- [ ] No GoRouter introduced
- [ ] No duplicate `lib/ui`, `lib/state`, `lib/core_adapter`, `lib/app`
- [ ] Single `RoomShell` instance via `IndexedStack` (not rebuild per tab)
- [ ] Riverpod providers remain authoritative for state
- [ ] `flutter analyze` PASS, `flutter test` PASS, `flutter build apk --debug` PASS

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| State mapping incomplete | Map each Mahin state to provider status exhaustively in Phase 3-5 |
| RoomShell IndexedStack loses scroll position | IndexedStack preserves state; test thoroughly |
| Theme conflicts (current vs Mahin colors) | Audit all color usages; prefer Mahin's tokens, map to current names |
| Tests break due to UI changes | Update tests to validate recovered UI (per AGENTS.md: "Update the test to validate the recovered design") |
| Missing backend APIs for Mahin UI states | Create minimal integration seams in providers; don't embed backend logic in UI |

---

## Next Steps

1. **Review this plan** with user for approval
2. **Phase 1**: Create design system files
3. **Phase 2**: Replace components
4. **Phase 3**: Replace Home/Create/Join/QR screens
5. **Phase 4**: Rewrite RoomShell + refactor room screens to content widgets
6. **Phase 5**: Recover room content screens + merge Diagnostics
7. **Phase 6**: Validate & report