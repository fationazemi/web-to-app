import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// User preferences, persisted as a small JSON file in the app's documents
/// directory.
class AppSettings extends ChangeNotifier {
  /// Number of drawings a free account can keep.
  static const int freeDrawingLimit = 10;

  /// Layers per drawing for free and Pro accounts.
  static const int freeLayerLimit = 2;
  static const int proLayerLimit = 10;

  /// AI requests a free account may make per day.
  static const int freeAiRequestsPerDay = 5;

  ThemeMode _themeMode = ThemeMode.system;
  double _defaultStrokeWidth = 12;
  bool _showTips = true;
  bool _isPro = false;
  bool _samplesSeeded = false;
  bool _stylusOnly = false;
  bool _pressureSensitivity = true;
  String _aiEndpoint = '';
  String _aiApiKey = '';
  String _aiUsageDay = '';
  int _aiUsageCount = 0;
  File? _file;

  ThemeMode get themeMode => _themeMode;
  double get defaultStrokeWidth => _defaultStrokeWidth;
  bool get showTips => _showTips;
  bool get isPro => _isPro;
  bool get samplesSeeded => _samplesSeeded;

  /// When on, only a stylus draws; fingers are ignored (palm rejection).
  bool get stylusOnly => _stylusOnly;

  /// Whether stylus pressure changes the stroke width.
  bool get pressureSensitivity => _pressureSensitivity;

  /// Custom endpoint for the AI assistant (empty = api.anthropic.com).
  String get aiEndpoint => _aiEndpoint;

  /// API key for direct calls. Kept in the app's private documents folder;
  /// for a store release use a proxy endpoint instead (see README).
  String get aiApiKey => _aiApiKey;

  /// AI requests made today (free quota bookkeeping).
  int get aiRequestsToday => _aiUsageDay == _today ? _aiUsageCount : 0;

  bool get canUseAi => _isPro || aiRequestsToday < freeAiRequestsPerDay;

  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

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
        _stylusOnly = json['stylusOnly'] as bool? ?? false;
        _pressureSensitivity = json['pressureSensitivity'] as bool? ?? true;
        _aiEndpoint = json['aiEndpoint'] as String? ?? '';
        _aiApiKey = json['aiApiKey'] as String? ?? '';
        _aiUsageDay = json['aiUsageDay'] as String? ?? '';
        _aiUsageCount = (json['aiUsageCount'] as num?)?.toInt() ?? 0;
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
        'stylusOnly': _stylusOnly,
        'pressureSensitivity': _pressureSensitivity,
        'aiEndpoint': _aiEndpoint,
        'aiApiKey': _aiApiKey,
        'aiUsageDay': _aiUsageDay,
        'aiUsageCount': _aiUsageCount,
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
  void setStylusOnly(bool value) {
    _stylusOnly = value;
    notifyListeners();
    _persist();
  }

  void setPressureSensitivity(bool value) {
    _pressureSensitivity = value;
    notifyListeners();
    _persist();
  }

  void setAiEndpoint(String value) {
    _aiEndpoint = value.trim();
    notifyListeners();
    _persist();
  }

  void setAiApiKey(String value) {
    _aiApiKey = value.trim();
    notifyListeners();
    _persist();
  }

  /// Records one AI request against today's free quota.
  void countAiRequest() {
    if (_aiUsageDay != _today) {
      _aiUsageDay = _today;
      _aiUsageCount = 0;
    }
    _aiUsageCount++;
    notifyListeners();
    _persist();
  }

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
