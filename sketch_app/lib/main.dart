import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/drawing_repository.dart';
import 'data/sample_sketches.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  final settings = AppSettings();
  final repository = DrawingRepository();
  await Future.wait([settings.load(), repository.load()]);

  runApp(SketchApp(settings: settings, repository: repository));

  // Populate the library with starter sketches after the first frame so the
  // app opens instantly.
  SampleSketches.seedIfNeeded(settings, repository);
}
