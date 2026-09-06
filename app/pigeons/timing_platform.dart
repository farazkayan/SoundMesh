import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/timing_messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/soundmesh/soundmesh/TimingMessages.g.kt',
    kotlinOptions: KotlinOptions(),
    swiftOut: 'ios/Runner/TimingMessages.g.swift',
    swiftOptions: SwiftOptions(),
    copyrightHeader: 'pigeons/copyright.txt',
    dartPackageName: 'soundmesh',
  ),
)
@HostApi()
abstract class TimingPlatform {
  int getMonotonicTimeNanos();
}
