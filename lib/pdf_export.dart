import "dart:io";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:path_provider/path_provider.dart";
import "package:printing/printing.dart";

import "models.dart";
import "utils.dart";

class PdfExporter {
  static Future<void> exportOrderPdf({
    required Customer customer,
    required OrderHeader order,
    required List<OrderItem> items,
  }) async {
    final pdf = pw.Document();

    final confirmed = items.where((e) => e.status == ItemStatus.confirmed).toList();

    final totalRevenue = confirmed.fold<double>(0, (p, e) => p + e.revenueEgp);
    final totalCost = confirmed.fold<double>(0, (p, e) => p + e.costEgp);
    final totalProfit = confirmed.fold<double>(0, (p, e) => p + e.grossProfitEgp);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("ملخص الطلب", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),

                pw.Text("العميل: ${customer.name}"),
                if ((customer.whatsapp ?? "").trim().isNotEmpty) pw.Text("واتساب: ${customer.whatsapp}"),
                pw.Text("رقم الطلب: ${order.id ?? "-"}"),
                pw.SizedBox(height: 10),
                pw.Divider(),

                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        _cell("المنتج"),
                        _cell("إيراد"),
                        _cell("تكلفة"),
                        _cell("ربح"),
                      ],
                    ),
                    ...confirmed.map(
                      (e) => pw.TableRow(
                        children: [
                          _cell(e.note ?? "—"),
                          _cell(fmtMoney(e.revenueEgp)),
                          _cell(fmtMoney(e.costEgp)),
                          _cell(fmtMoney(e.grossProfitEgp)),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Text("إجمالي الإيراد: ${fmtMoney(totalRevenue)} جنيه", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("إجمالي التكلفة: ${fmtMoney(totalCost)} جنيه", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("إجمالي الربح: ${fmtMoney(totalProfit)} جنيه", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );

    // ✅ Save file
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/order_${order.id}.pdf");
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    // ✅ Share PDF (works on Android)
    await Printing.sharePdf(bytes: bytes, filename: "order_${order.id}.pdf");
  }

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, textDirection: pw.TextDirection.rtl),
    );
  }
}
