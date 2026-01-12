import "dart:io";
import "dart:typed_data";
import "package:intl/intl.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

final _moneyFmt = NumberFormat("#,##0.00", "en_US");

String fmtMoney(num v) => _moneyFmt.format(v);

Future<String> saveImageToAppDir(File source) async {
  final dir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory(p.join(dir.path, "images"));
  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }
  final ts = DateTime.now().millisecondsSinceEpoch;
  final ext = p.extension(source.path).isEmpty ? ".jpg" : p.extension(source.path);
  final destPath = p.join(imagesDir.path, "img_$ts$ext");
  await source.copy(destPath);
  return destPath;
}

Future<Uint8List> readBytes(String path) async {
  final f = File(path);
  return f.readAsBytes();
}
