import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/state_compat.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                        child: _buildBody(context, appState),
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

  Widget _buildBody(BuildContext context, ApplicationState appState) {
    final children = <Widget>[];

    if (appState.state == SMAppState.error) {
      children.add(
        _ErrorBanner(message: appState.message ?? 'Something went wrong.'),
      );
      children.add(SizedBox(height: SMSpacing.xl));
    }

    children.addAll([
      Center(
        child: Image.asset(
          'assets/logos/FOR_HOMESCREEN.png',
          width: 180,
          height: 180,
          fit: BoxFit.contain,
        ),
      ),
      SizedBox(height: SMSpacing.xl),
      Text(
        'SoundMesh',
        textAlign: TextAlign.center,
        style: SMTypography.display.copyWith(color: SMColors.primaryText),
      ),
      SizedBox(height: SMSpacing.md),
      Text(
        'Make your phones one speaker.',
        textAlign: TextAlign.center,
        style: SMTypography.body.copyWith(color: SMColors.secondaryText),
      ),
      SizedBox(height: SMSpacing.xxl),
      SMButton(
        text: 'Create Room',
        icon: Icons.add_circle,
        variant: SMButtonVariant.primary,
        onPressed: () => Navigator.pushNamed(context, AppRouter.createRoom),
      ),
      SizedBox(height: SMSpacing.lg),
      SMButton(
        text: 'Join Room',
        icon: Icons.sensors,
        variant: SMButtonVariant.secondary,
        onPressed: () => Navigator.pushNamed(context, AppRouter.joinRoom),
      ),
      SizedBox(height: SMSpacing.xxl),
    ]);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SMCard(
      elevated: false,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: SMColors.error,
            size: SMDimensions.iconSize,
          ),
          SizedBox(width: SMSpacing.md),
          Expanded(
            child: Text(
              message,
              style: SMTypography.body.copyWith(color: SMColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}