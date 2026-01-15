// lib/statement_export.dart
import "dart:io";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

class StatementExporter {
  static String _fmtMoney(num v) => v.toDouble().toStringAsFixed(2);

  static String _fmtDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return "${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}";
  }

  static double _balanceDelta(String type, double amount) {
    // balance = debit - credit
    // debit: +amount
    // credit: -amount
    // cash: delta = -amount (cash + reduces balance, cash - increases balance)
    switch (type) {
      case "order":
      case "expense":
        return amount;
      case "payment":
        return -amount;
      case "cash":
        return -amount;
      default:
        return 0;
    }
  }

  static String _typeLabel(String type) {
    switch (type) {
      case "order":
        return "أوردر";
      case "payment":
        return "دفعة";
      case "expense":
        return "مصروف";
      case "cash":
        return "خزنة";
      default:
        return "حركة";
    }
  }

  static String _titleFor(Map<String, Object?> r) {
    final type = (r["type"] as String?) ?? "";
    final orderId = r["order_id"];
    final amount = (r["amount"] as double?) ?? 0;

    switch (type) {
      case "order":
        return "أوردر مُسلّم #$orderId";
      case "payment":
        return "دفعة ${orderId == null ? "(تحت الحساب)" : "على أوردر #$orderId"}";
      case "expense":
        return "مصروف ${orderId == null ? "" : "(أوردر #$orderId)"}";
      case "cash":
        return "حركة خزنة ${amount >= 0 ? "(دخل)" : "(صرف)"} ${orderId == null ? "" : "— أوردر #$orderId"}";
      default:
        return "حركة";
    }
  }

  static String _escapeHtml(String s) {
    return s
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#39;");
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
      final type = (r["type"] as String?) ?? "";
      final ms = (r["created_at"] as int?) ?? 0;
      final orderId = r["order_id"];
      final amount = (r["amount"] as double?) ?? 0;
      final note = ((r["note"] ?? "") as String).trim();

      running += _balanceDelta(type, amount);

      final title = _titleFor(r);
      final typeLbl = _typeLabel(type);

      final orderStr = (orderId == null) ? "-" : orderId.toString();

      // Display sign:
      // - for cash, show natural sign (+/-)
      // - for others: debit + , credit -
      String amountStr;
      if (type == "cash") {
        amountStr = "${amount >= 0 ? "+" : "-"}${_fmtMoney(amount.abs())}";
      } else if (type == "order" || type == "expense") {
        amountStr = "+${_fmtMoney(amount)}";
      } else {
        amountStr = "-${_fmtMoney(amount)}";
      }

      rows.add("""
<tr>
  <td>${_fmtDateTime(ms)}</td>
  <td>${_escapeHtml(typeLbl)}</td>
  <td>${_escapeHtml(orderStr)}</td>
  <td>${_escapeHtml(title)}</td>
  <td>${_escapeHtml(note)}</td>
  <td style="text-align:right;">$amountStr</td>
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
  <title>كشف حساب - ${_escapeHtml(customerName)}</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 16px; }
    h2 { margin: 0 0 8px 0; }
    .summary { margin: 12px 0; padding: 12px; border: 1px solid #ddd; border-radius: 10px; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; }
    th, td { border: 1px solid #ddd; padding: 8px; vertical-align: top; }
    th { background: #f6f6f6; }
    .muted { color: #666; font-size: 12px; }
    .right { text-align: right; }
  </style>
</head>
<body>
  <h2>كشف حساب: ${_escapeHtml(customerName)}</h2>
  <div class="muted">تاريخ التصدير: ${_fmtDateTime(DateTime.now().millisecondsSinceEpoch)}</div>

  <div class="summary">
    <div>إجمالي مدين: <b>${_fmtMoney(debit)} EGP</b></div>
    <div>إجمالي دائن: <b>${_fmtMoney(credit)} EGP</b></div>
    <div style="margin-top:8px;">الرصيد: <b>${_fmtMoney(balance)} EGP</b></div>
  </div>

  <table>
    <thead>
      <tr>
        <th>التاريخ</th>
        <th>النوع</th>
        <th>رقم الأوردر</th>
        <th>الوصف</th>
        <th>ملاحظة</th>
        <th class="right">المبلغ</th>
        <th class="right">الرصيد بعد الحركة</th>
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
