import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/soundmesh_theme.dart';
import '../../application/providers/create_room_flow_provider.dart';
import '../../application/providers/join_room_flow_provider.dart';
import '../../application/providers/room_lifecycle_provider.dart';
import '../../application/repositories/network_repository.dart';
import '../../application/protocol.dart';
import '../../application/room/room_lifecycle.dart';

enum MessageSource { self, remote }

class MessageLogEntry {
  final String message;
  final MessageSource source;
  final DateTime timestamp;

  MessageLogEntry({
    required this.message,
    required this.source,
    required this.timestamp,
  });
}

class RoomScreenState {
  final NetworkConnectionState connectionState;
  final RoomLifecycleState roomLifecycleState;
  final RoomRole roomRole;
  final List<MessageLogEntry> messageLog;
  final String? errorMessage;
  final String? closedReason;

  const RoomScreenState({
    this.connectionState = NetworkConnectionState.disconnected,
    this.roomLifecycleState = RoomLifecycleState.created,
    this.roomRole = RoomRole.host,
    this.messageLog = const [],
    this.errorMessage,
    this.closedReason,
  });

  static const _unset = Object();

  RoomScreenState copyWith({
    NetworkConnectionState? connectionState,
    RoomLifecycleState? roomLifecycleState,
    RoomRole? roomRole,
    List<MessageLogEntry>? messageLog,
    Object? errorMessage = _unset,
    Object? closedReason = _unset,
  }) {
    return RoomScreenState(
      connectionState: connectionState ?? this.connectionState,
      roomLifecycleState: roomLifecycleState ?? this.roomLifecycleState,
      roomRole: roomRole ?? this.roomRole,
      messageLog: messageLog ?? this.messageLog,
      // Unrelated events (chat messages, connection changes) must not wipe an
      // active error/closed banner; clearing is explicit via null.
      errorMessage: errorMessage == _unset ? this.errorMessage : errorMessage as String?,
      closedReason: closedReason == _unset ? this.closedReason : closedReason as String?,
    );
  }
}

class RoomScreenNotifier extends StateNotifier<RoomScreenState> {
  final NetworkRepository _networkRepository;
  final RoomLifecycleNotifier _roomLifecycleNotifier;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _protocolMessageSubscription;
  StreamSubscription? _roomLifecycleSubscription;
  Timer? _errorClearTimer;

  RoomScreenNotifier(this._networkRepository, this._roomLifecycleNotifier) : super(const RoomScreenState()) {
    _stateSubscription = _networkRepository.connectionStateStream.listen((connState) {
      state = state.copyWith(connectionState: connState);
    });

    _messageSubscription = _networkRepository.messageStream.listen((message) {
      final entry = MessageLogEntry(
        message: message,
        source: MessageSource.remote,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messageLog: [...state.messageLog, entry],
      );
    });

    _protocolMessageSubscription = _networkRepository.protocolMessageStream.listen((protocolMessage) {
      final messageType = ProtocolMessageTypeX.fromWireValue(protocolMessage.messageType);
      if (messageType == ProtocolMessageType.versionRejected) {
        _setError('Protocol version mismatch: host v${protocolMessage.payload?['hostVersion'] ?? '?'} vs this device v$currentProtocolVersion');
      } else if (messageType == ProtocolMessageType.error) {
        final errorCode = protocolMessage.payload?['errorCode'] as String?;
        final errorMessage = protocolMessage.payload?['errorMessage'] as String?;
        if (errorCode == 'PROTOCOL_DECODE_ERROR') {
          _setError('Protocol error: $errorMessage');
        }
      }
    });

    _roomLifecycleSubscription = _roomLifecycleNotifier.stream.listen((lifecycleData) {
      state = state.copyWith(
        roomLifecycleState: lifecycleData.lifecycleState,
        roomRole: lifecycleData.role,
        closedReason: lifecycleData.closedReason,
      );
    });
  }

  void _setError(String error) {
    _errorClearTimer?.cancel();
    state = state.copyWith(errorMessage: error);
    _errorClearTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        state = state.copyWith(errorMessage: null);
      }
    });
  }

  void clearError() {
    _errorClearTimer?.cancel();
    state = state.copyWith(errorMessage: null);
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final success = await _networkRepository.sendChatMessage(message);
    if (success) {
      final entry = MessageLogEntry(
        message: message,
        source: MessageSource.self,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messageLog: [...state.messageLog, entry],
      );
    }
  }

  void disconnect() {
    _networkRepository.disconnect();
  }

  Future<void> closeRoom() async {
    await _roomLifecycleNotifier.closeRoom();
  }

  Future<void> leaveRoom() async {
    await _roomLifecycleNotifier.leaveRoom();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    _protocolMessageSubscription?.cancel();
    _roomLifecycleSubscription?.cancel();
    _errorClearTimer?.cancel();
    super.dispose();
  }
}

final roomScreenProvider =
    StateNotifierProvider<RoomScreenNotifier, RoomScreenState>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  final roomLifecycleNotifier = ref.watch(roomLifecycleProvider.notifier);
  return RoomScreenNotifier(networkRepo, roomLifecycleNotifier);
});

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenState = ref.watch(roomScreenProvider);
    final createState = ref.watch(createRoomFlowProvider);
    final lifecycleState = ref.watch(roomLifecycleProvider);
    final isHost = lifecycleState.role == RoomRole.host;
    final isReady = lifecycleState.lifecycleState == RoomLifecycleState.ready;
    final isHandshaking = lifecycleState.lifecycleState == RoomLifecycleState.joining;
    final isListening = lifecycleState.lifecycleState == RoomLifecycleState.discoverable;
    final isClosed = lifecycleState.lifecycleState == RoomLifecycleState.closed;
    final showHostAddress = isHost && (isListening || isHandshaking || isReady);

    ref.listen<RoomScreenState>(roomScreenProvider, (previous, next) {
      if (next.messageLog.length > (previous?.messageLog.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: SoundMeshColors.background,
      appBar: AppBar(
        backgroundColor: SoundMeshColors.surface,
        title: Text(
          _getTitle(lifecycleState),
          style: const TextStyle(
            color: SoundMeshColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: isClosed
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                color: SoundMeshColors.primaryText,
                onPressed: () {
                  ref.read(roomScreenProvider.notifier).disconnect();
                  ref.read(createRoomFlowProvider.notifier).reset();
                  ref.read(joinRoomFlowProvider.notifier).reset();
                  Navigator.pop(context);
                },
              ),
        actions: [
          if (!isClosed) _buildRoomActionButton(lifecycleState, isHost),
          _buildConnectionIndicator(screenState.connectionState, isHandshaking, isListening),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (showHostAddress) _buildHostAddressInfo(createState),
            if (isHandshaking) _buildHandshakingIndicator(),
            if (isListening) _buildListeningIndicator(),
            if (isClosed) _buildClosedBanner(screenState.closedReason ?? 'Room closed'),
            if (screenState.errorMessage != null) _buildErrorBanner(screenState.errorMessage!),
            _buildMessageLog(screenState.messageLog, isReady),
            _buildMessageInput(screenState, isReady && !isClosed),
          ],
        ),
      ),
    );
  }

  String _getTitle(RoomLifecycleStateData lifecycleState) {
    switch (lifecycleState.lifecycleState) {
      case RoomLifecycleState.created:
        return lifecycleState.role == RoomRole.host ? 'Creating Room...' : 'Joining Room...';
      case RoomLifecycleState.discoverable:
        return 'Host (Waiting)';
      case RoomLifecycleState.joining:
        return 'Participant (Joining...)';
      case RoomLifecycleState.ready:
        return lifecycleState.role == RoomRole.host ? 'Host' : 'Participant';
      case RoomLifecycleState.closed:
        return 'Room Closed';
    }
  }

  Widget _buildRoomActionButton(RoomLifecycleStateData lifecycleState, bool isHost) {
    if (isHost) {
      return IconButton(
        tooltip: 'End Room',
        onPressed: () => _showEndRoomDialog(),
        icon: const Icon(Icons.stop_rounded, color: SoundMeshColors.error, size: 24),
      );
    } else {
      return IconButton(
        tooltip: 'Leave Room',
        onPressed: () => _showLeaveRoomDialog(),
        icon: const Icon(Icons.exit_to_app_rounded, color: SoundMeshColors.warning, size: 24),
      );
    }
  }

  void _showEndRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SoundMeshColors.surface,
        title: const Text('End Room', style: TextStyle(color: SoundMeshColors.primaryText)),
        content: const Text('This will end the room for all participants.', style: TextStyle(color: SoundMeshColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: SoundMeshColors.mutedText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SoundMeshColors.error),
            onPressed: () {
              Navigator.pop(context);
              ref.read(roomScreenProvider.notifier).closeRoom();
            },
            child: const Text('End Room', style: TextStyle(color: SoundMeshColors.primaryText)),
          ),
        ],
      ),
    );
  }

  void _showLeaveRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SoundMeshColors.surface,
        title: const Text('Leave Room', style: TextStyle(color: SoundMeshColors.primaryText)),
        content: const Text('You will leave this room. The host can continue with other participants.', style: TextStyle(color: SoundMeshColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: SoundMeshColors.mutedText)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(roomScreenProvider.notifier).leaveRoom();
              ref.read(joinRoomFlowProvider.notifier).reset();
            },
            child: const Text('Leave Room', style: TextStyle(color: SoundMeshColors.primaryText)),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedBanner(String reason) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: SoundMeshColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoundMeshColors.error.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: SoundMeshColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(
                color: SoundMeshColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostAddressInfo(CreateRoomFlowState flowState) {
    final address =
        '${flowState.localIpAddress ?? '...'}:${flowState.port ?? 8765}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SoundMeshColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoundMeshColors.elevatedSurface, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.dns_rounded,
            size: 20,
            color: SoundMeshColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Host address',
                  style: TextStyle(
                    color: SoundMeshColors.mutedText,
                    fontSize: 10,
                  ),
                ),
                Text(
                  address,
                  style: const TextStyle(
                    color: SoundMeshColors.primaryText,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Copy host address',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, color: SoundMeshColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildHandshakingIndicator() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SoundMeshColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoundMeshColors.accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(SoundMeshColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Handshaking...',
              style: TextStyle(
                color: SoundMeshColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningIndicator() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SoundMeshColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoundMeshColors.warning.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(SoundMeshColors.warning),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Waiting for participant...',
              style: TextStyle(
                color: SoundMeshColors.warning,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SoundMeshColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SoundMeshColors.error.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: () => ref.read(roomScreenProvider.notifier).clearError(),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: SoundMeshColors.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: SoundMeshColors.error,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.close_rounded, color: SoundMeshColors.error.withValues(alpha: 0.7), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator(NetworkConnectionState connectionState, bool isHandshaking, bool isListening) {
    Color color;
    String label;

    if (isHandshaking) {
      color = SoundMeshColors.accent;
      label = 'Handshaking';
    } else if (isListening) {
      color = SoundMeshColors.warning;
      label = 'Waiting';
    } else {
      switch (connectionState) {
        case NetworkConnectionState.ready:
          color = SoundMeshColors.success;
          label = 'Ready';
          break;
        case NetworkConnectionState.connected:
          color = SoundMeshColors.success;
          label = 'Connected';
          break;
        case NetworkConnectionState.connecting:
          color = SoundMeshColors.warning;
          label = 'Connecting';
          break;
        case NetworkConnectionState.handshaking:
          color = SoundMeshColors.accent;
          label = 'Handshaking';
          break;
        case NetworkConnectionState.listening:
          color = SoundMeshColors.warning;
          label = 'Waiting';
          break;
        case NetworkConnectionState.failed:
          color = SoundMeshColors.error;
          label = 'Failed';
          break;
        case NetworkConnectionState.reconnecting:
          color = SoundMeshColors.warning;
          label = 'Reconnecting';
          break;
        case NetworkConnectionState.disconnected:
          color = SoundMeshColors.mutedText;
          label = 'Disconnected';
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageLog(List<MessageLogEntry> messageLog, bool isReady) {
    if (messageLog.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: SoundMeshColors.mutedText,
              ),
              const SizedBox(height: 16),
              Text(
                isReady ? 'No messages yet' : 'Waiting for handshake...',
                style: TextStyle(
                  color: SoundMeshColors.mutedText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isReady ? 'Send a message' : 'Protocol handshake in progress',
                style: TextStyle(
                  color: SoundMeshColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: messageLog.length,
        itemBuilder: (context, index) {
          final entry = messageLog[index];
          return _buildMessageBubble(entry);
        },
      ),
    );
  }

  Widget _buildMessageBubble(MessageLogEntry entry) {
    final isSelf = entry.source == MessageSource.self;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelf
                  ? SoundMeshColors.accent
                  : SoundMeshColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isSelf ? 16 : 4),
                bottomRight: Radius.circular(isSelf ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  style: const TextStyle(
                    color: SoundMeshColors.primaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(entry.timestamp),
                  style: TextStyle(
                    color: isSelf
                        ? SoundMeshColors.primaryText.withValues(alpha: 0.7)
                        : SoundMeshColors.mutedText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageInput(RoomScreenState screenState, bool canSend) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: SoundMeshColors.surface,
        border: Border(
          top: BorderSide(
            color: SoundMeshColors.elevatedSurface,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: SoundMeshColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                enabled: canSend,
                style: const TextStyle(
                  color: SoundMeshColors.primaryText,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: canSend ? 'Type a message...' : 'Waiting for handshake...',
                  hintStyle: TextStyle(color: SoundMeshColors.mutedText),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: canSend ? (value) => _sendMessage() : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: canSend
                ? SoundMeshColors.accent
                : SoundMeshColors.mutedText,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: canSend ? _sendMessage : null,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.send_rounded,
                  color: SoundMeshColors.primaryText,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      ref.read(roomScreenProvider.notifier).sendMessage(message);
      _messageController.clear();
    }
  }
}