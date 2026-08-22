import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  runApp(const RentTrackApp());
}

class RentTrackApp extends StatefulWidget {
  const RentTrackApp({super.key});

  @override
  State<RentTrackApp> createState() => _RentTrackAppState();
}

class _RentTrackAppState extends State<RentTrackApp> {
  final _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'RentTrack',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeController.mode,
          home: MainShell(themeController: _themeController),
        );
      },
    );
  }
}
