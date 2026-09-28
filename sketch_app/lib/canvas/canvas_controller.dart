import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/layer.dart';
import '../models/stroke.dart';
import 'flood_fill.dart';
import 'sketch_painter.dart';

/// An immutable snapshot of the canvas content. Undo/redo is a stack of
/// these, which keeps the history logic trivial and bug-free.
class CanvasSnapshot {
  CanvasSnapshot({List<Layer>? layers, this.activeIndex = 0})
      : layers = layers ?? [Layer(id: Layer.newId(), name: 'Layer 1')];

  final List<Layer> layers;
  final int activeIndex;

  Layer get active => layers[activeIndex.clamp(0, layers.length - 1)];

  bool get isEmpty => layers.every((l) => l.isEmpty);

  int get strokeCount => layers.fold(0, (n, l) => n + l.strokes.length);

  CanvasSnapshot copyWith({List<Layer>? layers, int? activeIndex}) =>
      CanvasSnapshot(layers: layers ?? this.layers, activeIndex: activeIndex ?? this.activeIndex);

  /// Returns a snapshot with the layer at [index] replaced.
  CanvasSnapshot replaceLayer(int index, Layer layer) {
    final next = List<Layer>.of(layers);
    next[index] = layer;
    return copyWith(layers: List.unmodifiable(next));
  }
}

/// Holds the editing state of one drawing: tool settings, layers, the
/// in-progress stroke and the undo/redo history.
class CanvasController extends ChangeNotifier {
  CanvasController({
    required this.template,
    CanvasSnapshot? initial,
    this.tool = ToolType.pen,
    this.color = Colors.black,
    this.strokeWidth = 12,
    this.paperColor = defaultPaperColor,
    this.maxLayers = 10,
  }) : _current = initial ?? CanvasSnapshot();

  static const int maxHistory = 100;

  /// Logical size every drawing is rasterised at. Stroke geometry is
  /// normalized, so this only affects the resolution of fills and imports.
  static const Size referenceSize = Size(360, 480);

  /// Device-independent oversampling for raster operations.
  static const double rasterPixelRatio = 2;

  static const Color defaultPaperColor = Color(0xFFFCFBF8);

  /// Paper colors offered in the editor.
  static const List<Color> paperColors = [
    defaultPaperColor,
    Color(0xFFFFFFFF),
    Color(0xFFF3EBDD),
    Color(0xFFE9EEF5),
    Color(0xFFDCE9DC),
    Color(0xFF2B2B2B),
    Color(0xFF111111),
  ];

  CanvasTemplate template;
  ToolType tool;
  Color color;
  Color paperColor;
  SymmetryMode symmetry = SymmetryMode.none;

  /// Upper bound on layers (the UI may lower it for free accounts).
  int maxLayers;

  /// Stroke width in logical pixels, as shown on the slider.
  double strokeWidth;

  CanvasSnapshot _current;
  final List<CanvasSnapshot> _undo = [];
  final List<CanvasSnapshot> _redo = [];

  Stroke? _active;
  List<Offset>? _activePoints;
  List<double>? _activePressures;

  /// Cached pictures of committed strokes, per layer id.
  final Map<String, _PictureCacheEntry> _pictures = {};

  bool _dirty = false;

  bool get dirty => _dirty;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isEmpty => _current.isEmpty && _active == null;

  CanvasSnapshot get snapshot => _current;
  List<Layer> get layers => _current.layers;
  int get activeIndex => _current.activeIndex;
  Layer get activeLayer => _current.active;
  int get strokeCount => _current.strokeCount;

  /// Strokes of the active layer.
  List<Stroke> get strokes => activeLayer.strokes;

  /// Raster background of the active layer.
  ui.Image? get background => activeLayer.background;

  Stroke? get activeStroke => _active;

  /// The in-progress stroke plus its symmetry mirrors.
  List<Stroke> get activeStrokes {
    final active = _active;
    if (active == null) return const [];
    return [active, ..._mirrors(active)];
  }

  void markSaved() {
    _dirty = false;
    notifyListeners();
  }

  void setTool(ToolType value) {
    if (tool == value) return;
    tool = value;
    notifyListeners();
  }

  void setColor(Color value) {
    if (color == value) return;
    color = value;
    notifyListeners();
  }

  void setStrokeWidth(double value) {
    if (strokeWidth == value) return;
    strokeWidth = value;
    notifyListeners();
  }

  void setTemplate(CanvasTemplate value) {
    if (template == value) return;
    template = value;
    _dirty = true;
    notifyListeners();
  }

  void setPaperColor(Color value) {
    if (paperColor == value) return;
    paperColor = value;
    _dirty = true;
    notifyListeners();
  }

  void setSymmetry(SymmetryMode value) {
    if (symmetry == value) return;
    symmetry = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Strokes
  // ---------------------------------------------------------------------------

  /// Starts a stroke at [normalized] (0..1 canvas coordinates). [size] is the
  /// on-screen canvas size, used to convert the pixel width to a fraction.
  ///
  /// Pass [pressure] (normalized 0..1) for stylus input to get a
  /// pressure-sensitive stroke; leave it `null` for finger or mouse input.
  void beginStroke(Offset normalized, Size size, {double? pressure}) {
    if (tool == ToolType.fill || size.width <= 0 || !activeLayer.visible) return;
    final points = [normalized];
    final pressures = pressure == null ? null : [pressure];
    _activePoints = points;
    _activePressures = pressures;
    _active = Stroke(
      tool: tool,
      color: color,
      width: strokeWidth / size.width,
      points: points,
      pressures: pressures,
    );
    notifyListeners();
  }

  void extendStroke(Offset normalized, {double? pressure}) {
    final points = _activePoints;
    if (points == null) return;
    // Skip points that would not be visible; keeps the stroke data compact.
    if ((points.last - normalized).distance < 0.0008) return;
    points.add(normalized);
    _activePressures?.add(pressure ?? _activePressures!.last);
    notifyListeners();
  }

  void endStroke() {
    final active = _active;
    final points = _activePoints;
    final pressures = _activePressures;
    _active = null;
    _activePoints = null;
    _activePressures = null;
    if (active == null || points == null || points.isEmpty) {
      notifyListeners();
      return;
    }
    final committed = Stroke(
      tool: active.tool,
      color: active.color,
      width: active.width,
      points: List.unmodifiable(points),
      pressures: pressures == null ? null : List.unmodifiable(pressures),
    );
    final layer = activeLayer;
    _commit(_current.replaceLayer(
      activeIndex,
      layer.copyWith(strokes: List.unmodifiable([...layer.strokes, committed, ..._mirrors(committed)])),
    ));
  }

  void cancelStroke() {
    _active = null;
    _activePoints = null;
    _activePressures = null;
    notifyListeners();
  }

  List<Stroke> _mirrors(Stroke stroke) {
    Stroke mirrored(Offset Function(Offset) f) => Stroke(
          tool: stroke.tool,
          color: stroke.color,
          width: stroke.width,
          points: [for (final p in stroke.points) f(p)],
          pressures: stroke.pressures,
        );
    return switch (symmetry) {
      SymmetryMode.none => const [],
      SymmetryMode.vertical => [mirrored((p) => Offset(1 - p.dx, p.dy))],
      SymmetryMode.horizontal => [mirrored((p) => Offset(p.dx, 1 - p.dy))],
      SymmetryMode.quad => [
          mirrored((p) => Offset(1 - p.dx, p.dy)),
          mirrored((p) => Offset(p.dx, 1 - p.dy)),
          mirrored((p) => Offset(1 - p.dx, 1 - p.dy)),
        ],
    };
  }

  // ---------------------------------------------------------------------------
  // Layers
  // ---------------------------------------------------------------------------

  bool get canAddLayer => layers.length < maxLayers;

  void addLayer() {
    if (!canAddLayer) return;
    final next = List<Layer>.of(layers)
      ..insert(activeIndex + 1, Layer(id: Layer.newId(), name: 'Layer ${layers.length + 1}'));
    _commit(CanvasSnapshot(layers: List.unmodifiable(next), activeIndex: activeIndex + 1));
  }

  void removeLayer(int index) {
    if (layers.length <= 1 || index < 0 || index >= layers.length) return;
    final next = List<Layer>.of(layers)..removeAt(index);
    final active = activeIndex >= next.length ? next.length - 1 : (activeIndex > index ? activeIndex - 1 : activeIndex);
    _commit(CanvasSnapshot(layers: List.unmodifiable(next), activeIndex: active));
  }

  void duplicateLayer(int index) {
    if (!canAddLayer || index < 0 || index >= layers.length) return;
    final source = layers[index];
    final copy = Layer(
      id: Layer.newId(),
      name: '${source.name} copy',
      visible: source.visible,
      opacity: source.opacity,
      strokes: source.strokes,
      background: source.background,
    );
    final next = List<Layer>.of(layers)..insert(index + 1, copy);
    _commit(CanvasSnapshot(layers: List.unmodifiable(next), activeIndex: index + 1));
  }

  void moveLayer(int from, int to) {
    if (from == to || from < 0 || from >= layers.length || to < 0 || to >= layers.length) return;
    final next = List<Layer>.of(layers);
    final layer = next.removeAt(from);
    next.insert(to, layer);
    final activeId = activeLayer.id;
    _commit(CanvasSnapshot(
      layers: List.unmodifiable(next),
      activeIndex: next.indexWhere((l) => l.id == activeId),
    ));
  }

  void selectLayer(int index) {
    if (index == activeIndex || index < 0 || index >= layers.length) return;
    // Selection is not an edit: it does not touch the undo stack.
    _current = _current.copyWith(activeIndex: index);
    notifyListeners();
  }

  void setLayerVisible(int index, bool visible) =>
      _commit(_current.replaceLayer(index, layers[index].copyWith(visible: visible)));

  CanvasSnapshot? _transientBase;

  /// Call before a continuous edit (e.g. dragging an opacity slider) so the
  /// whole drag becomes a single undo step; finish with [endTransientEdit].
  void beginTransientEdit() => _transientBase ??= _current;

  void endTransientEdit() {
    final base = _transientBase;
    _transientBase = null;
    if (base == null || identical(base, _current)) return;
    _undo.add(base);
    if (_undo.length > maxHistory) _undo.removeAt(0);
    _redo.clear();
    _dirty = true;
    notifyListeners();
  }

  void setLayerOpacity(int index, double opacity) {
    final next = _current.replaceLayer(index, layers[index].copyWith(opacity: opacity.clamp(0.0, 1.0)));
    if (_transientBase != null) {
      _current = next;
      _dirty = true;
      notifyListeners();
    } else {
      _commit(next);
    }
  }

  void renameLayer(int index, String name) {
    if (name.trim().isEmpty) return;
    _commit(_current.replaceLayer(index, layers[index].copyWith(name: name.trim())));
  }

  /// Merges layer [index] into the one below it (index - 1).
  Future<void> mergeDown(int index) async {
    if (index <= 0 || index >= layers.length) return;
    final upper = layers[index], lower = layers[index - 1];
    final merged = await _rasterizeLayers([lower, upper], referenceSize, rasterPixelRatio);
    final next = List<Layer>.of(layers)
      ..removeAt(index)
      ..[index - 1] = lower.copyWith(strokes: const [], background: merged, opacity: 1, visible: true);
    _commit(CanvasSnapshot(layers: List.unmodifiable(next), activeIndex: index - 1));
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  void _commit(CanvasSnapshot next) {
    _undo.add(_current);
    if (_undo.length > maxHistory) _undo.removeAt(0);
    _redo.clear();
    _current = next;
    _dirty = true;
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_current);
    _current = _undo.removeLast();
    _dirty = true;
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_current);
    _current = _redo.removeLast();
    _dirty = true;
    notifyListeners();
  }

  /// Clears the active layer.
  void clear() {
    if (activeLayer.isEmpty) return;
    _commit(_current.replaceLayer(activeIndex, activeLayer.copyWith(strokes: const [], clearBackground: true)));
  }

  // ---------------------------------------------------------------------------
  // Raster operations
  // ---------------------------------------------------------------------------

  /// Returns a picture of a layer's committed strokes for [size], recording
  /// a new one only when the layer or size changed.
  ui.Picture pictureFor(Layer layer, Size size) {
    final entry = _pictures[layer.id];
    if (entry != null && entry.revision == layer.revision && entry.size == size) return entry.picture;
    entry?.picture.dispose();
    final picture = recordStrokes(size, layer.strokes);
    _pictures[layer.id] = _PictureCacheEntry(layer.revision, size, picture);
    return picture;
  }

  Future<ui.Image> _rasterizeLayers(List<Layer> layers, Size size, double pixelRatio, {ui.Image? underlay}) {
    final width = (size.width * pixelRatio).round();
    final height = (size.height * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    canvas.scale(pixelRatio);
    final rect = Offset.zero & size;
    if (underlay != null) {
      final src = Rect.fromLTWH(0, 0, underlay.width.toDouble(), underlay.height.toDouble());
      canvas.drawImageRect(underlay, src, rect, Paint()..filterQuality = FilterQuality.high);
    }
    paintDrawing(canvas, size, layers: layers);
    return recorder.endRecording().toImage(width, height);
  }

  /// Renders the visible content (optionally with paper and template) into
  /// an image of `size * pixelRatio` pixels.
  Future<ui.Image> rasterize(
    Size size, {
    double pixelRatio = 1,
    bool includePaper = false,
    List<Layer>? layers,
  }) {
    final width = (size.width * pixelRatio).round();
    final height = (size.height * pixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    canvas.scale(pixelRatio);
    paintDrawing(
      canvas,
      size,
      layers: layers ?? this.layers,
      template: includePaper ? template : CanvasTemplate.blank,
      paperColor: includePaper ? paperColor : null,
      templateInk: templateInkFor(paperColor),
    );
    return recorder.endRecording().toImage(width, height);
  }

  /// Exports the drawing as PNG bytes, including paper and template.
  Future<Uint8List> exportPng(Size size, {double pixelRatio = 2, List<Layer>? layers}) async {
    final image = await rasterize(size, pixelRatio: pixelRatio, includePaper: true, layers: layers);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Flood-fills the region under [normalized] on the active layer with the
  /// current color. The layer is flattened into a raster background first.
  Future<void> fillAt(Offset normalized) async {
    final layer = activeLayer;
    if (!layer.visible) return;
    final flattened = await _rasterizeLayers([layer.copyWith(opacity: 1)], referenceSize, rasterPixelRatio);
    final x = (normalized.dx * flattened.width).floor().clamp(0, flattened.width - 1);
    final y = (normalized.dy * flattened.height).floor().clamp(0, flattened.height - 1);
    final filled = await floodFillImage(flattened, x, y, color);
    flattened.dispose();
    _commit(_current.replaceLayer(activeIndex, layer.copyWith(strokes: const [], background: filled)));
  }

  /// Places [image] underneath the active layer's content (fitted to the
  /// canvas) and flattens that layer into a raster background.
  Future<void> importImage(ui.Image image) async {
    final layer = activeLayer;
    final fitted = await _fitImage(image, referenceSize * rasterPixelRatio);
    final flattened = await _rasterizeLayers([layer.copyWith(opacity: 1)], referenceSize, rasterPixelRatio, underlay: fitted);
    fitted.dispose();
    _commit(_current.replaceLayer(activeIndex, layer.copyWith(strokes: const [], background: flattened)));
  }

  Future<ui.Image> _fitImage(ui.Image image, Size size) {
    final width = size.width.round();
    final height = size.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, imageSize, size);
    final src = Alignment.center.inscribe(fitted.source, Offset.zero & imageSize);
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.high);
    return recorder.endRecording().toImage(width, height);
  }

  @override
  void dispose() {
    for (final entry in _pictures.values) {
      entry.picture.dispose();
    }
    _pictures.clear();
    super.dispose();
  }
}

class _PictureCacheEntry {
  const _PictureCacheEntry(this.revision, this.size, this.picture);

  final int revision;
  final Size size;
  final ui.Picture picture;
}
