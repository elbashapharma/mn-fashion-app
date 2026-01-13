import "dart:io";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:path_provider/path_provider.dart";
import "package:open_file/open_file.dart";
import "models.dart";
import "utils.dart";

class PdfExporter {
  static Future<void> exportOrderPdf({
    required Customer customer,
    required OrderHeader order,
    required List<OrderItem> items,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "كشف طلب",
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),

                  pw.Text("العميل: ${customer.name}"),
                  if ((customer.whatsapp ?? "").isNotEmpty)
                    pw.Text("واتساب: ${customer.whatsapp}"),

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
                          _cell("بيع"),
                          _cell("تكلفة"),
                          _cell("ربح"),
                        ],
                      ),
                      ...items
                          .where((e) => e.status == ItemStatus.confirmed)
                          .map(
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

                  pw.SizedBox(height: 12),
                  pw.Divider(),

                  pw.Text(
                    "إجمالي الإيراد: ${fmtMoney(
                      items.fold<double>(
                        0,
                        (p, e) => p + (e.status == ItemStatus.confirmed ? e.revenueEgp : 0),
                      ),
                    )} جنيه",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),

                  pw.Text(
                    "إجمالي الربح: ${fmtMoney(
                      items.fold<double>(
                        0,
                        (p, e) => p + (e.status == ItemStatus.confirmed ? e.grossProfitEgp : 0),
                      ),
                    )} جنيه",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/order_${order.id}.pdf");
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  static pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, textDirection: pw.TextDirection.rtl),
    );
  }
}
