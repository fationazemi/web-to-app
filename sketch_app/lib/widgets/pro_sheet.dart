import 'package:flutter/material.dart';

import '../app.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';

/// Shows the freemium upgrade sheet.
Future<void> showProSheet(BuildContext context, {String? reason}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ProSheet(reason: reason),
  );
}

class _ProSheet extends StatelessWidget {
  const _ProSheet({this.reason});

  final String? reason;

  static const _benefits = [
    (Icons.all_inclusive, 'Unlimited drawings', 'Free accounts keep up to ${AppSettings.freeDrawingLimit} sketches.'),
    (Icons.palette_outlined, 'Custom colors', 'Pick any color with the HSV picker.'),
    (Icons.hd_outlined, 'High-resolution export', 'Share crisp 4x PNGs.'),
    (Icons.cloud_outlined, 'Cloud backup', 'Coming soon: sync across devices.'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('PRO',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Text('Sketch Pro', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Text(reason!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            for (final (icon, title, subtitle) in _benefits)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  foregroundColor: AppColors.ink,
                  child: Icon(icon),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(subtitle),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                // Placeholder until store billing is integrated.
                settings.setPro(true);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Welcome to Sketch Pro!')),
                );
              },
              child: const Text('Upgrade · \$4.99 / month'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later'),
            ),
            Text(
              'Billing is not connected yet. The button activates Pro locally for testing.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
