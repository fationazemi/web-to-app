import 'package:flutter/material.dart';

import '../ai/ai_service.dart';
import '../app.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../widgets/dialogs.dart';
import '../widgets/pro_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Layout.pagePadding(context, maxWidth: Layout.narrowContentMaxWidth).left,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: Layout.pagePadding(context, maxWidth: Layout.narrowContentMaxWidth)
                .copyWith(top: 4, bottom: 24 + MediaQuery.paddingOf(context).bottom + 70),
            children: [
              _ProCard(isPro: settings.isPro),
              const SizedBox(height: 20),
              const _Header('Appearance'),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.setThemeMode(s.first),
              ),
              const SizedBox(height: 20),
              const _Header('Canvas'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Default brush size'),
                subtitle: Slider(
                  value: settings.defaultStrokeWidth,
                  min: 1,
                  max: 40,
                  onChanged: settings.setDefaultStrokeWidth,
                ),
                trailing: Text('${settings.defaultStrokeWidth.round()} px'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show tips on Home'),
                value: settings.showTips,
                onChanged: settings.setShowTips,
              ),
              const SizedBox(height: 20),
              const _Header('Stylus'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pressure sensitivity'),
                subtitle: const Text('Press harder with Apple Pencil or S Pen for thicker lines.'),
                value: settings.pressureSensitivity,
                onChanged: settings.setPressureSensitivity,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Draw with stylus only'),
                subtitle: const Text('Ignore fingers so you can rest your palm on the screen.'),
                value: settings.stylusOnly,
                onChanged: settings.setStylusOnly,
              ),
              const SizedBox(height: 20),
              const _Header('Sketch AI'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_outlined),
                title: const Text('Claude API key'),
                subtitle: Text(settings.aiApiKey.isEmpty ? 'Not set' : '••••${settings.aiApiKey.substring(settings.aiApiKey.length - 4)}'),
                onTap: () async {
                  final value = await showNameDialog(context, title: 'Claude API key', initial: settings.aiApiKey);
                  if (value != null) settings.setAiApiKey(value);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Proxy endpoint (optional)'),
                subtitle: Text(settings.aiEndpoint.isNotEmpty
                    ? settings.aiEndpoint
                    : (AiDefaults.hasProxy ? 'Configured for this build' : 'Direct to api.anthropic.com')),
                onTap: () async {
                  final value = await showNameDialog(context, title: 'Proxy endpoint', initial: settings.aiEndpoint);
                  if (value != null) settings.setAiEndpoint(value);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Usage today'),
                subtitle: Text(settings.isPro
                    ? 'Unlimited with Pro'
                    : '${settings.aiRequestsToday} of ${AppSettings.freeAiRequestsPerDay} free requests used'),
              ),
              const SizedBox(height: 20),
              const _Header('Backup'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.upload_outlined),
                title: const Text('Export backup'),
                subtitle: const Text('Save all sketches as one file to move them to another device.'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await scope.backup.exportAndShare();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined),
                title: const Text('Restore backup'),
                subtitle: const Text('Import a .sketchbackup file. Existing sketches with the same id are replaced.'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final count = await scope.backup.pickAndRestore();
                    if (count != null) {
                      messenger.showSnackBar(SnackBar(content: Text('Restored $count sketches')));
                    }
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
                  }
                },
              ),
              const SizedBox(height: 20),
              const _Header('Data'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text('Delete all sketches', style: TextStyle(color: theme.colorScheme.error)),
                onTap: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Delete all sketches?',
                    message: 'This removes every saved sketch. It cannot be undone.',
                    confirmLabel: 'Delete all',
                  );
                  if (ok) await scope.repository.deleteAll();
                },
              ),
              const SizedBox(height: 20),
              const _Header('About'),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('Sketch'),
                subtitle: Text('Version 1.0.0 · Draw. Create. Share.'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.4,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPro ? 'You are on Sketch Pro' : 'Upgrade to Sketch Pro',
                  style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  isPro
                      ? 'Unlimited sketches, custom colors and HD export.'
                      : 'Free plan: up to ${AppSettings.freeDrawingLimit} sketches.',
                  style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.75), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isPro)
            const Icon(Icons.verified, color: AppColors.orange)
          else
            FilledButton(
              onPressed: () => showProSheet(context),
              style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white),
              child: const Text('Go Pro'),
            ),
        ],
      ),
    );
  }
}
