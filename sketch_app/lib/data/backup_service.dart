import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'drawing_repository.dart';

/// Moves the whole library between devices as a single `.sketchbackup`
/// file (a zip of the drawings folder). Works offline and with any file
/// transfer: AirDrop, Drive, email, cables.
class BackupService {
  BackupService(this._repository);

  final DrawingRepository _repository;

  static const String extension = 'sketchbackup';

  /// Zips every drawing into bytes.
  Future<Uint8List> createArchive() async {
    final root = _repository.rootDirectory;
    if (root == null) throw StateError('Storage is not available');
    final archive = Archive();
    await for (final entry in root.list(recursive: true)) {
      if (entry is! File) continue;
      final relative = entry.path.substring(root.path.length + 1).replaceAll('\\', '/');
      archive.addFile(ArchiveFile.bytes(relative, await entry.readAsBytes()));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Restores drawings from archive bytes. Existing drawings with the same
  /// id are overwritten. Returns how many drawings were imported.
  Future<int> restoreArchive(Uint8List bytes) async {
    final root = _repository.rootDirectory;
    if (root == null) throw StateError('Storage is not available');
    final archive = ZipDecoder().decodeBytes(bytes);
    final ids = <String>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final parts = file.name.split('/');
      // Only accept <id>/<file> entries; anything else is not ours.
      if (parts.length != 2 || parts.any((p) => p.isEmpty || p == '..')) continue;
      final target = File('${root.path}/${parts[0]}/${parts[1]}');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(file.readBytes() ?? Uint8List(0));
      ids.add(parts[0]);
    }
    await _repository.reload();
    return ids.length;
  }

  /// Creates a backup file and opens the share sheet for it.
  Future<void> exportAndShare() async {
    final bytes = await createArchive();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/sketch-backup-$stamp.$extension');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/zip')],
      text: 'Sketch backup',
    ));
  }

  /// Lets the user pick a backup file and restores it. Returns the number of
  /// drawings imported, or `null` when cancelled.
  Future<int?> pickAndRestore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    final picked = result?.files.firstOrNull;
    if (picked == null) return null;
    final bytes = picked.bytes ?? (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) throw StateError('Could not read the selected file');
    return restoreArchive(bytes);
  }
}
