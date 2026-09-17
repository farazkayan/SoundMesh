import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/application/providers/capture_provider.dart';
import 'package:soundmesh/application/repositories/device_info_repository.dart';
import 'package:soundmesh/application/repositories/timing_info_repository.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  final DeviceInfoRepository Function()? deviceRepositoryBuilder;
  final TimingInfoRepository Function()? timingRepositoryBuilder;

  const DiagnosticsScreen({
    super.key,
    this.deviceRepositoryBuilder,
    this.timingRepositoryBuilder,
  });

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  late final DeviceInfoRepository _deviceRepository;
  late final TimingInfoRepository _timingRepository;
  DeviceInfo? _deviceInfo;
  int? _monotonicTimeNanos;
  int? _previousMonotonicTimeNanos;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _deviceRepository = (widget.deviceRepositoryBuilder ?? () => LiveDeviceInfoRepository())();
    _timingRepository = (widget.timingRepositoryBuilder ?? () => LiveTimingInfoRepository())();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await _deviceRepository.getDeviceInfo();
      final timeNanos = await _timingRepository.getMonotonicTimeNanos();
      if (mounted) {
        setState(() {
          _deviceInfo = info;
          _previousMonotonicTimeNanos = _monotonicTimeNanos;
          _monotonicTimeNanos = timeNanos;
          _isLoading = false;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${e.code}: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatNanos(int nanos) {
    final micros = nanos / 1000;
    final millis = nanos / 1000000;
    return '${nanos.toString()} ns\n(${micros.toStringAsFixed(2)} µs)\n(${millis.toStringAsFixed(3)} ms)';
  }

  String _formatDelta(int? previous, int current) {
    if (previous == null) return 'N/A';
    final delta = current - previous;
    final millis = delta / 1000000;
    return '${delta.toString()} ns (${millis.toStringAsFixed(6)} ms)';
  }

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(captureStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: _buildBody(captureState),
    );
  }

  Widget _buildBody(CaptureUiStateData captureState) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Platform Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _fetchData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final info = _deviceInfo!;
    final timeNanos = _monotonicTimeNanos!;
    final previousTimeNanos = _previousMonotonicTimeNanos;
    final isIncreasing = previousTimeNanos == null || timeNanos > previousTimeNanos;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Native Bridge Active',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              _InfoRow(label: 'Platform', value: info.platformName),
              _InfoRow(label: 'OS Version', value: info.osVersion),
              _InfoRow(label: 'Device Model', value: info.deviceModel),
              if (info.brand != null)
                _InfoRow(label: 'Brand', value: info.brand!),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Monotonic Timing',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _InfoRow(
                label: 'Current Time',
                value: _formatNanos(timeNanos),
                isMultiLine: true,
              ),
              _InfoRow(
                label: 'Last Delta',
                value: _formatDelta(previousTimeNanos, timeNanos),
                isMultiLine: true,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIncreasing ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isIncreasing
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isIncreasing ? 'Increasing (monotonic)' : 'ERROR: Decreased!',
                    style: TextStyle(
                      color: isIncreasing
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh),
                label: const Text('Read Again'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              _buildCaptureSection(captureState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureSection(CaptureUiStateData captureState) {
    final theme = Theme.of(context);
    final isCapturing = captureState.state == CaptureUiState.capturing;
    final canStart = captureState.state == CaptureUiState.permissionGranted;
    final canRequest = captureState.state == CaptureUiState.idle ||
        captureState.state == CaptureUiState.permissionDenied ||
        captureState.state == CaptureUiState.stopped ||
        captureState.state == CaptureUiState.failed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Audio Capture (Phase 5)',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        _CaptureInfoRow(
          label: 'State',
          value: _formatCaptureState(captureState.state),
          valueColor: _getStateColor(captureState.state, theme),
        ),
        if (captureState.metadata != null) ...[
          const SizedBox(height: 8),
          _CaptureInfoRow(
            label: 'Session ID',
            value: captureState.metadata!.sessionId,
            isMultiLine: true,
          ),
          _CaptureInfoRow(
            label: 'Generation',
            value: captureState.metadata!.generation.toString(),
          ),
          _CaptureInfoRow(
            label: 'Sample Rate',
            value: '${captureState.metadata!.sampleRate} Hz',
          ),
          _CaptureInfoRow(
            label: 'Channels',
            value: captureState.metadata!.channelCount.toString(),
          ),
          _CaptureInfoRow(
            label: 'Started At',
            value: '${captureState.metadata!.startedAtNanos} ns',
            isMultiLine: true,
          ),
        ],
        if (captureState.error != null) ...[
          const SizedBox(height: 8),
          _CaptureInfoRow(
            label: 'Error',
            value: '${captureState.error!.code}: ${captureState.error!.message}',
            valueColor: theme.colorScheme.error,
            isMultiLine: true,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canRequest
                    ? () => ref.read(captureStateProvider.notifier).requestPermission()
                    : null,
                icon: const Icon(Icons.security_rounded),
                label: const Text('Request Permission'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: canStart
                    ? () => ref.read(captureStateProvider.notifier).start()
                    : null,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Start Capture'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isCapturing
                ? () => ref.read(captureStateProvider.notifier).stop()
                : null,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop Capture'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isCapturing ? theme.colorScheme.error : theme.disabledColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => ref.read(captureStateProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh State'),
        ),
      ],
    );
  }

  String _formatCaptureState(CaptureUiState state) {
    switch (state) {
      case CaptureUiState.idle:
        return 'IDLE';
      case CaptureUiState.requestingPermission:
        return 'REQUESTING PERMISSION...';
      case CaptureUiState.permissionGranted:
        return 'PERMISSION GRANTED';
      case CaptureUiState.permissionDenied:
        return 'PERMISSION DENIED';
      case CaptureUiState.capturing:
        return 'CAPTURING';
      case CaptureUiState.stopped:
        return 'STOPPED';
      case CaptureUiState.failed:
        return 'FAILED';
    }
  }

  Color _getStateColor(CaptureUiState state, ThemeData theme) {
    switch (state) {
      case CaptureUiState.capturing:
        return theme.colorScheme.primary;
      case CaptureUiState.permissionGranted:
        return theme.colorScheme.primary;
      case CaptureUiState.requestingPermission:
        return theme.colorScheme.secondary;
      case CaptureUiState.permissionDenied:
      case CaptureUiState.failed:
        return theme.colorScheme.error;
      case CaptureUiState.stopped:
        return theme.colorScheme.onSurfaceVariant;
      case CaptureUiState.idle:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiLine;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isMultiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (isMultiLine)
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.start,
              ),
            )
          else
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
      ),
    );
  }
}

class _CaptureInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiLine;
  final Color? valueColor;

  const _CaptureInfoRow({
    required this.label,
    required this.value,
    this.isMultiLine = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (isMultiLine)
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: valueColor,
                ),
                textAlign: TextAlign.start,
              ),
            )
          else
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: valueColor,
              ),
            ),
        ],
      ),
    );
  }
}