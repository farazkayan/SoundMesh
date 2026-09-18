import 'package:flutter/material.dart';
import '../../core/design_system/index.dart';
import 'soundmesh_button.dart';

enum SoundMeshEmptyStateKind { empty, error }

class SoundMeshEmptyState extends StatelessWidget {
  const SoundMeshEmptyState.empty({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Try again',
  }) : kind = SoundMeshEmptyStateKind.empty;

  const SoundMeshEmptyState.error({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Try again',
  }) : kind = SoundMeshEmptyStateKind.error;

  final String title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final SoundMeshEmptyStateKind kind;

  @override
  Widget build(BuildContext context) {
    final iconColor = kind == SoundMeshEmptyStateKind.error ? SMColors.error : SMColors.mutedText;
    final titleColor = kind == SoundMeshEmptyStateKind.error ? SMColors.error : SMColors.primaryText;
    final defaultIcon = kind == SoundMeshEmptyStateKind.error ? Icons.error_outline : Icons.inbox_outlined;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: SMSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? defaultIcon,
              size: SMDimensions.emptyIconSize,
              color: iconColor,
            ),
            SizedBox(height: SMSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SMTypography.title.copyWith(color: titleColor),
            ),
            if (message != null) ...[
              SizedBox(height: SMSpacing.md),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: SMTypography.body.copyWith(
                  color: SMColors.secondaryText,
                ),
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: SMSpacing.xl),
              SoundMeshButton(text: retryLabel, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}