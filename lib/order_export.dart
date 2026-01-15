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
  static String _statusLabel(ItemStatus s) {
    switch (s) {
      case ItemStatus.confirmed:
        return "مؤكد";
      case ItemStatus.cancelled:
        return "ملغي";
      default:
        return "معلق";
    }
  }

  static Future<String> exportOrderHtml({
    required Customer customer,
    required OrderHeader order,
    required List<OrderItem> items,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = "order_${order.id}_${DateTime.now().millisecondsSinceEpoch}.html";
    final filePath = p.join(dir.path, fileName);

    // totals (confirmed only)
    final confirmed = items.where((e) => e.status == ItemStatus.confirmed).toList();
    final totalRevenue = confirmed.fold<double>(0, (p, e) => p + e.revenueEgp);
    final totalCost = confirmed.fold<double>(0, (p, e) => p + e.costEgp);
    final totalGross = confirmed.fold<double>(0, (p, e) => p + e.grossProfitEgp);

    final rows = <String>[];
    for (final it in items) {
      final qty = (it.qty ?? 0);
      final unitSell = (it.priceSar * it.rateEgp) + it.profitEgp;
      final lineTotal = unitSell * qty;

      rows.add("""
<tr>
  <td>${it.id ?? "-"}</td>
  <td>${_escapeHtml(it.note ?? "")}</td>
  <td>${_escapeHtml(_statusLabel(it.status))}</td>
  <td>${_escapeHtml(_shipLabel(it.shipping))}</td>
  <td>${_escapeHtml(it.size ?? "-")}</td>
  <td style="text-align:right;">${qty}</td>
  <td style="text-align:right;">${_fmtMoney(it.buyPriceSar)}</td>
  <td style="text-align:right;">${_fmtMoney(it.priceSar)}</td>
  <td style="text-align:right;">${_fmtMoney(it.rateEgp)}</td>
  <td style="text-align:right;">${_fmtMoney(it.profitEgp)}</td>
  <td style="text-align:right;">${_fmtMoney(unitSell)}</td>
  <td style="text-align:right;">${_fmtMoney(lineTotal)}</td>
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
  <div class="muted">العميل: ${_escapeHtml(customer.name)} ${_escapeHtml((customer.whatsapp ?? "").isEmpty ? "" : "— واتساب: ${customer.whatsapp}")}</div>
  ${((customer.deliveryAddress ?? "").trim().isEmpty) ? "" : '<div class="muted">العنوان: ${_escapeHtml(customer.deliveryAddress!)} </div>'}
  <div class="box">
    <div>سعر الريال الافتراضي: <b>${_fmtMoney(order.defaultRate)}</b></div>
    <div>الحالة: <b>${order.deliveredAt == null ? "غير مُسلّم" : "مُسلّم ✅"}</b></div>
  </div>

  <div class="box">
    <div><b>إجماليات (المؤكد فقط)</b></div>
    <div>إيراد: ${_fmtMoney(totalRevenue)} EGP</div>
    <div>تكلفة: ${_fmtMoney(totalCost)} EGP</div>
    <div><b>ربح إجمالي: ${_fmtMoney(totalGross)} EGP</b></div>
  </div>

  <table>
    <thead>
      <tr>
        <th>#</th>
        <th>ملاحظة</th>
        <th>الحالة</th>
        <th>الشحن</th>
        <th>المقاس</th>
        <th class="right">الكمية</th>
        <th class="right">شراء SAR</th>
        <th class="right">بيع SAR</th>
        <th class="right">الريال EGP</th>
        <th class="right">ربح/قطعة</th>
        <th class="right">سعر/قطعة EGP</th>
        <th class="right">إجمالي السطر EGP</th>
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
