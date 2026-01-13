import "dart:typed_data";
import "package:flutter/services.dart" show rootBundle;
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";
import "package:arabic_reshaper/arabic_reshaper.dart";

import "models.dart";
import "utils.dart";
import "constants.dart";

class PdfExporter {
  static Future<void> _exportPdf() async {
  final o = order;
  final c = customer;
  if (o == null || c == null) return;

  try {
    await PdfExporter.exportOrderPdf(customer: c, order: o, items: items);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF Error: $e")),
      );
    }
  }
}


    // ✅ Load Cairo font
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final cairo = pw.Font.ttf(fontData);
    final theme = pw.ThemeData.withFont(base: cairo);

    final confirmed = items.where((e) => e.status == ItemStatus.confirmed).toList();

    // ✅ preload images
    final Map<int?, Uint8List> images = {};
    for (final it in confirmed) {
      try {
        images[it.id] = await readBytes(it.imagePath);
      } catch (_) {}
    }

    final totalRevenue = confirmed.fold<double>(0, (p, e) => p + e.revenueEgp);
    final totalCost = confirmed.fold<double>(0, (p, e) => p + e.costEgp);
    final totalGross = confirmed.fold<double>(0, (p, e) => p + e.grossProfitEgp);

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(ar("ملخص الطلب"), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),

                pw.Text(ar("العميل: ${customer.name}")),
                if ((customer.whatsapp ?? "").trim().isNotEmpty) pw.Text(ar("واتساب: ${customer.whatsapp}")),
                pw.Text(ar("رقم الطلب: ${order.id ?? "-"}")),
                pw.Text(ar(order.deliveredAt == null ? "الحالة: غير مُسلّم" : "الحالة: مُسلّم ✅")),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 6),

                ...confirmed.map((it) => _itemBlock(it, images[it.id])),

                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 6),

                pw.Text(ar("الإجماليات"), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(ar("إيراد: ${fmtMoney(totalRevenue)} ${AppConstants.currencyEgp}")),
                pw.Text(ar("تكلفة: ${fmtMoney(totalCost)} ${AppConstants.currencyEgp}")),
                pw.Text(
                  ar("ربح إجمالي: ${fmtMoney(totalGross)} ${AppConstants.currencyEgp}"),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: "order_${order.id}.pdf");
  }

  static pw.Widget _itemBlock(OrderItem it, Uint8List? imgBytes) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 90,
              height: 90,
              child: imgBytes == null
                  ? pw.Container(color: PdfColors.grey200)
                  : pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if ((it.note ?? "").trim().isNotEmpty)
                    pw.Text(ar(it.note!), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),

                  pw.Text(ar("سعر الشراء (ريال): ${it.buyPriceSar}")),
                  pw.Text(ar("سعر البيع (ريال): ${it.priceSar}")),
                  pw.Text(ar("سعر الريال (جنيه): ${it.rateEgp}")),
                  pw.Text(ar("ربح إضافي/قطعة: ${it.profitEgp} جنيه")),
                  pw.Text(ar("الكمية: ${it.qty ?? 0}")),
                  pw.SizedBox(height: 4),

                  pw.Text(ar("إيراد الصنف: ${fmtMoney(it.revenueEgp)} ${AppConstants.currencyEgp}")),
                  pw.Text(ar("تكلفة الصنف: ${fmtMoney(it.costEgp)} ${AppConstants.currencyEgp}")),
                  pw.Text(
                    ar("الربح الإجمالي: ${fmtMoney(it.grossProfitEgp)} ${AppConstants.currencyEgp}"),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Arabic shaping + (fallback RTL) without bidi package
  static String ar(String input) {
    final reshaped = ArabicReshaper().reshape(input);
    // fallback: reverse to make pdf render correctly in many cases
    return reshaped.split("").reversed.join();
  }
}
