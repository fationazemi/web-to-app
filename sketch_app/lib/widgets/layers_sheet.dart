import 'package:flutter/material.dart';

import '../canvas/canvas_controller.dart';
import '../models/layer.dart';
import 'dialogs.dart';

/// Opens the layer manager.
Future<void> showLayersSheet(
  BuildContext context,
  CanvasController controller, {
  required bool isPro,
  required VoidCallback onUpgrade,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, scroll) => _LayersPanel(
        controller: controller,
        scrollController: scroll,
        isPro: isPro,
        onUpgrade: onUpgrade,
      ),
    ),
  );
}

class _LayersPanel extends StatelessWidget {
  const _LayersPanel({
    required this.controller,
    required this.scrollController,
    required this.isPro,
    required this.onUpgrade,
  });

  final CanvasController controller;
  final ScrollController scrollController;
  final bool isPro;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final layers = controller.layers;
        final count = layers.length;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Text('Layers', style: theme.textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Text('$count / ${controller.maxLayers}', style: theme.textTheme.labelMedium),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: controller.canAddLayer
                        ? controller.addLayer
                        : (isPro ? null : onUpgrade),
                    icon: Icon(controller.canAddLayer || isPro ? Icons.add : Icons.lock_outline, size: 18),
                    label: Text(controller.canAddLayer || isPro ? 'Add layer' : 'More with Pro'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: scrollController,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: count,
                // Top of the list is the top of the stack.
                onReorderItem: (oldIndex, newIndex) =>
                    controller.moveLayer(count - 1 - oldIndex, count - 1 - newIndex),
                itemBuilder: (context, i) {
                  final index = count - 1 - i;
                  final layer = layers[index];
                  return _LayerTile(
                    key: ValueKey(layer.id),
                    controller: controller,
                    index: index,
                    layer: layer,
                    reorderIndex: i,
                    selected: index == controller.activeIndex,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    super.key,
    required this.controller,
    required this.index,
    required this.layer,
    required this.reorderIndex,
    required this.selected,
  });

  final CanvasController controller;
  final int index;
  final Layer layer;
  final int reorderIndex;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: selected ? scheme.primary.withValues(alpha: 0.08) : theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? scheme.primary.withValues(alpha: 0.4) : theme.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => controller.selectLayer(index),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(layer.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    tooltip: layer.visible ? 'Hide' : 'Show',
                    onPressed: () => controller.setLayerVisible(index, !layer.visible),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(layer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${layer.strokes.length} strokes${layer.background != null ? ' · raster' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'rename':
                          final name = await showNameDialog(context, title: 'Rename layer', initial: layer.name);
                          if (name != null) controller.renameLayer(index, name);
                        case 'duplicate':
                          controller.duplicateLayer(index);
                        case 'merge':
                          await controller.mergeDown(index);
                        case 'clear':
                          controller.selectLayer(index);
                          controller.clear();
                        case 'delete':
                          controller.removeLayer(index);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'duplicate', enabled: controller.canAddLayer, child: const Text('Duplicate')),
                      PopupMenuItem(value: 'merge', enabled: index > 0, child: const Text('Merge down')),
                      const PopupMenuItem(value: 'clear', child: Text('Clear')),
                      PopupMenuItem(value: 'delete', enabled: controller.layers.length > 1, child: const Text('Delete')),
                    ],
                  ),
                  ReorderableDragStartListener(
                    index: reorderIndex,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.drag_handle_rounded),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.opacity, size: 16, color: scheme.onSurface.withValues(alpha: 0.5)),
                  Expanded(
                    child: Slider(
                      value: layer.opacity,
                      onChangeStart: (_) => controller.beginTransientEdit(),
                      onChanged: (v) => controller.setLayerOpacity(index, v),
                      onChangeEnd: (_) => controller.endTransientEdit(),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${(layer.opacity * 100).round()}%', style: theme.textTheme.labelSmall),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
