import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/drawing.dart';
import '../models/stroke.dart';

/// A fully loaded drawing, ready to be edited.
class DrawingDocument {
  const DrawingDocument({required this.meta, required this.strokes, this.background});

  final DrawingMeta meta;
  final List<Stroke> strokes;
  final ui.Image? background;
}

/// Stores drawings on disk. Each drawing lives in its own folder:
///
/// ```
/// <documents>/drawings/<id>/meta.json     metadata
/// <documents>/drawings/<id>/strokes.json  vector strokes
/// <documents>/drawings/<id>/bg.png        optional raster background
/// <documents>/drawings/<id>/thumb.png     preview used in lists
/// ```
class DrawingRepository extends ChangeNotifier {
  Directory? _root;
  final Map<String, DrawingMeta> _items = {};

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
      final docs = await getApplicationDocumentsDirectory();
      final root = Directory('${docs.path}/drawings');
      if (!await root.exists()) await root.create(recursive: true);
      _root = root;
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
    } catch (_) {
      // Without storage the app still works, it just cannot persist.
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
    var strokes = const <Stroke>[];
    final strokesFile = File('${dir.path}/strokes.json');
    if (await strokesFile.exists()) {
      final list = jsonDecode(await strokesFile.readAsString()) as List<dynamic>;
      strokes = [for (final s in list) Stroke.fromJson(s as Map<String, dynamic>)];
    }
    ui.Image? background;
    final bgFile = File('${dir.path}/bg.png');
    if (await bgFile.exists()) {
      background = await decodeImageFromList(await bgFile.readAsBytes());
    }
    return DrawingDocument(meta: meta, strokes: strokes, background: background);
  }

  /// Creates or updates a drawing and returns its metadata.
  Future<DrawingMeta> save({
    String? id,
    required String name,
    required CanvasTemplate template,
    required List<Stroke> strokes,
    ui.Image? background,
    required Uint8List thumbnailPng,
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
      strokeCount: strokes.length,
      hasBackground: background != null,
    );

    final dir = _dir(meta.id);
    if (!await dir.exists()) await dir.create(recursive: true);

    await File('${dir.path}/strokes.json')
        .writeAsString(jsonEncode([for (final s in strokes) s.toJson()]));

    final bgFile = File('${dir.path}/bg.png');
    if (background != null) {
      final bytes = await background.toByteData(format: ui.ImageByteFormat.png);
      await bgFile.writeAsBytes(bytes!.buffer.asUint8List());
    } else if (await bgFile.exists()) {
      await bgFile.delete();
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
