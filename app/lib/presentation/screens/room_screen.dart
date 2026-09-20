import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/design_system/index.dart';
import '../../application/providers/create_room_flow_provider.dart';
import '../../application/providers/join_room_flow_provider.dart';
import '../../application/providers/room_lifecycle_provider.dart';
import '../../application/providers/capture_provider.dart';
import '../../application/repositories/network_repository.dart';
import '../../application/protocol.dart';
import '../../application/room/room_lifecycle.dart';
import '../components/surface.dart';

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
    final captureUiState = ref.watch(captureStateProvider);
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
      backgroundColor: SMColors.background,
      appBar: AppBar(
        backgroundColor: SMColors.surface,
        title: Text(
          _getTitle(lifecycleState),
          style: TextStyle(
            color: SMColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: isClosed
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                color: SMColors.primaryText,
                onPressed: () {
                  ref.read(roomScreenProvider.notifier).disconnect();
                  ref.read(createRoomFlowProvider.notifier).reset();
                  ref.read(joinRoomFlowProvider.notifier).reset();
                  Navigator.pop(context);
                },
              ),
        actions: [
          if (!isClosed && isHost && (isListening || isHandshaking || isReady))
            IconButton(
              tooltip: 'Show QR Code',
              onPressed: () => _showQrDialog(createState),
              icon: const Icon(Icons.qr_code_rounded, color: SMColors.soundmeshBlue, size: 24),
            ),
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
            _buildStatusSection(lifecycleState, screenState, captureUiState),
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
        icon: const Icon(Icons.stop_rounded, color: SMColors.error, size: 24),
      );
    } else {
      return IconButton(
        tooltip: 'Leave Room',
        onPressed: () => _showLeaveRoomDialog(),
        icon: const Icon(Icons.exit_to_app_rounded, color: SMColors.warning, size: 24),
      );
    }
  }

  void _showEndRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SMColors.surfaceHigh,
        title: const Text('End Room', style: TextStyle(color: SMColors.primaryText)),
        content: const Text('This will end the room for all participants.', style: TextStyle(color: SMColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: SMColors.mutedText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SMColors.error),
            onPressed: () {
              Navigator.pop(context);
              ref.read(roomScreenProvider.notifier).closeRoom();
            },
            child: const Text('End Room', style: TextStyle(color: SMColors.primaryText)),
          ),
        ],
      ),
    );
  }

  void _showLeaveRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SMColors.surfaceHigh,
        title: const Text('Leave Room', style: TextStyle(color: SMColors.primaryText)),
        content: const Text('You will leave this room. The host can continue with other participants.', style: TextStyle(color: SMColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: SMColors.mutedText)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(roomScreenProvider.notifier).leaveRoom();
              ref.read(joinRoomFlowProvider.notifier).reset();
            },
            child: const Text('Leave Room', style: TextStyle(color: SMColors.primaryText)),
          ),
        ],
      ),
    );
  }

  void _showQrDialog(CreateRoomFlowState createState) {
    final roomId = createState.roomId;
    final hostIp = createState.localIpAddress;
    final port = createState.port ?? 8765;
    final joinCode = createState.joinCode;

    if (roomId == null || hostIp == null || joinCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room information not ready yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final payload = JoinPayload(
      roomId: roomId,
      hostAddress: hostIp,
      hostPort: port,
      protocolVersion: currentProtocolVersion,
      code: joinCode,
    );

    final uriString = payload.toJoinUri();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SMColors.surfaceHigh,
        title: const Text('Room QR Code', style: TextStyle(color: SMColors.primaryText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240.0,
              height: 240.0,
              child: QrImageView(
                data: uriString,
                version: QrVersions.auto,
                size: 240.0,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: SMColors.background,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: SMColors.background,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan with SoundMesh to join',
              style: TextStyle(color: SMColors.secondaryText, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              uriString,
              style: TextStyle(
                color: SMColors.mutedText,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: SMColors.mutedText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SMColors.soundmeshBlue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: uriString));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('QR code URI copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy URI', style: TextStyle(color: SMColors.primaryText)),
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
        color: SMColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SMRadius.large),
        border: Border.all(color: SMColors.error.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: SMColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(
                color: SMColors.error,
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
        color: SMColors.surfaceLow,
        borderRadius: BorderRadius.circular(SMRadius.large),
        border: Border.all(color: SMColors.outlineVariant.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.dns_rounded,
            size: 20,
            color: SMColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Host address',
                  style: TextStyle(
                    color: SMColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                Text(
                  address,
                  style: TextStyle(
                    color: SMColors.primaryText,
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
            icon: const Icon(Icons.copy_rounded, color: SMColors.soundmeshBlue),
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
        color: SMColors.soundmeshBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SMRadius.large),
        border: Border.all(color: SMColors.soundmeshBlue.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(SMColors.soundmeshBlue),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Handshaking...',
              style: TextStyle(
                color: SMColors.soundmeshBlue,
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
        color: SMColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SMRadius.large),
        border: Border.all(color: SMColors.warning.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(SMColors.warning),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Waiting for participant...',
              style: TextStyle(
                color: SMColors.warning,
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
        color: SMColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SMRadius.large),
        border: Border.all(color: SMColors.error.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: () => ref.read(roomScreenProvider.notifier).clearError(),
        borderRadius: BorderRadius.circular(SMRadius.large),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: SMColors.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(
                  color: SMColors.error,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.close_rounded, color: SMColors.error.withValues(alpha: 0.7), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator(NetworkConnectionState connectionState, bool isHandshaking, bool isListening) {
    Color color;
    String label;

    if (connectionState == NetworkConnectionState.reconnecting) {
      color = SMColors.warning;
      label = 'Reconnecting';
    } else if (isHandshaking) {
      color = SMColors.soundmeshBlue;
      label = 'Handshaking';
    } else if (isListening) {
      color = SMColors.warning;
      label = 'Waiting';
    } else {
      switch (connectionState) {
        case NetworkConnectionState.ready:
          color = SMColors.success;
          label = 'Ready';
          break;
        case NetworkConnectionState.connected:
          color = SMColors.success;
          label = 'Connected';
          break;
        case NetworkConnectionState.connecting:
          color = SMColors.warning;
          label = 'Connecting';
          break;
        case NetworkConnectionState.handshaking:
          color = SMColors.soundmeshBlue;
          label = 'Handshaking';
          break;
        case NetworkConnectionState.listening:
          color = SMColors.warning;
          label = 'Waiting';
          break;
        case NetworkConnectionState.failed:
          color = SMColors.error;
          label = 'Failed';
          break;
        case NetworkConnectionState.reconnecting:
          color = SMColors.warning;
          label = 'Reconnecting';
          break;
        case NetworkConnectionState.disconnected:
          color = SMColors.mutedText;
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

  /// Builds the status section showing role, devices, capture, sync, and audio session.
  /// Uses real data where available; honest placeholders elsewhere.
  Widget _buildStatusSection(
    RoomLifecycleStateData lifecycleState,
    RoomScreenState screenState,
    CaptureUiStateData captureState,
  ) {
    final isHost = lifecycleState.role == RoomRole.host;
    final isReady = lifecycleState.lifecycleState == RoomLifecycleState.ready;

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Role
            _buildStatusCard(
              icon: isHost ? Icons.wifi_tethering : Icons.devices,
              iconColor: isHost ? SMColors.soundmeshBlue : SMColors.secondaryText,
              title: isHost ? 'Host' : 'Participant',
              subtitle: isHost
                  ? 'You are hosting this room'
                  : 'You are connected as a participant',
            ),
            const SizedBox(height: 12),

            // Connection state
            _buildStatusCard(
              icon: _connectionIcon(screenState.connectionState),
              iconColor: _connectionColor(screenState.connectionState),
              title: 'Connection',
              subtitle: _connectionStatusText(screenState.connectionState),
            ),
            const SizedBox(height: 12),

            // Device count (honest placeholder - no real device list exists)
            _buildStatusCard(
              icon: Icons.devices,
              iconColor: SMColors.mutedText,
              title: 'Connected Devices',
              subtitle: _buildDeviceCountContent(isReady),
              showPlaceholderBadge: true,
            ),
            const SizedBox(height: 12),

            // Device list (names only, honest placeholder)
            if (isReady) _buildDeviceListPlaceholder(),

            // Capture state (REAL data from captureStateProvider)
            _buildStatusCard(
              icon: _captureIcon(captureState.state),
              iconColor: _captureColor(captureState.state),
              title: 'Audio Capture',
              subtitle: _captureStatusText(captureState),
            ),
            const SizedBox(height: 12),

            // Audio session state (honest placeholder - no separate audio session state exists)
            _buildStatusCard(
              icon: Icons.graphic_eq,
              iconColor: SMColors.mutedText,
              title: 'Audio Session',
              subtitle: 'Audio session state is not yet tracked.\n'
                  'Synchronization state and playback scheduling\n'
                  'are not yet implemented.',
              showPlaceholderBadge: true,
            ),
            const SizedBox(height: 12),

            // Sync quality (honest placeholder - no real offset/drift metrics)
            _buildStatusCard(
              icon: Icons.sync,
              iconColor: _syncColor(lifecycleState.lifecycleState),
              title: 'Synchronization',
              subtitle: _syncStatusText(lifecycleState.lifecycleState, isReady),
              showPlaceholderBadge: !isReady,
            ),
          ],
        ),
      ),
    );
  }

  String _buildDeviceCountContent(bool isReady) {
    // No real device list exists in the codebase yet.
    // NetworkRepository only tracks a single _participantJoined boolean.
    if (!isReady) {
      return 'Waiting for devices to connect';
    }
    return 'Device tracking not yet implemented';
  }

  Widget _buildDeviceListPlaceholder() {
    return SMCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.devices,
                size: SMDimensions.iconSize,
                color: SMColors.mutedText,
              ),
              SizedBox(width: SMSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Devices in this Room',
                      style: SMTypography.heading.copyWith(color: SMColors.primaryText),
                    ),
                    SizedBox(height: SMSpacing.xs),
                    Text(
                      'Names will appear here once device tracking is implemented.\n'
                      'This is a placeholder — not a fabricated list.',
                      style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: SMSpacing.md),
          const Text(
            '[UI SCAFFOLDING — NO REAL DEVICE DATA]',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SMColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  IconData _connectionIcon(NetworkConnectionState state) {
    switch (state) {
      case NetworkConnectionState.ready:
        return Icons.circle;
      case NetworkConnectionState.connected:
        return Icons.circle;
      case NetworkConnectionState.connecting:
        return Icons.wifi;
      case NetworkConnectionState.handshaking:
        return Icons.handshake;
      case NetworkConnectionState.listening:
        return Icons.wifi_tethering;
      case NetworkConnectionState.failed:
        return Icons.error;
      case NetworkConnectionState.reconnecting:
        return Icons.wifi_protected_setup;
      case NetworkConnectionState.disconnected:
        return Icons.cancel;
    }
  }

  Color _connectionColor(NetworkConnectionState state) {
    switch (state) {
      case NetworkConnectionState.ready:
        return SMColors.success;
      case NetworkConnectionState.connected:
        return SMColors.success;
      case NetworkConnectionState.connecting:
        return SMColors.warning;
      case NetworkConnectionState.handshaking:
        return SMColors.soundmeshBlue;
      case NetworkConnectionState.listening:
        return SMColors.warning;
      case NetworkConnectionState.failed:
        return SMColors.error;
      case NetworkConnectionState.reconnecting:
        return SMColors.warning;
      case NetworkConnectionState.disconnected:
        return SMColors.mutedText;
    }
  }

  String _connectionStatusText(NetworkConnectionState state) {
    switch (state) {
      case NetworkConnectionState.ready:
        return 'All systems connected';
      case NetworkConnectionState.connected:
        return 'Network connected';
      case NetworkConnectionState.connecting:
        return 'Establishing connection';
      case NetworkConnectionState.handshaking:
        return 'Negotiating protocol';
      case NetworkConnectionState.listening:
        return 'Listening for participants';
      case NetworkConnectionState.failed:
        return 'Connection failed';
      case NetworkConnectionState.reconnecting:
        return 'Reconnecting to host';
      case NetworkConnectionState.disconnected:
        return 'Not connected';
    }
  }

  IconData _captureIcon(CaptureUiState state) {
    switch (state) {
      case CaptureUiState.idle:
        return Icons.stop;
      case CaptureUiState.requestingPermission:
        return Icons.lock;
      case CaptureUiState.permissionGranted:
        return Icons.check_circle;
      case CaptureUiState.permissionDenied:
        return Icons.cancel;
      case CaptureUiState.capturing:
        return Icons.graphic_eq;
      case CaptureUiState.stopped:
        return Icons.stop;
      case CaptureUiState.failed:
        return Icons.error;
    }
  }

  Color _captureColor(CaptureUiState state) {
    switch (state) {
      case CaptureUiState.idle:
      case CaptureUiState.stopped:
        return SMColors.mutedText;
      case CaptureUiState.requestingPermission:
        return SMColors.warning;
      case CaptureUiState.permissionGranted:
        return SMColors.success;
      case CaptureUiState.permissionDenied:
        return SMColors.error;
      case CaptureUiState.capturing:
        return SMColors.soundmeshBlue;
      case CaptureUiState.failed:
        return SMColors.error;
    }
  }

  String _captureStatusText(CaptureUiStateData captureState) {
    switch (captureState.state) {
      case CaptureUiState.idle:
        return 'Idle';
      case CaptureUiState.requestingPermission:
        return 'Requesting permission…';
      case CaptureUiState.permissionGranted:
        return 'Permission granted';
      case CaptureUiState.permissionDenied:
        return 'Permission denied';
      case CaptureUiState.capturing:
        return 'Capturing audio';
      case CaptureUiState.stopped:
        return 'Stopped';
      case CaptureUiState.failed:
        final error = captureState.error;
        return 'Capture failed: $error';
    }
  }

  Color _syncColor(RoomLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case RoomLifecycleState.ready:
        return SMColors.success;
      case RoomLifecycleState.joining:
      case RoomLifecycleState.discoverable:
        return SMColors.warning;
      case RoomLifecycleState.created:
      case RoomLifecycleState.closed:
        return SMColors.mutedText;
    }
  }

  String _syncStatusText(RoomLifecycleState lifecycleState, bool isReady) {
    if (isReady) {
      return 'Synchronized (basic)\n'
          'Note: Offset, drift, and confidence metrics\n'
          'are not yet available — this status reflects\n'
          'room readiness only.';
    }
    return 'Not yet synchronized';
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool showPlaceholderBadge = false,
  }) {
    return SMCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SMColors.surfaceContainer,
              borderRadius: BorderRadius.circular(SMRadius.medium),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          SizedBox(width: SMSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: SMTypography.bodyEmphasis.copyWith(color: SMColors.primaryText),
                ),
                SizedBox(height: SMSpacing.xs),
                Text(
                  subtitle,
                  style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
                ),
                if (showPlaceholderBadge) ...[
                  SizedBox(height: SMSpacing.xs),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: SMSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: SMColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(SMRadius.xs),
                    ),
                    child: Text(
                      'Not yet available',
                      style: TextStyle(
                        color: SMColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
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
                color: SMColors.mutedText,
              ),
              const SizedBox(height: 16),
              Text(
                isReady ? 'No messages yet' : 'Waiting for handshake...',
                style: TextStyle(
                  color: SMColors.mutedText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isReady ? 'Send a message' : 'Protocol handshake in progress',
                style: TextStyle(
                  color: SMColors.mutedText,
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
                  ? SMColors.soundmeshBlue
                  : SMColors.surfaceLow,
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
                  style: TextStyle(
                    color: isSelf ? SMColors.primaryText : SMColors.primaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(entry.timestamp),
                  style: TextStyle(
                    color: isSelf
                        ? SMColors.primaryText.withValues(alpha: 0.7)
                        : SMColors.mutedText,
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
      decoration: BoxDecoration(
        color: SMColors.surfaceLow,
        border: Border(
          top: BorderSide(
            color: SMColors.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: SMColors.background,
                borderRadius: BorderRadius.circular(SMRadius.full),
              ),
              child: TextField(
                controller: _messageController,
                enabled: canSend,
                style: TextStyle(
                  color: SMColors.primaryText,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: canSend ? 'Type a message...' : 'Waiting for handshake...',
                  hintStyle: TextStyle(color: SMColors.mutedText),
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
                ? SMColors.soundmeshBlue
                : SMColors.mutedText,
            borderRadius: BorderRadius.circular(SMRadius.full),
            child: InkWell(
              onTap: canSend ? _sendMessage : null,
              borderRadius: BorderRadius.circular(SMRadius.full),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.send_rounded,
                  color: SMColors.primaryText,
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
