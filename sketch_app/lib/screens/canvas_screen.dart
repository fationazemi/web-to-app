import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ai/ai_gate.dart';
import '../app.dart';
import '../canvas/canvas_controller.dart';
import '../canvas/timelapse.dart';
import '../models/ai.dart';
import '../models/drawing.dart';
import '../models/layer.dart';
import '../models/stroke.dart';
import '../settings/app_settings.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../widgets/ai_sheets.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/dialogs.dart';
import '../widgets/layers_sheet.dart';
import '../widgets/pro_sheet.dart';
import '../widgets/replay_dialog.dart';
import '../widgets/sketch_canvas.dart';
import 'ai_screen.dart';

/// The drawing editor. Opens either an existing drawing ([existing]) or a
/// fresh canvas with the given [template].
class CanvasScreen extends StatefulWidget {
  const CanvasScreen({
    super.key,
    this.existing,
    this.template = CanvasTemplate.blank,
    this.initialName,
    this.tutorial,
  });

  final DrawingMeta? existing;
  final CanvasTemplate template;
  final String? initialName;

  /// A step-by-step guide to show above the tools (from Sketch AI).
  final Tutorial? tutorial;

  static Route<void> route({
    DrawingMeta? existing,
    CanvasTemplate template = CanvasTemplate.blank,
    String? initialName,
    Tutorial? tutorial,
  }) {
    return MaterialPageRoute(
      builder: (_) => CanvasScreen(existing: existing, template: template, initialName: initialName, tutorial: tutorial),
    );
  }

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  CanvasController? _controller;
  final CanvasViewport _viewport = CanvasViewport();
  String? _id;
  String? _name;
  String? _loadError;
  bool _busy = false;
  double? _progress;
  Tutorial? _tutorial;
  int _tutorialStep = 0;

  @override
  void initState() {
    super.initState();
    _id = widget.existing?.id;
    _name = widget.existing?.name ?? widget.initialName;
    _tutorial = widget.tutorial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final existing = widget.existing;
    final maxLayers = scope.settings.isPro ? AppSettings.proLayerLimit : AppSettings.freeLayerLimit;
    try {
      CanvasController controller;
      if (existing == null) {
        controller = CanvasController(
          template: widget.template,
          color: AppColors.palette.first,
          strokeWidth: scope.settings.defaultStrokeWidth,
          maxLayers: maxLayers,
        );
      } else {
        final doc = await scope.repository.open(existing.id);
        controller = CanvasController(
          template: doc.meta.template,
          initial: CanvasSnapshot(layers: doc.layers),
          color: AppColors.palette.first,
          strokeWidth: scope.settings.defaultStrokeWidth,
          paperColor: doc.meta.paperColor == null ? CanvasController.defaultPaperColor : Color(doc.meta.paperColor!),
          // Never lock someone out of layers they already made.
          maxLayers: maxLayers < doc.layers.length ? doc.layers.length : maxLayers,
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
    _viewport.dispose();
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
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<File> _tempFile(String extension) async {
    final dir = await getTemporaryDirectory();
    final safeName = (_name ?? 'sketch').replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    return File('${dir.path}/${safeName.isEmpty ? 'sketch' : safeName}.$extension');
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
        layers: controller.layers,
        paperColor: controller.paperColor == CanvasController.defaultPaperColor ? null : controller.paperColor.toARGB32(),
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
      final file = await _tempFile('png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'Made with Sketch',
      ));
    });
  }

  Future<void> _shareTimelapse() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.isEmpty) {
      _toast('Draw something first.');
      return;
    }
    if (!AppScope.of(context).settings.isPro) {
      await showProSheet(context, reason: 'Time-lapse export is a Pro feature.');
      return;
    }
    await _guard(() async {
      final bytes = await Timelapse.encodeGif(
        controller,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      final file = await _tempFile('gif');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/gif')],
        text: 'Drawn with Sketch',
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
    if (controller == null || controller.activeLayer.isEmpty) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Clear layer?',
      message: 'Everything on "${controller.activeLayer.name}" will be removed. You can undo this.',
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

  Future<void> _pickPaper() async {
    final controller = _controller;
    if (controller == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paper color', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in CanvasController.paperColors)
                      _PaperSwatch(
                        color: color,
                        selected: controller.paperColor == color,
                        onTap: () => controller.setPaperColor(color),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSymmetry() async {
    final controller = _controller;
    if (controller == null) return;
    final chosen = await showModalBottomSheet<SymmetryMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in SymmetryMode.values)
              ListTile(
                leading: Icon(switch (mode) {
                  SymmetryMode.none => Icons.block,
                  SymmetryMode.vertical => Icons.flip,
                  SymmetryMode.horizontal => Icons.flip_camera_android,
                  SymmetryMode.quad => Icons.grid_view_rounded,
                }),
                title: Text(mode.label),
                trailing: mode == controller.symmetry ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) controller.setSymmetry(chosen);
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

  Future<void> _openLayers() async {
    final controller = _controller;
    if (controller == null) return;
    final settings = AppScope.of(context).settings;
    await showLayersSheet(
      context,
      controller,
      isPro: settings.isPro,
      onUpgrade: () => showProSheet(context, reason: 'Free accounts get ${AppSettings.freeLayerLimit} layers.'),
    );
  }

  // ---------------------------------------------------------------------------
  // Sketch AI
  // ---------------------------------------------------------------------------

  Future<void> _openAi() async {
    final controller = _controller;
    if (controller == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Feedback on this sketch'),
              subtitle: const Text('What works and three things to try now'),
              enabled: !controller.isEmpty,
              onTap: () => Navigator.pop(context, 'feedback'),
            ),
            ListTile(
              leading: const Icon(Icons.format_list_numbered_rounded),
              title: const Text('Guide me step by step'),
              subtitle: const Text('Tell Sketch AI what you want to draw'),
              onTap: () => Navigator.pop(context, 'guide'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Ask Sketch AI'),
              subtitle: const Text('Chat about this drawing'),
              onTap: () => Navigator.pop(context, 'chat'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'feedback':
        await _aiFeedback(controller);
      case 'guide':
        await _aiGuide();
      case 'chat':
        Navigator.of(context).push(AiScreen.route(
          initialTab: 1,
          chatContext: 'The user is in the editor drawing "${_name ?? 'an untitled sketch'}" '
              'with ${controller.layers.length} layer(s) and ${controller.strokeCount} strokes so far.',
        ));
    }
  }

  Future<void> _aiFeedback(CanvasController controller) async {
    final feedback = await _guard(() async {
      final png = await controller.exportPng(CanvasController.referenceSize, pixelRatio: 2);
      if (!mounted) return null;
      return runAi(context, (ai) => ai.critique(png, title: _name));
    });
    if (feedback != null && mounted) await showFeedbackSheet(context, feedback);
  }

  Future<void> _aiGuide() async {
    final subject = await showNameDialog(context, title: 'What do you want to draw?', initial: _name ?? '');
    if (subject == null || subject.trim().isEmpty || !mounted) return;
    final tutorial = await _guard(() => runAi(context, (ai) => ai.tutorial(subject)));
    if (tutorial == null || tutorial.steps.isEmpty || !mounted) return;
    setState(() {
      _tutorial = tutorial;
      _tutorialStep = 0;
      _name ??= subject.trim();
    });
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

  /// Keyboard shortcuts for iPad keyboards, Chromebooks and desktops.
  Map<ShortcutActivator, VoidCallback> _shortcuts(CanvasController c) => {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): c.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): c.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): c.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): c.redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): c.redo,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyP): () => c.setTool(ToolType.pen),
        const SingleActivator(LogicalKeyboardKey.keyB): () => c.setTool(ToolType.brush),
        const SingleActivator(LogicalKeyboardKey.keyE): () => c.setTool(ToolType.eraser),
        const SingleActivator(LogicalKeyboardKey.keyF): () => c.setTool(ToolType.fill),
        const SingleActivator(LogicalKeyboardKey.keyL): _openLayers,
        const SingleActivator(LogicalKeyboardKey.keyM): _pickSymmetry,
        const SingleActivator(LogicalKeyboardKey.digit0, control: true): _viewport.reset,
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true): _viewport.reset,
        const SingleActivator(LogicalKeyboardKey.bracketLeft): () => c.setStrokeWidth((c.strokeWidth - 2).clamp(1, 40)),
        const SingleActivator(LogicalKeyboardKey.bracketRight): () => c.setStrokeWidth((c.strokeWidth + 2).clamp(1, 40)),
      };

  Widget _body(CanvasController controller) {
    final settings = AppScope.of(context).settings;
    final canvas = Center(
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: softShadow(context, blur: 20, y: 8, alpha: 0.08),
            ),
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) => SketchCanvas(
                controller: controller,
                viewport: _viewport,
                stylusOnly: settings.stylusOnly,
                pressureSensitivity: settings.pressureSensitivity,
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: ListenableBuilder(
              listenable: _viewport,
              builder: (context, _) => AnimatedOpacity(
                opacity: _viewport.isIdentity ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: IgnorePointer(
                  ignoring: _viewport.isIdentity,
                  child: _RoundIconButton(
                    icon: Icons.fit_screen_outlined,
                    onPressed: _viewport.reset,
                    label: '${(_viewport.scale * 100).round()}%',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final toolbar = _Toolbar(
      controller: controller,
      busy: _busy,
      onCustomColor: _pickCustomColor,
      onImport: _importImage,
      onClear: _clear,
      onShare: _share,
      onLayers: _openLayers,
      onSymmetry: _pickSymmetry,
      onPaper: _pickPaper,
      onReplay: () => showReplayDialog(context, controller),
      onAi: _openAi,
    );
    final tutorial = _tutorial;
    final guide = tutorial == null
        ? null
        : TutorialGuide(
            tutorial: tutorial,
            index: _tutorialStep.clamp(0, tutorial.steps.length - 1),
            onPrevious: () => setState(() => _tutorialStep--),
            onNext: () => setState(() => _tutorialStep++),
            onClose: () => setState(() => _tutorial = null),
          );

    return CallbackShortcuts(
      bindings: _shortcuts(controller),
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final landscape = constraints.maxWidth > constraints.maxHeight;
              // Tablets in landscape (and desktops) get the tools beside the
              // canvas so the drawing area uses the full height.
              if (landscape && constraints.maxWidth >= 700) {
                return Row(
                  children: [
                    Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(24, 8, 12, 24), child: canvas)),
                    SizedBox(
                      width: 364,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(8, 8, 24, 24),
                          child: Column(children: [?guide, toolbar]),
                        ),
                      ),
                    ),
                  ],
                );
              }
              final wide = constraints.maxWidth > Layout.contentMaxWidth;
              final side = wide ? (constraints.maxWidth - Layout.contentMaxWidth) / 2 : 16.0;
              return Column(
                children: [
                  Expanded(child: Padding(padding: EdgeInsets.fromLTRB(side, 4, side, 8), child: canvas)),
                  if (guide != null) Padding(padding: EdgeInsets.symmetric(horizontal: wide ? side - 16 : 0), child: guide),
                  Padding(padding: EdgeInsets.symmetric(horizontal: wide ? side - 16 : 0), child: toolbar),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

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
                        case 'paper':
                          _pickPaper();
                        case 'share':
                          _share();
                        case 'timelapse':
                          _shareTimelapse();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'save', child: ListTile(leading: Icon(Icons.save_outlined), title: Text('Save'))),
                      PopupMenuItem(value: 'saveAs', child: ListTile(leading: Icon(Icons.drive_file_rename_outline), title: Text('Save with name'))),
                      PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Rename'))),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'template', child: ListTile(leading: Icon(Icons.grid_on_outlined), title: Text('Change template'))),
                      PopupMenuItem(value: 'paper', child: ListTile(leading: Icon(Icons.palette_outlined), title: Text('Paper color'))),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.ios_share), title: Text('Export PNG'))),
                      PopupMenuItem(value: 'timelapse', child: ListTile(leading: Icon(Icons.movie_creation_outlined), title: Text('Export time-lapse GIF'))),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
        ),
        body: Stack(
          children: [
            _loadError != null
                ? Center(child: Text(_loadError!))
                : controller == null
                    ? const Center(child: CircularProgressIndicator())
                    : _body(controller),
            if (_progress != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Rendering time-lapse…', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            SizedBox(width: 200, child: LinearProgressIndicator(value: _progress)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
    required this.onLayers,
    required this.onSymmetry,
    required this.onPaper,
    required this.onReplay,
    required this.onAi,
  });

  final CanvasController controller;
  final bool busy;
  final VoidCallback onCustomColor;
  final VoidCallback onImport;
  final VoidCallback onClear;
  final VoidCallback onShare;
  final VoidCallback onLayers;
  final VoidCallback onSymmetry;
  final VoidCallback onPaper;
  final VoidCallback onReplay;
  final VoidCallback onAi;

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
              // Secondary actions. FittedBox scales the row down slightly on
              // narrow screens or wide fonts so it never overflows.
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final compact = width < 520;
                  final tight = width < 400;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ChipButton(
                            icon: Icons.layers_outlined,
                            label: compact ? '${controller.layers.length}' : 'Layers · ${controller.layers.length}',
                            onPressed: onLayers,
                          ),
                          const SizedBox(width: 6),
                          _ChipButton(
                            icon: Icons.flip,
                            label: compact ? null : 'Mirror',
                            active: controller.symmetry != SymmetryMode.none,
                            onPressed: onSymmetry,
                          ),
                          const SizedBox(width: 6),
                          _ChipButton(icon: Icons.palette_outlined, label: compact ? null : 'Paper', onPressed: onPaper),
                          const SizedBox(width: 18),
                          _ChipButton(
                            icon: Icons.auto_awesome_rounded,
                            label: tight ? null : (compact ? 'AI' : 'Sketch AI'),
                            active: true,
                            onPressed: onAi,
                          ),
                          const SizedBox(width: 6),
                          _ChipButton(
                            icon: Icons.play_arrow_rounded,
                            label: compact ? null : 'Replay',
                            onPressed: controller.isEmpty ? null : onReplay,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
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

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.icon, this.label, this.onPressed, this.active = false});

  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = onPressed == null
        ? scheme.onSurface.withValues(alpha: 0.35)
        : (active ? scheme.onPrimary : scheme.onSurface);
    return Material(
      color: active ? scheme.primary : theme.cardColor,
      shape: StadiumBorder(side: BorderSide(color: active ? scheme.primary : theme.dividerColor)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(label!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperSwatch extends StatelessWidget {
  const _PaperSwatch({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 72,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? ring : ring.withValues(alpha: 0.15), width: selected ? 2.5 : 1),
        ),
        child: selected
            ? Icon(Icons.check, color: color.computeLuminance() > 0.4 ? Colors.black : Colors.white)
            : null,
      ),
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
  const _RoundIconButton({required this.icon, this.onPressed, this.enabled, this.label});

  final IconData icon;
  final VoidCallback? onPressed;

  /// Overrides the dimmed look; defaults to whether [onPressed] is set.
  final bool? enabled;

  /// Optional text shown next to the icon (turns the circle into a pill).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = enabled ?? onPressed != null;
    final color = theme.colorScheme.onSurface.withValues(alpha: isEnabled ? 1 : 0.3);
    return Material(
      color: theme.cardColor,
      shape: StadiumBorder(side: BorderSide(color: theme.dividerColor)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: 36,
          width: label == null ? 36 : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(label!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
