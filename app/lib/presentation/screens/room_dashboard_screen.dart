import 'package:flutter/material.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/empty_state.dart';
import 'package:soundmesh/presentation/components/loading_indicator.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_types.dart';

class RoomDashboardScreen extends StatelessWidget {
  const RoomDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StateBuilder(
      builder: (context, appState) {
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: SMSpacing.xl,
                vertical: SMSpacing.xl,
              ),
              child: _buildContent(context, appState),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, ApplicationState appState) {
    final state = appState.state;

    switch (state) {
      case SMAppState.error:
        return Column(
          children: [
            SMEmptyState.error(
              title: 'Room Error',
              message: appState.message ?? 'Something went wrong with the room.',
              icon: Icons.error_outline,
              onRetry: () => StateProvider.of(context).leaveRoom(),
            ),
            SizedBox(height: SMSpacing.xxl),
          ],
        );

      case SMAppState.preparing:
        return _preparingContent(appState);

      case SMAppState.ready:
        return _readyContent(context, appState);

      case SMAppState.playing:
      case SMAppState.paused:
        return _sessionStatusContent(context, appState);

      case SMAppState.stopping:
        return _stoppingContent(appState);

      case SMAppState.roomReady:
        return _roomReadyContent(context, appState);

      case SMAppState.idle:
      case SMAppState.creatingRoom:
      case SMAppState.joiningRoom:
        return _notInRoomContent(context);
    }
  }

  Widget _roomReadyContent(BuildContext context, ApplicationState appState) {
    final isHost = appState.isHost == true;
    final joinCode = appState.joinCode ?? '';
    final isValidCode = isValidRoomCode(joinCode);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Room identity with code confirmation
        _roomIdentityHeader(context, appState),
        SizedBox(height: SMSpacing.xl),
        
        // 6-digit code confirmation card (visible to both host and participant)
        SMCard(
          elevated: true,
          padding: EdgeInsets.all(SMSpacing.xl),
          child: Column(
            children: [
              Icon(
                isHost ? Icons.wifi_tethering : Icons.check_circle,
                size: SMDimensions.emptyIconSize * 0.7,
                color: isHost ? SMColors.soundmeshBlue : SMColors.success,
              ),
              SizedBox(height: SMSpacing.lg),
              Text(
                isHost ? 'Share This Code' : 'Code Confirmed',
                style: SMTypography.heading.copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.md),
              // Large 6-digit code display
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SMSpacing.xl,
                  vertical: SMSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: SMColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(SMRadius.large),
                  border: Border.all(
                    color: (isHost ? SMColors.soundmeshBlue : SMColors.success).withValues(alpha: 0.5),
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
                isHost
                    ? 'Other phones enter this 6-digit code to join'
                    : 'Both devices show the same code',
                style: SMTypography.caption.copyWith(color: SMColors.mutedText),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: SMSpacing.lg),
              Text(
                'Room: ${appState.roomId ?? "—"}',
                style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.xl),
        
        // Mesh visualization placeholder
        SMCard(
          elevated: true,
          child: Column(
            children: [
              Icon(
                Icons.hub,
                size: SMDimensions.emptyIconSize,
                color: SMColors.soundmeshBlue,
              ),
              SizedBox(height: SMSpacing.lg),
              Text(
                'Mesh Visualization',
                style: SMTypography.heading
                    .copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                'Device nodes and connections will appear here when devices join.',
                textAlign: TextAlign.center,
                style: SMTypography.body
                    .copyWith(color: SMColors.secondaryText),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.xl),
        // Sync control / affordance
        _syncAffordance(context, appState),
        SizedBox(height: SMSpacing.xl),
        // Leave room button
        SMButton(
          text: 'Leave Room',
          icon: Icons.logout,
          variant: SMButtonVariant.danger,
          onPressed: () => _showLeaveDialog(context),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  // Room identity card per the Stitch export: icon chip, room name with a
  // room-ID badge, supporting caption, and a QR invite chip.
  Widget _roomIdentityHeader(BuildContext context, ApplicationState appState) {
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
            child: Icon(
              Icons.group,
              size: 20,
              color: SMColors.secondaryText,
            ),
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
                      style: SMTypography.heading
                          .copyWith(color: SMColors.primaryText),
                    ),
                    if (appState.roomId != null) ...[
                      SizedBox(width: SMSpacing.sm),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: SMSpacing.sm,
                          vertical: SMSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: SMColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(SMRadius.xs),
                        ),
                        child: Text(
                          appState.roomId!,
                          style: SMTypography.smallMetadata.copyWith(
                            color: SMColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: SMSpacing.xs),
                Text(
                  'Room details appear here when a session is available.',
                  style: SMTypography.caption
                      .copyWith(color: SMColors.secondaryText),
                ),
              ],
            ),
          ),
          SizedBox(width: SMSpacing.sm),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SMColors.surfaceContainer,
              borderRadius: BorderRadius.circular(SMRadius.medium),
            ),
            child: IconButton(
              icon: Icon(Icons.qr_code_2, size: 20, color: SMColors.secondaryText),
              onPressed: () => Navigator.pushNamed(context, AppRouter.qrScan),
              tooltip: 'Show QR Code',
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readyContent(BuildContext context, ApplicationState appState) {
    final sync = appState.sync;
    final offset = sync?.offsetMs;
    final drift = sync?.driftMsPerSecond;
    final isHost = appState.isHost == true;
    final joinCode = appState.joinCode ?? '';
    final isValidCode = isValidRoomCode(joinCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Room identity
        _roomIdentityHeader(context, appState),
        SizedBox(height: SMSpacing.xl),
        
        // Show join code for both host and participant (participant auto-navigates here)
        if (joinCode.isNotEmpty) ...[
          SMCard(
            elevated: true,
            padding: EdgeInsets.all(SMSpacing.xl),
            child: Column(
              children: [
                Icon(
                  isHost ? Icons.wifi_tethering : Icons.check_circle,
                  size: SMDimensions.emptyIconSize * 0.7,
                  color: isHost ? SMColors.soundmeshBlue : SMColors.success,
                ),
                SizedBox(height: SMSpacing.lg),
                Text(
                  isHost ? 'Share This Code' : 'Code Confirmed',
                  style: SMTypography.heading.copyWith(color: SMColors.primaryText),
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
                      color: (isHost ? SMColors.soundmeshBlue : SMColors.success).withValues(alpha: 0.5),
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
                  isHost
                      ? 'Other phones enter this 6-digit code to join'
                      : 'Both devices show the same code',
                  style: SMTypography.caption.copyWith(color: SMColors.mutedText),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: SMSpacing.lg),
                Text(
                  'Room: ${appState.roomId ?? "—"}',
                  style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
                ),
              ],
            ),
          ),
          SizedBox(height: SMSpacing.xl),
        ],
        // Sync status — synchronized
        SMCard(
          child: Row(
            children: [
              Icon(
                Icons.sync,
                color: SMColors.success,
                size: SMDimensions.iconSize,
              ),
              SizedBox(width: SMSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synchronized',
                      style: SMTypography.body
                          .copyWith(color: SMColors.primaryText),
                    ),
                    if (offset != null && drift != null)
                      Text(
                        'Offset: ${offset.toStringAsFixed(1)} ms · Drift: ${drift.toStringAsFixed(2)} ms/s',
                        style: SMTypography.caption
                            .copyWith(color: SMColors.secondaryText),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.xl),
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
                style: SMTypography.heading
                    .copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                'Devices are calibrated and ready. Open your media app and start playing audio to begin the synchronized session.',
                textAlign: TextAlign.center,
                style: SMTypography.body
                    .copyWith(color: SMColors.secondaryText),
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
        // Leave room button
        SMButton(
          text: 'Leave Room',
          icon: Icons.logout,
          variant: SMButtonVariant.danger,
          onPressed: () => _showLeaveDialog(context),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _sessionStatusContent(BuildContext context, ApplicationState appState) {
    final state = appState.state;
    final isPlaying = state == SMAppState.playing;

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
                    isPlaying ? 'Synchronized Audio Active' : 'Synchronized Audio Paused',
                    style: SMTypography.largeTitle
                        .copyWith(color: SMColors.primaryText),
                  ),
                  Text(
                    appState.roomId ?? 'Room session active',
                    style: SMTypography.caption
                        .copyWith(color: SMColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: SMSpacing.xl),
        // Session status card
        SMCard(
          elevated: true,
          child: Column(
            children: [
              Text(
                isPlaying ? 'External audio is being captured, synchronized, and played on all devices.' : 'The external media app has paused. Synchronization is maintained at the paused position.',
                textAlign: TextAlign.center,
                style: SMTypography.body.copyWith(color: SMColors.secondaryText),
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
        // Sync status card
        _syncAffordance(context, appState),
        SizedBox(height: SMSpacing.xl),
        // Leave room button
        SMButton(
          text: 'Leave Room',
          variant: SMButtonVariant.secondary,
          onPressed: () => _showLeaveDialog(context),
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
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _syncAffordance(BuildContext context, ApplicationState appState) {
    final sync = appState.sync;
    final status = sync?.syncState ?? SMSyncStatus.unknown;

    IconData icon;
    String title;
    String subtitle;
    Color iconColor;

    switch (status) {
      case SMSyncStatus.synchronized:
        icon = Icons.sync;
        title = 'Synchronized';
        subtitle = 'Devices are calibrated and ready.';
        iconColor = SMColors.success;
      case SMSyncStatus.calibrating:
        icon = Icons.sync;
        title = 'Calibrating';
        subtitle = 'Measuring and compensating latency differences.';
        iconColor = SMColors.warning;
      case SMSyncStatus.resynchronizing:
        icon = Icons.sync;
        title = 'Resynchronizing';
        subtitle = 'Adjusting clock offsets between devices.';
        iconColor = SMColors.warning;
      case SMSyncStatus.degraded:
        icon = Icons.warning;
        title = 'Sync Degraded';
        subtitle = 'Synchronization quality has dropped.';
        iconColor = SMColors.warning;
      case SMSyncStatus.connectionLost:
        icon = Icons.sync_disabled;
        title = 'Connection Lost';
        subtitle = 'One or more devices have disconnected.';
        iconColor = SMColors.error;
      case SMSyncStatus.preparing:
        icon = Icons.sync;
        title = 'Preparing Sync';
        subtitle = 'Getting devices ready for calibration.';
        iconColor = SMColors.warning;
      case SMSyncStatus.unknown:
        icon = Icons.sync_disabled;
        title = 'Not calibrated';
        subtitle = 'Devices must be synchronized before the session starts.';
        iconColor = SMColors.warning;
    }

    return SMCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: SMColors.surfaceContainer,
              borderRadius: BorderRadius.circular(SMRadius.small),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: SMSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: SMSpacing.sm),
                    Text(
                      title,
                      style:
                          SMTypography.body.copyWith(color: SMColors.primaryText),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: SMTypography.caption
                      .copyWith(color: SMColors.secondaryText),
                ),
              ],
            ),
          ),
          // Tonal Prepare affordance per the Stitch export
          // (accent/20 fill with accent label).
          Material(
            color: SMColors.soundmeshBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(SMRadius.small),
            child: InkWell(
              borderRadius: BorderRadius.circular(SMRadius.small),
              onTap: () => StateProvider.of(context).prepare(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SMSpacing.md,
                  vertical: SMSpacing.sm,
                ),
                child: Text(
                  'Prepare',
                  style: SMTypography.label
                      .copyWith(color: SMColors.soundmeshBlue),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SMColors.surfaceHighest,
        title: Text(
          'Leave Room?',
          style: SMTypography.title.copyWith(color: SMColors.primaryText),
        ),
        content: Text(
          'The synchronized session will end for all connected devices.',
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
              StateProvider.of(context).leaveRoom();
              Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false);
            },
            child: const Text('Leave Room'),
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
}