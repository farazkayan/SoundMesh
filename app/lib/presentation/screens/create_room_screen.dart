import 'package:flutter/material.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/presentation/components/index.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'dart:developer' as developer;

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(applicationStateProvider);
    final createState = ref.watch(createRoomFlowProvider);

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
                        child: _buildContent(context, ref, appState, createState),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Loading overlay - appears immediately on button press
            if (_isCreating)
              Container(
                color: TSXColors.background.withValues(alpha: 0.9),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SMLoadingIndicator.tsx(size: 48),
                      SizedBox(height: TSXSpacing.lg),
                      Text(
                        'Creating room…',
                        style: TSXTypography.headlineMedium,
                      ),
                      SizedBox(height: TSXSpacing.md),
                      Text(
                        'Setting up network and discovery…',
                        style: TSXTypography.bodyMedium.copyWith(color: TSXColors.secondaryText),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, ApplicationState appState, CreateRoomFlowState createState) {
    final state = appState.state;

    developer.log(
      'CreateRoomScreen: Building UI | '
      'state=${state.name} | joinCode=${appState.joinCode ?? "null"} | isHost=${appState.isHost}',
      name: 'SoundMesh.CreateRoomScreen',
    );

    // Error → full-screen error state
    if (state == SMAppState.error) {
      return _buildErrorContent(appState, ref);
    }

    // Room ready → navigate to RoomCreatedScreen
    if (state == SMAppState.roomReady || state == SMAppState.ready) {
      // Use post-frame callback to navigate after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, AppRouter.roomCreated);
        }
      });
      // Show loading while navigation happens
      return _buildLoadingContent();
    }

    // Creating room → honest in-progress UI
    if (state == SMAppState.creatingRoom) {
      return _buildCreatingContent(context, appState);
    }

    // Idle or any other state → show the form
    return _buildFormContent(context, ref);
  }

  Widget _buildErrorContent(ApplicationState appState, WidgetRef ref) {
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
                  'Failed to Create Room',
                  style: TSXTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: TSXSpacing.md),
                Text(
                  appState.message ?? 'Something went wrong.',
                  style: TSXTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: TSXSpacing.xl),
                SMButton(
                  text: 'Try Again',
                  variant: SMButtonVariant.tsxPrimary,
                  onPressed: () {
                    ref.read(roomLifecycleProvider.notifier).leaveRoom();
                    ref.read(createRoomFlowProvider.notifier).reset();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SMLoadingIndicator.tsx(size: 48),
          SizedBox(height: TSXSpacing.lg),
          Text(
            'Loading room…',
            style: TSXTypography.headlineMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCreatingContent(BuildContext context, ApplicationState appState) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SMLoadingIndicator.tsx(size: 48),
          SizedBox(height: TSXSpacing.lg),
          Text(
            appState.message ?? 'Creating room…',
            textAlign: TextAlign.center,
            style: TSXTypography.headlineMedium,
          ),
          SizedBox(height: TSXSpacing.md),
          Text(
            'Waiting for the room to be established.',
            textAlign: TextAlign.center,
            style: TSXTypography.bodyMedium,
          ),
          SizedBox(height: TSXSpacing.xl),
          SMButton(
            text: 'Back',
            variant: SMButtonVariant.tsxSecondary,
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.home,
              (route) => false,
            ),
            isLoading: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TSX Emblem
        Center(child: TSXEmblem(size: 96, active: true)),
        SizedBox(height: TSXSpacing.md),
        _buildTitle('Create Room'),
        SizedBox(height: TSXSpacing.md),
        Text(
          'Start a local room for nearby phones to join.',
          style: TSXTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: TSXSpacing.xxl),

        // Room Name Input
        SMTextField(
          labelText: 'Room Name',
          hintText: 'e.g. Studio Space',
          tsx: true,
          onChanged: (value) =>
              ref.read(createRoomFlowProvider.notifier).setRoomName(value),
        ),
        SizedBox(height: TSXSpacing.xl),

        // Zero-setup notice card
        SMCard.tsx(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sensors, size: 20, color: TSXColors.accent),
              SizedBox(width: TSXSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zero Setup Needed',
                      style: TSXTypography.headlineMedium.copyWith(fontSize: 16),
                    ),
                    SizedBox(height: TSXSpacing.xs),
                    Text(
                      'Phones on the same network or nearby can stream synchronously with low latency.',
                      style: TSXTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: TSXSpacing.xl),

        // Create Room Button
        SMButton(
          text: 'Create Room',
          icon: Icons.add,
          variant: SMButtonVariant.tsxPrimary,
          onPressed: () => _createRoom(context, ref),
          isLoading: _isCreating,
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
    );
  }

  Future<void> _createRoom(BuildContext context, WidgetRef ref) async {
    // Immediate local loading state for instant feedback before native calls block
    setState(() => _isCreating = true);

    developer.log(
      'CreateRoomScreen: _createRoom() called',
      name: 'SoundMesh.CreateRoomScreen',
    );
    try {
      await ref.read(createRoomFlowProvider.notifier).createRoom(ref: ref);
      developer.log(
        'CreateRoomScreen: createRoom() completed',
        name: 'SoundMesh.CreateRoomScreen',
      );
      // State will update via stateChanges stream; UI reacts automatically.
      // Navigation to RoomCreatedScreen happens in _buildContent when state becomes roomReady
    } catch (e) {
      developer.log(
        'CreateRoomScreen: createRoom() threw error: $e',
        name: 'SoundMesh.CreateRoomScreen',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create room: $e'),
            backgroundColor: TSXColors.error.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: TSXTypography.headlineLarge,
      textAlign: TextAlign.center,
    );
  }
}