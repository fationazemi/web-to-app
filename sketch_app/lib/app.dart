import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ai/ai_service.dart';
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
    this.aiClient,
    required super.child,
  });

  final AppSettings settings;
  final DrawingRepository repository;
  final BillingService billing;
  final BackupService backup;

  /// HTTP client for the assistant; tests inject a mock here.
  final http.Client? aiClient;

  /// Builds an assistant client from the current settings.
  AiService buildAi() => AiService(
        config: AiConfig(
          endpoint: settings.aiEndpoint.isEmpty ? AiConfig.defaultEndpoint : settings.aiEndpoint,
          apiKey: settings.aiApiKey,
        ),
        client: aiClient,
      );

  /// Whether the assistant is reachable (key or proxy configured).
  bool get aiConfigured => settings.aiApiKey.isNotEmpty || settings.aiEndpoint.isNotEmpty;

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
  const SketchApp({super.key, required this.settings, required this.repository, this.billing, this.aiClient});

  final AppSettings settings;
  final DrawingRepository repository;
  final BillingService? billing;
  final http.Client? aiClient;

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
      aiClient: widget.aiClient,
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
