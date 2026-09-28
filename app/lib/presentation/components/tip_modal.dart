import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'tsx_visual_tokens.dart';

/// Tip Modal matching TSX TipModal.tsx
/// Preset amounts, custom input, confetti animation on success.
class TipModal extends StatefulWidget {
  const TipModal({
    super.key,
    required this.onClose,
    required this.onSuccess,
  });

  final VoidCallback onClose;
  final void Function(double amount) onSuccess;

  @override
  State<TipModal> createState() => _TipModalState();
}

class _TipModalState extends State<TipModal>
    with SingleTickerProviderStateMixin {
  int _selectedAmount = 3;
  String _customAmount = '';
  bool _isProcessing = false;
  late final ConfettiController _confettiController;
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _scaleController = AnimationController(
      duration: TSXAnimation.normal,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  double get _effectiveAmount => _customAmount.isNotEmpty
      ? double.tryParse(_customAmount) ?? _selectedAmount.toDouble()
      : _selectedAmount.toDouble();

  Future<void> _handleSendTip() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    _scaleController.forward().then((_) => _scaleController.reverse());

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    _confettiController.play();
    widget.onSuccess(_effectiveAmount);
    widget.onClose();
  }

  void _selectPreset(int amount) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedAmount = amount;
      _customAmount = '';
    });
  }

  void _onCustomChanged(String value) {
    setState(() {
      _customAmount = value;
      if (value.isNotEmpty) {
        _selectedAmount = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxHeight = constraints.maxHeight * 0.85;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(TSXSpacing.xl),
          child: Stack(
            children: [
              // Confetti overlay
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    TSXColors.accent,
                    TSXColors.accentHover,
                    Colors.white,
                    TSXColors.secondaryText,
                  ],
                  numberOfParticles: 80,
                  gravity: 0.3,
                  emissionFrequency: 0.05,
                ),
              ),

              // Modal content
              Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 350,
                    maxHeight: maxHeight,
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: BoxDecoration(
                        color: TSXColors.surface,
                        borderRadius: BorderRadius.circular(TSXRadius.modal),
                        border: Border.all(color: TSXColors.surfaceBorder),
                        boxShadow: TSXShadows.xl,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Padding(
                            padding: EdgeInsets.all(TSXSpacing.lg),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.favorite,
                                  size: 24,
                                  color: TSXColors.accent,
                                ),
                                SizedBox(width: TSXSpacing.md),
                                Expanded(
                                  child: Text(
                                    'Support SoundMesh',
                                    style: TSXTypography.headlineMedium,
                                  ),
                                ),
                                IconButton(
                                  onPressed: widget.onClose,
                                  icon: Icon(
                                    Icons.close,
                                    size: 20,
                                    color: TSXColors.secondaryText,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: TSXColors.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(TSXRadius.full),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Description
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: TSXSpacing.lg),
                            child: Text(
                              'SoundMesh is 100% free, local, and ad-free. Your support powers independent spatial audio research.',
                              style: TSXTypography.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),

                          SizedBox(height: TSXSpacing.lg),

                          // Preset Amounts
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: TSXSpacing.lg),
                            child: Row(
                              children: [1, 3, 5].map((amount) {
                                final isSelected = _selectedAmount == amount && _customAmount.isEmpty;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: amount == 5 ? 0 : TSXSpacing.sm,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _selectPreset(amount),
                                        borderRadius: BorderRadius.circular(TSXRadius.lg),
                                        child: AnimatedContainer(
                                          duration: TSXAnimation.normal,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? TSXColors.accent.withValues(alpha: 0.1)
                                                : TSXColors.background,
                                            borderRadius: BorderRadius.circular(TSXRadius.lg),
                                            border: Border.all(
                                              color: isSelected
                                                  ? TSXColors.accent
                                                  : TSXColors.surfaceBorder,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '\$$amount.00',
                                              style: TSXTypography.labelLarge.copyWith(
                                                color: isSelected
                                                    ? TSXColors.accent
                                                    : TSXColors.primaryText,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          SizedBox(height: TSXSpacing.md),

                          // Custom Input
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: TSXSpacing.lg),
                            child: TextField(
                              onChanged: _onCustomChanged,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              style: TSXTypography.bodyLarge.copyWith(
                                color: TSXColors.primaryText,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Custom amount',
                                hintStyle: TSXTypography.bodySmall,
                                prefixText: '\$ ',
                                prefixStyle: TSXTypography.bodyLarge.copyWith(
                                  color: TSXColors.secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: TSXColors.background,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: TSXSpacing.lg,
                                  vertical: TSXSpacing.md,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(TSXRadius.lg),
                                  borderSide: BorderSide(color: TSXColors.surfaceBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(TSXRadius.lg),
                                  borderSide: BorderSide(color: TSXColors.surfaceBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(TSXRadius.lg),
                                  borderSide: BorderSide(color: TSXColors.accent, width: 2),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: TSXSpacing.lg),

                          // Submit Button
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              TSXSpacing.lg,
                              0,
                              TSXSpacing.lg,
                              TSXSpacing.lg,
                            ),
                            child: AnimatedScale(
                              scale: _isProcessing ? 0.98 : 1.0,
                              duration: TSXAnimation.micro,
                              child: SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isProcessing ? null : _handleSendTip,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TSXColors.accent,
                                    foregroundColor: TSXColors.accentOn,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(TSXRadius.lg),
                                    ),
                                    shadowColor: TSXColors.accent.withValues(alpha: 0.1),
                                    disabledBackgroundColor: TSXColors.accent.withValues(alpha: 0.5),
                                  ),
                                  child: _isProcessing
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  TSXColors.accentOn,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: TSXSpacing.md),
                                            Text(
                                              'Linking Node...',
                                              style: TSXTypography.button,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.favorite, size: 20),
                                            SizedBox(width: TSXSpacing.md),
                                            Text(
                                              'Send Tip (\$${_effectiveAmount.toStringAsFixed(2)})',
                                              style: TSXTypography.button,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Helper to show tip modal
Future<void> showTipModal({
  required BuildContext context,
  required void Function(double amount) onSuccess,
}) async {
  await showDialog(
    context: context,
    barrierColor: TSXColors.overlayScrim,
    builder: (context) => TipModal(
      onClose: () => Navigator.pop(context),
      onSuccess: onSuccess,
    ),
  );
}