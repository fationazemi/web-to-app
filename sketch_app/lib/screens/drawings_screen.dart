import 'package:flutter/material.dart';

import '../app.dart';
import '../models/drawing.dart';
import '../models/stroke.dart';
import '../settings/app_settings.dart';
import '../theme/layout.dart';
import '../widgets/drawing_thumbnail.dart';
import 'canvas_screen.dart';
import 'home_screen.dart';

class DrawingsScreen extends StatelessWidget {
  const DrawingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Layout.pagePadding(context).left,
        title: const Text('My Drawings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        actions: [
          ListenableBuilder(
            listenable: Listenable.merge([scope.repository, scope.settings]),
            builder: (context, _) {
              final count = scope.repository.count;
              final label = scope.settings.isPro ? '$count sketches' : '$count / ${AppSettings.freeDrawingLimit}';
              return Padding(
                padding: EdgeInsets.only(right: Layout.pagePadding(context).right),
                child: Text(label, style: theme.textTheme.labelMedium),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: scope.repository,
        builder: (context, _) {
          final drawings = scope.repository.drawings;
          if (drawings.isEmpty) return const _EmptyState();
          final side = Layout.pagePadding(context, maxWidth: 1040);
          final width = MediaQuery.sizeOf(context).width - side.horizontal;
          return GridView.builder(
            padding: side.copyWith(top: 4, bottom: 24 + MediaQuery.paddingOf(context).bottom + 70),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Layout.columns(width),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: drawings.length,
            itemBuilder: (context, i) => _DrawingCard(meta: drawings[i]),
          );
        },
      ),
    );
  }
}

class _DrawingCard extends StatelessWidget {
  const _DrawingCard({required this.meta});

  final DrawingMeta meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(CanvasScreen.route(existing: meta)),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SizedBox(width: double.infinity, child: DrawingThumbnail(meta: meta, borderRadius: 14))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  meta.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DrawingMenu(meta: meta),
            ],
          ),
          Text(
            '${formatDate(meta.updatedAt)} · ${meta.template.label}',
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Nothing here yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Sketches you save will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(CanvasScreen.route()),
              icon: const Icon(Icons.add),
              label: const Text('New sketch'),
            ),
          ],
        ),
      ),
    );
  }
}
