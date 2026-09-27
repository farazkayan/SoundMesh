import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tsx_visual_tokens.dart';

/// Reusable 6-digit code display card with copy button.
/// Matches TSX RoomCreatedScreen and JoinRoomScreen code display.
/// TSX: h-13 (52px) height, px-3.5 (14px) horizontal padding, justify-between,
/// text-xl (20px) tracking-widest (0.1em), font-mono, font-bold
class CodeDisplayCard extends StatefulWidget {
  const CodeDisplayCard({
    super.key,
    required this.code,
    this.label = 'Room Code',
    this.onCopy,
    this.showLabel = true,
    this.helperText,
    this.compact = false,
  });

  final String code;
  final String label;
  final VoidCallback? onCopy;
  final bool showLabel;
  final String? helperText;
  final bool compact;

  @override
  State<CodeDisplayCard> createState() => _CodeDisplayCardState();
}

class _CodeDisplayCardState extends State<CodeDisplayCard> {
  bool _copied = false;

  String get _cleanCode => widget.code.replaceAll(RegExp(r'\D'), '');
  String get _formattedCode => _cleanCode.length == 6
      ? '${_cleanCode.substring(0, 3)} - ${_cleanCode.substring(3)}'
      : widget.code;

  void _handleCopy() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _cleanCode));
    if (widget.onCopy != null) {
      widget.onCopy!();
    }
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // TSX dimensions (mobile/base values, not sm breakpoint)
    const double containerHeight = 52.0; // h-13
    const double horizontalPadding = 14.0; // px-3.5
    const double codeFontSize = 20.0; // text-xl
    const double codeLetterSpacing = 2.0; // tracking-widest = 0.1em
    const double copyButtonHeight = 32.0; // h-8
    const double copyButtonHorizontalPadding = 8.0; // px-2
    const double iconSize = 14.0; // w-3.5 h-3.5 ≈ 14px

    return LayoutBuilder(
      builder: (context, constraints) {
        // On very narrow screens, reduce horizontal padding and copy button padding
        final double availableWidth = constraints.maxWidth;
        final double effectiveHorizontalPadding = availableWidth < 300 ? 10.0 : horizontalPadding;
        final double effectiveCopyButtonPadding = availableWidth < 300 ? 6.0 : copyButtonHorizontalPadding;
        final double effectiveCodeFontSize = availableWidth < 300 ? 18.0 : codeFontSize;
        final double effectiveCodeLetterSpacing = availableWidth < 300 ? 1.5 : codeLetterSpacing;

        return GestureDetector(
          onTap: _handleCopy,
          child: Container(
            height: containerHeight,
            padding: EdgeInsets.symmetric(horizontal: effectiveHorizontalPadding),
            decoration: BoxDecoration(
              color: TSXColors.background,
              borderRadius: BorderRadius.circular(TSXRadius.card),
              border: Border.all(
                color: TSXColors.accent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: TSXColors.accent.withValues(alpha: 0.08),
                  blurRadius: 15,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Code display - left aligned, monospace, tracking-widest
                Flexible(
                  child: Text(
                    _formattedCode,
                    style: TSXTypography.displayCode.copyWith(
                      fontFamily: 'monospace',
                      fontSize: effectiveCodeFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: effectiveCodeLetterSpacing,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 8),
                // Copy button - fixed height, right aligned
                AnimatedContainer(
                  duration: TSXAnimation.normal,
                  curve: TSXAnimation.standard,
                  height: copyButtonHeight,
                  padding: EdgeInsets.symmetric(horizontal: effectiveCopyButtonPadding),
                  decoration: BoxDecoration(
                    color: _copied ? TSXColors.accent : TSXColors.surface,
                    borderRadius: BorderRadius.circular(TSXRadius.md),
                    border: Border.all(
                      color: _copied ? TSXColors.accent : TSXColors.surfaceBorder,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check : Icons.copy,
                          size: iconSize,
                          color: _copied ? TSXColors.accentOn : TSXColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: TSXTypography.labelSmall.copyWith(
                            color: _copied ? TSXColors.accentOn : TSXColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact inline code display for modals/cards
/// Matches TSX modal code display: px-3 py-2.5 (12px/10px), text-xl (20px), tracking-widest
class InlineCodeDisplay extends StatelessWidget {
  const InlineCodeDisplay({
    super.key,
    required this.code,
    this.onTap,
    this.copied = false,
  });

  final String code;
  final VoidCallback? onTap;
  final bool copied;

  String get _formattedCode => code.replaceAll(RegExp(r'\D'), '').length == 6
      ? '${code.replaceAll(RegExp(r'\D'), '').substring(0, 3)} - ${code.replaceAll(RegExp(r'\D'), '').substring(3)}'
      : code;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: TSXAnimation.normal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: TSXColors.background,
          borderRadius: BorderRadius.circular(TSXRadius.md),
          border: Border.all(
            color: TSXColors.accent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formattedCode,
              style: TSXTypography.displayCode.copyWith(
                fontFamily: 'monospace',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                height: 1.0,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                copied ? Icons.check : Icons.copy,
                size: 16,
                color: copied ? TSXColors.success : TSXColors.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}