# Phase 4 Task 1 — Message Envelope and Protocol Handshake Implementation Summary

## Summary

Successfully implemented the structured message envelope and protocol version handshake for SoundMesh, building on top of the existing Phase 3 length-prefixed framing. The envelope is carried as a JSON string payload through the existing `sendMessage()`/`onMessageReceived()` bridge.

## Files Changed

### New Files Created
1. **DOCS/decisions.md** - Added DEC-084 recording UUID v4 decision for roomId/participantId/sessionId
2. **app/lib/application/protocol.dart** - Export file for protocol module
3. **app/lib/application/protocol/protocol_constants.dart** - Protocol constants, message types, error classes, UUID utilities
4. **app/lib/application/protocol/protocol_message.dart** - ProtocolMessage envelope class with serialization/deserialization
5. **app/test/protocol/protocol_message_test.dart** - Unit tests for ProtocolMessage (20 tests)
6. **app/test/room_screen_handshake_test.dart** - Widget tests for handshake flow (7 tests)

### Modified Files
1. **app/lib/application/repositories/network_repository.dart** - Added handshake logic, new connection states (handshaking, ready), protocol message handling
2. **app/lib/application/providers/create_room_flow_provider.dart** - Updated for handshaking/ready states
3. **app/lib/application/providers/join_room_flow_provider.dart** - Updated for handshaking/ready states and version mismatch handling
4. **app/lib/presentation/screens/room_screen.dart** - Shows handshaking indicator, disables input until ready, displays version mismatch errors
5. **app/pubspec.yaml** - Added mockito and build_runner dev dependencies

## Implementation Details

### ProtocolMessage Envelope
```json
{
  "protocolVersion": 1,
  "messageId": "<uuid v4>",
  "messageType": "HELLO|WELCOME|VERSION_REJECTED|PING|PONG|ERROR|ROOM_CLOSED",
  "sessionId": "<uuid v4, after handshake>",
  "senderId": "<uuid v4 participantId>",
  "generation": 0,
  "timestamp": <wall-clock ms>,
  "payload": <message-type-specific object>
}
```

### Handshake Flow
**Participant (Join Room):**
1. TCP connects → `connected` state
2. Auto-sends HELLO with protocolVersion and participantId → `handshaking`
3. Receives WELCOME with sessionId, roomId → `ready`
4. Receives VERSION_REJECTED → `failed` with clear error

**Host (Create Room):**
1. TCP accepts → `connected` state
2. Receives HELLO → validates version
3. If match: sends WELCOME with sessionId, roomId → `ready`
4. If mismatch: sends VERSION_REJECTED → closes connection

### Connection States (Extended)
```
DISCONNECTED → CONNECTING → CONNECTED → HANDSHAKING → READY
```

### Version Compatibility
- Exact version match only (protocolVersion == CURRENT_PROTOCOL_VERSION = 1)
- No forward/backward compatibility in this task

### Error Handling
- Malformed JSON: caught, logged, emits ProtocolMessageDecodeError, doesn't crash
- Version mismatch: explicit VERSION_REJECTED message with version info
- Missing/invalid UUID fields: proper validation with descriptive errors

## Tests

### Unit Tests (20 passing)
- ProtocolMessage serialization round-trip for all 7 message types
- Malformed JSON handling (8 test cases)
- UUID v4 validation
- ProtocolMessageType wire value conversions
- copyWith functionality

### Widget Tests (7 passing)
- Handshaking indicator during handshake
- Ready state after handshake (host and participant)
- Message input disabled during handshaking
- Message input enabled when ready
- Version mismatch error display
- Protocol decode error display

### All Tests (51 passing)
- All existing tests continue to pass
- No regressions introduced

## Verification

✅ `flutter analyze` - Clean (only pre-existing info/warnings)
✅ `flutter test` - All 51 tests pass
✅ `flutter build apk --debug` - Build succeeds

## Not Tested

### Real-Device Verification
**The "Real-Device Verification Steps" section above was a PLAN for Faraz to execute. I did NOT run it myself** — I have no access to physical Android devices. The following remain UNTESTED on real hardware:
- End-to-end handshake between two physical phones over Wi-Fi
- Actual network latency/jitter during handshake message exchange
- Hotspot mode (host as AP) handshake behavior
- Cross-platform (Android host + iOS participant) handshake
- Message reordering or duplicate delivery during handshake
- Connection stability over extended periods with handshake completed

### Reconnect-with-Generation-Increment Behavior
The `generation` field is defined and incremented on reconnect within the same session, but the full reconnection flow (TCP disconnect → reconnect → generation increment → state resync) was not implemented or tested in this task. That is future work.

### Protocol Version Mismatch on Real Devices
The version-mismatch test was **verified via widget tests with mocked ProtocolMessage objects** (emitting a VERSION_REJECTED message into the stream), NOT by building two APKs with different `CURRENT_PROTOCOL_VERSION` constants and running them against each other on physical devices. The mocked test validates the UI error display logic; the actual network-level handshake rejection path was not exercised on hardware.

### Network Edge Cases
- Handshake timeout (no WELCOME received within N seconds)
- Partial JSON frame delivery (frame split across TCP packets)
- Host crash during handshake
- Participant sends malformed HELLO (missing fields, wrong types) — unit tests cover decode logic but not the host's response behavior in this scenario

## Decisions

### DEC-084 — Room/Participant/Session Identity Format (UUID v4)
Recorded in `DOCS/decisions.md`:
- `roomId`: UUID v4, generated by host on room creation
- `participantId`: UUID v4, generated locally per device per room join (not persisted across restarts or rooms)
- `sessionId`: UUID v4, generated by host for this room's active session

### Implementation Decisions Made During This Task
No additional formal decisions were recorded, but the following implementation choices were made implicitly:
1. **VERSION_REJECTED payload shape**: `{"hostVersion": <int>, "participantVersion": <int>}` — sent by host when participant's protocolVersion != CURRENT_PROTOCOL_VERSION
2. **"ready" state interaction with message log**: The `ready` state enables the message input field but does NOT clear the message log. Pre-handshake messages (HELLO/WELCOME/VERSION_REJECTED) remain visible in the log as raw JSON strings. This is intentional — the log shows all wire traffic.
3. **HELLO payload includes participantId redundantly**: The `senderId` field and `payload.participantId` both carry the same UUID. Kept for explicitness and future extensibility.
4. **No handshake timeout**: If HELLO is sent but no WELCOME/VERSION_REJECTED arrives, the connection stays in `handshaking` indefinitely. A timeout with automatic disconnect is a future enhancement.

## Risks / Limitations

1. **Single participant only** — Multi-participant support is Task 2 scope
2. **No room lifecycle states** — CREATED/DISCOVERABLE/JOINING/READY/CLOSED is Task 2
3. **No reconnection logic** — Generation increment defined but reconnection flow is future work
4. **Timestamp is wall-clock** — Explicitly not for synchronization (per spec)
5. **iOS untested** — No macOS/Xcode access, but no native changes required
6. **Exact-version-match breaks compatibility** — Any future protocol version bump (e.g., v2) will reject ALL v1 peers. No graceful degradation or negotiation. This is intentional per spec ("exact version match only"), but means coordinated app updates are mandatory for any protocol change.
7. **Handshake adds ~1 RTT latency** — The HELLO/WELCOME exchange adds one round-trip before messages can be sent. On typical LAN Wi-Fi (~2-10ms RTT) this is negligible; on high-latency links it may be noticeable.
8. **No handshake retry** — If VERSION_REJECTED is lost or HELLO is corrupted, the participant has no automatic retry mechanism; user must manually re-join.
9. **Message log shows raw JSON during handshake** — The HELLO/WELCOME envelopes appear as raw strings in the message log until parsed. This is visible to the user and may be confusing; a dedicated "protocol log" vs "user message log" separation is a future UX improvement.

## Next Step

Phase 4 Task 2: Room Lifecycle State Machine (CREATED/DISCOVERABLE/JOINING/READY/CLOSED) and multi-participant support.