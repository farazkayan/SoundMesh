import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/providers/capture_provider.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_types.dart';
import 'package:soundmesh/presentation/components/index.dart';
import 'package:soundmesh/presentation/state_compat.dart';

class RoomDashboardScreen extends ConsumerStatefulWidget {
  const RoomDashboardScreen({super.key});

  @override
  ConsumerState<RoomDashboardScreen> createState() =>
      _RoomDashboardScreenState();
}

class _RoomDashboardScreenState
    extends ConsumerState<RoomDashboardScreen> {
  final String _activeTab = 'room';

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(applicationStateProvider);
    final createState = ref.watch(createRoomFlowProvider);
    final captureState = ref.watch(captureStateProvider);
    final lifecycleState = ref.watch(roomLifecycleProvider);

    final isHost = appState.isHost == true;
    final isInRoom = _isInRoomState(appState.state);

    final backgroundUsageDisabled =
        captureState.isIgnoringBatteryOptimizations == false;

    final showBackgroundUsageModal =
        isHost && isInRoom && backgroundUsageDisabled;

    final showHostEndedModal =
        !isHost && lifecycleState.hostEndedRoom && isInRoom;

    final showHostEndedModalForHost =
        isHost && lifecycleState.hostEndedRoom;

    return Scaffold(
      backgroundColor: TSXColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const RadialGradientBackdrop(),
            LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Container(
                        // On tablet: use 80% width up to 720px; on phone: full width
                        constraints: BoxConstraints(
                          maxWidth: isTablet
                              ? (constraints.maxWidth * 0.8).clamp(520.0, 720.0)
                              : double.infinity,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 32 : TSXSpacing.xl,
                          vertical: TSXSpacing.xl,
                        ),
                        child: _buildDashboardContent(
                          context,
                          ref,
                          appState,
                          createState,
                          lifecycleState,
                          captureState,
                          showBackgroundUsageModal,
                          showHostEndedModal,
                          showHostEndedModalForHost,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (showBackgroundUsageModal)
              const BackgroundUsageRequiredModal(),
            if (showHostEndedModal)
              const _HostEndedRoomModal(),
            if (showHostEndedModalForHost)
              const _YouEndedRoomModal(),
          ],
        ),
      ),
    );
  }

  bool _isInRoomState(SMAppState state) {
    return state == SMAppState.roomReady ||
        state == SMAppState.ready ||
        state == SMAppState.playing ||
        state == SMAppState.paused;
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    CreateRoomFlowState createState,
    RoomLifecycleStateData lifecycleState,
    CaptureUiStateData captureState,
    bool showBackgroundUsageModal,
    bool showHostEndedModal,
    bool showHostEndedModalForHost,
  ) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        _buildRoomHeader(
          context,
          ref,
          appState,
          createState,
          lifecycleState,
          captureState,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _buildMainContent(
              context,
              ref,
              appState,
              createState,
              lifecycleState,
              captureState,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Floating dock with safe area bottom padding
        Padding(
          padding: EdgeInsets.only(bottom: safeBottom > 0 ? safeBottom : TSXSpacing.xl),
          child: _buildFloatingDock(),
        ),
      ],
    );
  }

  Widget _buildRoomHeader(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    CreateRoomFlowState createState,
    RoomLifecycleStateData lifecycleState,
    CaptureUiStateData captureState,
  ) {
    final isHost = appState.isHost == true;
    final isCapturing =
        captureState.state == CaptureUiState.capturing;

    final status = isHost
        ? (isCapturing
            ? 'Broadcasting spatial stream'
            : 'Waiting for listeners...')
        : _participantStatus(
            appState,
            lifecycleState,
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TSXColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TSXColors.surfaceBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: TSXColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: TSXColors.surfaceBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.radio,
              size: 20,
              color: TSXColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Room',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TSXTypography.labelLarge.copyWith(
                          color: TSXColors.primaryText,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: TSXColors.accent
                              .withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(999),
                          border: Border.all(
                            color: TSXColors.accent
                                .withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          'HOST',
                          style:
                              TSXTypography.metadata.copyWith(
                            color: TSXColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TSXTypography.caption.copyWith(
                    color: TSXColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isHost) ...[
            const SizedBox(width: 8),
            _buildInviteButton(
              context,
              createState,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInviteButton(
    BuildContext context,
    CreateRoomFlowState createState,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            _showInviteModal(context, createState),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: TSXColors.surfaceBorder,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: TSXColors.surfaceBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add_alt_1,
                size: 14,
                color: TSXColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                '+ Invite',
                style: TSXTypography.labelMedium.copyWith(
                  color: TSXColors.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    CreateRoomFlowState createState,
    RoomLifecycleStateData lifecycleState,
    CaptureUiStateData captureState,
  ) {
    switch (appState.state) {
      case SMAppState.error:
        return _buildErrorContent(
          appState,
          ref,
        );

      case SMAppState.preparing:
        return _buildLoadingContent(
          appState,
          'Preparing session…',
          'Waiting for all devices to prepare for the synchronized session.',
        );

      case SMAppState.stopping:
        return _buildLoadingContent(
          appState,
          'Stopping session…',
          'Winding down the synchronized session and releasing devices.',
        );

      case SMAppState.idle:
      case SMAppState.creatingRoom:
      case SMAppState.joiningRoom:
        return _notInRoomContent(context);

      case SMAppState.roomReady:
      case SMAppState.ready:
      case SMAppState.playing:
      case SMAppState.paused:
        return _buildRoomTab(
          context,
          ref,
          appState,
          createState,
          lifecycleState,
          captureState,
        );
    }
  }

  Widget _buildRoomTab(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    CreateRoomFlowState createState,
    RoomLifecycleStateData lifecycleState,
    CaptureUiStateData captureState,
  ) {
    final isHost = appState.isHost == true;
    final screenError = lifecycleState.errorMessage;

    if (_activeTab == 'devices') {
      return _buildDevicesTab(
        context,
        appState,
        createState,
        lifecycleState,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (screenError != null) ...[
          _buildErrorBanner(screenError),
          const SizedBox(height: 12),
        ],
        if (isHost) ...[
          AudioShareToggle.tsx(
            isHost: true,
          ),
          const SizedBox(height: 12),
          _buildEndRoomButton(
            context,
            ref,
          ),
        ] else ...[
          _buildParticipantRoomCard(
            context,
            appState,
            lifecycleState,
          ),
          const SizedBox(height: 12),
          _buildParticipantLeaveButton(
            context,
            ref,
          ),
        ],
      ],
    );
  }

  Widget _buildDevicesTab(
    BuildContext context,
    ApplicationState appState,
    CreateRoomFlowState createState,
    RoomLifecycleStateData lifecycleState,
  ) {
    final roomCode =
        appState.joinCode ??
            createState.joinCode ??
            '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TSXColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: TSXColors.surfaceBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MESH TOPOLOGY',
                  style:
                      TSXTypography.metadata.copyWith(
                    color: TSXColors.secondaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Text(
                'LATENCY CALIBRATED',
                style:
                    TSXTypography.metadata.copyWith(
                  color: TSXColors.accent,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TSXColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: TSXColors.accent
                    .withValues(alpha: 0.40),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: TSXColors.accent
                        .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.smartphone,
                    size: 16,
                    color: TSXColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Host Transmitter',
                              style: TSXTypography
                                  .labelMedium
                                  .copyWith(
                                color:
                                    TSXColors.primaryText,
                                fontWeight:
                                    FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: TSXColors.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Primary Streamer (0ms)',
                        style:
                            TSXTypography.caption.copyWith(
                          color:
                              TSXColors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TSXColors.accent
                        .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(4),
                    border: Border.all(
                      color: TSXColors.accent
                          .withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    'MASTER',
                    style:
                        TSXTypography.metadata.copyWith(
                      color: TSXColors.accent,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: TSXColors.surfaceBorder,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.radio,
                  size: 24,
                  color: TSXColors.secondaryText
                      .withValues(alpha: 0.50),
                ),
                const SizedBox(height: 8),
                Text(
                  'Listening for Peer Nodes',
                  style:
                      TSXTypography.labelMedium.copyWith(
                    color: TSXColors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roomCode.isNotEmpty
                      ? 'Additional devices joining with code ${formatRoomCode(roomCode)} will sync here.'
                      : 'Additional devices joining with the room code will sync here.',
                  textAlign: TextAlign.center,
                  style:
                      TSXTypography.caption.copyWith(
                    color: TSXColors.secondaryText,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndRoomButton(
    BuildContext context,
    WidgetRef ref,
  ) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(16),
          onTap: () =>
              _showEndRoomModal(context, ref),
          child: Container(
            decoration: BoxDecoration(
              color: TSXColors.rose
                  .withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: TSXColors.rose
                    .withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset:
                      const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout,
                  size: 16,
                  color: TSXColors.rose,
                ),
                const SizedBox(width: 8),
                Text(
                  'End Room Session',
                  style:
                      TSXTypography.labelMedium.copyWith(
                    color: TSXColors.rose,
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantRoomCard(
    BuildContext context,
    ApplicationState appState,
    RoomLifecycleStateData lifecycleState,
  ) {
    final code = appState.joinCode ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TSXColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: TSXColors.surfaceBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: TSXColors.accent
                  .withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.headphones,
              size: 20,
              color: TSXColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connected to Host',
            style:
                TSXTypography.headlineMedium.copyWith(
              color: TSXColors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            code.isNotEmpty
                ? 'Listening for synchronized audio from room ${formatRoomCode(code)}.'
                : 'Listening for synchronized audio from the host.',
            textAlign: TextAlign.center,
            style:
                TSXTypography.caption.copyWith(
              color: TSXColors.secondaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantLeaveButton(
    BuildContext context,
    WidgetRef ref,
  ) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Material(
        color: TSXColors.surfaceBorder,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await ref
                .read(
                  roomLifecycleProvider.notifier,
                )
                .leaveRoom();

            if (!context.mounted) return;

            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.home,
              (route) => false,
            );
          },
          child: Center(
            child: Text(
              'Leave Room',
              style:
                  TSXTypography.labelMedium.copyWith(
                color: TSXColors.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingDock() {
    return Center(
      child: Container(
        width: 220,
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: TSXColors.surface.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: TSXColors.surfaceBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            // Tab 1: Room - internal tab (always active on this screen)
            Expanded(
              child: _buildDockButton(
                label: 'Room',
                icon: Icons.group,
                active: true,
                onTap: () {
                  // Already on Room screen, no-op
                },
              ),
            ),
            // Tab 2: Devices - navigate to separate RoomDevicesScreen
            Expanded(
              child: _buildDockButton(
                label: 'Devices',
                icon: Icons.tune,
                active: false,
                onTap: () {
                  Navigator.pushReplacementNamed(context, AppRouter.roomDevices);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockButton({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: active
                ? TSXColors.surfaceBorder
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active
                    ? TSXColors.accent
                    : TSXColors.secondaryText,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TSXTypography.labelMedium.copyWith(
                    color: active
                        ? TSXColors.accent
                        : TSXColors.secondaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 5),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TSXColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: TSXColors.accent
                            .withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent(
    ApplicationState appState,
    WidgetRef ref,
  ) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TSXColors.surface,
          borderRadius:
              BorderRadius.circular(24),
          border: Border.all(
            color: TSXColors.surfaceBorder,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: TSXColors.error,
            ),
            const SizedBox(height: 14),
            Text(
              'Room Error',
              style:
                  TSXTypography.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              appState.message ??
                  'Something went wrong with the room.',
              textAlign: TextAlign.center,
              style:
                  TSXTypography.bodyMedium,
            ),
            const SizedBox(height: 20),
            SMButton(
              text: 'Leave Room',
              variant:
                  SMButtonVariant.tsxPrimary,
              onPressed: () => ref
                  .read(
                    roomLifecycleProvider
                        .notifier,
                  )
                  .leaveRoom(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingContent(
    ApplicationState appState,
    String fallbackTitle,
    String description,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 80,
          horizontal: 20,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            SMLoadingIndicator.tsx(
              size: 48,
            ),
            const SizedBox(height: 18),
            Text(
              appState.message ??
                  fallbackTitle,
              textAlign:
                  TextAlign.center,
              style:
                  TSXTypography.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign:
                  TextAlign.center,
              style:
                  TSXTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _notInRoomContent(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 70,
        horizontal: 20,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: TSXColors.warning,
          ),
          const SizedBox(height: 14),
          Text(
            'Not in a Room',
            style:
                TSXTypography.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'You are viewing the room dashboard, but no room session is active.',
            textAlign:
                TextAlign.center,
            style:
                TSXTypography.bodyMedium,
          ),
          const SizedBox(height: 20),
          SMButton(
            text: 'Go to Home',
            icon: Icons.home,
            variant:
                SMButtonVariant.tsxPrimary,
            onPressed: () =>
                Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.home,
              (route) => false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: TSXColors.error
            .withValues(alpha: 0.15),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: TSXColors.error
              .withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: TSXColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: TSXColors.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _participantStatus(
    ApplicationState appState,
    RoomLifecycleStateData lifecycleState,
  ) {
    switch (lifecycleState.lifecycleState) {
      case RoomLifecycleState.created:
        return 'Initializing…';

      case RoomLifecycleState.discoverable:
        return 'Waiting for participant to join…';

      case RoomLifecycleState.joining:
        return 'Joining room…';

      case RoomLifecycleState.ready:
        if (appState.state ==
            SMAppState.playing) {
          return 'Audio sync active';
        }

        if (appState.state ==
            SMAppState.paused) {
          return 'Audio sync paused';
        }

        return 'Devices synchronized';

      case RoomLifecycleState.closed:
        return 'Room closed';
    }
  }

  void _showInviteModal(
    BuildContext context,
    CreateRoomFlowState createState,
  ) {
    final roomId = createState.roomId;
    final hostIp = createState.localIpAddress;
    final port = createState.port ?? 8765;
    final joinCode = createState.joinCode;

    if (roomId == null ||
        hostIp == null ||
        joinCode == null ||
        joinCode.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Room information not ready yet',
          ),
          duration:
              Duration(seconds: 2),
        ),
      );
      return;
    }

    final payload = JoinPayload(
      roomId: roomId,
      hostAddress: hostIp,
      hostPort: port,
      protocolVersion:
          currentProtocolVersion,
      code: joinCode,
    );

    final uriString = payload.toJoinUri();
    var copied = false;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black
          .withValues(alpha: 0.80),
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
          ),
          child: StatefulBuilder(
            builder:
                (context, setModalState) {
              return Dialog(
                backgroundColor:
                    TSXColors.surface,
                insetPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(24),
                  side: BorderSide(
                    color:
                        TSXColors.surfaceBorder,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Scan to Join',
                              style: TSXTypography
                                  .headlineMedium
                                  .copyWith(
                                color: TSXColors
                                    .primaryText,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                          _buildModalCloseButton(
                            onPressed: () =>
                                Navigator.of(
                              dialogContext,
                            ).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      Container(
                        width: 160,
                        height: 160,
                        padding:
                            const EdgeInsets.all(10),
                        decoration:
                            BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(
                                alpha: 0.14,
                              ),
                              blurRadius: 8,
                              offset:
                                  const Offset(
                                0,
                                3,
                              ),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: uriString,
                          version:
                              QrVersions.auto,
                          backgroundColor:
                              Colors.white,
                          eyeStyle:
                              const QrEyeStyle(
                            eyeShape:
                                QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle:
                              const QrDataModuleStyle(
                            dataModuleShape:
                                QrDataModuleShape
                                    .square,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      InkWell(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: joinCode,
                            ),
                          );

                          setModalState(() {
                            copied = true;
                          });

                          Future<void>.delayed(
                            const Duration(
                              seconds: 2,
                            ),
                            () {
                              if (context
                                  .mounted) {
                                setModalState(() {
                                  copied = false;
                                });
                              }
                            },
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                          decoration:
                              BoxDecoration(
                            color: TSXColors
                                .background,
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            border: Border.all(
                              color: TSXColors
                                  .accent,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: TSXColors
                                    .accent
                                    .withValues(
                                  alpha: 0.10,
                                ),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Text(
                            formatRoomCode(
                              joinCode,
                            ),
                            textAlign:
                                TextAlign.center,
                            style: TSXTypography
                                .headlineMedium
                                .copyWith(
                              color: TSXColors
                                  .primaryText,
                              fontFamily:
                                  'monospace',
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: Material(
                          color:
                              TSXColors.accent,
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            onTap: () async {
                              await Clipboard
                                  .setData(
                                ClipboardData(
                                  text: joinCode,
                                ),
                              );

                              setModalState(() {
                                copied = true;
                              });

                              Future<void>.delayed(
                                const Duration(
                                  seconds: 2,
                                ),
                                () {
                                  if (context
                                      .mounted) {
                                    setModalState(
                                      () {
                                        copied = false;
                                      },
                                    );
                                  }
                                },
                              );
                            },
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                Icon(
                                  copied
                                      ? Icons.check
                                      : Icons.copy,
                                  size: 16,
                                  color:
                                      TSXColors
                                          .accentOn,
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Text(
                                  copied
                                      ? 'Code Copied!'
                                      : 'Copy Room Code',
                                  style:
                                      TSXTypography
                                          .labelMedium
                                          .copyWith(
                                    color:
                                        TSXColors
                                            .accentOn,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showEndRoomModal(
    BuildContext context,
    WidgetRef ref,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black
          .withValues(alpha: 0.80),
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
          ),
          child: Dialog(
            backgroundColor:
                TSXColors.surface,
            insetPadding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(24),
              side: BorderSide(
                color:
                    TSXColors.surfaceBorder,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: TSXColors.rose
                          .withValues(
                        alpha: 0.10,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: TSXColors.rose
                            .withValues(
                          alpha: 0.20,
                        ),
                      ),
                    ),
                    child: Icon(
                      Icons
                          .warning_amber_rounded,
                      size: 24,
                      color:
                          TSXColors.rose,
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  Text(
                    'End Session?',
                    style: TSXTypography
                        .titleLarge
                        .copyWith(
                      color: TSXColors
                          .primaryText,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    'This will immediately disconnect all active listeners and close the audio stream.',
                    textAlign:
                        TextAlign.center,
                    style: TSXTypography
                        .caption
                        .copyWith(
                      color: TSXColors
                          .secondaryText,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: Material(
                            color: TSXColors
                                .surfaceBorder,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                              onTap: () =>
                                  Navigator.of(
                                dialogContext,
                              ).pop(),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style:
                                      TSXTypography
                                          .labelMedium
                                          .copyWith(
                                    color:
                                        TSXColors
                                            .primaryText,
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: Material(
                            color:
                                TSXColors.rose,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                              onTap: () {
                                Navigator.of(
                                  dialogContext,
                                ).pop();

                                ref
                                    .read(
                                      roomLifecycleProvider
                                          .notifier,
                                    )
                                    .closeRoom();
                              },
                              child: Center(
                                child: Text(
                                  'End Room',
                                  style:
                                      TSXTypography
                                          .labelMedium
                                          .copyWith(
                                    color:
                                        Colors.white,
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalCloseButton({
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: TSXColors.background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder:
              const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            Icons.close,
            size: 16,
            color:
                TSXColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _HostEndedRoomModal
    extends ConsumerWidget {
  const _HostEndedRoomModal();

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return PopScope(
      canPop: false,
      child: Material(
        color:
            TSXColors.overlayScrim,
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: _buildModal(
              context,
              icon: Icons.info_outline,
              iconColor:
                  TSXColors.warning,
              title:
                  'Host Ended the Room',
              message:
                  'The host has ended the synchronized session. You have been disconnected from the room.',
              buttonText:
                  'Back to Home',
              onPressed: () {
                ref
                    .read(
                      roomLifecycleProvider
                          .notifier,
                    )
                    .leaveRoom();

                Navigator
                    .pushNamedAndRemoveUntil(
                  context,
                  AppRouter.home,
                  (route) => false,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _YouEndedRoomModal
    extends ConsumerWidget {
  const _YouEndedRoomModal();

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return PopScope(
      canPop: false,
      child: Material(
        color:
            TSXColors.overlayScrim,
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: _buildModal(
              context,
              icon:
                  Icons.check_circle_outline,
              iconColor:
                  TSXColors.success,
              title:
                  'You Ended the Room',
              message:
                  'The synchronized session has been ended for all devices.',
              buttonText:
                  'Back to Home',
              onPressed: () {
                Navigator
                    .pushNamedAndRemoveUntil(
                  context,
                  AppRouter.home,
                  (route) => false,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildModal(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required String message,
  required String buttonText,
  required VoidCallback onPressed,
}) {
  return Container(
    width: double.infinity,
    constraints:
        const BoxConstraints(
      maxWidth: 320,
    ),
    padding:
        const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: TSXColors.surface,
      borderRadius:
          BorderRadius.circular(24),
      border: Border.all(
        color: TSXColors.surfaceBorder,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black
              .withValues(alpha: 0.35),
          blurRadius: 30,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 32,
          color: iconColor,
        ),
        const SizedBox(
          height: 14,
        ),
        Text(
          title,
          textAlign:
              TextAlign.center,
          style: TSXTypography
              .headlineMedium
              .copyWith(
            color:
                TSXColors.primaryText,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          message,
          textAlign:
              TextAlign.center,
          style: TSXTypography
              .bodyMedium
              .copyWith(
            color:
                TSXColors.secondaryText,
            height: 1.45,
          ),
        ),
        const SizedBox(
          height: 20,
        ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: Material(
            color:
                TSXColors.accent,
            borderRadius:
                BorderRadius.circular(
              12,
            ),
            child: InkWell(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              onTap: onPressed,
              child: Center(
                child: Text(
                  buttonText,
                  style: TSXTypography
                      .labelMedium
                      .copyWith(
                    color:
                        TSXColors.accentOn,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}