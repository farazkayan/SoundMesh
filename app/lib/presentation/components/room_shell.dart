import 'package:flutter/material.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'floating_glass_dock.dart';

class RoomShell extends StatelessWidget {
  const RoomShell({super.key, required this.child});

  final Widget child;

  static const List<_RoomTab> _tabs = [
    _RoomTab(
      routeName: AppRouter.roomDashboardPath,
      path: AppRouter.roomDashboardPath,
      label: 'Room',
      icon: Icons.surround_sound_outlined,
    ),
    _RoomTab(
      routeName: AppRouter.roomDevicesPath,
      path: AppRouter.roomDevicesPath,
      label: 'Devices',
      icon: Icons.router_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final location = ModalRoute.of(context)?.settings.name ?? '';
    final currentIndex = _tabs.indexWhere(
      (tab) => location.startsWith('/room') && location == tab.path,
    );

    final effectiveIndex = currentIndex >= 0 ? currentIndex : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: FloatingGlassDock(
        currentIndex: effectiveIndex,
        onTap: (index) {
          final tab = _tabs[index];
          Navigator.pushReplacementNamed(context, tab.routeName);
        },
        tabLabels: _tabs.map((t) => t.label).toList(),
        tabIcons: _tabs.map((t) => t.icon).toList(),
      ),
    );
  }
}

class _RoomTab {
  const _RoomTab({
    required this.routeName,
    required this.path,
    required this.label,
    required this.icon,
  });

  final String routeName;
  final String path;
  final String label;
  final IconData icon;
}