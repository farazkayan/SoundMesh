

enum RoomLifecycleState {
  created,
  discoverable,
  joining,
  ready,
  closed,
}

enum RoomRole {
  host,
  participant,
}

class RoomMember {
  final String participantId;
  final String? displayName;
  final RoomRole role;
  final DateTime joinedAt;

  RoomMember({
    required this.participantId,
    this.displayName,
    required this.role,
    required this.joinedAt,
  });
}

enum JoinRejectReason {
  roomFull,
  versionMismatch,
  closed,
  internalError,
}

extension JoinRejectReasonX on JoinRejectReason {
  String get wireValue {
    switch (this) {
      case JoinRejectReason.roomFull:
        return 'ROOM_FULL';
      case JoinRejectReason.versionMismatch:
        return 'VERSION_MISMATCH';
      case JoinRejectReason.closed:
        return 'CLOSED';
      case JoinRejectReason.internalError:
        return 'INTERNAL_ERROR';
    }
  }

  static JoinRejectReason? fromWireValue(String value) {
    switch (value) {
      case 'ROOM_FULL':
        return JoinRejectReason.roomFull;
      case 'VERSION_MISMATCH':
        return JoinRejectReason.versionMismatch;
      case 'CLOSED':
        return JoinRejectReason.closed;
      case 'INTERNAL_ERROR':
        return JoinRejectReason.internalError;
      default:
        return null;
    }
  }

  /// Human-readable reason for UI-facing state. Raw wire values must not leak
  /// into user-visible messages.
  String get friendlyMessage {
    switch (this) {
      case JoinRejectReason.roomFull:
        return 'Room is full';
      case JoinRejectReason.versionMismatch:
        return 'Protocol version mismatch';
      case JoinRejectReason.closed:
        return 'Room is closed';
      case JoinRejectReason.internalError:
        return 'Internal error';
    }
  }
}

extension RoomLifecycleStateX on RoomLifecycleState {
  String get displayName {
    switch (this) {
      case RoomLifecycleState.created:
        return 'Creating...';
      case RoomLifecycleState.discoverable:
        return 'Waiting for participant...';
      case RoomLifecycleState.joining:
        return 'Joining...';
      case RoomLifecycleState.ready:
        return 'Ready';
      case RoomLifecycleState.closed:
        return 'Closed';
    }
  }

  String get description {
    switch (this) {
      case RoomLifecycleState.created:
        return 'Room object exists, not yet discoverable';
      case RoomLifecycleState.discoverable:
        return 'Host is listening for participants';
      case RoomLifecycleState.joining:
        return 'Participant handshake complete, join request pending';
      case RoomLifecycleState.ready:
        return 'Participant formally joined the room';
      case RoomLifecycleState.closed:
        return 'Room has ended';
    }
  }
}