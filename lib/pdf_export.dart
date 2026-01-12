import "dart:typed_data";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";
import "models.dart";
import "utils.dart";
import "constants.dart";

class PdfExporter {
  static Future<void> exportOrderPdf({
    required Customer customer,
    required OrderHeader order,
    required List<OrderItem> items,
  }) async {
    final doc = pw.Document();

    final confirmed = items.where((e) => e.status == ItemStatus.confirmed).toList();
    final total = confirmed.fold<double>(0, (p, e) => p + e.lineTotal);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text("Order Summary", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text("Customer: ${customer.name}"),
          if ((customer.whatsapp ?? "").trim().isNotEmpty) pw.Text("WhatsApp: ${customer.whatsapp}"),
          pw.Text("Order ID: ${order.id}"),
          pw.Text("Created: ${order.createdAt}"),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 6),
          ...confirmed.map((it) => _itemBlock(it)),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total: ${fmtMoney(total)} ${AppConstants.currencyEgp}",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: "order_${order.id}.pdf");
  }

  static pw.Widget _itemBlock(OrderItem it) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 90,
            height: 90,
            child: pw.FutureBuilder<Uint8List>(
              future: readBytes(it.imagePath),
              builder: (context, snap) {
                if (snap.data == null) return pw.Container(color: PdfColors.grey200);
                return pw.Image(pw.MemoryImage(snap.data!), fit: pw.BoxFit.cover);
              },
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if ((it.note ?? "").trim().isNotEmpty)
                  pw.Text(it.note!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text("Unit: ${fmtMoney(it.unitPriceEgp)} ${AppConstants.currencyEgp}"),
                pw.Text("Size: ${it.size ?? "-"}"),
                pw.Text("Qty: ${it.qty ?? 0}"),
                pw.Text(
                  "Line Total: ${fmtMoney(it.lineTotal)} ${AppConstants.currencyEgp}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text("Shipping: ${it.shipping.name.toUpperCase()}"),
                pw.Text(
                  "ETA: ${it.shipping == ShippingType.air ? AppConstants.shippingDaysAir : AppConstants.shippingDaysLand} days",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
