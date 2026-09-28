import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/index.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';
import 'package:soundmesh/presentation/screens/debug_screen.dart';

class RoomDevicesScreen extends ConsumerWidget {
  const RoomDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(applicationStateProvider);
    final lifecycleState = ref.watch(roomLifecycleProvider);
    final isHost = appState.isHost == true;

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
                        constraints: BoxConstraints(
                          maxWidth: isTablet
                              ? (constraints.maxWidth * 0.8).clamp(520.0, 720.0)
                              : double.infinity,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 32 : TSXSpacing.xl,
                          vertical: TSXSpacing.xl,
                        ),
                        child: _buildDevicesContent(
                          context,
                          ref,
                          appState,
                          lifecycleState,
                          isHost,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesContent(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    RoomLifecycleStateData lifecycleState,
    bool isHost,
  ) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        _buildDevicesContentInner(context, ref, appState, lifecycleState, isHost),
        const SizedBox(height: 10),
        // Floating dock with safe area bottom padding
        Padding(
          padding: EdgeInsets.only(bottom: safeBottom > 0 ? safeBottom : TSXSpacing.xl),
          child: _buildFloatingDock(context),
        ),
      ],
    );
  }

  Widget _buildDevicesContentInner(
    BuildContext context,
    WidgetRef ref,
    ApplicationState appState,
    RoomLifecycleStateData lifecycleState,
    bool isHost,
  ) {
    final state = appState.state;

    switch (state) {
      case SMAppState.error:
        return _buildErrorContent(appState, ref);

      case SMAppState.preparing:
        return _preparingContent(context, ref, appState);

      case SMAppState.ready:
      case SMAppState.playing:
      case SMAppState.paused:
        return _devicesContent(context, appState, lifecycleState, isHost);

      case SMAppState.stopping:
        return _stoppingContent(appState);

      case SMAppState.roomReady:
      case SMAppState.idle:
      case SMAppState.creatingRoom:
      case SMAppState.joiningRoom:
        return _devicesContent(context, appState, lifecycleState, isHost);
    }
  }

  Widget _buildErrorContent(ApplicationState appState, WidgetRef ref) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SMCard.tsx(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 64, color: TSXColors.error),
                  SizedBox(height: TSXSpacing.lg),
                  Text('Room Error', style: TSXTypography.headlineMedium),
                  SizedBox(height: TSXSpacing.md),
                  Text(appState.message ?? 'Something went wrong.', style: TSXTypography.bodyMedium, textAlign: TextAlign.center),
                  SizedBox(height: TSXSpacing.xl),
                  SMButton(text: 'Leave Room', variant: SMButtonVariant.tsxPrimary, onPressed: () => ref.read(roomLifecycleProvider.notifier).leaveRoom()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _devicesContent(
    BuildContext context,
    ApplicationState appState,
    RoomLifecycleStateData lifecycleState,
    bool isHost,
  ) {
    final members = lifecycleState.members;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Bar
          Row(
            children: [
              Text('Devices', style: TSXTypography.displayLarge),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.bug_report, color: TSXColors.primaryText),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DebugScreen())),
                tooltip: 'Debug / Diagnostics',
              ),
            ],
          ),
          SizedBox(height: TSXSpacing.md),
          Text('Connected devices in this room.', style: TSXTypography.bodyMedium),
          SizedBox(height: TSXSpacing.xl),

          // Main Devices Card
          Expanded(
            child: SMCard.tsx(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Devices', style: TSXTypography.metadata),
                  SizedBox(height: TSXSpacing.md),
                  ..._buildDeviceRows(members, isHost),
                  SizedBox(height: TSXSpacing.sm),
                  if (members.where((m) => m.role == RoomRole.participant).isEmpty && isHost) ...[
                    Row(
                      children: [
                        Icon(Icons.hourglass_empty, size: 16, color: TSXColors.warning),
                        SizedBox(width: TSXSpacing.sm),
                        Text('Waiting for participants to join…', style: TSXTypography.bodyMedium.copyWith(color: TSXColors.warning)),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Text('Per-device connection, audio, sync, and error state not yet available', style: TSXTypography.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDeviceRows(List<RoomMember> members, bool isHost) {
    final rows = <Widget>[];
    final participantMembers = members.where((m) => m.role == RoomRole.participant).toList();

    // Host row
    if (isHost) {
      rows.add(DeviceRow.tsx(
        name: 'This Device (Host)',
        role: 'HOST',
        roleColor: TSXColors.accent,
        isCurrent: true,
      ));
    }

    // Participant rows
    for (int i = 0; i < participantMembers.length; i++) {
      final member = participantMembers[i];
      if (i > 0) {
        rows.add(Divider(color: TSXColors.surfaceBorder, height: TSXSpacing.lg));
      }
      rows.add(DeviceRow.tsx(
        name: member.displayName ?? 'Participant ${i + 1}',
        role: 'PARTICIPANT',
        roleColor: TSXColors.secondaryText,
        isCurrent: false,
      ));
    }

    if (participantMembers.isEmpty && isHost) {
      if (rows.isNotEmpty) {
        rows.add(Divider(color: TSXColors.surfaceBorder, height: TSXSpacing.lg));
      }
      rows.add(Row(
        children: [
          Icon(Icons.hourglass_empty, size: 16, color: TSXColors.warning),
          SizedBox(width: TSXSpacing.sm),
          Text('Waiting for participants to join…', style: TSXTypography.bodyMedium.copyWith(color: TSXColors.warning)),
        ],
      ));
    }

    return rows;
  }

  Widget _preparingContent(BuildContext context, WidgetRef ref, ApplicationState appState) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SMLoadingIndicator.tsx(size: 48),
            SizedBox(height: TSXSpacing.lg),
            Text(appState.message ?? 'Preparing devices…', style: TSXTypography.headlineMedium, textAlign: TextAlign.center),
            SizedBox(height: TSXSpacing.md),
            Text('Waiting for all devices to prepare for synchronized session.', style: TSXTypography.bodyMedium, textAlign: TextAlign.center),
            SizedBox(height: TSXSpacing.xl),
            SMButton(text: 'Back to Room', variant: SMButtonVariant.tsxSecondary, onPressed: () => ref.read(roomLifecycleProvider.notifier).leaveRoom()),
          ],
        ),
      ),
    );
  }

  Widget _stoppingContent(ApplicationState appState) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SMLoadingIndicator.tsx(size: 48),
            SizedBox(height: TSXSpacing.lg),
            Text(appState.message ?? 'Stopping…', style: TSXTypography.headlineMedium, textAlign: TextAlign.center),
            SizedBox(height: TSXSpacing.md),
            Text('Wrapping up calibration and releasing devices.', style: TSXTypography.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingDock(BuildContext context) {
    return Center(
      child: Container(
        width: 220,
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: TSXColors.surface.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: TSXColors.surfaceBorder),
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
            // Tab 1: Room - navigate back to RoomDashboardScreen
            Expanded(
              child: _buildDockButton(
                label: 'Room',
                icon: Icons.group,
                active: false,
                onTap: () {
                  Navigator.pushReplacementNamed(context, AppRouter.roomDashboard);
                },
              ),
            ),
            // Tab 2: Devices - active (current screen)
            Expanded(
              child: _buildDockButton(
                label: 'Devices',
                icon: Icons.tune,
                active: true,
                onTap: () {
                  // Already on Devices screen
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
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: active ? TSXColors.surfaceBorder : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: TSXColors.accent.withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? TSXColors.accent : TSXColors.secondaryText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TSXTypography.labelSmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? TSXColors.accent : TSXColors.secondaryText,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 6),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TSXColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: TSXColors.accent.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 0,
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
}