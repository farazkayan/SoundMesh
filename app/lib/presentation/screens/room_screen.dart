import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/soundmesh_theme.dart';
import '../../application/providers/create_room_flow_provider.dart';
import '../../application/providers/join_room_flow_provider.dart';
import '../../application/repositories/network_repository.dart';

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
  final List<MessageLogEntry> messageLog;
  final String? errorMessage;

  const RoomScreenState({
    this.connectionState = NetworkConnectionState.disconnected,
    this.messageLog = const [],
    this.errorMessage,
  });

  RoomScreenState copyWith({
    NetworkConnectionState? connectionState,
    List<MessageLogEntry>? messageLog,
    String? errorMessage,
  }) {
    return RoomScreenState(
      connectionState: connectionState ?? this.connectionState,
      messageLog: messageLog ?? this.messageLog,
      errorMessage: errorMessage,
    );
  }
}

class RoomScreenNotifier extends StateNotifier<RoomScreenState> {
  final NetworkRepository _networkRepository;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _messageSubscription;

  RoomScreenNotifier(this._networkRepository) : super(const RoomScreenState()) {
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
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final success = await _networkRepository.sendMessage(message);
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

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }
}

final roomScreenProvider =
    StateNotifierProvider<RoomScreenNotifier, RoomScreenState>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  return RoomScreenNotifier(networkRepo);
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
    final isHost = createState.status == CreateRoomFlowStatus.hosted;

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
          isHost ? 'Host' : 'Participant',
          style: const TextStyle(
            color: SoundMeshColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
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
          _buildConnectionIndicator(screenState.connectionState),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isHost) _buildHostAddressInfo(createState),
            _buildMessageLog(screenState.messageLog),
            _buildMessageInput(screenState),
          ],
        ),
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

  Widget _buildConnectionIndicator(NetworkConnectionState connectionState) {
    Color color;
    String label;

    switch (connectionState) {
      case NetworkConnectionState.connected:
        color = SoundMeshColors.success;
        label = 'Connected';
      case NetworkConnectionState.connecting:
        color = SoundMeshColors.warning;
        label = 'Connecting';
      case NetworkConnectionState.failed:
        color = SoundMeshColors.error;
        label = 'Failed';
      case NetworkConnectionState.disconnected:
        color = SoundMeshColors.mutedText;
        label = 'Disconnected';
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

  Widget _buildMessageLog(List<MessageLogEntry> messageLog) {
    if (messageLog.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: SoundMeshColors.mutedText,
              ),
              SizedBox(height: 16),
              Text(
                'No messages yet',
                style: TextStyle(
                  color: SoundMeshColors.mutedText,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Send PING, HELLO, or any text',
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
                  style: TextStyle(
                    color: isSelf
                        ? SoundMeshColors.primaryText
                        : SoundMeshColors.primaryText,
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

  Widget _buildMessageInput(RoomScreenState screenState) {
    final isConnected = screenState.connectionState == NetworkConnectionState.connected;

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
                enabled: isConnected,
                style: const TextStyle(
                  color: SoundMeshColors.primaryText,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: SoundMeshColors.mutedText),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: isConnected
                ? SoundMeshColors.accent
                : SoundMeshColors.mutedText,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: isConnected ? _sendMessage : null,
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
