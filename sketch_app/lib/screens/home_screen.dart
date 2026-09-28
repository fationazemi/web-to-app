import 'package:flutter/material.dart';

import '../app.dart';
import '../models/drawing.dart';
import '../models/stroke.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/drawing_thumbnail.dart';
import 'canvas_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  /// Switches the shell to the given tab index.
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sketch', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26)),
            Text(
              'Draw. Create. Share.',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
        toolbarHeight: 72,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              backgroundColor: theme.cardColor,
              foregroundColor: theme.colorScheme.onSurface,
              child: const Text('JJ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([scope.repository, scope.settings]),
        builder: (context, _) {
          final recent = scope.repository.drawings.take(8).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              const _HeroCard(),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Recent', onSeeAll: () => onNavigate(1)),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                const _EmptyRecent()
              else
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _RecentCard(meta: recent[i]),
                  ),
                ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Templates', onSeeAll: () => onNavigate(2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final template in CanvasTemplate.values) ...[
                    Expanded(child: _TemplateCard(template: template)),
                    if (template != CanvasTemplate.values.last) const SizedBox(width: 10),
                  ],
                ],
              ),
              if (scope.settings.showTips) ...[
                const SizedBox(height: 20),
                _TipBanner(onDismiss: () => scope.settings.setShowTips(false)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: 10,
            bottom: 10,
            width: 170,
            child: CustomPaint(painter: _BrushStrokePainter()),
          ),
          Positioned(
            right: 22,
            bottom: 26,
            child: Transform.rotate(
              angle: -0.15,
              child: Text(
                'Create\nsomething\ntoday.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A BLANK CANVAS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Good ideas\nstart here.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.15),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(CanvasScreen.route()),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Start Drawing'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The decorative blue brush stroke on the hero card.
class _BrushStrokePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.height * 0.22
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.62)
      ..cubicTo(size.width * 0.35, size.height * 0.05, size.width * 0.55, size.height * 0.95,
          size.width * 0.9, size.height * 0.35);
    canvas.drawPath(path, paint);

    final thin = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    final squiggle = Path()
      ..moveTo(size.width * 0.62, size.height * 0.72)
      ..cubicTo(size.width * 0.70, size.height * 0.60, size.width * 0.58, size.height * 0.85,
          size.width * 0.72, size.height * 0.88);
    canvas.drawPath(squiggle, thin);
  }

  @override
  bool shouldRepaint(_BrushStrokePainter oldDelegate) => false;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        InkWell(
          onTap: onSeeAll,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Text('See All', style: Theme.of(context).textTheme.labelMedium),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.meta});

  final DrawingMeta meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: InkWell(
        onTap: () => Navigator.of(context).push(CanvasScreen.route(existing: meta)),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 104, height: 104, child: DrawingThumbnail(meta: meta)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    meta.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                DrawingMenu(meta: meta, iconSize: 16),
              ],
            ),
            Text(
              formatDate(meta.updatedAt),
              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "..." menu for a saved drawing: open, rename, delete.
class DrawingMenu extends StatelessWidget {
  const DrawingMenu({super.key, required this.meta, this.iconSize = 20});

  final DrawingMeta meta;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;
    return SizedBox(
      width: iconSize + 8,
      height: iconSize + 8,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: iconSize,
        icon: const Icon(Icons.more_horiz),
        onSelected: (value) async {
          switch (value) {
            case 'open':
              Navigator.of(context).push(CanvasScreen.route(existing: meta));
            case 'rename':
              final name = await showNameDialog(context, title: 'Rename sketch', initial: meta.name);
              if (name != null) await repository.rename(meta.id, name);
            case 'delete':
              final ok = await showConfirmDialog(
                context,
                title: 'Delete "${meta.name}"?',
                message: 'This sketch will be removed permanently.',
              );
              if (ok) await repository.delete(meta.id);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'open', child: Text('Open')),
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.brush_outlined, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No sketches yet. Your saved drawings will show up here.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});

  final CanvasTemplate template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(CanvasScreen.route(template: template)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(template.icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(template.label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  const _TipBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: dark ? AppColors.accent.withValues(alpha: 0.2) : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Small sketches today,\nbig progress tomorrow.',
              style: TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
