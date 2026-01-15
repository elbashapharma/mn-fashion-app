import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

import "models.dart";

class OrderExporter {
  static String _fmtMoney(num v) => v.toDouble().toStringAsFixed(2);

  static String _escapeHtml(String s) {
    return s
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#39;");
  }

  static String _shipLabel(ShippingType s) => (s == ShippingType.air) ? "جوي" : "بري";

  static String _mimeFromPath(String path) {
    final x = path.toLowerCase();
    if (x.endsWith(".png")) return "image/png";
    if (x.endsWith(".webp")) return "image/webp";
    return "image/jpeg";
  }

  static Future<String> _imgDataUri(String filePath) async {
    try {
      final f = File(filePath);
      if (!await f.exists()) return "";
      final bytes = await f.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = _mimeFromPath(filePath);
      return "data:$mime;base64,$b64";
    } catch (_) {
      return "";
    }
  }

  static Future<String> _imgCellHtml(String filePath) async {
    final uri = await _imgDataUri(filePath);
    if (uri.isEmpty) {
      return "<div style='color:#999;font-size:12px'>لا توجد صورة</div>";
    }
    return "<img src='$uri' style='width:80px;height:80px;object-fit:cover;border-radius:8px;border:1px solid #ddd;' />";
  }

  // ✅ إجماليات العميل: مؤكد / معلق / الكل
  static Map<String, double> _calcTotals(List<OrderItem> items) {
    double confirmed = 0;
    double pending = 0;

    for (final it in items) {
      final qty = (it.qty ?? 0);
      final unitSellEgp = (it.priceSar * it.rateEgp) + it.profitEgp;
      final lineTotalEgp = unitSellEgp * qty;

      if (it.status == ItemStatus.confirmed) {
        confirmed += lineTotalEgp;
      } else if (it.status == ItemStatus.pending) {
        pending += lineTotalEgp;
      }
    }

    return {
      "confirmed": confirmed,
      "pending": pending,
      "all": confirmed + pending,
    };
  }

  static Future<String> exportOrderHtml({
    required Customer customer,
    required OrderHeader order,
    required List<OrderItem> items,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = "order_${order.id}_${DateTime.now().millisecondsSinceEpoch}.html";
    final filePath = p.join(dir.path, fileName);

    final wa = (customer.whatsapp ?? "").trim();
    final addr = (customer.deliveryAddress ?? "").trim();

    final totals = _calcTotals(items);

    // ✅ جدول العميل: صورة + وصف + شحن + مقاس + كمية + سعر بيع + إجمالي
    final rows = <String>[];
    for (final it in items) {
      final qty = (it.qty ?? 0);
      final unitSellEgp = (it.priceSar * it.rateEgp) + it.profitEgp;
      final lineTotalEgp = unitSellEgp * qty;

      final imgCell = await _imgCellHtml(it.imagePath);

      rows.add("""
<tr>
  <td>$imgCell</td>
  <td>${it.id ?? "-"}</td>
  <td>${_escapeHtml(it.note ?? "")}</td>
  <td>${_escapeHtml(_shipLabel(it.shipping))}</td>
  <td>${_escapeHtml(it.size ?? "-")}</td>
  <td style="text-align:right;">$qty</td>
  <td style="text-align:right;">${_fmtMoney(unitSellEgp)}</td>
  <td style="text-align:right;">${_fmtMoney(lineTotalEgp)}</td>
  <td>${it.status == ItemStatus.confirmed ? "مؤكد" : (it.status == ItemStatus.pending ? "معلق" : "ملغي")}</td>
</tr>
""");
    }

    final html = """
<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>أمر بيع #${order.id}</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 16px; }
    h2 { margin: 0 0 8px 0; }
    .muted { color:#666; font-size:12px; }
    .box { border:1px solid #ddd; border-radius:10px; padding:12px; margin:12px 0; }
    table { width:100%; border-collapse:collapse; margin-top:12px; }
    th, td { border:1px solid #ddd; padding:8px; vertical-align:top; }
    th { background:#f6f6f6; }
    .right { text-align:right; }
  </style>
</head>
<body>
  <h2>أمر بيع (طلب) #${order.id}</h2>

  <div class="box">
    <div><b>العميل:</b> ${_escapeHtml(customer.name)}</div>
    ${wa.isEmpty ? "" : "<div><b>واتساب:</b> ${_escapeHtml(wa)}</div>"}
    ${addr.isEmpty ? "" : "<div><b>عنوان التسليم:</b> ${_escapeHtml(addr)}</div>"}
  </div>

  <div class="box">
    <div><b>إجمالي المؤكد:</b> ${_fmtMoney(totals["confirmed"]!)} EGP</div>
    <div><b>إجمالي المعلق:</b> ${_fmtMoney(totals["pending"]!)} EGP</div>
    <hr/>
    <div style="font-size:18px;"><b>إجمالي الطلب:</b> ${_fmtMoney(totals["all"]!)} EGP</div>
    <div class="muted">* الإجماليات محسوبة على آخر طلب (هذا الطلب) حسب حالة كل منتج</div>
  </div>

  <table>
    <thead>
      <tr>
        <th>الصورة</th>
        <th>#</th>
        <th>المنتج</th>
        <th>الشحن</th>
        <th>المقاس</th>
        <th class="right">الكمية</th>
        <th class="right">سعر القطعة EGP</th>
        <th class="right">إجمالي السطر EGP</th>
        <th>الحالة</th>
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
