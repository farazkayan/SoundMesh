import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';

class PrepareAudioModal extends StatelessWidget {
  const PrepareAudioModal({
    super.key,
    required this.onContinue,
  });

  final void Function(bool dontShowAgain) onContinue;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SMColors.surfaceHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SMRadius.large),
      ),
      title: Text(
        'Prepare Audio',
        style: SMTypography.title.copyWith(color: SMColors.primaryText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SoundMesh will synchronize audio from the host\'s media app.',
            style: SMTypography.body.copyWith(color: SMColors.secondaryText),
          ),
          SizedBox(height: SMSpacing.xl),
          _buildPreparationStep(
            number: '1',
            title: 'Allow audio capture',
            description:
                'SoundMesh needs permission to capture audio from this device so other phones can hear it too.',
          ),
          SizedBox(height: SMSpacing.md),
          _buildPreparationStep(
            number: '2',
            title: 'Return to your media app',
            description:
                'Open any supported app (YouTube, Spotify, etc.) and start playing audio.',
          ),
          SizedBox(height: SMSpacing.md),
          _buildPreparationStep(
            number: '3',
            title: 'Start playback',
            description:
                'The captured audio is distributed and played in sync on all devices.',
          ),
          SizedBox(height: SMSpacing.xl),
          _DontShowAgainCheckbox(onChanged: onContinue),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            onContinue(false);
            Navigator.of(context).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: SMColors.soundmeshBlue,
            foregroundColor: SMColors.onAccent,
            padding: EdgeInsets.symmetric(
              horizontal: SMSpacing.xl,
              vertical: SMSpacing.md,
            ),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildPreparationStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: SMColors.soundmeshBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: SMTypography.caption.copyWith(
                color: SMColors.onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(width: SMSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SMTypography.bodyEmphasis.copyWith(
                  color: SMColors.primaryText,
                ),
              ),
              SizedBox(height: SMSpacing.xs),
              Text(
                description,
                style: SMTypography.caption.copyWith(
                  color: SMColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DontShowAgainCheckbox extends StatefulWidget {
  const _DontShowAgainCheckbox({required this.onChanged});

  final void Function(bool dontShowAgain) onChanged;

  @override
  State<_DontShowAgainCheckbox> createState() => _DontShowAgainCheckboxState();
}

class _DontShowAgainCheckboxState extends State<_DontShowAgainCheckbox> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: _value,
          onChanged: (value) {
            setState(() {
              _value = value ?? false;
            });
          },
          activeColor: SMColors.soundmeshBlue,
          checkColor: SMColors.onAccent,
          side: BorderSide(color: SMColors.outlineVariant),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _value = !_value;
              });
            },
            child: Text(
              'Don\'t show this again',
              style: SMTypography.body.copyWith(
                color: SMColors.primaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}