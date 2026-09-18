import 'package:flutter/material.dart';
import '../../core/design_system/index.dart';
import '../components/soundmesh_button.dart';

/// QRScanScreen - placeholder for camera-based QR code scanning.
/// Adapted from Mahin's QRScanPlaceholderScreen.
class QRScanScreen extends StatelessWidget {
  const QRScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(SMSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: SMDimensions.emptyIconSize,
                color: SMColors.soundmeshBlue,
              ),
              SizedBox(height: SMSpacing.xl),
              Text(
                'Scan QR Code',
                textAlign: TextAlign.center,
                style: SMTypography.largeTitle.copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                'Camera-based QR scanning will be implemented in a later phase.',
                textAlign: TextAlign.center,
                style: SMTypography.body.copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.xxl),
              Text(
                '[UI SCAFFOLDING ONLY — NO CAMERA LOGIC]',
                textAlign: TextAlign.center,
                style: SMTypography.metadata.copyWith(color: SMColors.warning),
              ),
              SizedBox(height: SMSpacing.xl),
              SoundMeshButton(
                text: 'Back to Join Room',
                variant: SMButtonVariant.primary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}