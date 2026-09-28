import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../canvas/canvas_controller.dart';
import '../models/drawing.dart';
import '../models/stroke.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/dialogs.dart';
import '../widgets/pro_sheet.dart';
import '../widgets/sketch_canvas.dart';

/// The drawing editor. Opens either an existing drawing ([existing]) or a
/// fresh canvas with the given [template].
class CanvasScreen extends StatefulWidget {
  const CanvasScreen({
    super.key,
    this.existing,
    this.template = CanvasTemplate.blank,
    this.initialName,
  });

  final DrawingMeta? existing;
  final CanvasTemplate template;
  final String? initialName;

  static Route<void> route({DrawingMeta? existing, CanvasTemplate template = CanvasTemplate.blank, String? initialName}) {
    return MaterialPageRoute(
      builder: (_) => CanvasScreen(existing: existing, template: template, initialName: initialName),
    );
  }

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  CanvasController? _controller;
  String? _id;
  String? _name;
  String? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _id = widget.existing?.id;
    _name = widget.existing?.name ?? widget.initialName;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final existing = widget.existing;
    try {
      CanvasController controller;
      if (existing == null) {
        controller = CanvasController(
          template: widget.template,
          color: AppColors.palette.first,
          strokeWidth: scope.settings.defaultStrokeWidth,
        );
      } else {
        final doc = await scope.repository.open(existing.id);
        controller = CanvasController(
          template: doc.meta.template,
          initial: CanvasSnapshot(background: doc.background, strokes: doc.strokes),
          color: AppColors.palette.first,
          strokeWidth: scope.settings.defaultStrokeWidth,
        );
      }
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Could not open this sketch.');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<T?> _guard<T>(Future<T> Function() action) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await action();
    } catch (e) {
      if (mounted) _toast('Something went wrong: $e');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<bool> _save({bool askName = false}) async {
    final controller = _controller;
    if (controller == null) return false;
    final scope = AppScope.of(context);
    final settings = scope.settings;
    final repository = scope.repository;

    if (_id == null && !settings.isPro && repository.count >= AppSettings.freeDrawingLimit) {
      await showProSheet(
        context,
        reason: 'You have reached the free limit of ${AppSettings.freeDrawingLimit} sketches.',
      );
      return false;
    }

    var name = _name;
    if (askName || name == null || name.isEmpty) {
      name = await showNameDialog(context, initial: name ?? '');
      if (name == null) return false;
    }

    final saved = await _guard(() async {
      final thumb = await controller.exportPng(CanvasController.referenceSize, pixelRatio: 1.5);
      return repository.save(
        id: _id,
        name: name!,
        template: controller.template,
        strokes: controller.strokes,
        background: controller.background,
        thumbnailPng: thumb,
      );
    });
    if (saved == null) return false;
    _id = saved.id;
    _name = saved.name;
    controller.markSaved();
    if (mounted) _toast('Saved "${saved.name}"');
    return true;
  }

  Future<void> _rename() async {
    final name = await showNameDialog(context, title: 'Rename sketch', initial: _name ?? '');
    if (name == null || !mounted) return;
    setState(() => _name = name.trim().isEmpty ? _name : name.trim());
    final id = _id;
    if (id != null && _name != null) {
      await AppScope.of(context).repository.rename(id, _name!);
    }
  }

  Future<void> _share() async {
    final controller = _controller;
    if (controller == null) return;
    final isPro = AppScope.of(context).settings.isPro;
    await _guard(() async {
      final bytes = await controller.exportPng(CanvasController.referenceSize, pixelRatio: isPro ? 4 : 2);
      final dir = await getTemporaryDirectory();
      final safeName = (_name ?? 'sketch').replaceAll(RegExp(r'[^\w\- ]'), '').trim();
      final file = File('${dir.path}/${safeName.isEmpty ? 'sketch' : safeName}.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'Made with Sketch',
      ));
    });
  }

  Future<void> _importImage() async {
    final controller = _controller;
    if (controller == null) return;
    await _guard(() async {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048);
      if (picked == null) return;
      final image = await decodeImageFromList(await picked.readAsBytes());
      await controller.importImage(image);
      image.dispose();
    });
  }

  Future<void> _clear() async {
    final controller = _controller;
    if (controller == null || controller.isEmpty) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Clear canvas?',
      message: 'Everything on the canvas will be removed. You can undo this.',
      confirmLabel: 'Clear',
    );
    if (ok) controller.clear();
  }

  Future<void> _pickTemplate() async {
    final controller = _controller;
    if (controller == null) return;
    final chosen = await showModalBottomSheet<CanvasTemplate>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in CanvasTemplate.values)
              ListTile(
                leading: Icon(t.icon),
                title: Text(t.label),
                trailing: t == controller.template ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, t),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) controller.setTemplate(chosen);
  }

  Future<void> _pickCustomColor() async {
    final controller = _controller;
    if (controller == null) return;
    if (!AppScope.of(context).settings.isPro) {
      await showProSheet(context, reason: 'Custom colors are a Pro feature.');
      return;
    }
    final color = await showColorPickerDialog(context, initial: controller.color);
    if (color != null) controller.setColor(color);
  }

  Future<void> _handlePop() async {
    final controller = _controller;
    if (controller == null || !controller.dirty) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save your sketch?'),
        content: const Text('You have unsaved changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'discard'), child: const Text('Discard')),
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'discard':
        Navigator.of(context).pop();
      case 'save':
        if (await _save() && mounted) Navigator.of(context).pop();
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handlePop),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _name ?? 'Sketch',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: handStyle(size: 26, color: Theme.of(context).colorScheme.onSurface),
              ),
              Text(
                'Draw. Create. Share.',
                style: handStyle(
                  size: 14,
                  bold: false,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          actions: controller == null
              ? null
              : [
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.undo_rounded,
                          onPressed: controller.canUndo ? controller.undo : null,
                        ),
                        const SizedBox(width: 6),
                        _RoundIconButton(
                          icon: Icons.redo_rounded,
                          onPressed: controller.canRedo ? controller.redo : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    child: const _RoundIconButton(icon: Icons.more_horiz_rounded, enabled: true),
                    onSelected: (value) {
                      switch (value) {
                        case 'save':
                          _save();
                        case 'saveAs':
                          _save(askName: true);
                        case 'rename':
                          _rename();
                        case 'template':
                          _pickTemplate();
                        case 'share':
                          _share();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'save', child: ListTile(leading: Icon(Icons.save_outlined), title: Text('Save'))),
                      PopupMenuItem(value: 'saveAs', child: ListTile(leading: Icon(Icons.drive_file_rename_outline), title: Text('Save with name'))),
                      PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Rename'))),
                      PopupMenuItem(value: 'template', child: ListTile(leading: Icon(Icons.grid_on_outlined), title: Text('Change template'))),
                      PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.ios_share), title: Text('Export PNG'))),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
        ),
        body: _loadError != null
            ? Center(child: Text(_loadError!))
            : controller == null
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: softShadow(context, blur: 20, y: 8, alpha: 0.08),
                                ),
                                child: SketchCanvas(controller: controller),
                              ),
                            ),
                          ),
                        ),
                        _Toolbar(
                          controller: controller,
                          busy: _busy,
                          onCustomColor: _pickCustomColor,
                          onImport: _importImage,
                          onClear: _clear,
                          onShare: _share,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.busy,
    required this.onCustomColor,
    required this.onImport,
    required this.onClear,
    required this.onShare,
  });

  final CanvasController controller;
  final bool busy;
  final VoidCallback onCustomColor;
  final VoidCallback onImport;
  final VoidCallback onClear;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isCustom = !AppColors.palette.contains(controller.color);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tools
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    for (final tool in ToolType.values)
                      Expanded(
                        child: _ToolButton(
                          tool: tool,
                          selected: controller.tool == tool,
                          onTap: () => controller.setTool(tool),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Colors
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    for (final color in AppColors.palette)
                      Expanded(
                        child: _Swatch(
                          color: color,
                          selected: controller.color == color,
                          onTap: () => controller.setColor(color),
                        ),
                      ),
                    Expanded(
                      child: _Swatch(
                        color: isCustom ? controller.color : null,
                        selected: isCustom,
                        onTap: onCustomColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Width
              Row(
                children: [
                  Icon(Icons.circle, size: 6, color: scheme.onSurface),
                  Expanded(
                    child: Slider(
                      value: controller.strokeWidth,
                      min: 1,
                      max: 40,
                      onChanged: controller.setStrokeWidth,
                    ),
                  ),
                  Icon(Icons.circle, size: 14, color: scheme.onSurface),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${controller.strokeWidth.round()} px',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Bottom actions
              Row(
                children: [
                  _SquareButton(icon: Icons.image_outlined, onPressed: busy ? null : onImport),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onClear,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear Canvas'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SquareButton(icon: Icons.ios_share, onPressed: busy ? null : onShare),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool, required this.selected, required this.onTap});

  final ToolType tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tool.icon, size: 20, color: selected ? scheme.onPrimary : scheme.onSurface),
            const SizedBox(height: 2),
            Text(
              tool.label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});

  /// `null` renders the rainbow "custom color" swatch.
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: selected ? 30 : 24,
          height: selected ? 30 : 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            gradient: color == null
                ? const SweepGradient(colors: [
                    Colors.red, Colors.orange, Colors.yellow, Colors.green,
                    Colors.blue, Colors.purple, Colors.red,
                  ])
                : null,
            border: Border.all(
              color: selected ? ring : ring.withValues(alpha: 0.12),
              width: selected ? 2.5 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: onPressed == null ? 0.3 : 1)),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onPressed, this.enabled});

  final IconData icon;
  final VoidCallback? onPressed;

  /// Overrides the dimmed look; defaults to whether [onPressed] is set.
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = enabled ?? onPressed != null;
    return Material(
      color: theme.cardColor,
      shape: CircleBorder(side: BorderSide(color: theme.dividerColor)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: isEnabled ? 1 : 0.3),
          ),
        ),
      ),
    );
  }
}
