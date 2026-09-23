import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:soundmesh/core/router/app_router.dart';

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
      body: SafeArea(child: child),
      // Glassmorphism on the bottom nav only (designv3.md §3): the export's
      // backdrop-blur-xl treatment behind a 90%-opaque surface fill.
      // No blur is applied anywhere else in the app.
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: NavigationBar(
            selectedIndex: effectiveIndex,
            onDestinationSelected: (index) {
              final tab = _tabs[index];
              Navigator.pushReplacementNamed(context, tab.routeName);
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: _tabs.map((tab) {
              return NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.icon),
                label: tab.label,
              );
            }).toList(),
          ),
        ),
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