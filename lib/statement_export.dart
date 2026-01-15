import "dart:io";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

class StatementExporter {
  static String _fmtMoney(num v) {
    // نفس فكرة fmtMoney لكن بدون import utils لتفادي dependencies
    final x = v.toDouble();
    return x.toStringAsFixed(2);
  }

  static String _fmtDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return "${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}";
  }

  static Future<String> exportHtml({
    required String customerName,
    required List<Map<String, Object?>> ledger,
    required double debit,
    required double credit,
    required double balance,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = "statement_${DateTime.now().millisecondsSinceEpoch}.html";
    final filePath = p.join(dir.path, fileName);

    double running = 0;

    final rows = <String>[];
    for (final r in ledger) {
      final type = (r["type"] as String);
      final ms = (r["created_at"] as int);
      final orderId = r["order_id"];
      final amount = (r["amount"] as double);
      final note = (r["note"] ?? "") as String;

      final isDebit = type == "order";
      running += isDebit ? amount : -amount;

      final title = isDebit
          ? "أوردر مُسلّم #$orderId"
          : "دفعة ${orderId == null ? "(تحت الحساب)" : "على أوردر #$orderId"}";

      rows.add("""
        <tr>
          <td>${_fmtDateTime(ms)}</td>
          <td>$title</td>
          <td>${note.replaceAll("<", "&lt;").replaceAll(">", "&gt;")}</td>
          <td style="text-align:right;">${isDebit ? "+" : "-"}${_fmtMoney(amount)}</td>
          <td style="text-align:right;">${_fmtMoney(running)}</td>
        </tr>
      """);
    }

    final html = """
<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>كشف حساب - $customerName</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 16px; }
    h2 { margin: 0 0 8px 0; }
    .summary { margin: 12px 0; padding: 12px; border: 1px solid #ddd; border-radius: 10px; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; }
    th, td { border: 1px solid #ddd; padding: 8px; vertical-align: top; }
    th { background: #f6f6f6; }
    .muted { color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <h2>كشف حساب: $customerName</h2>
  <div class="muted">تاريخ التصدير: ${_fmtDateTime(DateTime.now().millisecondsSinceEpoch)}</div>

  <div class="summary">
    <div>إجمالي مدين (طلبات مُسلّمة): <b>${_fmtMoney(debit)} EGP</b></div>
    <div>إجمالي دائن (مدفوعات): <b>${_fmtMoney(credit)} EGP</b></div>
    <div style="margin-top:8px;">الرصيد: <b>${_fmtMoney(balance)} EGP</b></div>
  </div>

  <table>
    <thead>
      <tr>
        <th>التاريخ</th>
        <th>الحركة</th>
        <th>ملاحظة</th>
        <th>المبلغ</th>
        <th>الرصيد بعد الحركة</th>
      </tr>
    </thead>
    <tbody>
      ${rows.join("\n")}
    </tbody>
  </table>
</body>
</html>
""";

    await File(filePath).writeAsString(html, flush: true);
    return filePath;
  }

  static Future<void> shareFile(String path, {String? message}) async {
    await Share.shareXFiles([XFile(path)], text: message);
  }
}
