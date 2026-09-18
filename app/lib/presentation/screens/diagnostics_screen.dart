import 'package:flutter/material.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/surface.dart';

class RoomDiagnosticsScreen extends StatelessWidget {
  const RoomDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: SMSpacing.xl, vertical: SMSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Diagnostics',
                style: SMTypography.largeTitle.copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                'Technical details for debugging and verification.',
                style: SMTypography.body.copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.xl),
              SMCard(
                elevated: true,
                child: Column(
                  children: [
                    Icon(
                      Icons.bug_report,
                      size: SMDimensions.emptyIconSize,
                      color: SMColors.soundmeshBlue,
                    ),
                    SizedBox(height: SMSpacing.lg),
                    Text(
                      'Diagnostics',
                      style: SMTypography.heading.copyWith(color: SMColors.primaryText),
                    ),
                    SizedBox(height: SMSpacing.md),
                    Text(
                      'This screen exposes technical metrics for development and debugging.\nMetrics are categorized by confidence: Measured, Estimated, Unknown, Unavailable.',
                      textAlign: TextAlign.center,
                      style: SMTypography.body.copyWith(color: SMColors.secondaryText),
                    ),
                    SizedBox(height: SMSpacing.lg),
                    Text(
                      '[UI SCAFFOLDING — NO REAL DIAGNOSTICS DATA]',
                      style: SMTypography.metadata.copyWith(color: SMColors.warning),
                    ),
                  ],
                ),
              ),
              SizedBox(height: SMSpacing.xl),
              _DiagnosticsSection(
                title: 'Room',
                items: [
                  _DiagnosticItem('Room ID', '—', _DiagnosticConfidence.unavailable),
                  _DiagnosticItem('Host', '—', _DiagnosticConfidence.unavailable),
                  _DiagnosticItem('Session State', 'CREATED', _DiagnosticConfidence.measured),
                ],
              ),
              _DiagnosticsSection(
                title: 'Devices',
                items: [
                  _DiagnosticItem('Device Count', '0', _DiagnosticConfidence.measured),
                  _DiagnosticItem('Connected', '0', _DiagnosticConfidence.measured),
                  _DiagnosticItem('Ready', '0', _DiagnosticConfidence.measured),
                ],
              ),
              _DiagnosticsSection(
                title: 'Networking',
                items: [
                  _DiagnosticItem('Transport', '—', _DiagnosticConfidence.unavailable),
                  _DiagnosticItem('RTT (avg)', '—', _DiagnosticConfidence.unknown),
                  _DiagnosticItem('Jitter', '—', _DiagnosticConfidence.unknown),
                ],
              ),
              _DiagnosticsSection(
                title: 'Audio',
                items: [
                  _DiagnosticItem('Format', '—', _DiagnosticConfidence.unavailable),
                  _DiagnosticItem('Sample Rate', '—', _DiagnosticConfidence.unavailable),
                  _DiagnosticItem('Channels', '—', _DiagnosticConfidence.unavailable),
                ],
              ),
              _DiagnosticsSection(
                title: 'Synchronization',
                items: [
                  _DiagnosticItem('Offset', '—', _DiagnosticConfidence.unknown),
                  _DiagnosticItem('Drift Rate', '—', _DiagnosticConfidence.unknown),
                  _DiagnosticItem('Confidence', '—', _DiagnosticConfidence.unknown),
                ],
              ),
              SizedBox(height: SMSpacing.xl),
              SMButton(
                text: 'Back to Room',
                variant: SMButtonVariant.secondary,
                onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.roomDashboard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection({required this.title, required this.items});

  final String title;
  final List<_DiagnosticItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        SMCard(
          child: Column(
            children: items.map((item) => _DiagnosticRow(item: item)).toList(),
          ),
        ),
        SizedBox(height: SMSpacing.lg),
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.item});

  final _DiagnosticItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SMSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item.label, style: SMTypography.body.copyWith(color: SMColors.secondaryText)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.value, style: SMTypography.bodyEmphasis.copyWith(color: SMColors.primaryText)),
              SizedBox(width: SMSpacing.sm),
              _ConfidenceBadge(confidence: item.confidence),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiagnosticItem {
  const _DiagnosticItem(this.label, this.value, this.confidence);

  final String label;
  final String value;
  final _DiagnosticConfidence confidence;
}

enum _DiagnosticConfidence { measured, estimated, unknown, unavailable }

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final _DiagnosticConfidence confidence;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (confidence) {
      case _DiagnosticConfidence.measured:
        label = 'Measured';
        color = SMColors.success;
        break;
      case _DiagnosticConfidence.estimated:
        label = 'Estimated';
        color = SMColors.warning;
        break;
      case _DiagnosticConfidence.unknown:
        label = 'Unknown';
        color = SMColors.mutedText;
        break;
      case _DiagnosticConfidence.unavailable:
        label = 'Unavailable';
        color = SMColors.error;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SMSpacing.sm, vertical: SMSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}