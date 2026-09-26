import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/index.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_types.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/application/providers/capture_provider.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';

class RoomDashboardScreen extends ConsumerWidget {
  const RoomDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(applicationStateProvider);
    final createState = ref.watch(createRoomFlowProvider);
    final captureState = ref.watch(captureStateProvider);
    final lifecycleState = ref.watch(roomLifecycleProvider);

    // Determine if background usage modal should show
    final isHost = appState.isHost == true;
    final isInRoom = _isInRoomState(appState.state);
    final backgroundUsageDisabled = captureState.isIgnoringBatteryOptimizations == false;
    final showBackgroundUsageModal = isHost && isInRoom && backgroundUsageDisabled;

    // Determine if host-ended-room modal should show for participant
    final showHostEndedModal = !isHost && lifecycleState.hostEndedRoom && isInRoom;
    // Determine if host-ended-room modal should show for host (intentional shutdown)
    final showHostEndedModalForHost = isHost && lifecycleState.hostEndedRoom;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: SMSpacing.xl,
                vertical: SMSpacing.xl,
              ),
              child: _buildContent(context, ref, appState, createState),
            ),
          ),
          // Background usage required modal - only for host in room
          if (showBackgroundUsageModal)
            const BackgroundUsageRequiredModal(),
          // Host ended room modal - only for participant when host ends room
          if (showHostEndedModal)
            const _HostEndedRoomModal(),
          // Host ended room modal - for host when they intentionally end the room
          if (showHostEndedModalForHost)
            const _YouEndedRoomModal(),
        ],
      ),
    );
  }

  bool _isInRoomState(SMAppState state) {
    return state == SMAppState.roomReady ||
        state == SMAppState.ready ||
        state == SMAppState.playing ||
        state == SMAppState.paused;
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    CreateRoomFlowState createState,
  ) {
    final lifecycleState = ref.watch(roomLifecycleProvider);
    final captureState = ref.watch(captureStateProvider);
    final screenError = lifecycleState.errorMessage;

    final state = appState.state;
    final participantJoined = lifecycleState.participantJoined;
    final deviceCount =
        1 + (participantJoined ? 1 : 0); // Host + participant if joined

    // Determine room status text from lifecycle state
    final roomStatusText = _getRoomStatusText(
      lifecycleState,
      createState,
      appState,
    );

    switch (state) {
      case SMAppState.error:
        return Column(
          children: [
            SMEmptyState.error(
              title: 'Room Error',
              message:
                  appState.message ?? 'Something went wrong with the room.',
              icon: Icons.error_outline,
              onRetry: () => StateProvider.of(context).leaveRoom(),
            ),
            SizedBox(height: SMSpacing.xxl),
          ],
        );

      case SMAppState.preparing:
        return _preparingContent(appState);

      case SMAppState.ready:
        return _readyContent(
          context,
          ref,
          appState,
          createState,
          lifecycleState,
          captureState,
          deviceCount,
          participantJoined,
          roomStatusText,
          screenError,
        );

      case SMAppState.playing:
      case SMAppState.paused:
        return _sessionStatusContent(
          context,
          ref,
          appState,
          createState,
          lifecycleState,
          captureState,
          deviceCount,
          participantJoined,
          roomStatusText,
          screenError,
        );

      case SMAppState.stopping:
        return _stoppingContent(appState);

      case SMAppState.roomReady:
        return _roomReadyContent(
          context,
          ref,
          appState,
          createState,
          lifecycleState,
          captureState,
          deviceCount,
          participantJoined,
          roomStatusText,
          screenError,
        );

      case SMAppState.idle:
      case SMAppState.creatingRoom:
      case SMAppState.joiningRoom:
        return _notInRoomContent(context);
    }
  }

  Widget _roomReadyContent(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    CreateRoomFlowState createState,
    RoomLifecycleStateData lifecycleState,
    CaptureUiStateData captureState,
    int deviceCount,
    bool participantJoined,
    String roomStatusText,
    String? screenError,
  ) {
    final isHost = appState.isHost == true;
    final joinCode = appState.joinCode ?? '';
    final isValidCode = isValidRoomCode(joinCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Room identity with status
        _roomIdentityHeader(
          context,
          appState,
          createState,
          lifecycleState,
          roomStatusText,
        ),
        SizedBox(height: SMSpacing.xl),

        // Error banner if any
        if (screenError != null) ...[
          _buildErrorBanner(screenError),
          SizedBox(height: SMSpacing.lg),
        ],

        // Participant view: simple confirmation without share affordance
        if (!isHost && joinCode.isNotEmpty) ...[
          SMCard(
            elevated: true,
            padding: EdgeInsets.all(SMSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  size: SMDimensions.emptyIconSize * 0.7,
                  color: SMColors.success,
                ),
                SizedBox(height: SMSpacing.lg),
                Text(
                  'Code Confirmed',
                  style: SMTypography.heading.copyWith(
                    color: SMColors.primaryText,
                  ),
                ),
                SizedBox(height: SMSpacing.md),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SMSpacing.xl,
                    vertical: SMSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: SMColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(SMRadius.large),
                    border: Border.all(
                      color: SMColors.success.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    isValidCode ? _formatCode(joinCode) : joinCode,
                    style: SMTypography.display.copyWith(
                      color: SMColors.primaryText,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: SMSpacing.md),
                Text(
                  'Both devices show the same code',
                  style: SMTypography.caption.copyWith(
                    color: SMColors.mutedText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: SMSpacing.xl),
        ],

        // Audio Share toggle (host only)
        if (isHost) ...[
          AudioShareToggle(isHost: true),
          SizedBox(height: SMSpacing.xl),
        ],

        // Leave/End room button - host ends room, participant leaves room
        SMButton(
          text: isHost ? 'End Room' : 'Leave Room',
          icon: Icons.logout,
          variant: SMButtonVariant.danger,
          onPressed: () => _showLeaveDialog(context, isHost),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _roomIdentityHeader(
    BuildContext context,
    ApplicationState appState,
    CreateRoomFlowState createState,
    RoomLifecycleStateData lifecycleState,
    String roomStatusText,
  ) {
    final isHost = appState.isHost == true;

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
            child: Icon(Icons.group, size: 20, color: SMColors.secondaryText),
          ),
          SizedBox(width: SMSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Room',
                      style: SMTypography.heading.copyWith(
                        color: SMColors.primaryText,
                      ),
                    ),
                    if (isHost) ...[
                      SizedBox(width: SMSpacing.sm),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: SMSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: SMColors.soundmeshBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(SMRadius.small),
                        ),
                        child: Text(
                          'HOST',
                          style: SMTypography.metadata.copyWith(
                            color: SMColors.soundmeshBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(width: SMSpacing.sm),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: SMSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: SMColors.secondaryText.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(SMRadius.small),
                        ),
                        child: Text(
                          'PARTICIPANT',
                          style: SMTypography.metadata.copyWith(
                            color: SMColors.secondaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: SMSpacing.xs),
                Text(
                  roomStatusText,
                  style: SMTypography.caption.copyWith(
                    color: SMColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: SMSpacing.sm),
          if (isHost)
            SMButton(
              text: 'Invite',
              icon: Icons.person_add,
              variant: SMButtonVariant.secondary,
              onPressed: () => _showInviteModal(context, createState),
            ),
        ],
      ),
    );
  }

  String _getRoomStatusText(
    RoomLifecycleStateData lifecycleState,
    CreateRoomFlowState createState,
    ApplicationState appState,
  ) {
    switch (lifecycleState.lifecycleState) {
      case RoomLifecycleState.created:
        return 'Initializing…';
      case RoomLifecycleState.discoverable:
        if (createState.status == CreateRoomFlowStatus.listening) {
          return 'Waiting for participant to join…';
        }
        return 'Starting…';
      case RoomLifecycleState.joining:
        return 'Joining room…';
      case RoomLifecycleState.ready:
        final state = appState.state;
        if (state == SMAppState.playing) return 'Audio sync active';
        if (state == SMAppState.paused) return 'Audio sync paused';
        if (state == SMAppState.ready) {
          return 'Devices synchronized, ready for audio';
        }
        return 'Ready';
      case RoomLifecycleState.closed:
        return 'Room closed';
    }
  }

  Widget _readyContent(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    CreateRoomFlowState createState,
    RoomLifecycleStateData lifecycleState,
    CaptureUiStateData captureState,
    int deviceCount,
    bool participantJoined,
    String roomStatusText,
    String? screenError,
  ) {
    final isHost = appState.isHost == true;
    final joinCode = appState.joinCode ?? '';
    final isValidCode = isValidRoomCode(joinCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Room identity
        _roomIdentityHeader(
          context,
          appState,
          createState,
          lifecycleState,
          roomStatusText,
        ),
        SizedBox(height: SMSpacing.xl),

        // Error banner if any
        if (screenError != null) ...[
          _buildErrorBanner(screenError),
          SizedBox(height: SMSpacing.lg),
        ],

        // Show join code for participant (confirmation only)
        if (joinCode.isNotEmpty && !isHost) ...[
          SMCard(
            elevated: true,
            padding: EdgeInsets.all(SMSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  size: SMDimensions.emptyIconSize * 0.7,
                  color: SMColors.success,
                ),
                SizedBox(height: SMSpacing.lg),
                Text(
                  'Code Confirmed',
                  style: SMTypography.heading.copyWith(
                    color: SMColors.primaryText,
                  ),
                ),
                SizedBox(height: SMSpacing.md),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SMSpacing.xl,
                    vertical: SMSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: SMColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(SMRadius.large),
                    border: Border.all(
                      color: SMColors.success.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    isValidCode ? _formatCode(joinCode) : joinCode,
                    style: SMTypography.display.copyWith(
                      color: SMColors.primaryText,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: SMSpacing.md),
                Text(
                  'Both devices show the same code',
                  style: SMTypography.caption.copyWith(
                    color: SMColors.mutedText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: SMSpacing.xl),
        ],
        // Session status card
        SMCard(
          elevated: true,
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: SMDimensions.emptyIconSize,
                color: SMColors.success,
              ),
              SizedBox(height: SMSpacing.lg),
              Text(
                'Devices Synchronized',
                style: SMTypography.heading.copyWith(
                  color: SMColors.primaryText,
                ),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                'Devices are calibrated and ready. Open your media app and start playing audio to begin the synchronized session.',
                textAlign: TextAlign.center,
                style: SMTypography.body.copyWith(
                  color: SMColors.secondaryText,
                ),
              ),
              SizedBox(height: SMSpacing.lg),
              const Text(
                '[UI SCAFFOLDING — NO REAL CAPTURE DATA]',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SMColors.warning,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.xl),
        // Audio Share toggle (host only)
        if (isHost) ...[
          AudioShareToggle(isHost: true),
          SizedBox(height: SMSpacing.xl),
        ],
        // Leave/End room button - host ends room, participant leaves room
        SMButton(
          text: isHost ? 'End Room' : 'Leave Room',
          icon: Icons.logout,
          variant: SMButtonVariant.danger,
          onPressed: () => _showLeaveDialog(context, isHost),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _sessionStatusContent(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    CreateRoomFlowState createState,
    RoomLifecycleStateData lifecycleState,
    CaptureUiStateData captureState,
    int deviceCount,
    bool participantJoined,
    String roomStatusText,
    String? screenError,
  ) {
    final state = appState.state;
    final isPlaying = state == SMAppState.playing;
    final isHost = appState.isHost == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Session status header
        Row(
          children: [
            Icon(
              Icons.graphic_eq,
              size: SMDimensions.iconSize,
              color: SMColors.soundmeshBlue,
            ),
            SizedBox(width: SMSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPlaying
                        ? 'Synchronized Audio Active'
                        : 'Synchronized Audio Paused',
                    style: SMTypography.largeTitle.copyWith(
                      color: SMColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: SMSpacing.xl),

        // Room identity
        _roomIdentityHeader(
          context,
          appState,
          createState,
          lifecycleState,
          roomStatusText,
        ),
        SizedBox(height: SMSpacing.xl),

        // Error banner if any
        if (screenError != null) ...[
          _buildErrorBanner(screenError),
          SizedBox(height: SMSpacing.lg),
        ],

        // Audio Share toggle (host only)
        if (appState.isHost == true) ...[
          AudioShareToggle(isHost: true),
          SizedBox(height: SMSpacing.xl),
        ],

        // Session status card
        SMCard(
          elevated: true,
          child: Column(
            children: [
              Text(
                isPlaying
                    ? 'External audio is being captured, synchronized, and played on all devices.'
                    : 'The external media app has paused. Synchronization is maintained at the paused position.',
                textAlign: TextAlign.center,
                style: SMTypography.body.copyWith(
                  color: SMColors.secondaryText,
                ),
              ),
              SizedBox(height: SMSpacing.lg),
              const Text(
                '[UI SCAFFOLDING — NO REAL CAPTURE DATA]',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SMColors.warning,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.xl),
        // Leave/End room button - host ends room, participant leaves room
        SMButton(
          text: isHost ? 'End Room' : 'Leave Room',
          variant: SMButtonVariant.secondary,
          onPressed: () => _showLeaveDialog(context, isHost),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _preparingContent(ApplicationState appState) {
    return Column(
      children: [
        SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
        SizedBox(height: SMSpacing.lg),
        Text(
          appState.message ?? 'Preparing session…',
          textAlign: TextAlign.center,
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'Waiting for all devices to prepare for the synchronized session.',
          textAlign: TextAlign.center,
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _stoppingContent(ApplicationState appState) {
    return Column(
      children: [
        SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
        SizedBox(height: SMSpacing.lg),
        Text(
          appState.message ?? 'Stopping session…',
          textAlign: TextAlign.center,
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'Winding down the synchronized session and releasing devices.',
          textAlign: TextAlign.center,
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _notInRoomContent(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.warning,
          size: SMDimensions.emptyIconSize,
          color: SMColors.warning,
        ),
        SizedBox(height: SMSpacing.lg),
        Text(
          'Not in a Room',
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'You are viewing the room dashboard, but no room session is active.',
          textAlign: TextAlign.center,
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xl),
        SMButton(
          text: 'Go to Home',
          icon: Icons.home,
          variant: SMButtonVariant.primary,
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.home,
            (route) => false,
          ),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  void _showInviteModal(BuildContext context, CreateRoomFlowState createState) {
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
        backgroundColor: SMColors.surfaceHighest,
        title: Text(
          'Invite to Room',
          style: SMTypography.title.copyWith(color: SMColors.primaryText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact code display with copy button
            Container(
              padding: EdgeInsets.all(SMSpacing.md),
              decoration: BoxDecoration(
                color: SMColors.surfaceHigh,
                borderRadius: BorderRadius.circular(SMRadius.medium),
                border: Border.all(color: SMColors.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatCode(joinCode),
                      style: SMTypography.heading.copyWith(
                        color: SMColors.primaryText,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    color: SMColors.soundmeshBlue,
                    tooltip: 'Copy code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: joinCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room code copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: SMSpacing.lg),
            // QR code
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: SMColors.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, bool isHost) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SMColors.surfaceHighest,
        title: Text(
          isHost ? 'End Room?' : 'Leave Room?',
          style: SMTypography.title.copyWith(color: SMColors.primaryText),
        ),
        content: Text(
          isHost
              ? 'This will end the room for all connected devices.'
              : 'You will leave the room. The host and other participants will continue.',
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: SMColors.secondaryText),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SMColors.error),
            onPressed: () {
              Navigator.of(context).pop();
              if (isHost) {
                StateProvider.of(context).closeRoom();
                // Don't navigate immediately - let the "You ended the room" modal handle it
              } else {
                StateProvider.of(context).leaveRoom();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.home,
                  (route) => false,
                );
              }
            },
            child: Text(isHost ? 'End Room' : 'Leave Room'),
          ),
        ],
      ),
    );
  }

  String _formatCode(String code) {
    if (code.length == 6) {
      return '${code.substring(0, 3)}-${code.substring(3, 6)}';
    }
    return code;
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SMColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SMRadius.medium),
        border: Border.all(
          color: SMColors.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: SMColors.error, size: 20),
          const SizedBox(width: 12),
Expanded(
            child: Text(
              error,
              style: TextStyle(color: SMColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal shown to participants when the host ends the room.
class _HostEndedRoomModal extends ConsumerWidget {
  const _HostEndedRoomModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: SMSpacing.xl),
            child: SMCard(
              elevated: true,
              padding: EdgeInsets.all(SMSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: SMDimensions.emptyIconSize * 0.6,
                    color: SMColors.warning,
                  ),
                  SizedBox(height: SMSpacing.lg),
                  Text(
                    'Host Ended the Room',
                    style: SMTypography.heading.copyWith(color: SMColors.primaryText),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: SMSpacing.md),
                  Text(
                    'The host has ended the synchronized session. You have been disconnected from the room.',
                    style: SMTypography.body.copyWith(color: SMColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: SMSpacing.xl),
                  SMButton(
                    text: 'Back to Home',
                    icon: Icons.home,
                    variant: SMButtonVariant.primary,
                    onPressed: () {
                      // Reset room state and navigate to home
                      ref.read(roomLifecycleProvider.notifier).leaveRoom();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRouter.home,
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal shown to host when they intentionally end the room.
class _YouEndedRoomModal extends ConsumerWidget {
  const _YouEndedRoomModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: SMSpacing.xl),
            child: SMCard(
              elevated: true,
              padding: EdgeInsets.all(SMSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: SMDimensions.emptyIconSize * 0.6,
                    color: SMColors.success,
                  ),
                  SizedBox(height: SMSpacing.lg),
                  Text(
                    'You Ended the Room',
                    style: SMTypography.heading.copyWith(color: SMColors.primaryText),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: SMSpacing.md),
                  Text(
                    'The synchronized session has been ended for all devices.',
                    style: SMTypography.body.copyWith(color: SMColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: SMSpacing.xl),
                  SMButton(
                    text: 'Back to Home',
                    icon: Icons.home,
                    variant: SMButtonVariant.primary,
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRouter.home,
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
