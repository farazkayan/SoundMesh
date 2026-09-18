import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/brand_logo.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/empty_state.dart';
import 'package:soundmesh/presentation/components/loading_indicator.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/components/text_input.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_types.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'dart:developer' as developer;

class CreateRoomScreen extends StatelessWidget {
  const CreateRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: SMSpacing.xl,
                          vertical: SMSpacing.xl,
                        ),
                        child: _buildContent(context, appState),
                      ),
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

  Widget _buildContent(BuildContext context, ApplicationState appState) {
    final state = appState.state;

    developer.log(
      'CreateRoomScreen: Building UI | '
      'state=${state.name} | joinCode=${appState.joinCode ?? "null"} | isHost=${appState.isHost}',
      name: 'SoundMesh.CreateRoomScreen',
    );

    // Error → full-screen error state (Phase 1 SMEmptyState.error component).
    if (state == SMAppState.error) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SMEmptyState.error(
            title: 'Failed to Create Room',
            message: appState.message ?? 'Something went wrong.',
            icon: Icons.error_outline,
            onRetry: () => StateProvider.of(context).leaveRoom(),
          ),
          SizedBox(height: SMSpacing.xxl),
        ],
      );
    }

    // Room ready → success view with join info (no auto-navigation).
    // Handle both roomReady (listening) and ready (handshake complete) states.
    if (state == SMAppState.roomReady || state == SMAppState.ready) {
      final joinCode = appState.joinCode ?? '';
      final isValidCode = isValidRoomCode(joinCode);
      
      developer.log(
        'CreateRoomScreen: Showing room ready UI | joinCode=$joinCode | isValid=$isValidCode',
        name: 'SoundMesh.CreateRoomScreen',
      );
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitle(state == SMAppState.ready ? 'Room Ready' : 'Room Created'),
          SizedBox(height: SMSpacing.md),
          Text(
            state == SMAppState.ready
                ? 'Room is ready. Share the 6-digit code below to let others join.'
                : 'Share the 6-digit code below to let others join your room.',
            style: SMTypography.body.copyWith(color: SMColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: SMSpacing.xxl),
          
          // Prominent 6-digit code card
          SMCard(
            elevated: true,
            padding: EdgeInsets.all(SMSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.wifi_tethering,
                  size: SMDimensions.emptyIconSize * 0.8,
                  color: SMColors.soundmeshBlue,
                ),
                SizedBox(height: SMSpacing.lg),
                Text(
                  'Room Code',
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
                    border: Border.all(color: SMColors.soundmeshBlue.withValues(alpha: 0.5), width: 2),
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
                  'Other phones enter this code to join',
                  style: SMTypography.caption.copyWith(color: SMColors.mutedText),
                ),
                SizedBox(height: SMSpacing.lg),
                Text(
                  'Room: ${appState.roomId ?? "—"}',
                  style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
                ),
                SizedBox(height: SMSpacing.md),
                Text(
                  appState.isHost == true ? 'You are the host.' : 'You are a participant.',
                  style: SMTypography.bodyEmphasis.copyWith(color: SMColors.primaryText),
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
      );
    }

// Creating room → honest in-progress UI (no premature success).
    if (state == SMAppState.creatingRoom) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
            SizedBox(height: SMSpacing.lg),
            Text(
              appState.message ?? 'Creating room…',
              textAlign: TextAlign.center,
              style: SMTypography.heading
                  .copyWith(color: SMColors.primaryText),
            ),
            SizedBox(height: SMSpacing.md),
            Text(
              'Waiting for the room to be established.',
              textAlign: TextAlign.center,
              style: SMTypography.body.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xl),
            SMButton(
               text: 'Back',
               variant: SMButtonVariant.secondary,
               onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false),
               enabled: false,
               isLoading: true,
             ),
            SizedBox(height: SMSpacing.xxl),
          ],
        ),
      );
    }

    // idle or any other state → show the form (default).
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand mark — container treatment per the Stitch export
        // (rounded-2xl surface fill, shadow-2xl shadow-black/40).
        Center(
          child: BrandLogo(size: 96),
        ),
        SizedBox(height: SMSpacing.md),
        _buildTitle('Create Room'),
        SizedBox(height: SMSpacing.md),
        Text(
          'Start a local room for nearby phones to join.',
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xxl),
        Consumer(
          builder: (context, ref, _) => SMTextField(
            labelText: 'Room name',
            hintText: 'SoundMesh Room',
            onChanged: (value) => ref.read(createRoomFlowProvider.notifier).setRoomName(value),
          ),
        ),
        SizedBox(height: SMSpacing.xl),
        // Zero-setup notice card per the Stitch export.
        SMCard(
          padding: EdgeInsets.all(SMSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.sensors,
                size: 20,
                color: SMColors.soundmeshBlue,
              ),
              SizedBox(width: SMSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zero setup needed',
                      style: SMTypography.heading
                          .copyWith(color: SMColors.primaryText),
                    ),
                    SizedBox(height: SMSpacing.xs),
                    Text(
                      'Phones on the same network or nearby can stream synchronously with low latency.',
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
        SMButton(
          text: 'Create Room',
          icon: Icons.check,
          variant: SMButtonVariant.primary,
          onPressed: () => _createRoom(context),
        ),
        SizedBox(height: SMSpacing.lg),
        SMButton(
          text: 'Back',
          variant: SMButtonVariant.secondary,
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Future<void> _createRoom(BuildContext context) async {
    developer.log(
      'CreateRoomScreen: _createRoom() called',
      name: 'SoundMesh.CreateRoomScreen',
    );
    final controller = StateProvider.of(context);
    try {
      await controller.createRoom();
      developer.log(
        'CreateRoomScreen: createRoom() completed',
        name: 'SoundMesh.CreateRoomScreen',
      );
      // State will update via stateChanges stream; UI reacts automatically.
      // No navigation here — roomReady state shows the join code screen.
    } catch (e) {
      developer.log(
        'CreateRoomScreen: createRoom() threw error: $e',
        name: 'SoundMesh.CreateRoomScreen',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create room: $e'),
            backgroundColor: SMColors.error.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: SMTypography.largeTitle.copyWith(color: SMColors.primaryText),
    );
  }

  String _formatCode(String code) {
    // Format as XXX-XXX for readability
    if (code.length == 6) {
      return '${code.substring(0, 3)}-${code.substring(3, 6)}';
    }
    return code;
  }
}
