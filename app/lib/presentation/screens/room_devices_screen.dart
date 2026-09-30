import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/index.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';

class RoomDevicesScreen extends ConsumerWidget {
  const RoomDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(applicationStateProvider);
    final lifecycleState = ref.watch(roomLifecycleProvider);
    final networkRepo = ref.watch(networkRepositoryProvider);
    final isHost = appState.isHost == true;
    final currentParticipantId = networkRepo.participantId;

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
                          currentParticipantId,
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
                            Navigator.pushReplacementNamed(
                              context,
                              AppRouter.roomDashboard,
                            );
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
  String currentParticipantId,
) {
  final safeBottom = MediaQuery.paddingOf(context).bottom;
  final state = appState.state;

  Widget content;
  switch (state) {
    case SMAppState.error:
      content = _buildErrorContent(appState, ref);
      break;

    case SMAppState.preparing:
      content = _preparingContent(context, ref, appState);
      break;

    case SMAppState.ready:
    case SMAppState.playing:
    case SMAppState.paused:
    case SMAppState.roomReady:
    case SMAppState.idle:
    case SMAppState.creatingRoom:
    case SMAppState.joiningRoom:
      content = _devicesListContent(context, appState, lifecycleState, isHost, currentParticipantId);
      break;

    case SMAppState.stopping:
      content = _stoppingContent(appState);
      break;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      content,
      SizedBox(height: safeBottom > 0 ? safeBottom + 72 : 80),
    ],
  );
}

Widget _buildErrorContent(ApplicationState appState, WidgetRef ref) {
  return Center(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TSXColors.surface,
        borderRadius: BorderRadius.circular(24),
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
            style: TSXTypography.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            appState.message ?? 'Something went wrong with the room.',
            textAlign: TextAlign.center,
            style: TSXTypography.bodyMedium,
          ),
          const SizedBox(height: 20),
          SMButton(
            text: 'Leave Room',
            variant: SMButtonVariant.tsxPrimary,
            onPressed: () => ref
                .read(roomLifecycleProvider.notifier)
                .leaveRoom(),
          ),
        ],
      ),
    ),
  );
}

Widget _devicesListContent(
  BuildContext context,
  ApplicationState appState,
  RoomLifecycleStateData lifecycleState,
  bool isHost,
  String currentParticipantId,
) {
  final members = lifecycleState.members;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Top Header Bar
      Row(
        children: [
          Text('Devices', style: TSXTypography.displayLarge),
        ],
      ),
      SizedBox(height: TSXSpacing.md),
      Text('Connected devices in this room.', style: TSXTypography.bodyMedium),
      SizedBox(height: TSXSpacing.xl),

      // Main Devices Card
      SMCard.tsx(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Devices', style: TSXTypography.metadata),
            SizedBox(height: TSXSpacing.md),
            ..._buildDeviceRows(members, isHost, currentParticipantId),
            SizedBox(height: TSXSpacing.sm),
            if (members.where((m) => m.role == RoomRole.participant).isEmpty && isHost) ...[
              Row(
                children: [
                  Icon(Icons.hourglass_empty, size: 16, color: TSXColors.warning),
                  SizedBox(width: TSXSpacing.sm),
                  Text('Waiting for participants to join…', style: TSXTypography.bodyMedium.copyWith(color: TSXColors.warning)),
                ],
              ),
              SizedBox(height: TSXSpacing.sm),
            ],
            Text('Per-device connection, audio, sync, and error state not yet available', style: TSXTypography.caption),
          ],
        ),
      ),
    ],
  );
}

List<Widget> _buildDeviceRows(List<RoomMember> members, bool isHost, String currentParticipantId) {
  final rows = <Widget>[];
  final participantMembers = members
      .where((m) => m.role == RoomRole.participant)
      .toList();

  // Host row
  if (isHost) {
    rows.add(
      DeviceRow.tsx(
        name: 'This Device (Host)',
        role: 'HOST',
        roleColor: TSXColors.accent,
        isCurrent: true,
      ),
    );
  }

  // Participant rows
  for (int i = 0; i < participantMembers.length; i++) {
    final member = participantMembers[i];
    final isCurrentDevice = member.participantId == currentParticipantId;
    if (i > 0) {
      rows.add(Divider(color: TSXColors.surfaceBorder, height: TSXSpacing.lg));
    }
    rows.add(
      DeviceRow.tsx(
        name: isCurrentDevice
            ? 'This Device'
            : (member.displayName ?? 'Participant ${i + 1}'),
        role: isCurrentDevice ? 'YOU' : 'PARTICIPANT',
        roleColor: isCurrentDevice ? TSXColors.accent : TSXColors.secondaryText,
        isCurrent: isCurrentDevice,
      ),
    );
  }

  if (participantMembers.isEmpty && isHost) {
    if (rows.isNotEmpty) {
      rows.add(Divider(color: TSXColors.surfaceBorder, height: TSXSpacing.lg));
    }
    rows.add(
      Row(
        children: [
          Icon(Icons.hourglass_empty, size: 16, color: TSXColors.warning),
          SizedBox(width: TSXSpacing.sm),
          Text(
            'Waiting for participants to join…',
            style: TSXTypography.bodyMedium.copyWith(color: TSXColors.warning),
          ),
        ],
      ),
    );
  }

  return rows;
}

Widget _preparingContent(
  BuildContext context,
  WidgetRef ref,
  ApplicationState appState,
) {
  return SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 80,
        horizontal: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SMLoadingIndicator.tsx(
            size: 48,
          ),
          const SizedBox(height: 18),
          Text(
            appState.message ?? 'Preparing devices…',
            textAlign: TextAlign.center,
            style: TSXTypography.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for all devices to prepare for the synchronized session.',
            textAlign: TextAlign.center,
            style: TSXTypography.bodyMedium,
          ),
          const SizedBox(height: 20),
          SMButton(
            text: 'Back to Room',
            variant: SMButtonVariant.tsxSecondary,
            onPressed: () =>
                ref.read(roomLifecycleProvider.notifier).leaveRoom(),
          ),
        ],
      ),
    ),
  );
}

Widget _stoppingContent(ApplicationState appState) {
  return SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 80,
        horizontal: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SMLoadingIndicator.tsx(
            size: 48,
          ),
          const SizedBox(height: 18),
          Text(
            appState.message ?? 'Stopping…',
            textAlign: TextAlign.center,
            style: TSXTypography.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Wrapping up calibration and releasing devices.',
            textAlign: TextAlign.center,
            style: TSXTypography.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
