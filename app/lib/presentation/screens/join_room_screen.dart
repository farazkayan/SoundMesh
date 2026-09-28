import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;

import 'package:soundmesh/application/providers/discovery_provider.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_types.dart';
import 'package:soundmesh/presentation/components/index.dart';
import 'package:soundmesh/presentation/state_compat.dart';

class JoinRoomScreen extends ConsumerWidget {
  const JoinRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(applicationStateProvider);

    return Scaffold(
      backgroundColor: TSXColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const RadialGradientBackdrop(),
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: TSXSpacing.xl,
                    vertical: TSXSpacing.xl,
                  ),
                  child: _buildContent(context, appState, ref),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ApplicationState appState,
    WidgetRef ref,
  ) {
    final state = appState.state;

    if (state == SMAppState.error) {
      return _buildErrorContent(appState, ref);
    }

    if (state == SMAppState.roomReady || state == SMAppState.ready) {
      return _buildJoinedContent(context, appState, ref, state);
    }

    if (state == SMAppState.joiningRoom) {
      return _buildJoiningContent(context, appState);
    }

    return const _JoinRoomForm();
  }

  Widget _buildErrorContent(
    ApplicationState appState,
    WidgetRef ref,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SMCard.tsx(
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: TSXColors.error,
                ),
                SizedBox(height: TSXSpacing.lg),
                Text(
                  'Failed to Join Room',
                  style: TSXTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: TSXSpacing.md),
                Text(
                  appState.message ?? 'Code not found on this network.',
                  style: TSXTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: TSXSpacing.xl),
                SMButton(
                  text: 'Try Again',
                  variant: SMButtonVariant.tsxPrimary,
                  onPressed: () => ref
                      .read(roomLifecycleProvider.notifier)
                      .leaveRoom(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedContent(
    BuildContext context,
    ApplicationState appState,
    WidgetRef ref,
    SMAppState state,
  ) {
    final joinFlowState = ref.watch(joinRoomFlowProvider);
    final joinCode =
        (appState.joinCode ?? joinFlowState.joinCode ?? '').trim();

    if (state == SMAppState.ready && appState.isHost != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRouter.roomDashboard,
          );
        }
      });
    }

    if (joinCode.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SMLoadingIndicator.tsx(size: 48),
            SizedBox(height: TSXSpacing.lg),
            Text(
              'Finalizing connection…',
              style: TSXTypography.headlineMedium,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: TSXColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 28,
              color: TSXColors.success,
            ),
          ),
          SizedBox(height: TSXSpacing.lg),
          Text(
            'Joined Room',
            style: TSXTypography.headlineMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: TSXSpacing.sm),
          Text(
            'You\'ve joined the room. The code is confirmed below.',
            style: TSXTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: TSXSpacing.xxl),
          SMCard.tsx(
            child: Column(
              children: [
                Text(
                  'Room Code Confirmed',
                  style: TSXTypography.headlineMedium.copyWith(
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: TSXSpacing.md),
                InlineCodeDisplay(
                  code: joinCode,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(
                      ClipboardData(
                        text: joinCode.replaceAll(RegExp(r'\D'), ''),
                      ),
                    );
                  },
                ),
                SizedBox(height: TSXSpacing.md),
                Text(
                  'Both devices show the same code',
                  style: TSXTypography.caption,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: TSXSpacing.lg),
                Text(
                  'Room: ${appState.roomId ?? "—"}',
                  style: TSXTypography.caption,
                ),
              ],
            ),
          ),
          SizedBox(height: TSXSpacing.xl),
          SMButton(
            text: 'Enter Room',
            icon: Icons.arrow_forward,
            variant: SMButtonVariant.tsxPrimary,
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              AppRouter.roomDashboard,
            ),
          ),
          SizedBox(height: TSXSpacing.lg),
          SMButton(
            text: 'Back',
            variant: SMButtonVariant.tsxSecondary,
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.home,
              (route) => false,
            ),
          ),
          SizedBox(height: TSXSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildJoiningContent(
    BuildContext context,
    ApplicationState appState,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SMLoadingIndicator.tsx(size: 48),
          SizedBox(height: TSXSpacing.lg),
          Text(
            appState.message ?? 'Joining room…',
            textAlign: TextAlign.center,
            style: TSXTypography.headlineMedium,
          ),
          SizedBox(height: TSXSpacing.md),
          Text(
            'Scanning local network for room code…',
            textAlign: TextAlign.center,
            style: TSXTypography.bodyMedium,
          ),
          SizedBox(height: TSXSpacing.xl),
          SMButton(
            text: 'Cancel',
            variant: SMButtonVariant.tsxSecondary,
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.home,
              (route) => false,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinRoomForm extends ConsumerStatefulWidget {
  const _JoinRoomForm();

  @override
  ConsumerState<_JoinRoomForm> createState() => _JoinRoomFormState();
}

class _JoinRoomFormState extends ConsumerState<_JoinRoomForm> {
  final _codeController = TextEditingController();

  bool _isJoining = false;

  void _handleInputChange(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final cleaned = digits.length > 6 ? digits.substring(0, 6) : digits;

    if (cleaned != _codeController.text) {
      _codeController.value = _codeController.value.copyWith(
        text: cleaned,
        selection: TextSelection.collapsed(
          offset: cleaned.length,
        ),
      );
    }

    setState(() {});
  }

  Future<void> _handleJoin() async {
    if (_isJoining) return;

    final code = _codeController.text.trim();

    if (!isValidRoomCode(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid 6-digit code'),
          backgroundColor: TSXColors.warning.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final discoveryManager = ref.read(discoveryManagerProvider);

      final announcement = await discoveryManager.participantService
          .scanForRoom(code);

      if (announcement == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No response — check the code and that both devices are on the same network',
            ),
            backgroundColor: TSXColors.error.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() => _isJoining = false);
        return;
      }

      ref
          .read(joinRoomFlowProvider.notifier)
          .setHostIpAddress(announcement.hostIp);

      ref
          .read(joinRoomFlowProvider.notifier)
          .setHostPort(announcement.hostPort);

      ref
          .read(joinRoomFlowProvider.notifier)
          .setJoinCode(announcement.code);

      await ref.read(joinRoomFlowProvider.notifier).joinRoom();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log(
          '[JOIN_TRACE] EXCEPTION at join flow: $e\n$stackTrace',
          name: 'SoundMesh.JoinRoomScreen',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join room: $e'),
            backgroundColor: TSXColors.error.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  void _handleOpenQRScanner() {
    showQRScannerModal(
      context: context,
      onScanSuccess: () {
        // QR code was successfully scanned and processed
        // The modal will close and the join flow will be triggered
        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawCode = _codeController.text;
    final isComplete = rawCode.length == 6;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRouter.home,
                    (route) => false,
                  ),
                  borderRadius: BorderRadius.circular(TSXRadius.full),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: TSXColors.surface,
                      borderRadius: BorderRadius.circular(
                        TSXRadius.full,
                      ),
                      border: Border.all(
                        color: TSXColors.surfaceBorder,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      size: 24,
                      color: TSXColors.primaryText,
                    ),
                  ),
                ),
              ),
              SizedBox(width: TSXSpacing.md),
              Text(
                'Join Room',
                style: TSXTypography.headlineMedium,
              ),
            ],
          ),
          SizedBox(height: TSXSpacing.xl),
          const TSXPulsingEmblem(
            size: 52,
            iconSize: 28,
          ),
          SizedBox(height: TSXSpacing.lg),
          Text(
            'Connect to a Room',
            style: TSXTypography.headlineLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: TSXSpacing.sm),
          Text(
            'Enter the 6-digit room code shown on the host device or scan their QR code.',
            style: TSXTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: TSXSpacing.xxl),
          SMCard.tsx(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ROOM CODE',
                      style: TSXTypography.metadata,
                    ),
                    if (rawCode.isNotEmpty)
                      Text(
                        '${rawCode.length}/6',
                        style: TSXTypography.metadata.copyWith(
                          color: TSXColors.accent,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: TSXSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive font size and letter spacing for code input
                    final double availableWidth = constraints.maxWidth;
                    final double fontSize = availableWidth < 300 ? 24.0 : 28.0;
                    final double letterSpacing = availableWidth < 300 ? 4.0 : 6.0;
                    final double hintFontSize = availableWidth < 300 ? 24.0 : 28.0;
                    final double hintLetterSpacing = availableWidth < 300 ? 4.0 : 6.0;

                    return TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TSXTypography.displayCode.copyWith(
                        fontSize: fontSize,
                        letterSpacing: letterSpacing,
                        color: TSXColors.primaryText,
                      ),
                      maxLength: 6,
                      onChanged: _handleInputChange,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '• • • - • • •',
                        hintStyle: TSXTypography.displayCode.copyWith(
                          fontSize: hintFontSize,
                          letterSpacing: hintLetterSpacing,
                          color: TSXColors.mutedText.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        filled: true,
                        fillColor: TSXColors.background,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: TSXSpacing.lg,
                          vertical: TSXSpacing.md,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            TSXRadius.lg,
                          ),
                          borderSide: BorderSide(
                            color: TSXColors.accent,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            TSXRadius.lg,
                          ),
                          borderSide: BorderSide(
                            color: TSXColors.accent,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            TSXRadius.lg,
                          ),
                          borderSide: BorderSide(
                            color: TSXColors.accentHover,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: TSXSpacing.sm),
                Text(
                  'Auto-syncs audio latency upon connection.',
                  style: TSXTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: TSXSpacing.lg),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleOpenQRScanner,
              borderRadius: BorderRadius.circular(TSXRadius.lg),
              child: Container(
                padding: EdgeInsets.all(TSXSpacing.lg),
                decoration: BoxDecoration(
                  color: TSXColors.surface,
                  borderRadius: BorderRadius.circular(
                    TSXRadius.lg,
                  ),
                  border: Border.all(
                    color: TSXColors.surfaceBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: TSXColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(
                          TSXRadius.md,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.qr_code,
                          size: 20,
                          color: TSXColors.accent,
                        ),
                      ),
                    ),
                    SizedBox(width: TSXSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan QR Code',
                            style: TSXTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Point camera at host screen',
                            style: TSXTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: TSXSpacing.md,
                        vertical: TSXSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: TSXColors.background,
                        borderRadius: BorderRadius.circular(
                          TSXRadius.lg,
                        ),
                        border: Border.all(
                          color: TSXColors.surfaceBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 14,
                            color: TSXColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'SCAN',
                            style: TSXTypography.metadata.copyWith(
                              color: TSXColors.accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: TSXColors.accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: TSXSpacing.xl),
          SMButton(
            text: 'Join Room',
            icon: Icons.arrow_forward,
            variant: SMButtonVariant.tsxPrimary,
            onPressed:
                (isComplete && !_isJoining) ? _handleJoin : null,
            isLoading: _isJoining,
          ),
          SizedBox(height: TSXSpacing.lg),
          Text(
            'AUTO-DISCOVERY ACTIVE • P2P READY',
            style: TSXTypography.metadata.copyWith(
              color: TSXColors.mutedText.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: TSXSpacing.xxl),
        ],
      ),
    );
  }
}
