import 'package:flutter/material.dart';

import '../app.dart';
import '../models/drawing.dart';

/// Renders a saved drawing's preview image with a placeholder fallback.
class DrawingThumbnail extends StatelessWidget {
  const DrawingThumbnail({super.key, required this.meta, this.borderRadius = 12});

  final DrawingMeta meta;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;
    final file = repository.thumbnailFile(meta.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Image.file(
          file,
          key: ValueKey('${meta.id}-${meta.updatedAt.microsecondsSinceEpoch}'),
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => Center(
            child: Icon(
              Icons.image_outlined,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
