import 'package:flutter/material.dart';

import '../app.dart';
import '../settings/app_settings.dart';
import '../widgets/pro_sheet.dart';
import 'ai_service.dart';

/// Runs an assistant call with the shared checks: configuration, the free
/// daily quota, and friendly error reporting. Returns `null` when the call
/// did not run or failed.
Future<T?> runAi<T>(
  BuildContext context,
  Future<T> Function(AiService ai) action, {
  bool countsAgainstQuota = true,
}) async {
  final scope = AppScope.of(context);
  final settings = scope.settings;
  final messenger = ScaffoldMessenger.of(context);

  if (!scope.aiConfigured) {
    messenger.showSnackBar(const SnackBar(content: Text('Add your API key or proxy in Settings › Sketch AI first.')));
    return null;
  }
  if (countsAgainstQuota && !settings.canUseAi) {
    await showProSheet(
      context,
      reason: 'You have used your ${AppSettings.freeAiRequestsPerDay} free AI requests for today.',
    );
    return null;
  }

  final ai = scope.buildAi();
  try {
    final result = await action(ai);
    if (countsAgainstQuota) settings.countAiRequest();
    return result;
  } on AiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    return null;
  }
}
