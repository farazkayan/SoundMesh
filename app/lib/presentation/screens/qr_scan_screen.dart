import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide StateProvider; // Avoid conflict with StateProvider in state_compat
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/soundmesh_empty_state.dart';

class QRScanScreen extends ConsumerStatefulWidget {
  const QRScanScreen({super.key});

  @override
  ConsumerState<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends ConsumerState<QRScanScreen> {
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

      if (isValidQrJoinUri(rawValue)) {
        _isScanning = false;
        _handleValidQrCode(rawValue);
        return;
      }
    }
  }

  Future<void> _handleValidQrCode(String uriString) async {
    final payload = QrJoinPayload.parse(uriString);
    if (payload == null) {
      _showErrorAndReset('Invalid QR code format');
      return;
    }

    // Validate protocol version
    if (payload.version != currentProtocolVersion) {
      _showErrorAndReset('Protocol version mismatch: QR code is v${payload.version}, this app is v$currentProtocolVersion');
      return;
    }

    // Feed parsed values into existing JoinRoomFlowNotifier
    // This skips UDP discovery and goes straight to TCP connect/handshake
    ref.read(joinRoomFlowProvider.notifier).setHostIpAddress(payload.host);
    ref.read(joinRoomFlowProvider.notifier).setHostPort(payload.port);

    // Navigate to join room screen which will show connecting/handshaking states
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.joinRoom);

    // Trigger the join after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(joinRoomFlowProvider.notifier).joinRoom();
    });
  }

  void _showErrorAndReset(String message) {
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
    setState(() {
      _permissionDenied = true;
      _isScanning = false;
    });
  }

  void _retryScanning() {
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
    return Scaffold(
      backgroundColor: SMColors.background,
      appBar: AppBar(
        backgroundColor: SMColors.surface,
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: SMColors.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: SMColors.primaryText,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_permissionDenied) _buildPermissionDenied(),
            if (_hasError) _buildErrorBanner(),
            Expanded(
              child: Stack(
                children: [
                  if (!_permissionDenied && !_hasError)
                    MobileScanner(
                      controller: _controller!,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        _onPermissionDenied();
                        return _buildPermissionDenied();
                      },
                    ),
                  if (!_permissionDenied && !_hasError) _buildScannerOverlay(),
                ],
              ),
            ),
            _buildBottomHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(SMSpacing.xl),
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
      margin: EdgeInsets.all(SMSpacing.md),
      padding: EdgeInsets.all(SMSpacing.md),
      decoration: BoxDecoration(
        color: SMColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(SMRadius.medium),
        border: Border.all(color: SMColors.error.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: SMColors.error, size: 20),
          SizedBox(width: SMSpacing.md),
          Expanded(
            child: Text(
              _errorMessage ?? 'Invalid QR code',
              style: TextStyle(
                color: SMColors.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return CustomPaint(
      painter: _ScannerOverlayPainter(),
      child: Container(),
    );
  }

  Widget _buildBottomHint() {
    return Container(
      padding: EdgeInsets.all(SMSpacing.xl),
      decoration: BoxDecoration(
        color: SMColors.surface,
        border: Border(
          top: BorderSide(color: SMColors.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, color: SMColors.soundmeshBlue, size: 20),
              SizedBox(width: SMSpacing.sm),
              Text(
                'Point camera at a SoundMesh QR code',
                style: SMTypography.body.copyWith(color: SMColors.secondaryText),
              ),
            ],
          ),
          SizedBox(height: SMSpacing.md),
          Text(
            'Or go back and enter the 6-digit code manually',
            style: SMTypography.caption.copyWith(color: SMColors.mutedText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.75;
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
      ..color = SMColors.soundmeshBlue
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}