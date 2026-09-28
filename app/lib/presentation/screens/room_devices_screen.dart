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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;
            return Stack(
              children: [
                const RadialGradientBackdrop(),
                SingleChildScrollView(
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
                ),
                // Floating navigation dock anchored at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: FloatingGlassDock(
                        currentIndex: 1, // Devices tab active
                        onTap: (index) {
                          if (index == 0) {
                            Navigator.pushReplacementNamed(context, AppRouter.roomDashboard);
                          }
                        },
                        isTablet: isTablet,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
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
        // Space for the floating dock at bottom
        SizedBox(height: safeBottom > 0 ? safeBottom + 72 : 80),
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

