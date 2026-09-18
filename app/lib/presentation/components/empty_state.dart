import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'button.dart';

enum SMEmptyStateKind { empty, error }

class SMEmptyState extends StatelessWidget {
  const SMEmptyState._({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Try again',
    required this.kind,
  });

  const SMEmptyState.empty({
    Key? key,
    required String title,
    String? message,
    IconData? icon,
    VoidCallback? onRetry,
    String retryLabel = 'Try again',
  }) : this._(
          key: key,
          title: title,
          message: message,
          icon: icon,
          onRetry: onRetry,
          retryLabel: retryLabel,
          kind: SMEmptyStateKind.empty,
        );

  const SMEmptyState.error({
    Key? key,
    required String title,
    String? message,
    IconData? icon,
    VoidCallback? onRetry,
    String retryLabel = 'Try again',
  }) : this._(
          key: key,
          title: title,
          message: message,
          icon: icon,
          onRetry: onRetry,
          retryLabel: retryLabel,
          kind: SMEmptyStateKind.error,
        );

  final String title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final SMEmptyStateKind kind;

  @override
  Widget build(BuildContext context) {
    final iconColor = kind == SMEmptyStateKind.error ? SMColors.error : SMColors.mutedText;
    final titleColor = kind == SMEmptyStateKind.error ? SMColors.error : SMColors.primaryText;
    final defaultIcon = kind == SMEmptyStateKind.error ? Icons.error_outline : Icons.inbox_outlined;

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
              SMButton(text: retryLabel, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}