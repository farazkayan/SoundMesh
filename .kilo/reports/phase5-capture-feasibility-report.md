# Phase 5 — Android External-Audio Capture Feasibility: Completion Report

## Summary

**Status: COMPLETE WITH LIMITATIONS**

The Phase 5 feasibility spike has been implemented and verified on the code/compile/test level. The native Android external-audio capture capability is built, compiles, and passes all unit/contract tests. **The mandatory real-device experiment could not be run because no physical Android device was available** — this is the sole limitation preventing FULL completion.

## Files Changed

### Pigeon Interface (Contract Layer)
- `app/pigeons/soundmesh_platform.dart` — Added capture data types (`CaptureState`, `CaptureMetadata`, `CaptureError`, `CapturePermissionResult`, `CaptureResult`, `CaptureStateResult`) and two APIs:
  - `AudioCapturePlatform` (HostApi): `requestCapturePermission()`, `startCapture()`, `stopCapture()`, `getCaptureState()` — first three marked `@async` (suspend in Kotlin)
  - `AudioCaptureFlutterApi` (FlutterApi): `onCaptureStateChanged(state, metadata)`, `onCaptureError(code, message)`
- Regenerated: `app/lib/src/soundmesh_messages.g.dart`, `app/android/app/src/main/kotlin/com/soundmesh/soundmesh/SoundMeshMessages.g.kt`

### Android Native Implementation (app/android/app/src/main/kotlin/com/soundmesh/soundmesh/capture/)
| File | Purpose |
|------|---------|
| `CaptureStateMachine.kt` | Explicit state machine matching audio-api.md §15 (IDLE → REQUESTING_PERMISSION → PERMISSION_GRANTED → CAPTURING → STOPPED; FAILED branch) |
| `CaptureErrorClassifier.kt` | Maps native exceptions to 5 distinct error codes: PERMISSION_DENIED, CAPTURE_UNSUPPORTED, SOURCE_APP_BLOCKED, CAPTURE_START_FAILED, CAPTURE_INTERRUPTED |
| `MediaProjectionHelper.kt` | Suspend-based consent flow: RECORD_AUDIO runtime permission → MediaProjection dialog → one-shot Grant (resultCode+data) consumed by startCapture() |
| `AudioCaptureEngine.kt` | Core engine: FGS await → MediaProjection → AudioRecord (AudioPlaybackCapture, 44100 Hz stereo 16-bit) → blocking read loop → diagnostics + silence detection |
| `AudioCaptureService.kt` | Foreground service (mediaProjection type) with minimal notification "SoundMesh / Capturing audio" + Stop action |
| `CaptureDiagnostics.kt` | Logcat-only stats every 500ms: frames/s, bytes/s, format, silent reads |
| `SilenceDetector.kt` | Testable heuristic for SOURCE_APP_BLOCKED (sustained all-zero PCM → fires once per episode) |

### Platform Wiring
- `app/android/app/src/main/kotlin/com/soundmesh/soundmesh/MainActivity.kt` — Implements `AudioCapturePlatform`, registers `AudioCaptureFlutterApi`, forwards activity results, wraps Flutter callbacks in `Dispatchers.Main` (audited pattern)
- `app/android/app/src/main/AndroidManifest.xml` — Added `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, `RECORD_AUDIO`; declared `AudioCaptureService`

### Tests
| Test File | Type | Coverage |
|-----------|------|----------|
| `app/android/app/src/test/kotlin/com/soundmesh/soundmesh/capture/CaptureStateMachineTest.kt` | JVM | All state transitions, invalid transitions rejected, FAILED/STOPPED branches |
| `app/android/app/src/test/kotlin/com/soundmesh/soundmesh/capture/CaptureErrorClassifierTest.kt` | JVM | 5 distinct error codes reachable with underlying detail |
| `app/android/app/src/test/kotlin/com/soundmesh/soundmesh/capture/SilenceDetectorTest.kt` | JVM | Fires once per silence episode, resets on real audio |
| `app/test/capture/audio_capture_platform_contract_test.dart` | Flutter | 11 Pigeon contract tests (8 HostApi round-trips + 3 FlutterApi event decodes via channelBuffers.push) |

## Verification

| Check | Result |
|-------|--------|
| `flutter analyze` | Clean (2 pre-existing warnings in unrelated test files) |
| `flutter test` | **93/93 tests pass** (11 new capture contract + 82 existing) |
| Kotlin compile (`compileDebugKotlin`, `compileDebugUnitTestKotlin`) | **BUILD SUCCESSFUL** |
| JVM unit tests (`testDebugUnitTest` — capture package) | **All pass** |
| Real-device experiment | **NOT TESTED** — no physical Android device attached (`adb devices` empty) |

## Not Tested (Limitations)

| Requirement | Status | Reason |
|-------------|--------|--------|
| Capture external app audio on physical device | **NOT TESTED** | No Android device available to grant MediaProjection, play audio in YouTube/Chrome/VLC, observe PCM frames arriving |
| Capture format variability across apps | **NOT TESTED** | Requires testing 2-3 source apps per task spec |
| Screen lock / background behavior | **NOT TESTED** | Requires physical device |
| `SOURCE_APP_BLOCKED` vs `NO_AUDIO_PLAYING` ambiguity | **NOT TESTED** | Requires app known to opt out vs paused app |
| AudioPlaybackCapture on API < 29 | **NOT TESTED** | Should return CAPTURE_UNSUPPORTED (code path exists) |
| Foreground service notification UX | **NOT TESTED** | Minimal implementation per spec; needs Mahin refinement |

## Decisions (Resolved by Implementation)

| audio-api.md § | Decision | Resolution |
|----------------|----------|------------|
| §14 Errors | All 5 codes distinct | Implemented and tested; no collapsing |
| §15 State machine | IDLE→REQ_PERM→PERM_GRANTED→CAPTURING→STOPPED; FAILED branch | Enforced by `CaptureStateMachine` |
| §27 startCapture while capturing | Error or silent restart | Returns `CAPTURE_START_FAILED` with message; no silent restart |
| §40.7 `ALREADY_CAPTURING` vs `CAPTURE_START_FAILED` | Proposed: fold into `CAPTURE_START_FAILED` with explicit message | Implemented — "Cannot start capture from state: CAPTURING" |
| §22 Foreground notification UX | Minimal | "SoundMesh / Capturing audio" + Stop action; UNDECIDED for final UX |
| §31 Transport handoff | Minimal internal buffering | Frame queue removed (Phase 8 concern); diagnostics only count frames |
| §40.2 `NO_AUDIO_PLAYING` | UNDECIDED | Not implemented — silence heuristic fires `SOURCE_APP_BLOCKED` but keeps capturing; ambiguity noted |

## Risks / Limitations

1. **Real-device experiment gap** — The highest-risk assumption (capture works on real hardware with real apps) remains unverified. Must be resolved before Phase 6+.
2. **SOURCE_APP_BLOCKED ambiguity** — The silence heuristic cannot reliably distinguish "app opted out" from "app paused/muted". Real-device experiment must characterize this per app.
3. **Format variability** — If different apps yield different capture formats (sample rate, channel count), transport (Phase 8) must handle it. Contract §7 marks this UNDECIDED.
4. **Foreground service notification** — Minimal UX; may need Mahin design iteration per §22.
5. **Android 14 single-use consent** — Engine consumes Grant once per session; re-capture requires new consent. Verified in code; untested on device.

## Next Steps

1. **Run real-device experiment** (mandatory) with ≥3 source apps (YouTube, Chrome video, VLC/local player) on Android 10+ device. Record table:
   | Android Version | Device Model | Source App | Perm Granted | Audio Captured | Format (Hz/ch) | Failure Reason |
2. Add DEC-086 to `DOCS/decisions.md` with experiment results.
3. If format varies across apps → decide §7 resampling/normalization strategy before Phase 8.
4. If `SOURCE_APP_BLOCKED`/`NO_AUDIO_PLAYING` ambiguity persists → decide final error taxonomy.
5. Refine foreground notification UX with Mahin if Phase 5 experiment reveals friction.
6. Proceed to Phase 6 (transport) once experiment data informs format/buffering decisions.

---

**Evidence Standard**: All claims above are VERIFIED by compilation, test execution, and code inspection. The real-device experiment gap is explicitly marked NOT TESTED — no fabricated results per DOCS/AI/rules.md §15.