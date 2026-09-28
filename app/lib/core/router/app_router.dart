import 'package:flutter/material.dart';

import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/create_room_screen.dart';
import '../../presentation/screens/join_room_screen.dart';
import '../../presentation/screens/room_dashboard_screen.dart';
import '../../presentation/screens/room_devices_screen.dart';
import '../../presentation/screens/room_preparation_screen.dart';
import '../../presentation/screens/room_created_screen.dart';
import '../../presentation/screens/support_screen.dart';
import '../../presentation/screens/qr_scan_screen.dart';
import '../../presentation/screens/diagnostics_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String createRoom = '/create-room';
  static const String joinRoom = '/join-room';
  static const String roomDashboard = '/room';
  static const String roomDevices = '/room/devices';
  static const String roomPreparation = '/room/preparation';
  static const String roomCreated = '/room-created';
  static const String qrScan = '/qr-scan';
  static const String support = '/support';
  static const String diagnostics = '/diagnostics';

  // Route names for named navigation
  static const String homeRoute = 'home';
  static const String createRoomRoute = 'createRoom';
  static const String joinRoomRoute = 'joinRoom';
  static const String roomDashboardRoute = 'roomDashboard';
  static const String roomDevicesRoute = 'roomDevices';
  static const String roomPreparationRoute = 'roomPreparation';
  static const String roomCreatedRoute = 'roomCreated';
  static const String qrScanRoute = 'qrScan';
  static const String supportRoute = 'support';
  static const String diagnosticsRoute = 'diagnostics';

  // Path constants for route matching
  static const String homePath = '/';
  static const String createRoomPath = '/create-room';
  static const String joinRoomPath = '/join-room';
  static const String roomDashboardPath = '/room';
  static const String roomDevicesPath = '/room/devices';
  static const String roomPreparationPath = '/room/preparation';
  static const String roomCreatedPath = '/room-created';
  static const String qrScanPath = '/qr-scan';
  static const String supportPath = '/support';
  static const String diagnosticsPath = '/diagnostics';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRouter.home:
        return _route(const HomeScreen(), settings);

      case AppRouter.createRoom:
        return _route(const CreateRoomScreen(), settings);

      case AppRouter.joinRoom:
        return _route(const JoinRoomScreen(), settings);

      // RoomDashboardScreen now owns its complete room UI,
      // including the floating Room / Devices dock.
      case AppRouter.roomDashboard:
        return _route(const RoomDashboardScreen(), settings);

      case AppRouter.roomDevices:
        return _route(const RoomDevicesScreen(), settings);

      case AppRouter.roomPreparation:
        return _route(const RoomPreparationScreen(), settings);

      case AppRouter.roomCreated:
        return _route(const RoomCreatedScreen(), settings);

      case AppRouter.qrScan:
        return _route(const QRScanScreen(), settings);

      case AppRouter.support:
        return _route(const SupportScreen(), settings);

      case AppRouter.diagnostics:
        return _route(const RoomDiagnosticsScreen(), settings);

      default:
        return _route(const HomeScreen(), settings);
    }
  }

  static MaterialPageRoute<dynamic> _route(
    Widget page,
    RouteSettings settings,
  ) {
    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }
}