import 'package:flutter/material.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/create_room_screen.dart';
import '../../presentation/screens/join_room_screen.dart';
import '../../presentation/screens/room_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/diagnostics_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String createRoom = '/create-room';
  static const String joinRoom = '/join-room';
  static const String room = '/room';
  static const String settings = '/settings';
  static const String diagnostics = '/diagnostics';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _route(const HomeScreen(), settings);
      case createRoom:
        return _route(const CreateRoomScreen(), settings);
      case joinRoom:
        return _route(const JoinRoomScreen(), settings);
      case room:
        return _route(const RoomScreen(), settings);
      case AppRouter.settings:
        return _route(const SettingsScreen(), settings);
      case diagnostics:
        return _route(const DiagnosticsScreen(), settings);
      default:
        return _route(const HomeScreen(), settings);
    }
  }

  static MaterialPageRoute<dynamic> _route(Widget page, RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }
}
