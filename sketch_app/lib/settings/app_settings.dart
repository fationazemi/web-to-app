import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// User preferences, persisted as a small JSON file in the app's documents
/// directory.
class AppSettings extends ChangeNotifier {
  /// Number of drawings a free account can keep.
  static const int freeDrawingLimit = 10;

  ThemeMode _themeMode = ThemeMode.system;
  double _defaultStrokeWidth = 12;
  bool _showTips = true;
  bool _isPro = false;
  bool _samplesSeeded = false;
  File? _file;

  ThemeMode get themeMode => _themeMode;
  double get defaultStrokeWidth => _defaultStrokeWidth;
  bool get showTips => _showTips;
  bool get isPro => _isPro;
  bool get samplesSeeded => _samplesSeeded;

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/settings.json');
      if (await _file!.exists()) {
        final json = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => ThemeMode.system,
        );
        _defaultStrokeWidth = (json['defaultStrokeWidth'] as num?)?.toDouble() ?? 12;
        _showTips = json['showTips'] as bool? ?? true;
        _isPro = json['isPro'] as bool? ?? false;
        _samplesSeeded = json['samplesSeeded'] as bool? ?? false;
      }
    } catch (_) {
      // Missing or corrupt settings fall back to defaults.
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode({
        'themeMode': _themeMode.name,
        'defaultStrokeWidth': _defaultStrokeWidth,
        'showTips': _showTips,
        'isPro': _isPro,
        'samplesSeeded': _samplesSeeded,
      }));
    } catch (_) {
      // Failing to persist preferences is not fatal.
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _persist();
  }

  void setDefaultStrokeWidth(double width) {
    _defaultStrokeWidth = width;
    notifyListeners();
    _persist();
  }

  void setShowTips(bool value) {
    _showTips = value;
    notifyListeners();
    _persist();
  }

  /// Marks the account as Pro. Billing is intentionally not wired up yet:
  /// hook `in_app_purchase` (or RevenueCat) here and call this on a
  /// verified purchase.
  void setSamplesSeeded(bool value) {
    _samplesSeeded = value;
    _persist();
  }

  void setPro(bool value) {
    _isPro = value;
    notifyListeners();
    _persist();
  }
}
