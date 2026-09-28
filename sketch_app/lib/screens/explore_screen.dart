import 'package:flutter/material.dart';

import '../models/stroke.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import 'canvas_screen.dart';

const _prompts = <String>[
  'A cup of coffee on a rainy morning',
  'Your favourite pair of shoes',
  'A cat that thinks it is a lion',
  'The view from your window',
  'A plant you keep forgetting to water',
  'A city skyline at night',
  'Something that made you smile today',
  'A bicycle leaning on a wall',
  'Three fruits in a bowl',
  'A paper boat on a puddle',
  'Your hand, drawn in one line',
  'A lighthouse in fog',
  'A mountain you would like to climb',
  'A dog wearing a scarf',
  'An old key and what it opens',
];

const _tips = <(IconData, String, String)>[
  (Icons.gesture, 'Warm up with lines', 'Draw ten quick lines and circles before starting. Loose wrists make cleaner strokes.'),
  (Icons.layers_outlined, 'Brush under, pen over', 'Block in shapes with the soft brush, then add detail with the pen on top.'),
  (Icons.format_color_fill_outlined, 'Close your shapes', 'The fill tool stops at gaps. Close outlines before filling a region.'),
  (Icons.grid_on_outlined, 'Use a template', 'Grid and dot paper make proportions and perspective much easier.'),
];

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  String get _promptOfTheDay {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return _prompts[dayOfYear % _prompts.length];
  }

  void _start(BuildContext context, String prompt) {
    Navigator.of(context).push(CanvasScreen.route(initialName: prompt));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Layout.pagePadding(context).left,
        title: const Text('Explore', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
      ),
      body: ListView(
        padding: Layout.pagePadding(context).copyWith(top: 4, bottom: 24 + MediaQuery.paddingOf(context).bottom + 70),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: dark ? AppColors.accent.withValues(alpha: 0.2) : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROMPT OF THE DAY',
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: AppColors.accent),
                ),
                const SizedBox(height: 8),
                Text(_promptOfTheDay, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _start(context, _promptOfTheDay),
                  icon: const Icon(Icons.brush_outlined, size: 18),
                  label: const Text('Draw it'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('More prompts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in _prompts)
                ActionChip(
                  label: Text(prompt),
                  onPressed: () => _start(context, prompt),
                  shape: const StadiumBorder(),
                  side: BorderSide(color: theme.dividerColor),
                  backgroundColor: theme.cardColor,
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final template in CanvasTemplate.values)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: theme.cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: ListTile(
                leading: Icon(template.icon),
                title: Text(template.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(CanvasScreen.route(template: template)),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Tips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final (icon, title, body) in _tips)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.cardColor,
                foregroundColor: theme.colorScheme.onSurface,
                child: Icon(icon, size: 20),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(body),
            ),
        ],
      ),
    );
  }
}
