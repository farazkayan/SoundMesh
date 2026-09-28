import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/presentation/components/soundmesh_empty_state.dart';
import 'package:soundmesh/presentation/components/index.dart';

/// Real functional QR scanner modal that uses mobile_scanner.
/// Opens as a modal over JoinRoomScreen, reuses the working scanner logic.
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
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      // Quick check for soundmesh://join URI before attempting full parse
      if (rawValue.startsWith('soundmesh://join')) {
        _isScanning = false;
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
    }

    // Validate protocol version
    if (payload.protocolVersion != currentProtocolVersion) {
      _showErrorAndReset('Protocol version mismatch: QR code is v${payload.protocolVersion}, this app is v$currentProtocolVersion');
      return;
    }

    // Feed parsed values into existing JoinRoomFlowNotifier
    ref.read(joinRoomFlowProvider.notifier).setHostIpAddress(payload.hostAddress);
    ref.read(joinRoomFlowProvider.notifier).setHostPort(payload.hostPort);
    ref.read(joinRoomFlowProvider.notifier).setJoinCode(payload.code);

    // Notify success and close modal
    if (!mounted) return;
    widget.onScanSuccess();
    widget.onClose();

    // Trigger the join after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(joinRoomFlowProvider.notifier).joinRoom();
      }
    });
  }

  void _showErrorAndReset(String message) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isScanning = false;
    });

    // Auto-reset after 3 seconds to allow retry
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _hasError = false;
          _errorMessage = null;
          _isScanning = true;
        });
      }
    });
  }

  void _onPermissionDenied() {
    if (!mounted) return;
    setState(() {
      _permissionDenied = true;
      _isScanning = false;
    });
  }

  void _retryScanning() {
    if (!mounted) return;
    setState(() {
      _permissionDenied = false;
      _hasError = false;
      _errorMessage = null;
      _isScanning = true;
    });
    _controller?.start();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxHeight = constraints.maxHeight * 0.9;
        final double availableWidth = constraints.maxWidth;
        final double modalWidth = availableWidth < 380 ? availableWidth - 32 : 360.0;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              // Modal backdrop with blur
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  color: TSXColors.overlayScrim,
                ),
              ),

              // Modal content
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: modalWidth,
                    maxHeight: maxHeight,
                  ),
                  child: Material(
                    color: Colors.transparent,
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
                                      borderRadius: BorderRadius.circular(TSXRadius.full),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Scanner View
                          if (_permissionDenied)
                            _buildPermissionDenied()
                          else if (_hasError)
                            _buildErrorBanner()
                          else
                            _buildScannerView(),

                          SizedBox(height: TSXSpacing.lg),

                          // Bottom hint
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: TSXSpacing.lg),
                            child: Text(
                              'Point camera at a SoundMesh QR code',
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildScannerView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate square scan area size (75% of width)
        final double scanAreaSize = (constraints.maxWidth - 32) * 0.75;

        return SizedBox(
          width: double.infinity,
          height: scanAreaSize,
          child: Stack(
            children: [
              // Mobile Scanner
              ClipRRect(
                borderRadius: BorderRadius.circular(TSXRadius.lg),
                child: MobileScanner(
                  controller: _controller!,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    _onPermissionDenied();
                    return _buildPermissionDenied();
                  },
                ),
              ),

              // Scanner Overlay (corner brackets + scan line)
              CustomPaint(
                painter: _ScannerOverlayPainter(
                  scanAreaSize: scanAreaSize,
                  accentColor: TSXColors.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionDenied() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(TSXSpacing.xl),
          child: SoundMeshEmptyState.error(
            title: 'Camera Permission Required',
            message: 'SoundMesh needs camera access to scan QR codes. Please enable camera permission in settings and try again, or use the 6-digit code entry instead.',
            icon: Icons.camera_alt_outlined,
            onRetry: _retryScanning,
            retryLabel: 'Retry Camera',
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: EdgeInsets.all(TSXSpacing.md),
      padding: EdgeInsets.all(TSXSpacing.md),
      decoration: BoxDecoration(
        color: TSXColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(TSXRadius.md),
        border: Border.all(color: TSXColors.error.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: TSXColors.error, size: 20),
          SizedBox(width: TSXSpacing.md),
          Expanded(
            child: Text(
              _errorMessage ?? 'Invalid QR code',
              style: TextStyle(
                color: TSXColors.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
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

    // Draw dark overlay with transparent square in the middle
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw corner brackets
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

    // Animated scan line
    // We'll use a simple pulsing line in the center
    final scanLinePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw a centered horizontal line
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(left + 16, centerY),
      Offset(right - 16, centerY),
      scanLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Helper to show QR scanner modal
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