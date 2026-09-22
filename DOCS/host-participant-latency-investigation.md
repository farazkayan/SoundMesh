# Host vs Participant Latency Investigation

**Status:** Phase 10 Investigation Complete
**Date:** 2026-09-22
**Purpose:** Document the timing relationship between host direct output and participant SoundMesh output for Phase 11 synchronization architecture.

---

## 1. Current Architecture Timing Model

### Host Audio Path
```
External Media App
        │
        ▼
Android Audio Mixer (system)
        │
        ├──► Host Speaker (direct output, NO SoundMesh involvement)
        │
        └──► AudioPlaybackCapture API
                │
                ▼
        SoundMesh Capture Engine
                │
                ▼
        Capture Timestamp assigned (SystemClock.elapsedRealtimeNanos())
                │
                ▼
        AudioTransportEngine → Network
```

**Key Fact:** The host does **NOT** have a SoundMesh local output path. The host hears the external application's audio directly through Android's audio mixer. SoundMesh only captures the mixer's output for distribution to participants.

### Participant Audio Path
```
SoundMesh Network (TCP)
        │
        ▼
AudioReceiveEngine (reorders, jitter buffers)
        │
        ▼
Jitter Buffer (3 packets = 60ms target)
        │
        ▼
AudioOutputEngine (AudioTrack)
        │
        ▼
AudioTrack Buffer (~100ms, 5 frames)
        │
        ▼
Participant Speaker
```

---

## 2. Latency Components

### Host Side (Capture Timestamp Point)
| Component | Estimated Latency | Measurable |
|-----------|------------------|------------|
| External app → Mixer | App-dependent | No (inside Android) |
| Mixer → AudioPlaybackCapture | ~5-20ms | No (platform) |
| Capture Engine read loop | ~1-5ms | Yes (diagnostics) |
| **Total to capture timestamp** | **~10-30ms** | **Partial** |

The capture timestamp (`SystemClock.elapsedRealtimeNanos()`) is assigned **after** the AudioRecord.read() returns, so it represents the time the frame was available from the capture API, not the original mixer output time.

### Network Transport
| Component | Estimated Latency | Measurable |
|-----------|------------------|------------|
| Host packetization | <1ms | Yes |
| TCP send + network | RTT/2 (one-way) | Yes (RTT measurement) |
| Participant receive + parse | <5ms | Yes |
| **Total network** | **RTT/2 + ~5ms** | **Yes** |

### Participant Side (Output)
| Component | Estimated Latency | Measurable |
|-----------|------------------|------------|
| Jitter buffer wait | 0-60ms (dynamic) | Yes (buffer depth) |
| AudioTrack write + buffer | ~100ms (5 frames) | Partial |
| AudioTrack → Speaker | Device-dependent | **No (requires external measurement)** |
| **Total participant** | **~160-220ms + network** | **Partial** |

---

## 3. Known End-to-End Latency

**Current measured participant latency: ~500ms**

Breakdown (estimated):
- Capture to timestamp: ~20ms
- Network (one-way): ~10-20ms (typical LAN)
- Jitter buffer: ~60ms (3 packets)
- AudioTrack buffer: ~100ms
- AudioTrack → Speaker: ~50-100ms (device-dependent)
- **Unaccounted/processing: ~250-350ms**

The ~500ms is a known Phase 10 observation. Phase 11 will address this through scheduled future-target playback and buffer optimization.

---

## 4. Host Direct Output vs Participant Output

### The Synchronization Problem
```
Host hears:     External App → Mixer → Speaker (latency: L_host_direct)
Participant hears: External App → Mixer → Capture → Network → Jitter → AudioTrack → Speaker (latency: L_participant)
```

**L_host_direct** is the Android audio output latency (mixer → speaker). This is typically **20-100ms** on modern Android devices but varies significantly by device, Android version, and audio route (speaker vs Bluetooth).

**L_participant** is the full SoundMesh pipeline latency (~500ms currently).

### Can We Measure Host Direct Output Latency in Software?
**No.** The host's direct output path bypasses SoundMesh entirely:
- SoundMesh captures **after** the mixer
- The host speaker output happens **at the mixer**
- There is no SoundMesh callback for "audio reached host speaker"

The capture timestamp represents mixer output + capture pipeline latency, NOT the host speaker output time.

---

## 5. What Can Be Measured in Software

### Available Timestamps
| Timestamp | Source | Meaning |
|-----------|--------|---------|
| `captureTimestampNanos` | `AudioCaptureEngine` | When frame read from AudioRecord |
| `receiveTimestampNanos` | `AudioReceiveEngine` | When packet parsed from network |
| `playbackTimestampNanos` | `AudioOutputEngine` | When frame written to AudioTrack |

### Measurable Latencies
1. **Capture-to-Network**: `receiveTimestamp - captureTimestamp` (includes network)
2. **Network RTT**: Via timestamp exchange protocol
3. **Participant Buffer Depth**: `AudioReceiveEngine.getBufferDepthMs()`
4. **Output Buffer Estimate**: `AudioOutputEngine.estimateBufferedMs()`

### NOT Measurable in Software
1. **Mixer → Speaker (host direct)**: No API exposure
2. **AudioTrack → Speaker (participant)**: Platform-dependent, no callback
3. **External app → Mixer**: Inside Android audio system

---

## 6. Phase 11 Requirements

For Phase 11 synchronized playback, the following timing information is needed:

### Required Measurements (External)
1. **Host direct output latency**: Measure with external microphone — time from external app play command to sound at host speaker
2. **Participant output latency**: Measure with external microphone — time from capture timestamp to sound at participant speaker
3. **Device-specific profiles**: Build latency profiles per device model/OS version

### Synchronization Strategy Options
| Strategy | Description | Feasibility |
|----------|-------------|-------------|
| **Host also uses SoundMesh output** | Host mutes direct output, plays via SoundMesh AudioTrack | Requires host to run AudioOutputEngine; adds ~100ms to host |
| **Compensate participant delay** | Schedule participant output earlier by (L_host_direct - L_participant_pipeline) | Requires knowing both latencies |
| **Align to latest** | Both target max(L_host, L_participant) + margin | Simplest, highest latency |

### Recommended Phase 11 Approach
1. **Measure host direct output latency** on target devices (external mic)
2. **Measure participant pipeline latency** on target devices (external mic)
3. **Implement scheduled playback** with future target time = `now + max(host_latency, participant_latency) + safety_margin`
4. **Host runs AudioOutputEngine** (muted or low volume) to participate in synchronized group
5. **External validation** with multi-microphone recording

---

## 7. Current Timing Data Available to Phase 11

From existing diagnostics:
- `CaptureDiagnostics`: frames/sec, peak amplitude, silence detection
- `AudioTransportEngine` diagnostics: packets sent/failed, queue depth
- `AudioReceiveEngine` diagnostics: packets received/lost/ooo, buffer depth (ms), underruns
- `AudioOutputEngine` diagnostics: packets written, write errors, underruns, play state

All timestamps use `SystemClock.elapsedRealtimeNanos()` (monotonic).

---

## 8. Conclusion

**Host has no SoundMesh local output path.** The host hears the external app directly. SoundMesh captures the mixer output for distribution only.

**Phase 11 must:**
1. Externally measure host direct output latency per device
2. Externally measure participant SoundMesh output latency per device
3. Implement scheduled playback targeting the slower path + margin
4. Optionally run AudioOutputEngine on host (muted) for true synchronization

The ~500ms participant latency is a known quantity to be reduced in Phase 11 through buffer optimization and scheduled playback.