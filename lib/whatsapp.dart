import "package:share_plus/share_plus.dart";

Future<void> shareToWhatsApp({
  required String message,
  required String imagePath,
}) async {
  final file = XFile(imagePath);
  await Share.shareXFiles([file], text: message);
}
