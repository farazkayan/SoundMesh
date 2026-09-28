import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/presentation/components/soundmesh_empty_state.dart';
import 'package:soundmesh/presentation/components/index.dart';

/// Real functional QR scanner modal that uses mobile_scanner.
/// Opens as a modal over JoinRoomScreen and reuses the working scanner logic.
class QRScannerModal extends ConsumerStatefulWidget {
  const QRScannerModal({
    super.key,
    required this.onClose,
    required this.onScanSuccess,
  });

  final VoidCallback onClose;
  final VoidCallback onScanSuccess;

  @override
  ConsumerState<QRScannerModal> createState() => _QRScannerModalState();
}

class _QRScannerModalState extends ConsumerState<QRScannerModal> {
  MobileScannerController? _controller;

  bool _isScanning = true;
  bool _permissionDenied = false;
  bool _hasError = false;
  bool _isProcessingScan = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning || _isProcessingScan) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;

      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }

      // Only process SoundMesh join QR codes.
      if (rawValue.startsWith('soundmesh://join')) {
        _isScanning = false;
        _controller?.stop();
        _handleValidQrCode(rawValue);
        return;
      }
    }
  }

  Future<void> _handleValidQrCode(String uriString) async {
    late final JoinPayload payload;

    try {
      payload = JoinPayload.parseJoinUri(uriString);
    } on JoinPayloadException catch (e) {
      _showErrorAndReset(e.message);
      return;
    } catch (_) {
      _showErrorAndReset('Invalid SoundMesh QR code');
      return;
    }

    // Validate protocol version before touching the join flow.
    if (payload.protocolVersion != currentProtocolVersion) {
      _showErrorAndReset(
        'Protocol version mismatch: QR code is '
        'v${payload.protocolVersion}, this app is v$currentProtocolVersion',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessingScan = true;
    });

    final joinNotifier = ref.read(joinRoomFlowProvider.notifier);

    joinNotifier.setHostIpAddress(payload.hostAddress);
    joinNotifier.setHostPort(payload.hostPort);
    joinNotifier.setJoinCode(payload.code);

    try {
      // Start the actual join while this widget is still alive.
      // Do not wait until after Navigator.pop().
      await joinNotifier.joinRoom();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessingScan = false;
        _isScanning = false;
      });

      _showErrorAndReset('Failed to join room: $e');
      return;
    }

    if (!mounted) {
      return;
    }

    widget.onScanSuccess();
    widget.onClose();
  }

  void _showErrorAndReset(String message) {
    if (!mounted) {
      return;
    }

    _controller?.stop();

    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isScanning = false;
      _isProcessingScan = false;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasError = false;
        _errorMessage = null;
        _isScanning = true;
        _isProcessingScan = false;
      });

      _controller?.start();
    });
  }

  void _handleScannerError(MobileScannerException error) {
    if (!mounted) {
      return;
    }

    final isPermissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    // errorBuilder can run during a build, so defer the state mutation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (isPermissionDenied) {
        if (_permissionDenied && !_isScanning) {
          return;
        }

        setState(() {
          _permissionDenied = true;
          _isScanning = false;
          _hasError = false;
          _isProcessingScan = false;
        });

        _controller?.stop();
        return;
      }

      setState(() {
        _permissionDenied = false;
        _hasError = true;
        _errorMessage = 'Unable to start the camera. Please try again.';
        _isScanning = false;
        _isProcessingScan = false;
      });

      _controller?.stop();
    });
  }

  void _retryScanning() {
    if (!mounted) {
      return;
    }

    setState(() {
      _permissionDenied = false;
      _hasError = false;
      _errorMessage = null;
      _isScanning = true;
      _isProcessingScan = false;
    });

    _controller?.start();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SizedBox(
            width: 360,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: TSXColors.surface,
                  borderRadius: BorderRadius.circular(TSXRadius.modal),
                  border: Border.all(
                    color: TSXColors.surfaceBorder,
                  ),
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
                              Icons.qr_code_scanner,
                              size: 24,
                              color: TSXColors.accent,
                            ),
                            SizedBox(width: TSXSpacing.md),
                            Expanded(
                              child: Text(
                                'Scan Host QR',
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
                                  borderRadius: BorderRadius.circular(
                                    TSXRadius.full,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Scanner / Error / Permission State
                      if (_permissionDenied)
                        _buildPermissionDenied()
                      else if (_hasError)
                        _buildErrorBanner()
                      else if (_isProcessingScan)
                        _buildProcessingView()
                      else
                        _buildScannerView(),

                      SizedBox(height: TSXSpacing.lg),

                      // Bottom hint
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: TSXSpacing.lg,
                        ),
                        child: Text(
                          _isProcessingScan
                              ? 'Connecting to the host…'
                              : 'Point camera at a SoundMesh QR code',
                          style: TSXTypography.caption.copyWith(
                            color: TSXColors.secondaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: TSXSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double scanAreaSize =
            ((constraints.maxWidth - 32) * 0.75).clamp(180.0, 280.0);

        return SizedBox(
          width: double.infinity,
          height: scanAreaSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Mobile Scanner
              ClipRRect(
                borderRadius: BorderRadius.circular(TSXRadius.lg),
                child: MobileScanner(
                  controller: _controller!,
                  fit: BoxFit.cover,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    _handleScannerError(error);

                    if (error.errorCode ==
                        MobileScannerErrorCode.permissionDenied) {
                      return _buildPermissionDenied();
                    }

                    return _buildErrorBanner();
                  },
                ),
              ),

              // Scanner Overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(
                    scanAreaSize: scanAreaSize,
                    accentColor: TSXColors.accent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProcessingView() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SMLoadingIndicator.tsx(size: 48),
            SizedBox(height: TSXSpacing.lg),
            Text(
              'Joining Room',
              style: TSXTypography.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(TSXSpacing.xl),
          child: SoundMeshEmptyState.error(
            title: 'Camera Permission Required',
            message:
                'SoundMesh needs camera access to scan QR codes. '
                'Please enable camera permission in settings and try again, '
                'or use the 6-digit code entry instead.',
            icon: Icons.camera_alt_outlined,
            onRetry: _retryScanning,
            retryLabel: 'Retry Camera',
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(TSXSpacing.lg),
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.all(TSXSpacing.md),
            padding: EdgeInsets.all(TSXSpacing.md),
            decoration: BoxDecoration(
              color: TSXColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(TSXRadius.md),
              border: Border.all(
                color: TSXColors.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: TSXColors.error,
                  size: 20,
                ),
                SizedBox(width: TSXSpacing.md),
                Expanded(
                  child: Text(
                    _errorMessage ?? 'Unable to use the camera.',
                    style: TextStyle(
                      color: TSXColors.error,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final Color accentColor;

  const _ScannerOverlayPainter({
    required this.scanAreaSize,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;
    final right = left + scanAreaSize;
    final bottom = top + scanAreaSize;

    // Draw dark overlay with a transparent square in the middle.
    final path = Path()
      ..addRect(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
      )
      ..addRect(
        Rect.fromLTWH(
          left,
          top,
          scanAreaSize,
          scanAreaSize,
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw corner brackets.
    final cornerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const cornerRadius = 12.0;

    final cornerPath = Path()
      ..moveTo(left + cornerRadius, top)
      ..lineTo(left, top)
      ..lineTo(left, top + cornerRadius)
      ..moveTo(right - cornerRadius, top)
      ..lineTo(right, top)
      ..lineTo(right, top + cornerRadius)
      ..moveTo(left, bottom - cornerRadius)
      ..lineTo(left, bottom)
      ..lineTo(left + cornerRadius, bottom)
      ..moveTo(right - cornerRadius, bottom)
      ..lineTo(right, bottom)
      ..lineTo(right, bottom - cornerRadius);

    canvas.drawPath(cornerPath, cornerPaint);

    // Static scan line.
    final scanLinePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;

    canvas.drawLine(
      Offset(left + 16, centerY),
      Offset(right - 16, centerY),
      scanLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanAreaSize != scanAreaSize ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Helper to show QR scanner modal.
Future<void> showQRScannerModal({
  required BuildContext context,
  required VoidCallback onScanSuccess,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: TSXColors.overlayScrim,
    builder: (context) => QRScannerModal(
      onClose: () => Navigator.pop(context),
      onScanSuccess: onScanSuccess,
    ),
  );
}