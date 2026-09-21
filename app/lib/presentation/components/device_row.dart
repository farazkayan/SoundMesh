import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';

class DeviceRow extends StatelessWidget {
  const DeviceRow({
    super.key,
    required this.name,
    required this.role,
    required this.roleColor,
    required this.isCurrent,
  });

  final String name;
  final String role;
  final Color roleColor;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
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
              Text(
                name,
                style: SMTypography.body.copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: SMSpacing.xs, vertical: 1),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(SMRadius.small),
                ),
                child: Text(
                  role,
                  style: SMTypography.metadata.copyWith(
                    color: roleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
            child: Text(
              'YOU',
              style: SMTypography.metadata.copyWith(
                color: SMColors.soundmeshBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}