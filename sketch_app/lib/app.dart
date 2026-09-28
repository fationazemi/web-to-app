import 'package:flutter/material.dart';

import 'data/drawing_repository.dart';
import 'screens/home_shell.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';

/// Gives every screen access to the app-wide settings and drawing store.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.repository,
    required super.child,
  });

  final AppSettings settings;
  final DrawingRepository repository;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      settings != oldWidget.settings || repository != oldWidget.repository;
}

class SketchApp extends StatelessWidget {
  const SketchApp({super.key, required this.settings, required this.repository});

  final AppSettings settings;
  final DrawingRepository repository;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      repository: repository,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return MaterialApp(
            title: 'Sketch',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: settings.themeMode,
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
