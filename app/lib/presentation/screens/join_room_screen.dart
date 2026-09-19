import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/empty_state.dart';
import 'package:soundmesh/presentation/components/loading_indicator.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/components/text_input.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/application/providers/discovery_provider.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_types.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'dart:developer' as developer;

class JoinRoomScreen extends ConsumerWidget {
  const JoinRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StateBuilder(
      builder: (context, appState) {
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: _buildContent(context, appState, ref),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, ApplicationState appState, WidgetRef ref) {
    final state = appState.state;

    // Error → full-screen error state.
    if (state == SMAppState.error) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SMEmptyState.error(
            title: 'Failed to Join Room',
            message: appState.message ?? 'Code not found on this network.',
            icon: Icons.error_outline,
            onRetry: () => StateProvider.of(context).leaveRoom(),
          ),
          SizedBox(height: SMSpacing.xxl),
        ],
      );
    }

    // Room ready → joined successfully, show code confirmation.
    if (state == SMAppState.roomReady || state == SMAppState.ready) {
      // Read joinCode directly from joinRoomFlowProvider as primary source
      // (more reliable than appState.joinCode which goes through applicationStateProvider)
      final joinFlowState = ref.watch(joinRoomFlowProvider);
      final joinCode = (appState.joinCode ?? joinFlowState.joinCode ?? '').trim();
      final isValidCode = isValidRoomCode(joinCode);
      
      // For participants, when ready state is reached, auto-navigate to dashboard
      if (state == SMAppState.ready && appState.isHost != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, AppRouter.roomDashboard);
          }
        });
      }
      
      // If code is still empty at render time, show loading state instead of blank
      if (joinCode.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: SMSpacing.xl,
            vertical: SMSpacing.xl,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
              SizedBox(height: SMSpacing.lg),
              Text(
                'Finalizing connection…',
                textAlign: TextAlign.center,
                style: SMTypography.heading.copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.xxl),
            ],
          ),
        );
      }
      
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SMSpacing.xl,
          vertical: SMSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitle('Joined Room'),
            SizedBox(height: SMSpacing.md),
            Text(
              'You\'ve joined the room. The code is confirmed below.',
              style: SMTypography.body.copyWith(color: SMColors.secondaryText),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: SMSpacing.xxl),
            SMCard(
              elevated: true,
              padding: EdgeInsets.all(SMSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: SMDimensions.emptyIconSize,
                    color: SMColors.success,
                  ),
                  SizedBox(height: SMSpacing.lg),
                  Text(
                    'Room Code Confirmed',
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
            SMButton(
              text: 'Enter Room',
              icon: Icons.arrow_forward,
              variant: SMButtonVariant.primary,
              onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.roomDashboard),
            ),
            SizedBox(height: SMSpacing.lg),
            SMButton(
              text: 'Back',
              variant: SMButtonVariant.secondary,
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false),
            ),
            SizedBox(height: SMSpacing.xxl),
          ],
        ),
      );
    }

    // Joining room → honest in-progress UI.
    if (state == SMAppState.joiningRoom) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SMSpacing.xl,
          vertical: SMSpacing.xl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
            SizedBox(height: SMSpacing.lg),
            Text(
              appState.message ?? 'Joining room…',
              textAlign: TextAlign.center,
              style: SMTypography.heading.copyWith(color: SMColors.primaryText),
            ),
            SizedBox(height: SMSpacing.md),
            Text(
              'Scanning local network for room code…',
              textAlign: TextAlign.center,
              style: SMTypography.body.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xl),
            SMButton(
              text: 'Cancel',
              variant: SMButtonVariant.secondary,
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false),
            ),
            SizedBox(height: SMSpacing.xxl),
          ],
        ),
      );
    }

    // idle → show the form.
    return _JoinRoomForm();
  }

  String _formatCode(String code) {
    if (code.length == 6) {
      return '${code.substring(0, 3)}-${code.substring(3, 6)}';
    }
    return code;
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: SMTypography.largeTitle.copyWith(color: SMColors.primaryText),
    );
  }
}

class _JoinRoomForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_JoinRoomForm> createState() => _JoinRoomFormState();
}

class _JoinRoomFormState extends ConsumerState<_JoinRoomForm> {
  final _codeController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SMSpacing.xl,
        vertical: SMSpacing.xl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Intro eyebrow per the Stitch export (accent dot + label).
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: SMColors.soundmeshBlue,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: SMSpacing.sm),
              Text(
                'SOUNDMESH CONNECT',
                style: SMTypography.smallMetadata.copyWith(
                  color: SMColors.secondaryText,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: SMSpacing.sm),
          _buildTitle('Join a Room'),
          SizedBox(height: SMSpacing.md),
          Text(
            'Enter the 6-digit code shown on the host\'s screen.',
            style: SMTypography.body.copyWith(color: SMColors.secondaryText),
          ),
          SizedBox(height: SMSpacing.xxl),
          // QR Scan area (placeholder for future)
          SMCard(
            elevated: true,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, AppRouter.qrScan),
              borderRadius: BorderRadius.circular(SMRadius.medium),
              child: Padding(
                padding: EdgeInsets.all(SMSpacing.xl),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: SMColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(SMRadius.medium),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        size: 32,
                        color: SMColors.soundmeshBlue,
                      ),
                    ),
                    SizedBox(height: SMSpacing.lg),
                    Text(
                      'Scan QR Code',
                      style: SMTypography.heading.copyWith(color: SMColors.primaryText),
                    ),
                    SizedBox(height: SMSpacing.md),
                    Text(
                      'Point your camera at a SoundMesh QR code to join instantly.',
                      textAlign: TextAlign.center,
                      style: SMTypography.body.copyWith(color: SMColors.secondaryText),
                    ),
                    SizedBox(height: SMSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, color: SMColors.soundmeshBlue, size: 18),
                        SizedBox(width: SMSpacing.xs),
                        Text(
                          'Open Scanner',
                          style: SMTypography.label.copyWith(color: SMColors.soundmeshBlue),
                        ),
                        SizedBox(width: SMSpacing.xs),
                        Icon(Icons.chevron_right, color: SMColors.soundmeshBlue, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: SMSpacing.xl),
          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: SMColors.divider)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: SMSpacing.md),
                child: Text(
                  'OR',
                  style: SMTypography.caption.copyWith(color: SMColors.mutedText),
                ),
              ),
              Expanded(child: Divider(color: SMColors.divider)),
            ],
          ),
          SizedBox(height: SMSpacing.xl),
          // 6-digit code input with controller
          SMTextField(
            controller: _codeController,
            labelText: 'Room Code',
            hintText: 'Enter 6-digit code',
            maxLines: 1,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (value) {
              // Auto-format: only keep digits, max 6
              final digits = value.replaceAll(RegExp(r'\D'), '');
              if (digits.length <= 6) {
                _codeController.value = _codeController.value.copyWith(
                  text: digits,
                  selection: TextSelection.collapsed(offset: digits.length),
                );
              }
            },
          ),
          SizedBox(height: SMSpacing.xl),
          // Join button
          SMButton(
            text: 'Join Room',
            icon: Icons.arrow_forward,
            variant: SMButtonVariant.primary,
            onPressed: _isJoining ? null : _handleJoin,
          ),
          SizedBox(height: SMSpacing.lg),
          // Back button
          SMButton(
            text: 'Back',
            variant: SMButtonVariant.secondary,
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false),
          ),
          SizedBox(height: SMSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _handleJoin() async {
    developer.log(
      '[JOIN_TRACE] 01 UI Join Room onPressed ENTERED',
      name: 'SoundMesh.JoinRoomScreen',
    );

    // Guard: prevent double-tap while already joining
    if (_isJoining) {
      developer.log(
        '[JOIN_TRACE] _handleJoin blocked — already joining',
        name: 'SoundMesh.JoinRoomScreen',
      );
      return;
    }

    final code = _codeController.text.trim();
    developer.log(
      '[JOIN_TRACE] 02 room code received: length=${code.length}, valid=${isValidRoomCode(code)}',
      name: 'SoundMesh.JoinRoomScreen',
    );
    
    if (!isValidRoomCode(code)) {
      developer.log(
        '[JOIN_TRACE] 03 VALIDATION FAILED: code not 6 digits',
        name: 'SoundMesh.JoinRoomScreen',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid 6-digit code'),
          backgroundColor: SMColors.warning.withValues(alpha: 0.9),
        ),
      );
      return;
    }
    developer.log(
      '[JOIN_TRACE] 03 validation passed',
      name: 'SoundMesh.JoinRoomScreen',
    );

    setState(() => _isJoining = true);

    try {
      developer.log(
        '[JOIN_TRACE] 04 JoinRoomFlow.join ENTERED',
        name: 'SoundMesh.JoinRoomScreen',
      );

      // Use DiscoveryManager to scan for the room via UDP broadcast
      final discoveryManager = DiscoveryManager(
        platform: ref.read(discoveryPlatformProvider),
      );

      developer.log(
        '[JOIN_TRACE] 05 JoinRoomFlow invoking discovery scanForRoom',
        name: 'SoundMesh.JoinRoomScreen',
      );

      final announcement = await discoveryManager.participantService.scanForRoom(code);
      
      developer.log(
        '[JOIN_TRACE] 06 discovery result received: ${announcement != null ? "FOUND (${announcement.hostIp}:${announcement.hostPort})" : "NULL (timeout/not found)"}',
        name: 'SoundMesh.JoinRoomScreen',
      );
      
      if (announcement == null) {
        if (!mounted) return;
        developer.log(
          '[JOIN_TRACE] 07 NO ANNOUNCEMENT - showing timeout/unavailable error',
          name: 'SoundMesh.JoinRoomScreen',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No response — check the code and that both devices are on the same network'),
            backgroundColor: SMColors.error.withValues(alpha: 0.9),
          ),
        );
        setState(() => _isJoining = false);
        return;
      }

      developer.log(
        '[JOIN_TRACE] 08 ===== ROOM DISCOVERED =====',
        name: 'SoundMesh.JoinRoomScreen',
      );
      developer.log(
        '[JOIN_TRACE] 09 Discovered room at ${announcement.hostIp}:${announcement.hostPort}',
        name: 'SoundMesh.JoinRoomScreen',
      );
      developer.log(
        '[JOIN_TRACE] 10 Room details - code: ${announcement.code}, roomId: ${announcement.roomId}, hostName: ${announcement.hostName}',
        name: 'SoundMesh.JoinRoomScreen',
      );

      // Set the discovered IP/port on joinRoomFlowProvider
      ref.read(joinRoomFlowProvider.notifier).setHostIpAddress(announcement.hostIp);
      ref.read(joinRoomFlowProvider.notifier).setHostPort(announcement.hostPort);
      ref.read(joinRoomFlowProvider.notifier).setJoinCode(announcement.code);

      developer.log(
        '[JOIN_TRACE] 11 Set host IP/port on joinRoomFlowProvider, calling joinRoom()',
        name: 'SoundMesh.JoinRoomScreen',
      );

      // Trigger the actual connection
      await ref.read(joinRoomFlowProvider.notifier).joinRoom();
      developer.log(
        '[JOIN_TRACE] 12 joinRoom() completed',
        name: 'SoundMesh.JoinRoomScreen',
      );

    } catch (e, stackTrace) {
      developer.log(
        '[JOIN_TRACE] EXCEPTION at join flow: $e\n$stackTrace',
        name: 'SoundMesh.JoinRoomScreen',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join room: $e'),
            backgroundColor: SMColors.error.withValues(alpha: 0.9),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: SMTypography.largeTitle.copyWith(color: SMColors.primaryText),
    );
  }
}