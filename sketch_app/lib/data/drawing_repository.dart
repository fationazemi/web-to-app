import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/drawing.dart';
import '../models/layer.dart';
import '../models/stroke.dart';

/// A fully loaded drawing, ready to be edited.
class DrawingDocument {
  const DrawingDocument({required this.meta, required this.layers});

  final DrawingMeta meta;
  final List<Layer> layers;
}

/// Stores drawings on disk. Each drawing lives in its own folder:
///
/// ```
/// <documents>/drawings/<id>/meta.json       metadata
/// <documents>/drawings/<id>/layers.json     layers with their vector strokes
/// <documents>/drawings/<id>/bg_<layer>.png  optional raster background per layer
/// <documents>/drawings/<id>/thumb.png       preview used in lists
/// ```
///
/// Drawings saved by 1.0 (a single `strokes.json` + `bg.png`) still open;
/// they are migrated to a single layer on the next save.
class DrawingRepository extends ChangeNotifier {
  /// Pass [root] to store drawings somewhere specific (tests, custom
  /// locations); otherwise the app documents directory is used.
  // ignore: prefer_initializing_formals
  DrawingRepository({Directory? root}) : _root = root;

  Directory? _root;
  final Map<String, DrawingMeta> _items = {};

  /// Where drawings live, `null` when storage is unavailable.
  Directory? get rootDirectory => _root;

  /// All drawings, most recently updated first.
  List<DrawingMeta> get drawings {
    final list = _items.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(list);
  }

  int get count => _items.length;

  DrawingMeta? byId(String id) => _items[id];

  Future<void> load() async {
    try {
      final root = _root ?? Directory('${(await getApplicationDocumentsDirectory()).path}/drawings');
      if (!await root.exists()) await root.create(recursive: true);
      _root = root;
      await reload();
      return;
    } catch (_) {
      // Without storage the app still works, it just cannot persist.
    }
    notifyListeners();
  }

  /// Re-reads every drawing folder from disk.
  Future<void> reload() async {
    final root = _root;
    if (root == null) return;
    _items.clear();
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final metaFile = File('${entry.path}/meta.json');
      if (!await metaFile.exists()) continue;
      try {
        final json = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        final meta = DrawingMeta.fromJson(json);
        _items[meta.id] = meta;
      } catch (_) {
        // Skip unreadable entries rather than failing the whole list.
      }
    }
    notifyListeners();
  }

  Directory _dir(String id) => Directory('${_root!.path}/$id');

  File thumbnailFile(String id) => File('${_dir(id).path}/thumb.png');

  Future<DrawingDocument> open(String id) async {
    final meta = _items[id];
    if (meta == null || _root == null) {
      throw StateError('Drawing $id does not exist');
    }
    final dir = _dir(id);
    final layersFile = File('${dir.path}/layers.json');
    final layers = <Layer>[];
    if (await layersFile.exists()) {
      final list = jsonDecode(await layersFile.readAsString()) as List<dynamic>;
      for (final raw in list) {
        final json = raw as Map<String, dynamic>;
        ui.Image? background;
        if (json['hasBackground'] == true) {
          final bgFile = File('${dir.path}/bg_${json['id']}.png');
          if (await bgFile.exists()) background = await decodeImageFromList(await bgFile.readAsBytes());
        }
        layers.add(Layer.fromJson(json, background: background));
      }
    } else {
      // Legacy single-layer format.
      var strokes = const <Stroke>[];
      final strokesFile = File('${dir.path}/strokes.json');
      if (await strokesFile.exists()) {
        final list = jsonDecode(await strokesFile.readAsString()) as List<dynamic>;
        strokes = [for (final s in list) Stroke.fromJson(s as Map<String, dynamic>)];
      }
      ui.Image? background;
      final bgFile = File('${dir.path}/bg.png');
      if (await bgFile.exists()) background = await decodeImageFromList(await bgFile.readAsBytes());
      layers.add(Layer(id: Layer.newId(), name: 'Layer 1', strokes: strokes, background: background));
    }
    if (layers.isEmpty) layers.add(Layer(id: Layer.newId(), name: 'Layer 1'));
    return DrawingDocument(meta: meta, layers: layers);
  }

  /// Creates or updates a drawing and returns its metadata.
  Future<DrawingMeta> save({
    String? id,
    required String name,
    required CanvasTemplate template,
    required List<Layer> layers,
    required Uint8List thumbnailPng,
    int? paperColor,
    DateTime? timestamp,
  }) async {
    final root = _root;
    if (root == null) throw StateError('Storage is not available');

    final now = timestamp ?? DateTime.now();
    final existing = id == null ? null : _items[id];
    final meta = DrawingMeta(
      id: existing?.id ?? now.microsecondsSinceEpoch.toRadixString(36),
      name: name.trim().isEmpty ? 'Untitled' : name.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      template: template,
      strokeCount: layers.fold(0, (n, l) => n + l.strokes.length),
      hasBackground: layers.any((l) => l.background != null),
      layerCount: layers.length,
      paperColor: paperColor,
    );

    final dir = _dir(meta.id);
    if (!await dir.exists()) await dir.create(recursive: true);

    await File('${dir.path}/layers.json')
        .writeAsString(jsonEncode([for (final l in layers) l.toJson()]));

    // Write current backgrounds, drop stale ones (and legacy files).
    final keep = <String>{};
    for (final layer in layers) {
      final bg = layer.background;
      if (bg == null) continue;
      final file = File('${dir.path}/bg_${layer.id}.png');
      keep.add(file.path);
      final bytes = await bg.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    }
    await for (final entry in dir.list()) {
      final name = entry.uri.pathSegments.last;
      final stale = (name.startsWith('bg_') && !keep.contains(entry.path)) || name == 'bg.png' || name == 'strokes.json';
      if (entry is File && stale) await entry.delete();
    }

    final thumb = thumbnailFile(meta.id);
    await thumb.writeAsBytes(thumbnailPng);
    // The path is reused across saves, so drop any cached decode of it.
    PaintingBinding.instance.imageCache.evict(FileImage(thumb));

    await File('${dir.path}/meta.json').writeAsString(jsonEncode(meta.toJson()));
    _items[meta.id] = meta;
    notifyListeners();
    return meta;
  }

  Future<void> rename(String id, String name) async {
    final meta = _items[id];
    if (meta == null) return;
    final updated = meta.copyWith(name: name.trim().isEmpty ? meta.name : name.trim());
    await File('${_dir(id).path}/meta.json').writeAsString(jsonEncode(updated.toJson()));
    _items[id] = updated;
    notifyListeners();
  }

  /// Copies a drawing (layers, backgrounds and thumbnail) under a new id.
  Future<DrawingMeta?> duplicate(String id) async {
    final source = _items[id];
    if (source == null || _root == null) return null;
    final now = DateTime.now();
    final copy = source.copyWith(name: '${source.name} copy', updatedAt: now);
    final copyMeta = DrawingMeta(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      name: copy.name,
      createdAt: now,
      updatedAt: now,
      template: copy.template,
      strokeCount: copy.strokeCount,
      hasBackground: copy.hasBackground,
      layerCount: copy.layerCount,
      paperColor: copy.paperColor,
    );
    final from = _dir(id);
    final to = _dir(copyMeta.id);
    await to.create(recursive: true);
    await for (final entry in from.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (name == 'meta.json') continue;
      await entry.copy('${to.path}/$name');
    }
    await File('${to.path}/meta.json').writeAsString(jsonEncode(copyMeta.toJson()));
    _items[copyMeta.id] = copyMeta;
    notifyListeners();
    return copyMeta;
  }

  Future<void> delete(String id) async {
    _items.remove(id);
    notifyListeners();
    final dir = _dir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> deleteAll() async {
    final ids = _items.keys.toList();
    for (final id in ids) {
      await delete(id);
    }
  }
}
