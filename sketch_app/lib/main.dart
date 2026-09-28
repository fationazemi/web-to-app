import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/drawing_repository.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = AppSettings();
  final repository = DrawingRepository();
  await Future.wait([settings.load(), repository.load()]);

  runApp(SketchApp(settings: settings, repository: repository));
}
