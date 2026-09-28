import 'package:flutter/material.dart';

import '../app.dart';
import '../models/drawing.dart';
import '../models/stroke.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../widgets/brush_stroke.dart';
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
        titleSpacing: Layout.pagePadding(context).left,
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sketch'),
            Text(
              'Draw. Create. Share.',
              style: handStyle(size: 17, bold: false, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
            ),
          ],
        ),
        actions: [
          Padding(padding: EdgeInsets.only(right: Layout.pagePadding(context).right), child: const _Avatar()),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([scope.repository, scope.settings]),
        builder: (context, _) {
          final recent = scope.repository.drawings.take(8).toList();
          final tablet = Layout.isTablet(context);
          final cardSize = tablet ? 140.0 : 108.0;
          final side = Layout.pagePadding(context);
          return ListView(
            padding: EdgeInsets.fromLTRB(side.left, 4, side.right, 24 + MediaQuery.paddingOf(context).bottom + 70),
            children: [
              const _HeroCard(),
              const SizedBox(height: 28),
              _SectionHeader(title: 'Recent', onSeeAll: () => onNavigate(1)),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                const _EmptyRecent()
              else
                SizedBox(
                  height: cardSize + 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => _RecentCard(meta: recent[i], size: cardSize),
                  ),
                ),
              const SizedBox(height: 28),
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
                const SizedBox(height: 22),
                _TipBanner(onDismiss: () => scope.settings.setShowTips(false)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFE9E6DE)],
        ),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: softShadow(context, blur: 8, y: 2),
      ),
      alignment: Alignment.center,
      child: const Text(
        'JJ',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink, letterSpacing: 0.2),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Container(
      height: 196,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor),
        boxShadow: softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            right: -6,
            top: 14,
            bottom: 14,
            width: 180,
            child: CustomPaint(painter: BrushStrokePainter()),
          ),
          Positioned(
            right: 26,
            bottom: 22,
            child: Transform.rotate(
              angle: -0.18,
              child: Text(
                'Create\nsomething\ntoday.',
                textAlign: TextAlign.center,
                style: handStyle(size: 15, bold: false, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), height: 1.05),
              ),
            ),
          ),
          Positioned(
            right: 92,
            bottom: 24,
            child: Text('S', style: handStyle(size: 26, bold: false, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A BLANK CANVAS', style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                const SizedBox(height: 8),
                const Text(
                  'Good ideas\nstart here.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -0.6),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(CanvasScreen.route()),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Start Drawing'),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 16),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        const Spacer(),
        InkWell(
          onTap: onSeeAll,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Text('See All', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: muted)),
                Icon(Icons.chevron_right_rounded, size: 18, color: muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.meta, this.size = 108});

  final DrawingMeta meta;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      child: InkWell(
        onTap: () => Navigator.of(context).push(CanvasScreen.route(existing: meta)),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: softShadow(context, blur: 12, y: 4),
              ),
              child: DrawingThumbnail(meta: meta, borderRadius: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    meta.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                DrawingMenu(meta: meta, iconSize: 16),
              ],
            ),
            Text(
              formatDate(meta.updatedAt),
              style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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
        icon: Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        onSelected: (value) async {
          switch (value) {
            case 'open':
              Navigator.of(context).push(CanvasScreen.route(existing: meta));
            case 'rename':
              final name = await showNameDialog(context, title: 'Rename sketch', initial: meta.name);
              if (name != null) await repository.rename(meta.id, name);
            case 'duplicate':
              await repository.duplicate(meta.id);
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
          PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
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
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
          boxShadow: softShadow(context, blur: 10, y: 3, alpha: 0.04),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CustomPaint(
                painter: _TemplatePreviewPainter(template, theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              template.label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A miniature of each paper pattern for the template cards.
class _TemplatePreviewPainter extends CustomPainter {
  const _TemplatePreviewPainter(this.template, this.color);

  final CanvasTemplate template;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    switch (template) {
      case CanvasTemplate.blank:
        final frame = RRect.fromRectAndRadius(Rect.fromLTWH(1, 3, w - 2, h - 6), const Radius.circular(3));
        canvas.drawRRect(frame, paint);
        final mountains = Path()
          ..moveTo(4, h - 8)
          ..lineTo(w * 0.35, h * 0.42)
          ..lineTo(w * 0.52, h * 0.62)
          ..lineTo(w * 0.66, h * 0.5)
          ..lineTo(w - 4, h - 8);
        canvas.drawPath(mountains, paint);
        canvas.drawCircle(Offset(w * 0.72, h * 0.3), 2.2, paint);
      case CanvasTemplate.grid:
        for (var i = 0; i <= 3; i++) {
          final x = w * i / 3, y = h * i / 3;
          canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
          canvas.drawLine(Offset(0, y), Offset(w, y), paint);
        }
      case CanvasTemplate.ruled:
        for (var i = 0; i < 4; i++) {
          final y = h * (0.2 + i * 0.2);
          canvas.drawLine(Offset(2, y), Offset(w - 2, y), paint);
        }
      case CanvasTemplate.dots:
        final dot = Paint()..color = color;
        for (var i = 0; i < 3; i++) {
          for (var j = 0; j < 3; j++) {
            canvas.drawCircle(Offset(w * (0.2 + i * 0.3), h * (0.2 + j * 0.3)), 1.9, dot);
          }
        }
    }
  }

  @override
  bool shouldRepaint(_TemplatePreviewPainter oldDelegate) =>
      oldDelegate.template != template || oldDelegate.color != color;
}

class _TipBanner extends StatelessWidget {
  const _TipBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: dark ? AppColors.accent.withValues(alpha: 0.2) : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accentDeep),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Small sketches today,\nbig progress tomorrow.',
              style: TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
