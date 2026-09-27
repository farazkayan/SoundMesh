import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'tsx_visual_tokens.dart';

class DeviceRow extends StatelessWidget {
  const DeviceRow({
    super.key,
    required this.name,
    required this.role,
    required this.roleColor,
    required this.isCurrent,
    this.tsx = false,
  });

  const DeviceRow.tsx({
    super.key,
    required this.name,
    required this.role,
    required this.roleColor,
    required this.isCurrent,
  }) : tsx = true;

  final String name;
  final String role;
  final Color roleColor;
  final bool isCurrent;
  final bool tsx;

  @override
  Widget build(BuildContext context) {
    if (tsx) {
      return Row(
        children: [
          Icon(
            isCurrent ? Icons.phone_android : Icons.phone_android_outlined,
            size: 20,
            color: isCurrent ? TSXColors.accent : TSXColors.secondaryText,
          ),
          SizedBox(width: TSXSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TSXTypography.bodyMedium),
                SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: TSXSpacing.xs, vertical: 1),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(TSXRadius.sm),
                  ),
                  child: Text(role, style: TSXTypography.metadata.copyWith(color: roleColor, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: EdgeInsets.symmetric(horizontal: TSXSpacing.xs, vertical: 1),
              decoration: BoxDecoration(
                color: TSXColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(TSXRadius.sm),
              ),
              child: Text('YOU', style: TSXTypography.metadata.copyWith(color: TSXColors.accent, fontWeight: FontWeight.w700)),
            ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          isCurrent ? Icons.phone_android : Icons.phone_android_outlined,
          size: 20,
          color: isCurrent ? SMColors.soundmeshBlue : SMColors.secondaryText,
        ),
        SizedBox(width: SMSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: SMTypography.body.copyWith(color: SMColors.primaryText)),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: SMSpacing.xs, vertical: 1),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(SMRadius.small),
                ),
                child: Text(role, style: SMTypography.metadata.copyWith(color: roleColor, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        if (isCurrent)
          Container(
            padding: EdgeInsets.symmetric(horizontal: SMSpacing.xs, vertical: 1),
            decoration: BoxDecoration(
              color: SMColors.soundmeshBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(SMRadius.small),
            ),
            child: Text('YOU', style: SMTypography.metadata.copyWith(color: SMColors.soundmeshBlue, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}