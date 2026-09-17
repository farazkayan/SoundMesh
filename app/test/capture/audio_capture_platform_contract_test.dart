import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';

/// Phase 5 — Pigeon contract tests for the capture API surface
/// (DOCS/interfaces/audio-api.md §9–§12, §24–§25).
///
/// Each test drives the generated Dart client through the real Pigeon codec
/// (encode → mock platform reply → decode), verifying the wire contract for
/// every Flutter-facing operation and both native→Flutter events.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final binding = TestWidgetsFlutterBinding.instance;

  group('AudioCapturePlatform Pigeon contract', () {
    late AudioCapturePlatform platform;

    setUp(() {
      platform = AudioCapturePlatform();
    });

    void mockReply(String method, Object? Function(Object? request) replyBuilder) {
      binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.soundmesh.AudioCapturePlatform.$method',
          AudioCapturePlatform.pigeonChannelCodec,
        ),
        (Object? message) async => replyBuilder(message),
      );
    }

    test('requestCapturePermission round-trips GRANTED', () async {
      mockReply('requestCapturePermission', (_) {
        return <Object?>[CapturePermissionResult(result: 'GRANTED')];
      });

      final result = await platform.requestCapturePermission();

      expect(result.result, 'GRANTED');
      expect(result.error, isNull);
    });

    test('requestCapturePermission round-trips DENIED with error detail',
        () async {
      mockReply('requestCapturePermission', (_) {
        return <Object?>[
          CapturePermissionResult(
            result: 'DENIED',
            error: CaptureError(
              code: 'PERMISSION_DENIED',
              message: 'User declined MediaProjection consent',
            ),
          ),
        ];
      });

      final result = await platform.requestCapturePermission();

      expect(result.result, 'DENIED');
      expect(result.error?.code, 'PERMISSION_DENIED');
      expect(result.error?.message, contains('declined'));
    });

    test('startCapture round-trips success with discovered metadata',
        () async {
      final metadata = CaptureMetadata(
        sessionId: 'session-1',
        generation: 1,
        sampleRate: 44100,
        channelCount: 2,
        startedAtNanos: 123456789,
      );
      mockReply('startCapture', (_) {
        return <Object?>[
          CaptureResult(success: true, metadata: metadata),
        ];
      });

      final result = await platform.startCapture();

      expect(result.success, isTrue);
      expect(result.error, isNull);
      // Format discovery payload required by audio-api.md §6/§18.
      expect(result.metadata?.sessionId, 'session-1');
      expect(result.metadata?.sampleRate, 44100);
      expect(result.metadata?.channelCount, 2);
      expect(result.metadata?.generation, 1);
    });

    test('startCapture round-trips failure with a distinct error code',
        () async {
      mockReply('startCapture', (_) {
        return <Object?>[
          CaptureResult(
            success: false,
            error: CaptureError(
              code: 'SOURCE_APP_BLOCKED',
              message: 'source opted out',
            ),
          ),
        ];
      });

      final result = await platform.startCapture();

      expect(result.success, isFalse);
      expect(result.metadata, isNull);
      expect(result.error?.code, 'SOURCE_APP_BLOCKED');
    });

    test('stopCapture completes without payload', () async {
      mockReply('stopCapture', (_) => <Object?>[null]);

      await platform.stopCapture();
    });

    test('getCaptureState round-trips state plus metadata while capturing',
        () async {
      final metadata = CaptureMetadata(
        sessionId: 'session-2',
        generation: 3,
        sampleRate: 48000,
        channelCount: 2,
        startedAtNanos: 999,
      );
      mockReply('getCaptureState', (_) {
        return <Object?>[
          CaptureStateResult(
            state: CaptureState(state: 'CAPTURING'),
            metadata: metadata,
          ),
        ];
      });

      final result = await platform.getCaptureState();

      expect(result.state.state, 'CAPTURING');
      expect(result.metadata?.sessionId, 'session-2');
      expect(result.metadata?.sampleRate, 48000);
    });

    test('getCaptureState round-trips bare state when idle', () async {
      mockReply('getCaptureState', (_) {
        return <Object?>[
          CaptureStateResult(state: CaptureState(state: 'IDLE')),
        ];
      });

      final result = await platform.getCaptureState();

      expect(result.state.state, 'IDLE');
      expect(result.metadata, isNull);
    });

    test('platform-side thrown errors surface as PlatformException',
        () async {
      mockReply('requestCapturePermission', (_) {
        return <Object?>['CAPTURE_UNSUPPORTED', 'requires API 29', null];
      });

      await expectLater(
        platform.requestCapturePermission(),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'CAPTURE_UNSUPPORTED')
              .having((e) => e.message, 'message', 'requires API 29'),
        ),
      );
    });
  });

  group('AudioCaptureFlutterApi Pigeon contract', () {
    tearDown(() {
      AudioCaptureFlutterApi.setUp(null);
    });

    // The FlutterApi channels are platform→Dart (engine-dispatched), so a
    // Dart-side channel.send() does not loop back to the setUp handler.
    // channelBuffers.push() is the test seam that simulates the Kotlin side
    // sending on the channel, exercising the real generated decode path.
    void pushEvent(String method, List<Object?> args) {
      final encoded =
          AudioCaptureFlutterApi.pigeonChannelCodec.encodeMessage(args);
      TestWidgetsFlutterBinding.instance.channelBuffers.push(
        'dev.flutter.pigeon.soundmesh.AudioCaptureFlutterApi.$method',
        encoded,
        (ByteData? data) {},
      );
    }

    testWidgets('onCaptureStateChanged decodes state and metadata',
        (tester) async {
      final received = <(String, CaptureMetadata?)>[];
      final errors = <(String, String)>[];
      AudioCaptureFlutterApi.setUp(
        _RecordingCaptureApi(states: received, errors: errors),
      );

      pushEvent('onCaptureStateChanged', <Object?>[
        'CAPTURING',
        CaptureMetadata(
          sessionId: 'session-9',
          generation: 1,
          sampleRate: 44100,
          channelCount: 2,
          startedAtNanos: 42,
        ),
      ]);
      await tester.pump();

      expect(received, hasLength(1));
      expect(received.single.$1, 'CAPTURING');
      expect(received.single.$2?.sessionId, 'session-9');
      expect(received.single.$2?.sampleRate, 44100);
    });

    testWidgets('onCaptureStateChanged tolerates null metadata',
        (tester) async {
      final received = <(String, CaptureMetadata?)>[];
      final errors = <(String, String)>[];
      AudioCaptureFlutterApi.setUp(
        _RecordingCaptureApi(states: received, errors: errors),
      );

      pushEvent('onCaptureStateChanged', <Object?>['PERMISSION_DENIED', null]);
      await tester.pump();

      expect(received.single.$1, 'PERMISSION_DENIED');
      expect(received.single.$2, isNull);
    });

    testWidgets('onCaptureError decodes error code and message',
        (tester) async {
      final states = <(String, CaptureMetadata?)>[];
      final errors = <(String, String)>[];
      AudioCaptureFlutterApi.setUp(
        _RecordingCaptureApi(states: states, errors: errors),
      );

      pushEvent('onCaptureError', <Object?>[
        'CAPTURE_INTERRUPTED',
        'MediaProjection grant was revoked',
      ]);
      await tester.pump();

      expect(errors.single.$1, 'CAPTURE_INTERRUPTED');
      expect(errors.single.$2, contains('revoked'));
    });
  });
}

class _RecordingCaptureApi implements AudioCaptureFlutterApi {
  _RecordingCaptureApi({required this.states, required this.errors});

  final List<(String, CaptureMetadata?)> states;
  final List<(String, String)> errors;

  @override
  void onCaptureStateChanged(String state, CaptureMetadata? metadata) {
    states.add((state, metadata));
  }

  @override
  void onCaptureError(String errorCode, String errorMessage) {
    errors.add((errorCode, errorMessage));
  }
}
