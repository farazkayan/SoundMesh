import 'package:flutter/material.dart';
import '../../core/theme/soundmesh_theme.dart';
import '../../core/router/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoundMeshColors.background,
      appBar: AppBar(
        backgroundColor: SoundMeshColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_board_rounded, color: SoundMeshColors.secondaryText),
            tooltip: 'Diagnostics',
            onPressed: () => Navigator.pushNamed(context, AppRouter.diagnostics),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildLogo(),
              const SizedBox(height: 16),
              _buildTitle(),
              const SizedBox(height: 8),
              _buildSubtitle(),
              const Spacer(flex: 2),
              _buildActions(context),
              const Spacer(flex: 1),
              _buildFooter(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: SoundMeshColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SoundMeshColors.accent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.speaker_group_rounded,
        size: 40,
        color: SoundMeshColors.accent,
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'SoundMesh',
      style: TextStyle(
        color: SoundMeshColors.primaryText,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'Synchronized audio, multiple devices',
      style: TextStyle(
        color: SoundMeshColors.secondaryText,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        _PrimaryButton(
          label: 'Create Room',
          icon: Icons.add_rounded,
          onPressed: () => Navigator.pushNamed(context, AppRouter.createRoom),
        ),
        const SizedBox(height: 16),
        _SecondaryButton(
          label: 'Join Room',
          icon: Icons.qr_code_scanner_rounded,
          onPressed: () => Navigator.pushNamed(context, AppRouter.joinRoom),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return const Text(
      'Turn nearby phones into one speaker',
      style: TextStyle(
        color: SoundMeshColors.mutedText,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: SoundMeshColors.accent,
          foregroundColor: SoundMeshColors.primaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: SoundMeshColors.primaryText,
          side: const BorderSide(
            color: SoundMeshColors.elevatedSurface,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
