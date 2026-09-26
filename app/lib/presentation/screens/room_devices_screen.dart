import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:soundmesh/core/design_system/index.dart';
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
      appBar: AppBar(
        title: Text(
          'Devices',
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        backgroundColor: SMColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report, color: SMColors.primaryText),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebugScreen()),
              );
            },
            tooltip: 'Debug / Diagnostics',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: SMSpacing.xl,
            vertical: SMSpacing.xl,
          ),
          child: _buildContent(
            context,
            appState,
            lifecycleState,
            isHost,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ApplicationState appState,
    RoomLifecycleStateData lifecycleState,
    bool isHost,
  ) {
    final state = appState.state;

    switch (state) {
      case SMAppState.error:
        return Column(
          children: [
            SMEmptyState.error(
              title: 'Room Error',
              message: appState.message ?? 'Something went wrong.',
              icon: Icons.error_outline,
              onRetry: () => StateProvider.of(context).leaveRoom(),
            ),
            SizedBox(height: SMSpacing.xxl),
          ],
        );

      case SMAppState.preparing:
        return _preparingContent(context, appState);

      case SMAppState.ready:
      case SMAppState.playing:
      case SMAppState.paused:
        return _devicesContent(
          context,
          appState,
          lifecycleState,
          isHost,
        );

      case SMAppState.stopping:
        return _stoppingContent(appState);

      case SMAppState.roomReady:
      case SMAppState.idle:
      case SMAppState.creatingRoom:
      case SMAppState.joiningRoom:
        return _devicesContent(
          context,
          appState,
          lifecycleState,
          isHost,
        );
    }
  }

  Widget _devicesContent(
    BuildContext context,
    ApplicationState appState,
    RoomLifecycleStateData lifecycleState,
    bool isHost,
  ) {
    final members = lifecycleState.members;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Devices header
        Text(
          'Devices',
          style: SMTypography.largeTitle.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'Connected devices in this room.',
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xl),

        // Device list
        _buildDeviceListCard(members, isHost),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _buildDeviceListCard(List<RoomMember> members, bool isHost) {
    return SMCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Devices',
            style: SMTypography.label.copyWith(color: SMColors.secondaryText),
          ),
          SizedBox(height: SMSpacing.md),
          ..._buildDeviceRows(members, isHost),
          SizedBox(height: SMSpacing.sm),
          if (members.where((m) => m.role == RoomRole.participant).isEmpty && isHost) ...[
            Text(
              'Waiting for participants to join…',
              style: SMTypography.body.copyWith(color: SMColors.warning),
            ),
          ],
          SizedBox(height: SMSpacing.sm),
          Text(
            'Per-device connection, audio, sync, and error state not yet available',
            style: SMTypography.caption.copyWith(color: SMColors.mutedText),
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
      rows.add(DeviceRow(
        name: 'This Device (Host)',
        role: 'HOST',
        roleColor: SMColors.soundmeshBlue,
        isCurrent: true,
      ));
    }

    // Participant rows
    for (int i = 0; i < participantMembers.length; i++) {
      final member = participantMembers[i];
      if (i > 0) {
        rows.add(Divider(color: SMColors.divider, height: SMSpacing.lg));
      }
      rows.add(DeviceRow(
        name: member.displayName ?? 'Participant ${i + 1}',
        role: 'PARTICIPANT',
        roleColor: SMColors.secondaryText,
        isCurrent: false,
      ));
    }

    // If no participants yet and host
    if (participantMembers.isEmpty && isHost) {
      if (rows.isNotEmpty) {
        rows.add(Divider(color: SMColors.divider, height: SMSpacing.lg));
      }
      rows.add(Row(
        children: [
          Icon(Icons.hourglass_empty, size: 16, color: SMColors.warning),
          SizedBox(width: SMSpacing.sm),
          Text(
            'Waiting for participants to join…',
            style: SMTypography.body.copyWith(color: SMColors.warning),
          ),
        ],
      ));
    }

    return rows;
  }

  Widget _preparingContent(BuildContext context, ApplicationState appState) {
    return Column(
      children: [
        SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
        SizedBox(height: SMSpacing.lg),
        Text(
          appState.message ?? 'Preparing devices…',
          textAlign: TextAlign.center,
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'Waiting for all devices to prepare for synchronized session.',
          textAlign: TextAlign.center,
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xl),
        SMButton(
          text: 'Back to Room',
          variant: SMButtonVariant.secondary,
          onPressed: () => StateProvider.of(context).leaveRoom(),
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
          appState.message ?? 'Stopping…',
          textAlign: TextAlign.center,
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'Wrapping up calibration and releasing devices.',
          textAlign: TextAlign.center,
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }
}