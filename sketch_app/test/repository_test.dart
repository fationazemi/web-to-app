import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sketch/data/backup_service.dart';
import 'package:sketch/data/drawing_repository.dart';
import 'package:sketch/models/layer.dart';
import 'package:sketch/models/stroke.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late DrawingRepository repo;

  final thumb = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]);
  const stroke = Stroke(tool: ToolType.pen, color: Color(0xFF123456), width: 0.02, points: [Offset(0.1, 0.1), Offset(0.5, 0.5)]);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sketch_repo_');
    repo = DrawingRepository(root: Directory('${temp.path}/drawings'));
    await repo.load();
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('save, open, rename, duplicate and delete', () async {
    final layers = [
      Layer(id: 'l1', name: 'Base', strokes: const [stroke]),
      Layer(id: 'l2', name: 'Top', opacity: 0.5, visible: false),
    ];
    final meta = await repo.save(name: 'Test', template: CanvasTemplate.grid, layers: layers, thumbnailPng: thumb, paperColor: 0xFF111111);
    expect(repo.count, 1);
    expect(meta.layerCount, 2);
    expect(meta.strokeCount, 1);
    expect(meta.paperColor, 0xFF111111);

    final doc = await repo.open(meta.id);
    expect(doc.layers, hasLength(2));
    expect(doc.layers[0].strokes.single.color, const Color(0xFF123456));
    expect(doc.layers[1].opacity, 0.5);
    expect(doc.layers[1].visible, isFalse);
    expect(await repo.thumbnailFile(meta.id).exists(), isTrue);

    await repo.rename(meta.id, 'Renamed');
    expect(repo.byId(meta.id)!.name, 'Renamed');

    final copy = await repo.duplicate(meta.id);
    expect(copy, isNotNull);
    expect(repo.count, 2);
    expect((await repo.open(copy!.id)).layers, hasLength(2));

    await repo.delete(meta.id);
    expect(repo.count, 1);
    expect(await Directory('${temp.path}/drawings/${meta.id}').exists(), isFalse);
  });

  test('legacy single-layer drawings still open', () async {
    final dir = Directory('${temp.path}/drawings/old')..createSync(recursive: true);
    File('${dir.path}/meta.json').writeAsStringSync(
        '{"id":"old","name":"Old","createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-01T00:00:00.000","template":"blank","strokeCount":1,"hasBackground":false}');
    File('${dir.path}/strokes.json').writeAsStringSync('[{"tool":"pen","color":4278190080,"width":0.02,"points":[0.1,0.1,0.2,0.2]}]');
    await repo.reload();
    final doc = await repo.open('old');
    expect(doc.layers, hasLength(1));
    expect(doc.layers.single.strokes, hasLength(1));
  });

  test('backup archive round trip', () async {
    await repo.save(name: 'A', template: CanvasTemplate.blank, layers: [Layer(id: 'x', name: 'L', strokes: const [stroke])], thumbnailPng: thumb);
    await repo.save(name: 'B', template: CanvasTemplate.dots, layers: [Layer(id: 'y', name: 'L')], thumbnailPng: thumb);
    final backup = BackupService(repo);
    final bytes = await backup.createArchive();
    expect(bytes, isNotEmpty);

    await repo.deleteAll();
    expect(repo.count, 0);

    final restored = await backup.restoreArchive(bytes);
    expect(restored, 2);
    expect(repo.count, 2);
    expect(repo.drawings.map((d) => d.name), containsAll(['A', 'B']));
  });
}
