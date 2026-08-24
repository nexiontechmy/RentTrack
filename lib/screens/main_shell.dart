import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';
import 'tenants_screen.dart';

/// Root bottom-navigation shell: Home (tenants overview), Analysis
/// (cross-tenant stats), Settings.
class MainShell extends StatefulWidget {
  final ThemeController themeController;

  const MainShell({super.key, required this.themeController});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const TenantsScreen();
      case 1:
        return const AnalysisScreen();
      default:
        return SettingsScreen(themeController: widget.themeController);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Rebuilt fresh (not IndexedStack) so each tab reloads its data
      // every time it's selected, instead of showing stale state from
      // when the app first launched.
      body: _buildTab(_index),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Analysis'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
