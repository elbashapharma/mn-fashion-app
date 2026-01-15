import "dart:io";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";
import "package:file_picker/file_picker.dart";
import "package:shared_preferences/shared_preferences.dart";

import "db.dart";

class BackupService {
  static const _kLastAutoBackupMs = "last_auto_backup_ms";
  static const _keepMax = 7;

  static Future<String> _backupsDirPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, "backups");
  }

  static String _tsName() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return "shein_pricing_backup_$ms.db";
  }

  static Future<File> createBackupFile() async {
    // تأكد DB متفتح
    await AppDb.instance.db;

    final srcPath = await AppDb.instance.getDbFilePath();
    final src = File(srcPath);
    if (!await src.exists()) {
      throw Exception("ملف الداتا غير موجود");
    }

    final backupsDir = await _backupsDirPath();
    await Directory(backupsDir).create(recursive: true);

    final outPath = p.join(backupsDir, _tsName());
    final out = await src.copy(outPath);

    await _cleanupOldBackups();
    return out;
  }

  static Future<void> shareBackup(File file, {String? message}) async {
    await Share.shareXFiles([XFile(file.path)], text: message);
  }

  static Future<File?> latestBackup() async {
    final dir = Directory(await _backupsDirPath());
    if (!await dir.exists()) return null;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith(".db"))
        .toList();

    if (files.isEmpty) return null;

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.first;
  }

  static Future<void> restoreFromPicker() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["db"],
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;

    final path = res.files.single.path;
    if (path == null) throw Exception("لم يتم اختيار ملف");

    await AppDb.instance.restoreFromFile(path);
  }

  static Future<void> restoreFromFilePath(String path) async {
    await AppDb.instance.restoreFromFile(path);
  }

  static Future<void> autoBackupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastAutoBackupMs) ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final dayMs = 24 * 60 * 60 * 1000;

    if (now - lastMs < dayMs) return;

    await createBackupFile();
    await prefs.setInt(_kLastAutoBackupMs, now);
  }

  static Future<void> _cleanupOldBackups() async {
    final dir = Directory(await _backupsDirPath());
    if (!await dir.exists()) return;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith(".db"))
        .toList();

    if (files.length <= _keepMax) return;

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())); // newest first
    final toDelete = files.sublist(_keepMax);

    for (final f in toDelete) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}
