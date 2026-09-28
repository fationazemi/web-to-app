import 'package:flutter/material.dart';

import 'billing/billing_service.dart';
import 'data/backup_service.dart';
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
    required this.billing,
    required this.backup,
    required super.child,
  });

  final AppSettings settings;
  final DrawingRepository repository;
  final BillingService billing;
  final BackupService backup;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      settings != oldWidget.settings || repository != oldWidget.repository;
}

class SketchApp extends StatefulWidget {
  const SketchApp({super.key, required this.settings, required this.repository, this.billing});

  final AppSettings settings;
  final DrawingRepository repository;
  final BillingService? billing;

  @override
  State<SketchApp> createState() => _SketchAppState();
}

class _SketchAppState extends State<SketchApp> {
  late final BillingService _billing = widget.billing ?? BillingService(widget.settings);
  late final BackupService _backup = BackupService(widget.repository);

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return AppScope(
      settings: settings,
      repository: widget.repository,
      billing: _billing,
      backup: _backup,
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
