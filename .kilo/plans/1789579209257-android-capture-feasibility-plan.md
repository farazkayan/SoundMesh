# Phase 5 — Android External-Audio Capture Feasibility Plan

## Overview

Prove SoundMesh can capture eligible audio from another Android app using `AudioPlaybackCapture` + `MediaProjection`, exposing it as a minimal native capability behind the existing Pigeon platform boundary. This is a feasibility spike — **not a production pipeline**.

**Classification**: EXPERIMENT + AUDIO + PLATFORM + NETWORKING (control plane only)

---

## Authority & Contract

- **Primary contract**: `DOCS/interfaces/audio-api.md` (now updated with capture operations per DEC-085)
- **Architecture**: `DOCS/architecture.md` §16, §18, §23, §38, §45
- **Audio spec**: `DOCS/audio.md` §4, §5, §6, §46
- **Decisions**: DEC-085 (Android-only host capture), DEC-005 (native timing-critical), DEC-006 (Pigeon boundary)
- **AI rules**: `DOCS/AI/rules.md` §9, §10, §11, §13, §15, §17, §25, §26, §27

---

## Current State (Verified)

| Component | Status |
|-----------|--------|
| Pigeon interface (`soundmesh_platform.dart`) | Defines `NetworkHostPlatform`, `DevicePlatform`, `TimingPlatform` + `NetworkFlutterApi` callbacks |
| Android `MainActivity` | Implements all three HostApis; uses `Dispatchers.Main` for Flutter callbacks |
| Flutter generated code | `lib/src/soundmesh_messages.g.dart`, `android/app/src/main/kotlin/.../SoundMeshMessages.g.kt` |
| `audio-api.md` capture contract | **Defined** (§9–§15, §25): state machine, 5 errors, 4 methods, 2 events |
| Foreground service notification UX | **UNDECIDED** — user directed: minimal notification |
| Capture format | **UNDECIDED** — user directed: "whatever is BEST" |
| Diagnostic surface | **UNDECIDED** — user directed: "you decide" |

---

## Design Decisions (Resolved for This Plan)

| Decision | Resolution | Rationale |
|----------|------------|-----------|
| **Capture contract** | Already defined in `audio-api.md` | User confirmed updated |
| **Foreground service notification** | Minimal: app name + "Capturing audio" with stop action | Meets Android requirement; defers UX polish |
| **AudioPlaybackCapture config** | Request `AudioFormat.ENCODING_PCM_16BIT`, sample rate = `AudioFormat.SAMPLE_RATE_UNSPECIFIED` (let source decide), channel mask = `CHANNEL_IN_STEREO` | Most compatible; discover actual format at runtime via `AudioRecord.getFormat()` |
| **Diagnostic surface** | Periodic native→Flutter callback (every 500ms) with: frame count, bytes/sec, current format, buffer health | No raw PCM crosses boundary; observable in Flutter dev screen |
| **Transport of captured frames** | Native-only queue → Phase 8 transport (out of scope) | Per `audio-api.md` §31: minimal internal buffering only |

---

## Scope

### In Scope
1. New Pigeon `AudioCapturePlatform` HostApi + `AudioCaptureFlutterApi` callbacks
2. Android `AudioCaptureService` (foreground service) + `AudioCaptureEngine` (capture logic)
3. MediaProjection permission flow (Activity-based, returns `GRANTED`/`DENIED`)
4. AudioPlaybackCapture session lifecycle with format discovery
5. Five distinct error codes surfaced to Flutter
6. Capture state machine matching `audio-api.md` §15
7. Unit tests: state machine, error classification
8. Contract tests: Pigeon round-trip for each new method
9. **Real-device experiment**: 3+ source apps (YouTube, browser, local player)

### Out of Scope
- Networking / packetization / transport (Phase 6/8)
- Native audio output / playback (Phase 9)
- UI beyond minimal trigger/state display for manual testing
- iOS (explicitly excluded by DEC-085)
- Resampling / format normalization (UNDECIDED per `audio-api.md` §19)

---

## Architecture

### Pigeon Interface Additions (`app/pigeons/soundmesh_platform.dart`)

```dart
// Data classes
class CaptureState { final String state; }  // IDLE, REQUESTING_PERMISSION, PERMISSION_GRANTED, CAPTURING, STOPPED, FAILED
class CaptureMetadata { final String sessionId; final int generation; final int sampleRate; final int channelCount; final int startedAtNanos; }
class CaptureError { final String code; final String message; }

// Host API (Flutter → Native)
@HostApi()
abstract class AudioCapturePlatform {
  CapturePermissionResult requestCapturePermission();  // GRANTED | DENIED
  CaptureResult startCapture();  // success with metadata | error
  void stopCapture();
  CaptureStateResult getCaptureState();  // state + optional metadata
}

// Flutter API (Native → Flutter)
@FlutterApi()
abstract class AudioCaptureFlutterApi {
  void onCaptureStateChanged(String state, CaptureMetadata? metadata);
  void onCaptureError(String errorCode, String errorMessage);
}
```

### Native Android Components

```
android/app/src/main/kotlin/com/soundmesh/soundmesh/
├── capture/
│   ├── AudioCaptureEngine.kt          # Core AudioPlaybackCapture logic
│   ├── AudioCaptureService.kt         # Foreground service (lifecycle)
│   ├── CaptureStateMachine.kt         # State transitions + validation
│   ├── CaptureErrorClassifier.kt      # Maps exceptions → 5 error codes
│   ├── MediaProjectionHelper.kt       # Permission intent + callback handling
│   └── CaptureDiagnostics.kt          # Periodic stats for Flutter callback
├── SoundMeshMessages.g.kt             # Regenerated (Pigeon)
└── MainActivity.kt                    # Updated: sets up AudioCapturePlatform + registers FlutterApi
```

### Threading Model

| Operation | Thread |
|-----------|--------|
| `requestCapturePermission()` | Main (shows dialog) → IO (result) |
| `startCapture()` | IO (MediaProjection + AudioRecord setup) |
| `stopCapture()` | IO (cleanup) |
| `getCaptureState()` | IO (read volatile state) |
| `onCaptureStateChanged` / `onCaptureError` | **Main** (via `Dispatchers.Main`, audited pattern) |
| AudioRecord read loop | Dedicated coroutine on `Dispatchers.IO` |
| Diagnostics emission | IO → Main (throttled 500ms) |

---

## Implementation Steps

### Step 1: Update Pigeon Definition & Regenerate
1. Add data classes (`CaptureState`, `CaptureMetadata`, `CaptureError`, `CapturePermissionResult`, `CaptureResult`, `CaptureStateResult`) to `soundmesh_platform.dart`
2. Add `AudioCapturePlatform` HostApi + `AudioCaptureFlutterApi` FlutterApi
3. Run `flutter pub run pigeon --input app/pigeons/soundmesh_platform.dart`
4. Verify generated Dart + Kotlin code compiles

### Step 2: Implement Native Capture Engine (`AudioCaptureEngine.kt`)
- `AudioRecord` with `AudioPlaybackCaptureConfiguration` (API 29+)
- MediaProjection token → `MediaProjection.createAudioRecordConfiguration()`
- Format discovery: on first `read()` success, capture `AudioFormat` (sampleRate, channelCount, encoding)
- Generation counter: increment on each `startCapture()`
- Frame queue: `ArrayBlockingQueue<ByteBuffer>` (capacity ~200ms) — **native only**
- Diagnostics: frame count, bytes/sec, buffer occupancy, emitted every 500ms via callback

### Step 3: Implement Foreground Service (`AudioCaptureService.kt`)
- `Service` with `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION`
- Minimal notification: `NotificationCompat.Builder` with:
  - Title: "SoundMesh"
  - Text: "Capturing audio"
  - Small icon: app icon
  - Action: "Stop" → calls `stopCapture()`
- Lifecycle: `onCreate()` → `startForeground()`; `onDestroy()` → cleanup

### Step 4: Implement State Machine & Error Classifier
- `CaptureStateMachine`: validates transitions per `audio-api.md` §15
- `CaptureErrorClassifier`: maps exceptions → 5 codes:
  - `SecurityException` (permission) → `PERMISSION_DENIED`
  - `UnsupportedOperationException` / API level < 29 → `CAPTURE_UNSUPPORTED`
  - `IllegalStateException` (source app `ALLOW_CAPTURE_BY_ALL=false`) → `SOURCE_APP_BLOCKED`
  - Generic `Exception` during start → `CAPTURE_START_FAILED` (with cause message)
  - `MediaProjection.Callback.onStop()` / audio focus loss → `CAPTURE_INTERRUPTED`

### Step 5: Wire into MainActivity
- Implement `AudioCapturePlatform` in `MainActivity` (or dedicated class)
- Hold reference to `AudioCaptureEngine` + `AudioCaptureService`
- Register `AudioCaptureFlutterApi` via generated `setUp()`
- Forward callbacks to Flutter on `Dispatchers.Main`

### Step 6: Unit Tests (JVM)
- `CaptureStateMachineTest`: all valid/invalid transitions
- `CaptureErrorClassifierTest`: each error code reachable via mocked exceptions
- `MediaProjectionHelperTest`: intent creation, result parsing

### Step 7: Contract Tests (Flutter)
- Pigeon round-trip for each method
- State machine integration: permission → start → metadata → stop → idle

### Step 8: Real-Device Experiment (MANDATORY)
Test matrix (record per app):

| Android Version | Device Model | Source App | Permission Granted? | Audio Captured? | Format (Hz/ch) | Failure Reason |
|-----------------|--------------|------------|---------------------|-----------------|----------------|----------------|
|                 |              | YouTube    |                     |                 |                |                |
|                 |              | Chrome (video) |                 |                 |                |                |
|                 |              | VLC / local player |           |                 |                |                |

**Stop conditions** (per task + `audio-api.md` §36):
- Source app blocks capture with no documented workaround → STOP, report app + reason
- Format varies unpredictably, cannot be discovered at start → STOP, report
- Foreground notification conflicts with UI flow → STOP, escalate to Mahin

---

## File Changes

| File | Change Type |
|------|-------------|
| `app/pigeons/soundmesh_platform.dart` | Add capture types + APIs |
| `app/lib/src/soundmesh_messages.g.dart` | Regenerated |
| `app/android/app/src/main/kotlin/.../SoundMeshMessages.g.kt` | Regenerated |
| `app/android/app/src/main/kotlin/.../MainActivity.kt` | Implement `AudioCapturePlatform`, register `AudioCaptureFlutterApi` |
| `app/android/app/src/main/kotlin/.../capture/AudioCaptureEngine.kt` | **New** |
| `app/android/app/src/main/kotlin/.../capture/AudioCaptureService.kt` | **New** |
| `app/android/app/src/main/kotlin/.../capture/CaptureStateMachine.kt` | **New** |
| `app/android/app/src/main/kotlin/.../capture/CaptureErrorClassifier.kt` | **New** |
| `app/android/app/src/main/kotlin/.../capture/MediaProjectionHelper.kt` | **New** |
| `app/android/app/src/main/kotlin/.../capture/CaptureDiagnostics.kt` | **New** |
| `app/android/app/src/main/AndroidManifest.xml` | Add foreground service + permissions |
| `app/test/capture/capture_state_machine_test.dart` | **New** (Flutter contract tests) |
| `app/android/app/src/test/kotlin/.../capture/*Test.kt` | **New** (JVM unit tests) |
| `DOCS/decisions.md` | Add DEC-08X with experiment results |

---

## Android Manifest Additions

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />  <!-- Already implied by capture -->
<uses-permission android:name="android.permission.MEDIA_PROJECTION" />  <!-- Not a manifest perm, but declare for clarity -->

<service
    android:name=".capture.AudioCaptureService"
    android:foregroundServiceType="mediaProjection"
    android:exported="false" />
```

---

## Validation Checklist (Per Task Completion Criteria)

- [ ] At least one real external app's audio captured on physical Android device, PCM frames observed arriving (via diagnostics)
- [ ] Capture can be started/stopped repeatedly without crashing or leaking MediaProjection
- [ ] All five error cases distinctly reported (not collapsed)
- [ ] Experiment table (per-app results) delivered in completion report
- [ ] `audio-api.md` updated to match what was actually built (resolve UNDECIDED items)
- [ ] `decisions.md` entry added (DEC-08X) with experiment results

---

## Risks & Limitations

| Risk | Mitigation |
|------|------------|
| Source app opts out of capture (`ALLOW_CAPTURE_BY_ALL=false`) | Detect → `SOURCE_APP_BLOCKED`; report in experiment table |
| Format varies across apps | Discover at runtime; flag UNDECIDED in `audio-api.md` if normalization needed |
| Foreground notification UX not final | Minimal for Phase 5; refine in Phase 10+ with Mahin |
| Screen lock / background behavior untested | Flag in experiment report; don't block Phase 5 |
| AudioRecord read loop latency | Keep native; diagnose via 500ms stats callback |

---

## Next Step

After plan approval: implement Step 1 (Pigeon update) → Step 2–5 (native) → Step 6–7 (tests) → Step 8 (real-device experiment) → update docs + report.