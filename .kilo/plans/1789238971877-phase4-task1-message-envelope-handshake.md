# Phase 4 Task 1 — Message Envelope and Protocol Handshake Implementation Plan

## Summary

This plan covers implementing the structured message envelope and protocol version handshake for SoundMesh, building on top of the existing Phase 3 length-prefixed framing. The envelope is carried as a JSON string payload through the existing `sendMessage()`/`onMessageReceived()` bridge.

---

## Current State Analysis

### Existing Infrastructure
- **NetworkRepository** (`app/lib/application/repositories/network_repository.dart`): Manages connection state stream and message stream
- **Connection States**: `disconnected`, `connecting`, `connected`, `failed`
- **Pigeon Interface** (`app/pigeons/network_platform.dart`): `NetworkHostPlatform` + `NetworkFlutterApi`
- **Native Implementations**: Android `MainActivity.kt`, iOS `NetworkHandler.swift` with `FrameDecoder`
- **Flow Providers**: `CreateRoomFlowProvider`, `JoinRoomFlowProvider` react to connection state changes
- **RoomScreen**: Shows "Connected" state and allows raw string messaging

### Key Constraints
- Do NOT modify Pigeon interfaces or native frame-level code
- Envelope rides as UTF-8 string payload in existing frames
- Room lifecycle state machine (CREATED/DISCOVERABLE/JOINING/READY/CLOSED) is Task 2 scope
- Multi-participant support is Task 2 scope
- iOS requires no native changes for this task

---

## Implementation Plan

### Step 1: Record UUID v4 Decision in decisions.md
**File**: `DOCS/decisions.md`
- Add new decision entry following existing ADR format
- Decision ID: DEC-037 (next sequential)
- Title: Room/Participant/Session Identity Format
- Status: DECIDED
- Content: roomId, participantId, sessionId are UUID v4 strings; participantId regenerated per room join

### Step 2: Create ProtocolMessage Envelope Class
**File**: `app/lib/application/protocol/protocol_message.dart` (new file)

```dart
class ProtocolMessage {
  final int protocolVersion;
  final String messageId;      // UUID v4
  final String messageType;    // HELLO, WELCOME, PING, PONG, VERSION_REJECTED, ERROR, ROOM_CLOSED
  final String? sessionId;     // UUID v4, present after handshake
  final String senderId;       // participantId, UUID v4
  final int generation;        // starts at 0
  final int timestamp;         // wall-clock ms (protocol bookkeeping only)
  final Map<String, dynamic>? payload;

  // Factory constructors for each message type
  // toJson() / fromJson() with validation
  // Malformed JSON handling: throw ProtocolMessageDecodeError (custom)
}
```

**Key Points**:
- Pure Dart, no Pigeon involvement
- `timestamp` is explicitly NOT synchronization timing (per spec)
- `generation` starts at 0, increments on reconnect within same session
- `messageId` is UUID v4 for duplicate detection

### Step 3: Define Protocol Constants and Error Types
**File**: `app/lib/application/protocol/protocol_constants.dart` (new file)

```dart
const int CURRENT_PROTOCOL_VERSION = 1;

enum ProtocolMessageType {
  hello,
  welcome,
  versionRejected,
  ping,
  pong,
  error,
  roomClosed,
}

class ProtocolMessageDecodeError implements Exception { ... }
class ProtocolVersionMismatchError implements Exception { ... }
```

### Step 4: Implement Handshake Logic in NetworkRepository
**File**: `app/lib/application/repositories/network_repository.dart` (modify)

**Changes**:
1. Add new connection state: `handshaking` (between `connected` and `ready`)
2. Add `protocolVersion` constant reference
3. Add `participantId` generation (UUID v4) on repository creation
4. Add handshake state machine:
   - On `connected` → automatically send HELLO (participant) or await HELLO (host)
   - Host validates version, responds WELCOME (with sessionId, roomId) or VERSION_REJECTED
   - Participant receives WELCOME → transitions to `ready`
   - Participant receives VERSION_REJECTED → transitions to `failed` with error
5. Expose `ready` state stream for UI
6. Handle malformed messages gracefully (log, emit protocol error, don't crash)

### Step 5: Update Connection State Enum and Flow Providers
**File**: `app/lib/application/repositories/network_repository.dart`
- Add `handshaking` and `ready` to `NetworkConnectionState`

**File**: `app/lib/application/providers/create_room_flow_provider.dart`
- Add `handshaking` and `ready` status handling
- Host transitions: `hosting` → `handshaking` (on connected) → `ready` (on WELCOME sent)

**File**: `app/lib/application/providers/join_room_flow_provider.dart`
- Add `handshaking` and `ready` status handling
- Participant transitions: `connecting` → `handshaking` (on connected) → `ready` (on WELCOME received)

### Step 6: Update RoomScreen for Ready State
**File**: `app/lib/presentation/screens/room_screen.dart`
- Disable message input until `ready` state
- Show "Handshaking..." indicator during handshaking
- Show version mismatch error clearly if handshake fails

### Step 7: Unit Tests
**File**: `app/test/protocol/protocol_message_test.dart` (new)
- Serialization round-trip for all message types
- Malformed JSON handling (missing fields, wrong types, invalid UUIDs)
- Version-compatible handshake scenario (mocked NetworkRepository)
- Version-incompatible handshake scenario (mocked NetworkRepository)

**File**: `app/test/application/repositories/network_repository_handshake_test.dart` (new)
- Test handshake state transitions using mocked platform
- Test HELLO sent automatically on connect (participant)
- Test WELCOME sent automatically on HELLO received (host)
- Test VERSION_REJECTED on mismatch
- Test malformed message handling

### Step 8: Widget Tests
**File**: `app/test/room_screen_handshake_test.dart` (new)
- Connection flow shows "handshaking" then "ready" states
- Version mismatch shows error state with human-readable message
- Message input disabled until ready

### Step 9: Run Static Checks and Tests
```bash
flutter analyze
flutter test
flutter build apk --debug
```

### Step 10: Document Real-Device Verification Steps
Create a verification guide for manual two-device testing.

---

## Files to Create

1. `DOCS/decisions.md` — Add DEC-037 entry (append)
2. `app/lib/application/protocol/protocol_constants.dart` — New
3. `app/lib/application/protocol/protocol_message.dart` — New
4. `app/test/protocol/protocol_message_test.dart` — New
5. `app/test/application/repositories/network_repository_handshake_test.dart` — New
6. `app/test/room_screen_handshake_test.dart` — New

## Files to Modify

1. `app/lib/application/repositories/network_repository.dart` — Add handshake logic, new states
2. `app/lib/application/providers/create_room_flow_provider.dart` — Handle handshaking/ready
3. `app/lib/application/providers/join_room_flow_provider.dart` — Handle handshaking/ready
4. `app/lib/presentation/screens/room_screen.dart` — Show handshaking/ready, disable input until ready

---

## State Machine Details

### Connection States (Extended)
```
DISCONNECTED
    ↓
CONNECTING
    ↓
CONNECTED (raw TCP established)
    ↓
HANDSHAKING (HELLO/WELCOME exchange)
    ↓
READY (handshake complete, protocol aligned)
    ↓
ACTIVE (future: audio transfer, calibration, playback)
    ↓
DEGRADED / RECONNECTING / FAILED / DISCONNECTED
```

### Handshake Flow

**Participant (Join Room)**:
1. TCP connects → `connected` state
2. Auto-send HELLO `{protocolVersion, participantId}` → `handshaking`
3. Receive WELCOME `{protocolVersion, sessionId, roomId}` → `ready`
4. Receive VERSION_REJECTED → `failed` with error

**Host (Create Room)**:
1. TCP accepts → `connected` state
2. Receive HELLO → validate version
3. If match: send WELCOME `{protocolVersion, sessionId, roomId}` → `ready`
4. If mismatch: send VERSION_REJECTED `{hostVersion, participantVersion}` → close

### Compatibility Rule
- **Exact version match only** (protocolVersion == CURRENT_PROTOCOL_VERSION)
- No forward/backward compatibility logic in this task

---

## Error Handling Requirements

1. **Malformed JSON**: Catch decode error, log, emit `ProtocolMessageDecodeError`, stay in current state
2. **Missing required fields**: Treat as malformed
3. **Version mismatch**: Explicit VERSION_REJECTED message, clean disconnect, user-visible error
4. **Unexpected message type in handshaking**: Log warning, ignore
5. **Timeout**: Not required for this task (future enhancement)

---

## Testing Strategy

### Unit Tests (No Device Needed)
- ProtocolMessage serialization/deserialization
- Handshake logic with mocked NetworkRepository
- Edge cases: malformed JSON, missing fields, wrong types

### Widget Tests
- RoomScreen shows handshaking indicator
- RoomScreen shows ready state
- RoomScreen shows version mismatch error
- Message input disabled until ready

### Integration (Real Device)
- Host creates room, participant joins
- Verify handshake completes automatically
- Verify messages exchange after ready
- Test version mismatch (temporarily change constant on one device)

---

## Risks / Limitations

1. **No native changes needed** — envelope is pure Dart over existing bridge
2. **Single participant only** — multi-participant is Task 2
3. **No room lifecycle states** — CREATED/DISCOVERABLE/JOINING/READY/CLOSED is Task 2
4. **No reconnection logic** — generation increment on reconnect is defined but reconnection flow is future
5. **Timestamp is wall-clock** — explicitly not for synchronization (per spec)

---

## Acceptance Criteria

- [ ] DEC-037 added to decisions.md with UUID v4 decision
- [ ] ProtocolMessage class exists with toJson/fromJson
- [ ] Unit tests pass for serialization and malformed handling
- [ ] HELLO sent automatically on TCP connect (participant)
- [ ] WELCOME sent automatically on HELLO received (host)
- [ ] VERSION_REJECTED sent on version mismatch with clear error
- [ ] Connection state includes `handshaking` and `ready`
- [ ] UI shows handshaking → ready progression
- [ ] Message input disabled until ready
- [ ] flutter analyze: clean
- [ ] flutter test: all pass
- [ ] flutter build apk --debug: succeeds
- [ ] Real-device verification steps documented

---

## Next Steps (After This Task)

Phase 4 Task 2: Room Lifecycle State Machine (CREATED/DISCOVERABLE/JOINING/READY/CLOSED) and multi-participant support.