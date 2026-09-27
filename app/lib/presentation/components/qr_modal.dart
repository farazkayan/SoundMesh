import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'tsx_visual_tokens.dart';

/// Reusable QR code modal matching TSX design.
/// White-on-black grid representation with code display and copy button.
class QrModal extends StatefulWidget {
  const QrModal({
    super.key,
    required this.title,
    required this.code,
    required this.roomName,
    required this.uriString,
    this.onCopy,
    this.onClose,
  });

  final String title;
  final String code;
  final String roomName;
  final String uriString;
  final VoidCallback? onCopy;
  final VoidCallback? onClose;

  @override
  State<QrModal> createState() => _QrModalState();
}

class _QrModalState extends State<QrModal> {
  bool _copied = false;

  String get _cleanCode => widget.code.replaceAll(RegExp(r'\D'), '');
  String get _formattedCode => _cleanCode.length == 6
      ? '${_cleanCode.substring(0, 3)} - ${_cleanCode.substring(3)}'
      : widget.code;

  void _handleCopy() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.uriString));
    widget.onCopy?.call();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(TSXSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxModalWidth = constraints.maxWidth < 380 ? constraints.maxWidth : 360;
          return _QrModalContent(
            title: widget.title,
            code: _formattedCode,
            roomName: widget.roomName,
            uriString: widget.uriString,
            copied: _copied,
            onCopy: _handleCopy,
            onClose: widget.onClose ?? () => Navigator.pop(context),
            maxModalWidth: maxModalWidth,
          );
        },
      ),
    );
  }
}

class _QrModalContent extends StatefulWidget {
  const _QrModalContent({
    required this.title,
    required this.code,
    required this.roomName,
    required this.uriString,
    required this.copied,
    required this.onCopy,
    required this.onClose,
    required this.maxModalWidth,
  });

  final String title;
  final String code;
  final String roomName;
  final String uriString;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onClose;
  final double maxModalWidth;

  @override
  State<_QrModalContent> createState() => _QrModalContentState();
}

class _QrModalContentState extends State<_QrModalContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: TSXAnimation.major,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: TSXAnimation.spring),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: TSXAnimation.standard),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: widget.maxModalWidth),
            decoration: BoxDecoration(
              color: TSXColors.surface,
              borderRadius: BorderRadius.circular(TSXRadius.modal),
              border: Border.all(color: TSXColors.surfaceBorder),
              boxShadow: TSXShadows.xl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.all(TSXSpacing.lg),
                    child: Row(
                      children: [
                        Icon(
                          Icons.qr_code,
                          size: 24,
                          color: TSXColors.accent,
                        ),
                        SizedBox(width: TSXSpacing.md),
                        Expanded(
                          child: Text(
                            widget.title,
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

                  // QR Code Display
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: TSXSpacing.lg),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(TSXRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: QrImageView(
                          data: widget.uriString,
                          version: QrVersions.auto,
                          size: 144,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: TSXSpacing.md),

                  // Code Display
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: TSXSpacing.lg),
                    child: GestureDetector(
                      onTap: widget.onCopy,
                      child: AnimatedContainer(
                        duration: TSXAnimation.normal,
                        padding: EdgeInsets.symmetric(
                          horizontal: TSXSpacing.lg,
                          vertical: TSXSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: TSXColors.background,
                          borderRadius: BorderRadius.circular(TSXRadius.lg),
                          border: Border.all(
                            color: TSXColors.accent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.code,
                                style: TSXTypography.displayCode.copyWith(
                                  fontSize: 28,
                                  letterSpacing: 6,
                                ),
                                overflow: TextOverflow.visible,
                                softWrap: false,
                              ),
                            ),
                            SizedBox(width: TSXSpacing.sm),
                            AnimatedContainer(
                              duration: TSXAnimation.normal,
                              padding: EdgeInsets.symmetric(
                                horizontal: TSXSpacing.md,
                                vertical: TSXSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: widget.copied
                                    ? TSXColors.accent
                                    : TSXColors.surface,
                                borderRadius: BorderRadius.circular(TSXRadius.md),
                                border: Border.all(
                                  color: widget.copied
                                      ? TSXColors.accent
                                      : TSXColors.surfaceBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.copied ? Icons.check : Icons.copy,
                                    size: 16,
                                    color: widget.copied
                                        ? TSXColors.accentOn
                                        : TSXColors.accent,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    widget.copied ? 'Copied' : 'Copy',
                                    style: TSXTypography.labelSmall.copyWith(
                                      color: widget.copied
                                          ? TSXColors.accentOn
                                          : TSXColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: TSXSpacing.sm),

                  // Subtitle
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: TSXSpacing.lg),
                    child: Text(
                      'Point any phone camera to connect directly to ${widget.roomName}',
                      style: TSXTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: TSXSpacing.lg),

                  // Copy Link Button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: TSXSpacing.lg),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: widget.onCopy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TSXColors.accent,
                          foregroundColor: TSXColors.accentOn,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TSXRadius.lg),
                          ),
                          shadowColor: TSXColors.accent.withValues(alpha: 0.1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.copied ? Icons.check : Icons.copy,
                              size: 20,
                            ),
                            SizedBox(width: TSXSpacing.sm),
                            Text(
                              widget.copied ? 'Code Copied!' : 'Copy Link & Code',
                              style: TSXTypography.button,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: TSXSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to show QR modal
Future<void> showQrModal({
  required BuildContext context,
  required String title,
  required String code,
  required String roomName,
  required String uriString,
  VoidCallback? onCopy,
}) async {
  await showDialog(
    context: context,
    barrierColor: TSXColors.overlayScrim,
    builder: (context) => QrModal(
      title: title,
      code: code,
      roomName: roomName,
      uriString: uriString,
      onCopy: onCopy,
    ),
  );
}