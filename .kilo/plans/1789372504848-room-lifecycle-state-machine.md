# Phase 4 Task 2 — Room Lifecycle State Machine Implementation Plan

## Summary
Implement a distinct `RoomLifecycleState` state machine on top of the existing `NetworkConnectionState`. Add JOIN_REQUEST/JOIN_ACCEPTED/JOIN_REJECTED protocol messages, explicit room closure with ROOM_CLOSED message, and Leave/End Room UI actions. Scope: exactly 1 host + 1 participant (Task 3 handles multi-participant).

---

## Authority & Constraints
- **Primary**: Current task specification + DOCS/roadmap.md Phase 4 + DOCS/interfaces/room-api.md
- **DEC-084**: UUID v4 for roomId, participantId, sessionId
- **DEC-067**: Explicit state machines required
- **Must NOT** touch native Pigeon bridge (Dart-only, rides existing envelope)
- **Must NOT** implement multi-participant beyond single reject stub
- **Must NOT** rename/restructure `NetworkConnectionState` — add `RoomLifecycleState` alongside it

---

## Current State Analysis

### Existing Connection States (`NetworkConnectionState`)
```
disconnected → connecting → connected → (host: listening, participant: handshaking) → ready → failed
```

### Existing Flow Provider Status Enums
- `CreateRoomFlowStatus`: idle, creating, hosting, listening, handshaking, ready, failed
- `JoinRoomFlowStatus`: idle, connecting, handshaking, ready, failed

### Existing Protocol Message Types
- HELLO, WELCOME, VERSION_REJECTED, PING, PONG, ERROR, ROOM_CLOSED, CHAT

### Gap: No Room-Level State Machine
The task requires a **separate** `RoomLifecycleState` enum:
```
CREATED → DISCOVERABLE → JOINING → READY → CLOSED
```
Mapping to connection states:
- CREATED: room object exists, before TCP listener
- DISCOVERABLE: maps to host's `listening` connection state
- JOINING: maps to participant's `handshaking` + explicit join-request step
- READY: maps to `ready` connection state + participant formally added to room
- CLOSED: new terminal state (host ends OR participant leaves)

---

## Implementation Plan

### 1. Define RoomLifecycleState Enum & Types
**File**: `app/lib/application/room/room_lifecycle.dart` (NEW)

```dart
enum RoomLifecycleState {
  created,      // Host: room object exists, before listener
  discoverable, // Host: listening for participants
  joining,      // Participant: handshake done, join request sent/pending
  ready,        // Both: handshake complete, participant formally in room
  closed,       // Terminal: room ended
}
```

Supporting types:
- `RoomRole` { host, participant }
- `RoomMember` { participantId, displayName?, role, joinedAt }
- `JoinRejectReason` { roomFull, versionMismatch, closed, internalError }

### 2. Extend Protocol Constants & Messages
**File**: `app/lib/application/protocol/protocol_constants.dart`
- Add message types: `joinRequest`, `joinAccepted`, `joinRejected`
- Add `wireValue` and `fromWireValue` for new types

**File**: `app/lib/application/protocol/protocol_message.dart`
- Add factories:
  - `ProtocolMessage.joinRequest({participantId, displayName, sessionId, generation})`
  - `ProtocolMessage.joinAccepted({sessionId, roomId, hostParticipantId, participantId, generation})`
  - `ProtocolMessage.joinRejected({sessionId, reason, generation})`
  - `ProtocolMessage.roomClosed({senderId, roomId, sessionId, reason, generation})` — enhance existing

### 3. NetworkRepository: Room Lifecycle Logic
**File**: `app/lib/application/repositories/network_repository.dart`

**New fields**:
- `_roomLifecycleState` (RoomLifecycleState)
- `_roomRole` (RoomRole)
- `_participantDisplayName` (String?)
- `_participantJoined` (bool) — host tracks if participant has joined
- `_roomClosedReason` (String?)

**Host-side logic** (`_handleHello`):
1. On HELLO in `listening` state → transition to `handshaking` (existing)
2. After version check passes, send WELCOME (existing)
3. **NEW**: Wait for JOIN_REQUEST from participant
4. On JOIN_REQUEST:
   - If no participant joined yet → send JOIN_ACCEPTED, set `_participantJoined = true`, emit room lifecycle READY
   - If participant already joined → send JOIN_REJECTED (reason: roomFull)

**Participant-side logic** (`_handleWelcome`):
1. On WELCOME → transition to `handshaking` (existing)
2. **NEW**: Immediately send JOIN_REQUEST with displayName (if any) and participantId
3. On JOIN_ACCEPTED → emit room lifecycle READY
4. On JOIN_REJECTED → emit room lifecycle CLOSED with reason

**Room closure**:
- Host: `closeRoom()` method → send ROOM_CLOSED, transition to CLOSED, disconnect
- Participant: `leaveRoom()` method → transition to CLOSED locally, disconnect (no mandatory message)
- Both sides: on receiving ROOM_CLOSED → transition to CLOSED, emit distinct message

**State stream**: Add `roomLifecycleStateStream` (Stream<RoomLifecycleState>)

### 4. Room Lifecycle Provider (NEW)
**File**: `app/lib/application/providers/room_lifecycle_provider.dart` (NEW)

`RoomLifecycleNotifier` wraps `NetworkRepository` and exposes:
- `roomLifecycleState` (RoomLifecycleState)
- `roomRole` (RoomRole)
- `roomId`, `sessionId`
- `participantJoined` (bool, host only)
- `closeRoom()` / `leaveRoom()` actions
- Maps connection state + protocol messages → room lifecycle state

### 5. Update Flow Providers
**Files**: `create_room_flow_provider.dart`, `join_room_flow_provider.dart`
- Subscribe to `roomLifecycleStateStream` instead of (or in addition to) connection state
- Update status enums to align with room lifecycle (or keep separate, map explicitly)
- Handle JOIN_REJECTED, ROOM_CLOSED protocol messages

### 6. Room Screen: Leave/End Room UI
**File**: `app/lib/presentation/screens/room_screen.dart`

**AppBar actions**:
- Host: "End Room" button (red, destructive)
- Participant: "Leave Room" button

**Behavior**:
- Host tap "End Room" → `closeRoom()` → shows "Room ended" locally, sends ROOM_CLOSED
- Participant tap "Leave Room" → `leaveRoom()` → shows "You left the room" locally
- On receiving ROOM_CLOSED:
  - Participant: show "Host ended the room"
  - Host: show "Participant left" (on TCP disconnect detection)

**Distinct error messages** (not generic):
- "Host ended the room" (ROOM_CLOSED from host)
- "Participant left" (TCP disconnect, host side)
- "Room full" (JOIN_REJECTED)
- "Handshake failed" (existing)

### 7. Unit Tests
**File**: `app/test/room_lifecycle_test.dart` (NEW)
- CREATED → DISCOVERABLE transition (host starts hosting)
- DISCOVERABLE → JOINING → READY (participant joins, handshake + join request)
- READY → CLOSED (host closes room)
- READY → CLOSED (participant leaves)
- JOIN_REQUEST while participant exists → JOIN_REJECTED
- ROOM_CLOSED received → distinct message on other side

**File**: `app/test/protocol/protocol_message_join_test.dart` (NEW)
- JOIN_REQUEST serialization/deserialization
- JOIN_ACCEPTED serialization/deserialization
- JOIN_REJECTED serialization/deserialization
- ROOM_CLOSED with reason field

**File**: `app/test/application/repositories/network_repository_room_lifecycle_test.dart` (NEW)
- Host receives HELLO → sends WELCOME → waits for JOIN_REQUEST
- Host receives JOIN_REQUEST (no participant) → sends JOIN_ACCEPTED, transitions READY
- Host receives JOIN_REQUEST (participant exists) → sends JOIN_REJECTED
- Participant receives WELCOME → sends JOIN_REQUEST
- Participant receives JOIN_ACCEPTED → transitions READY
- Participant receives JOIN_REJECTED → transitions CLOSED
- Host calls closeRoom() → sends ROOM_CLOSED, transitions CLOSED
- Participant calls leaveRoom() → transitions CLOSED locally
- Participant receives ROOM_CLOSED → transitions CLOSED, distinct message
- Host detects participant disconnect → distinct "Participant left" message

### 8. Widget Tests
**File**: `app/test/room_screen_lifecycle_test.dart` (NEW)
- Room screen shows "Waiting for participant..." in DISCOVERABLE
- Room screen shows "Joining..." in JOINING
- Room screen shows "Ready" in READY
- Host sees "End Room" button, participant sees "Leave Room" button
- Host ending room shows "Room ended" locally + "Host ended the room" on participant
- Participant leaving shows "You left the room" locally + "Participant left" on host
- JOIN_REJECTED shows "Room full" message

### 9. Validation
- `flutter analyze`: clean
- `flutter test`: all existing + new tests pass
- `flutter build apk --debug`: succeeds

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Separate `RoomLifecycleState` enum | Per task: never confuse with `NetworkConnectionState` |
| JOIN_REQUEST after WELCOME | Handshake proves protocol compatibility; join request = formal membership |
| Host sends JOIN_ACCEPTED only after JOIN_REQUEST | Deliberate additional step — "READY" = member of room, not just pipe open |
| JOIN_REJECTED for second participant | Forward-looking stub for Task 3; clean rejection not silent hang |
| ROOM_CLOSED with reason field | Enables distinct UI messages ("Host ended" vs "Participant left") |
| Participant leave = local CLOSED + disconnect | No mandatory message; host detects via TCP disconnect |
| RoomLifecycleProvider as separate layer | Keeps flow providers focused on their flows; room lifecycle is cross-cutting |

---

## Files to Create
1. `app/lib/application/room/room_lifecycle.dart`
2. `app/lib/application/providers/room_lifecycle_provider.dart`
3. `app/test/room_lifecycle_test.dart`
4. `app/test/protocol/protocol_message_join_test.dart`
5. `app/test/application/repositories/network_repository_room_lifecycle_test.dart`
6. `app/test/room_screen_lifecycle_test.dart`

## Files to Modify
1. `app/lib/application/protocol/protocol_constants.dart`
2. `app/lib/application/protocol/protocol_message.dart`
3. `app/lib/application/repositories/network_repository.dart`
4. `app/lib/application/providers/create_room_flow_provider.dart`
5. `app/lib/application/providers/join_room_flow_provider.dart`
6. `app/lib/presentation/screens/room_screen.dart`

---

## Verification Steps (Real Device)

### Path 1: Host closes room
1. Device A: Create Room → wait for "Waiting for participant..."
2. Device B: Join Room (enter Device A IP) → both show "Ready", exchange chat
3. Device A: Tap "End Room" → Device A shows "Room ended", returns to Home
4. Device B: Shows "Host ended the room", returns to Home

### Path 2: Participant leaves room
1. Device A: Create Room → wait
2. Device B: Join Room → both show "Ready", exchange chat
3. Device B: Tap "Leave Room" → Device B shows "You left the room", returns to Home
4. Device A: Shows "Participant left", returns to Home

### Path 3: Second joiner rejected
1. Device A: Create Room → wait
2. Device B: Join Room → both show "Ready"
3. Device C: Attempt Join Room (same IP) → Device C shows "Room full"
4. Device A & B: Unaffected, still in room

### Path 4: Full lifecycle (create → join → chat → close both ways)
- Verify all four transitions: CREATED → DISCOVERABLE → JOINING → READY → CLOSED
- Document exact manual steps, device models, network conditions

---

## Risks & Limitations

| Risk | Mitigation |
|------|------------|
| State machine ambiguity between connection/room states | Explicit naming, separate enums, clear mapping comments |
| Second joiner edge case not fully tested | Unit test for reject path; real-device test with 3rd device if available |
| ROOM_CLOSED delivery reliability | TCP is reliable; if participant already disconnected, host shows "Participant left" anyway |
| No host migration | Per DEC-036, MVP does not require it |

---

## Next Step
Implement the plan starting with:
1. `room_lifecycle.dart` (types)
2. Protocol constants/messages
3. NetworkRepository room lifecycle logic
4. RoomLifecycleProvider
5. Flow provider updates
6. Room screen UI
7. Tests