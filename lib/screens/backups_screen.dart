import "dart:io";
import "package:flutter/material.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "../backup_service.dart";
import "../utils.dart";

class BackupsScreen extends StatefulWidget {
  const BackupsScreen({super.key});

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> {
  bool loading = true;
  List<FileSystemEntity> files = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _backupsDirPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, "backups");
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final dir = Directory(await _backupsDirPath());
    if (!await dir.exists()) {
      setState(() {
        files = [];
        loading = false;
      });
      return;
    }

    final list = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith(".db"))
        .toList();

    list.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {
      files = list;
      loading = false;
    });
  }

  String _fmtTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, "0");
    return "${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}";
  }

  Future<void> _createAndShare({bool share = true}) async {
    try {
      final f = await BackupService.createBackupFile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم إنشاء Backup ✅\n${p.basename(f.path)}")),
      );

      await _load();

      if (share) {
        await BackupService.shareBackup(f, message: "Backup قاعدة بيانات التطبيق");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  Future<void> _restoreFromFile(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("استرجاع Backup"),
        content: const Text("سيتم استبدال بيانات التطبيق الحالية بهذه النسخة. هل أنت متأكد؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("استرجاع")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await BackupService.restoreFromFilePath(path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم الاسترجاع ✅ (يفضّل إعادة فتح التطبيق)")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  Future<void> _importAndRestore() async {
    try {
      await BackupService.restoreFromPicker();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم استيراد واسترجاع النسخة ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Backups"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: "تحديث"),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("اختيارات النسخ الاحتياطي", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _createAndShare(share: true),
                                  icon: const Icon(Icons.backup),
                                  label: const Text("Backup + Share"),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _createAndShare(share: false),
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text("Backup فقط"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _importAndRestore,
                                  icon: const Icon(Icons.file_open),
                                  label: const Text("استيراد Backup (db)"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "ملاحظة: رفع Google Drive يتم يدويًا عبر زر Share ثم تختار Google Drive.",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: files.isEmpty
                      ? const Center(child: Text("لا توجد Backups بعد. اضغط Backup لإنشاء نسخة."))
                      : ListView.separated(
                          itemCount: files.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final f = files[i] as File;
                            final name = p.basename(f.path);
                            final size = f.lengthSync();
                            final dt = f.lastModifiedSync();

                            return ListTile(
                              title: Text(name),
                              subtitle: Text("${_fmtTime(dt)}  •  ${fmtMoney(size / 1024)} KB"),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == "share") {
                                    await BackupService.shareBackup(f, message: "Backup قاعدة بيانات التطبيق");
                                  } else if (v == "restore") {
                                    await _restoreFromFile(f.path);
                                  } else if (v == "delete") {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("حذف Backup"),
                                        content: Text("تأكيد حذف: $name ؟"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
                                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حذف")),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      try {
                                        await f.delete();
                                        await _load();
                                      } catch (_) {}
                                    }
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: "share", child: Text("مشاركة (Drive/WhatsApp)")),
                                  PopupMenuItem(value: "restore", child: Text("استرجاع هذه النسخة")),
                                  PopupMenuDivider(),
                                  PopupMenuItem(value: "delete", child: Text("حذف")),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
