import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/soundmesh_theme.dart';
import '../../core/router/app_router.dart';
import '../../application/providers/create_room_flow_provider.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _roomNameController = TextEditingController();

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(createRoomFlowProvider);

    ref.listen<CreateRoomFlowState>(createRoomFlowProvider, (previous, next) {
      if (next.status == CreateRoomFlowStatus.ready) {
        Navigator.pushReplacementNamed(context, AppRouter.room);
      }
    });

    return Scaffold(
      backgroundColor: SoundMeshColors.background,
      appBar: AppBar(
        backgroundColor: SoundMeshColors.surface,
        title: const Text(
          'Create Room',
          style: TextStyle(
            color: SoundMeshColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: SoundMeshColors.primaryText,
          onPressed: () {
            // Cancel in-flight hosting so the port is released and state is
            // not left running in the background, matching RoomScreen's back.
            ref.read(createRoomFlowProvider.notifier).reset();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildRoomNameInput(flowState),
                const SizedBox(height: 24),
                if (flowState.status == CreateRoomFlowStatus.idle)
                  _buildCreateButton(flowState),
                if (flowState.status == CreateRoomFlowStatus.creating ||
                    flowState.status == CreateRoomFlowStatus.hosting ||
                    flowState.status == CreateRoomFlowStatus.listening)
                  _buildHostingIndicator(flowState),
                if (flowState.status == CreateRoomFlowStatus.ready)
                  _buildConnectionInfo(flowState),
                if (flowState.status == CreateRoomFlowStatus.failed)
                  _buildError(flowState),
                const SizedBox(height: 32),
                _buildInstructions(flowState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room Name',
          style: TextStyle(
            color: SoundMeshColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Choose a name for your room',
          style: TextStyle(color: SoundMeshColors.secondaryText, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRoomNameInput(CreateRoomFlowState flowState) {
    final hasError = flowState.errorMessage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: SoundMeshColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? SoundMeshColors.error
                  : SoundMeshColors.elevatedSurface,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _roomNameController,
            enabled: flowState.status == CreateRoomFlowStatus.idle,
            style: const TextStyle(
              color: SoundMeshColors.primaryText,
              fontSize: 16,
            ),
            decoration: const InputDecoration(
              hintText: 'My Room',
              hintStyle: TextStyle(color: SoundMeshColors.mutedText),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: InputBorder.none,
            ),
            onChanged: (value) {
              ref.read(createRoomFlowProvider.notifier).setRoomName(value);
            },
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            flowState.errorMessage!,
            style: const TextStyle(color: SoundMeshColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildCreateButton(CreateRoomFlowState flowState) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          ref.read(createRoomFlowProvider.notifier).createRoom();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: SoundMeshColors.accent,
          foregroundColor: SoundMeshColors.primaryText,
          disabledBackgroundColor: SoundMeshColors.accent.withValues(
            alpha: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Create Room',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHostingIndicator(CreateRoomFlowState flowState) {
    final showAddress =
        flowState.status == CreateRoomFlowStatus.hosting ||
        flowState.status == CreateRoomFlowStatus.listening;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SoundMeshColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoundMeshColors.elevatedSurface, width: 1),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(SoundMeshColors.accent),
          ),
          const SizedBox(height: 16),
          Text(
            flowState.status == CreateRoomFlowStatus.creating
                ? 'Creating room...'
                : flowState.status == CreateRoomFlowStatus.hosting
                    ? 'Starting server...'
                    : 'Waiting for participant...',
            style: const TextStyle(
              color: SoundMeshColors.primaryText,
              fontSize: 14,
            ),
          ),
          if (showAddress) ...[
            const SizedBox(height: 24),
            _buildIpPortDisplay(flowState),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(CreateRoomFlowState flowState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SoundMeshColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoundMeshColors.success, width: 1),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: SoundMeshColors.success,
          ),
          const SizedBox(height: 16),
          const Text(
            'Room Created!',
            style: TextStyle(
              color: SoundMeshColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          _buildIpPortDisplay(flowState),
          const SizedBox(height: 16),
          const Text(
            'Give this address to the participant',
            style: TextStyle(
              color: SoundMeshColors.secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRouter.room);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SoundMeshColors.accent,
                foregroundColor: SoundMeshColors.primaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Enter Room',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpPortDisplay(CreateRoomFlowState flowState) {
    final ip = flowState.localIpAddress ?? '...';
    final port = flowState.port ?? 8765;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: SoundMeshColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IP Address',
                  style: TextStyle(
                    color: SoundMeshColors.mutedText,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ip,
                  style: const TextStyle(
                    color: SoundMeshColors.primaryText,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: SoundMeshColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Port',
                  style: TextStyle(
                    color: SoundMeshColors.mutedText,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  port.toString(),
                  style: const TextStyle(
                    color: SoundMeshColors.primaryText,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: '$ip:$port'));
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
    );
  }

  Widget _buildError(CreateRoomFlowState flowState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SoundMeshColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoundMeshColors.error, width: 1),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: SoundMeshColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            flowState.errorMessage ?? 'An error occurred',
            style: const TextStyle(color: SoundMeshColors.error, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                ref.read(createRoomFlowProvider.notifier).reset();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: SoundMeshColors.accent,
                side: const BorderSide(color: SoundMeshColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(CreateRoomFlowState flowState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SoundMeshColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SoundMeshColors.elevatedSurface, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            flowState.status == CreateRoomFlowStatus.ready
                ? Icons.rocket_launch_rounded
                : Icons.info_outline_rounded,
            size: 64,
            color: flowState.status == CreateRoomFlowStatus.ready
                ? SoundMeshColors.accent
                : SoundMeshColors.mutedText,
          ),
          const SizedBox(height: 16),
          Text(
            _getInstructionsText(flowState.status),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SoundMeshColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getInstructionsText(CreateRoomFlowStatus status) {
    switch (status) {
      case CreateRoomFlowStatus.idle:
        return 'Enter a room name and tap Create Room\nto start hosting';
      case CreateRoomFlowStatus.creating:
        return 'Creating your room...';
      case CreateRoomFlowStatus.hosting:
        return 'Starting server...\nWaiting for participant';
      case CreateRoomFlowStatus.listening:
        return 'Server started!\nWaiting for participant to join...';
      case CreateRoomFlowStatus.handshaking:
        return 'Handshaking with participant...\nExchanging protocol info';
      case CreateRoomFlowStatus.ready:
        return 'Share the IP address and port\nwith the participant device';
      case CreateRoomFlowStatus.failed:
        return 'Failed to create room\nTap Try Again to retry';
    }
  }
}
