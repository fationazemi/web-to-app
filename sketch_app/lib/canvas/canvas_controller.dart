import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/stroke.dart';
import 'flood_fill.dart';
import 'sketch_painter.dart';

/// An immutable snapshot of the canvas content. Undo/redo is a stack of
/// these, which keeps the history logic trivial and bug-free.
class CanvasSnapshot {
  const CanvasSnapshot({this.background, this.strokes = const []});

  final ui.Image? background;
  final List<Stroke> strokes;

  bool get isEmpty => background == null && strokes.isEmpty;
}

/// Holds the editing state of one drawing: tool settings, the committed
/// content, the in-progress stroke and the undo/redo history.
class CanvasController extends ChangeNotifier {
  CanvasController({
    required this.template,
    CanvasSnapshot initial = const CanvasSnapshot(),
    this.tool = ToolType.pen,
    this.color = Colors.black,
    this.strokeWidth = 12,
  }) : _current = initial;

  static const int maxHistory = 100;

  /// Logical size every drawing is rasterised at. Stroke geometry is
  /// normalized, so this only affects the resolution of fills and imports.
  static const Size referenceSize = Size(360, 480);

  /// Device-independent oversampling for raster operations.
  static const double rasterPixelRatio = 2;

  CanvasTemplate template;
  ToolType tool;
  Color color;

  /// Stroke width in logical pixels, as shown on the slider.
  double strokeWidth;

  CanvasSnapshot _current;
  final List<CanvasSnapshot> _undo = [];
  final List<CanvasSnapshot> _redo = [];

  Stroke? _active;
  List<Offset>? _activePoints;
  List<double>? _activePressures;

  /// Bumped whenever the committed content changes; used to invalidate the
  /// cached picture of committed strokes.
  int _version = 0;
  ui.Picture? _cachedPicture;
  Size? _cachedSize;
  int _cachedVersion = -1;

  bool _dirty = false;

  bool get dirty => _dirty;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isEmpty => _current.isEmpty && _active == null;

  ui.Image? get background => _current.background;
  List<Stroke> get strokes => _current.strokes;
  Stroke? get activeStroke => _active;
  CanvasSnapshot get snapshot => _current;

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

  // ---------------------------------------------------------------------------
  // Strokes
  // ---------------------------------------------------------------------------

  /// Starts a stroke at [normalized] (0..1 canvas coordinates). [size] is the
  /// on-screen canvas size, used to convert the pixel width to a fraction.
  ///
  /// Pass [pressure] (normalized 0..1) for stylus input to get a
  /// pressure-sensitive stroke; leave it `null` for finger or mouse input.
  void beginStroke(Offset normalized, Size size, {double? pressure}) {
    if (tool == ToolType.fill || size.width <= 0) return;
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
    _commit(CanvasSnapshot(
      background: _current.background,
      strokes: List.unmodifiable([..._current.strokes, committed]),
    ));
  }

  void cancelStroke() {
    _active = null;
    _activePoints = null;
    _activePressures = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  void _commit(CanvasSnapshot next) {
    _undo.add(_current);
    if (_undo.length > maxHistory) _undo.removeAt(0);
    _redo.clear();
    _current = next;
    _version++;
    _dirty = true;
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_current);
    _current = _undo.removeLast();
    _version++;
    _dirty = true;
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_current);
    _current = _redo.removeLast();
    _version++;
    _dirty = true;
    notifyListeners();
  }

  void clear() {
    if (_current.isEmpty) return;
    _commit(const CanvasSnapshot());
  }

  // ---------------------------------------------------------------------------
  // Raster operations
  // ---------------------------------------------------------------------------

  /// Returns a picture of the committed strokes for [size], recording a new
  /// one only when the content or size changed.
  ui.Picture committedPicture(Size size) {
    if (_cachedPicture == null || _cachedSize != size || _cachedVersion != _version) {
      _cachedPicture?.dispose();
      _cachedPicture = recordStrokes(size, _current.strokes);
      _cachedSize = size;
      _cachedVersion = _version;
    }
    return _cachedPicture!;
  }

  /// Renders the current content (optionally with paper and template) into
  /// an image of `size * pixelRatio` pixels.
  Future<ui.Image> rasterize(
    Size size, {
    double pixelRatio = 1,
    bool includePaper = false,
    Color paperColor = Colors.white,
    ui.Image? underlay,
  }) {
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
    paintDrawing(
      canvas,
      size,
      strokes: _current.strokes,
      background: _current.background,
      template: includePaper ? template : CanvasTemplate.blank,
      paperColor: includePaper ? paperColor : null,
    );
    return recorder.endRecording().toImage(width, height);
  }

  /// Exports the drawing as PNG bytes, including paper and template.
  Future<Uint8List> exportPng(Size size, {double pixelRatio = 2, Color paperColor = Colors.white}) async {
    final image = await rasterize(size, pixelRatio: pixelRatio, includePaper: true, paperColor: paperColor);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Flood-fills the region under [normalized] with the current color. The
  /// content is flattened into a raster background first.
  Future<void> fillAt(Offset normalized) async {
    final flattened = await rasterize(referenceSize, pixelRatio: rasterPixelRatio);
    final x = (normalized.dx * flattened.width).floor().clamp(0, flattened.width - 1);
    final y = (normalized.dy * flattened.height).floor().clamp(0, flattened.height - 1);
    final filled = await floodFillImage(flattened, x, y, color);
    flattened.dispose();
    _commit(CanvasSnapshot(background: filled));
  }

  /// Places [image] underneath the existing content (fitted to the canvas)
  /// and flattens everything into the raster background.
  Future<void> importImage(ui.Image image) async {
    final fitted = await _fitImage(image, referenceSize * rasterPixelRatio);
    final flattened = await rasterize(referenceSize, pixelRatio: rasterPixelRatio, underlay: fitted);
    fitted.dispose();
    _commit(CanvasSnapshot(background: flattened));
  }

  Future<ui.Image> _fitImage(ui.Image image, Size size) {
    final width = size.width.round();
    final height = size.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(image.width.toDouble(), image.height.toDouble()),
      size,
    );
    final src = Alignment.center.inscribe(fitted.source, Offset.zero & Size(image.width.toDouble(), image.height.toDouble()));
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.high);
    return recorder.endRecording().toImage(width, height);
  }

  @override
  void dispose() {
    _cachedPicture?.dispose();
    super.dispose();
  }
}
