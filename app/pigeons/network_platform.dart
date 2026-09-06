import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/network_messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/soundmesh/soundmesh/NetworkMessages.g.kt',
    kotlinOptions: KotlinOptions(),
    swiftOut: 'ios/Runner/NetworkMessages.g.swift',
    swiftOptions: SwiftOptions(),
    copyrightHeader: 'pigeons/copyright.txt',
    dartPackageName: 'soundmesh',
  ),
)
class ConnectionState {
  final String state;
  ConnectionState({required this.state});
}

@HostApi()
abstract class NetworkHostPlatform {
  bool startHosting(int port);
  bool connectToHost(String ipAddress, int port);
  bool sendMessage(String message);
  void disconnect();
  String getLocalIpAddress();
}

@FlutterApi()
abstract class NetworkFlutterApi {
  void onMessageReceived(String message);
  void onConnectionStateChanged(String state);
}
