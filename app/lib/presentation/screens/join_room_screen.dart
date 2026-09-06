import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/soundmesh_theme.dart';
import '../../core/router/app_router.dart';
import '../../application/providers/join_room_flow_provider.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8765');

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(joinRoomFlowProvider);

    ref.listen<JoinRoomFlowState>(joinRoomFlowProvider, (previous, next) {
      if (next.status == JoinRoomFlowStatus.connected) {
        Navigator.pushReplacementNamed(context, AppRouter.room);
      }
    });

    return Scaffold(
      backgroundColor: SoundMeshColors.background,
      appBar: AppBar(
        backgroundColor: SoundMeshColors.surface,
        title: const Text(
          'Join Room',
          style: TextStyle(
            color: SoundMeshColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: SoundMeshColors.primaryText,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildHostInput(flowState),
              const SizedBox(height: 16),
              _buildPortInput(flowState),
              const SizedBox(height: 24),
              if (flowState.status == JoinRoomFlowStatus.idle)
                _buildJoinButton(flowState),
              if (flowState.status == JoinRoomFlowStatus.connecting)
                _buildConnectingIndicator(flowState),
              if (flowState.status == JoinRoomFlowStatus.failed)
                _buildError(flowState),
              const SizedBox(height: 32),
              _buildInstructions(flowState),
            ],
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
          'Host Address',
          style: TextStyle(
            color: SoundMeshColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Enter the IP address and port from the host device',
          style: TextStyle(
            color: SoundMeshColors.secondaryText,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildHostInput(JoinRoomFlowState flowState) {
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
            controller: _ipController,
            enabled: flowState.status == JoinRoomFlowStatus.idle,
            style: const TextStyle(
              color: SoundMeshColors.primaryText,
              fontSize: 16,
            ),
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              hintText: '192.168.1.100',
              hintStyle: TextStyle(color: SoundMeshColors.mutedText),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
              labelText: 'IP Address',
              labelStyle: TextStyle(color: SoundMeshColors.mutedText),
            ),
            onChanged: (value) {
              ref.read(joinRoomFlowProvider.notifier).setHostIpAddress(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPortInput(JoinRoomFlowState flowState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: SoundMeshColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SoundMeshColors.elevatedSurface,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _portController,
            enabled: flowState.status == JoinRoomFlowStatus.idle,
            style: const TextStyle(
              color: SoundMeshColors.primaryText,
              fontSize: 16,
            ),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '8765',
              hintStyle: TextStyle(color: SoundMeshColors.mutedText),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
              labelText: 'Port',
              labelStyle: TextStyle(color: SoundMeshColors.mutedText),
            ),
            onChanged: (value) {
              final port = int.tryParse(value) ?? 8765;
              ref.read(joinRoomFlowProvider.notifier).setHostPort(port);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJoinButton(JoinRoomFlowState flowState) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          ref.read(joinRoomFlowProvider.notifier).joinRoom();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: SoundMeshColors.accent,
          foregroundColor: SoundMeshColors.primaryText,
          disabledBackgroundColor: SoundMeshColors.accent.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Join Room',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectingIndicator(JoinRoomFlowState flowState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SoundMeshColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SoundMeshColors.elevatedSurface,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(SoundMeshColors.accent),
          ),
          const SizedBox(height: 16),
          Text(
            'Connecting to ${flowState.hostIpAddress}:${flowState.hostPort}...',
            style: const TextStyle(
              color: SoundMeshColors.primaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(JoinRoomFlowState flowState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SoundMeshColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SoundMeshColors.error,
          width: 1,
        ),
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
            flowState.errorMessage ?? 'Failed to connect',
            style: const TextStyle(
              color: SoundMeshColors.error,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                ref.read(joinRoomFlowProvider.notifier).reset();
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

  Widget _buildInstructions(JoinRoomFlowState flowState) {
    return Expanded(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: SoundMeshColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SoundMeshColors.elevatedSurface,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                flowState.status == JoinRoomFlowStatus.connected
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 48,
                color: flowState.status == JoinRoomFlowStatus.connected
                    ? SoundMeshColors.success
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
        ),
      ),
    );
  }

  String _getInstructionsText(JoinRoomFlowStatus status) {
    switch (status) {
      case JoinRoomFlowStatus.idle:
        return 'Enter the host IP address and port\nfrom the Create Room screen';
      case JoinRoomFlowStatus.connecting:
        return 'Establishing connection...';
      case JoinRoomFlowStatus.connected:
        return 'Connected!\nEntering room...';
      case JoinRoomFlowStatus.failed:
        return 'Could not connect to host\nCheck the IP address and port';
    }
  }
}
