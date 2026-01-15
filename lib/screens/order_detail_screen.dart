import "dart:io";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../models.dart";
import "../repo.dart";
import "../utils.dart";
import "../constants.dart";
import "../whatsapp.dart";
import "../pdf_export.dart";
import "../order_export.dart";

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderHeader? order;
  Customer? customer;
  List<OrderItem> items = [];

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final o = await Repo.instance.getOrder(widget.orderId);
    final c = await Repo.instance.getCustomer(o.customerId);
    final it = await Repo.instance.listItems(widget.orderId);

    if (!mounted) return;
    setState(() {
      order = o;
      customer = c;
      items = it;
    });
  }

  Future<void> _setDefaultRate() async {
    final o = order;
    if (o == null) return;

    final ctrl = TextEditingController(text: o.defaultRate.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تغيير سعر الريال الافتراضي"),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "سعر الريال الافتراضي لهذا الطلب"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حفظ")),
        ],
      ),
    );

    if (ok == true) {
      final v = double.tryParse(ctrl.text.trim().replaceAll(",", ".")) ?? 0;
      await Repo.instance.updateOrderDefaultRate(o.id!, v);
      await _load();
    }
  }

  Future<void> _markDelivered() async {
    final o = order;
    if (o == null) return;

    await Repo.instance.markOrderDelivered(o.id!);
    await _load();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم تسجيل الطلب كمُسلّم ✅")),
    );
  }

  Future<void> _addShippingExpense() async {
    final c = customer;
    final o = order;
    if (c == null || o == null) return;

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: "شحن");

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة مصروف شحن"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "المبلغ بالجنيه"),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: "ملاحظة (اختياري)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حفظ")),
        ],
      ),
    );

    if (ok == true) {
      final amount = double.tryParse(amountCtrl.text.trim().replaceAll(",", ".")) ?? 0;
      if (amount <= 0) return;

      await Repo.instance.addExpense(
        orderId: o.id,
        customerId: c.id,
        amountEgp: amount,
        type: "shipping",
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إضافة مصروف الشحن ✅")),
      );
    }
  }

  Future<void> _collectPaymentForOrder() async {
    final c = customer;
    final o = order;
    if (c == null || o == null) return;

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: "تحصيل على أوردر #${o.id}");

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تحصيل على الأوردر"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "المبلغ بالجنيه"),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: "ملاحظة (اختياري)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حفظ")),
        ],
      ),
    );

    if (ok == true) {
      final amount = double.tryParse(amountCtrl.text.trim().replaceAll(",", ".")) ?? 0;
      if (amount <= 0) return;

      await Repo.instance.addPayment(
        customerId: c.id!,
        orderId: o.id!,
        amountEgp: amount,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تسجيل التحصيل ✅")),
      );
    }
  }

  Future<void> _addImages() async {
    final List<XFile> picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    final o = order;
    if (o == null) return;

    for (final x in picked) {
      final saved = await saveImageToAppDir(File(x.path));
      final newItem = OrderItem(
        orderId: o.id!,
        imagePath: saved,
        note: null,
        buyPriceSar: 0,
        priceSar: 0,
        rateEgp: o.defaultRate,
        profitEgp: 0,
        shipping: ShippingType.air,
        status: ItemStatus.pending,
        size: null,
        qty: 1, // ✅ default 1
      );
      await Repo.instance.addItem(newItem);
    }
    await _load();
  }

  double _confirmedTotalRevenueEgp() {
    return items
        .where((e) => e.status == ItemStatus.confirmed)
        .fold<double>(0, (p, e) => p + e.revenueEgp);
  }

  double _confirmedTotalGrossProfitEgp() {
    return items
        .where((e) => e.status == ItemStatus.confirmed)
        .fold<double>(0, (p, e) => p + e.grossProfitEgp);
  }

  Future<void> _exportPdf() async {
    final o = order;
    final c = customer;
    if (o == null || c == null) return;
    await PdfExporter.exportOrderPdf(customer: c, order: o, items: items);
  }

  Future<void> _exportHtml() async {
    final o = order;
    final c = customer;
    if (o == null || c == null) return;

    final path = await OrderExporter.exportOrderHtml(customer: c, order: o, items: items);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تصدير HTML ✅")));

    await OrderExporter.shareFile(path, message: "أمر بيع للعميل: ${c.name} (طلب #${o.id})");
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final c = customer;

    if (o == null || c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final confirmed = items.where((e) => e.status == ItemStatus.confirmed).length;
    final cancelled = items.where((e) => e.status == ItemStatus.cancelled).length;
    final pending = items.where((e) => e.status == ItemStatus.pending).length;

    final totalRevenue = _confirmedTotalRevenueEgp();
    final totalGrossProfit = _confirmedTotalGrossProfitEgp();

    return Scaffold(
      appBar: AppBar(
        title: Text("طلب #${o.id} - ${c.name}"),
        actions: [
          IconButton(onPressed: _setDefaultRate, icon: const Icon(Icons.currency_exchange), tooltip: "سعر الريال"),
          IconButton(onPressed: _addShippingExpense, icon: const Icon(Icons.local_shipping_outlined), tooltip: "مصروف شحن"),
          IconButton(onPressed: _collectPaymentForOrder, icon: const Icon(Icons.payments), tooltip: "تحصيل"),
          IconButton(onPressed: _markDelivered, icon: const Icon(Icons.check_circle_outline), tooltip: "تم التسليم"),
          IconButton(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf), tooltip: "PDF"),
          IconButton(onPressed: _exportHtml, icon: const Icon(Icons.description_outlined), tooltip: "HTML"),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("الزبون: ${c.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    if ((c.whatsapp ?? "").trim().isNotEmpty) Text("واتساب: ${c.whatsapp}"),
                    if ((c.deliveryAddress ?? "").trim().isNotEmpty) Text("العنوان: ${c.deliveryAddress}"),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Chip(label: Text("معلق: $pending")),
                        Chip(label: Text("مؤكد: $confirmed")),
                        Chip(label: Text("ملغي: $cancelled")),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "إجمالي الإيرادات (مؤكد): ${fmtMoney(totalRevenue)} EGP",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "إجمالي الربح الإجمالي (مؤكد): ${fmtMoney(totalGrossProfit)} EGP",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      o.deliveredAt == null ? "الحالة: غير مُسلّم" : "الحالة: مُسلّم ✅",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _addImages,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text("إضافة صور"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _exportPdf,
                          icon: const Icon(Icons.share),
                          label: const Text("مشاركة PDF"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("سعر الريال الافتراضي: ${o.defaultRate}"),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("لا يوجد منتجات بعد. اضغط (إضافة صور)."))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => _ItemCard(
                      customer: c,
                      item: items[i],
                      onChanged: (updated) async {
                        await Repo.instance.updateItem(updated);
                        await _load();
                      },
                      onDelete: (id) async {
                        await Repo.instance.deleteItem(id);
                        await _load();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatefulWidget {
  final Customer customer;
  final OrderItem item;
  final Future<void> Function(OrderItem updated) onChanged;
  final Future<void> Function(int id) onDelete;

  const _ItemCard({
    required this.customer,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late TextEditingController buySarCtrl;
  late TextEditingController sellSarCtrl;
  late TextEditingController rateCtrl;
  late TextEditingController extraProfitCtrl;
  late TextEditingController noteCtrl;
  late TextEditingController sizeCtrl;
  late TextEditingController qtyCtrl;

  ShippingType shipping = ShippingType.air;
  ItemStatus status = ItemStatus.pending;

  @override
  void initState() {
    super.initState();
    final it = widget.item;

    buySarCtrl = TextEditingController(text: it.buyPriceSar.toString());
    sellSarCtrl = TextEditingController(text: it.priceSar.toString());
    rateCtrl = TextEditingController(text: it.rateEgp.toString());
    extraProfitCtrl = TextEditingController(text: it.profitEgp.toString());

    noteCtrl = TextEditingController(text: it.note ?? "");
    sizeCtrl = TextEditingController(text: it.size ?? "");
    qtyCtrl = TextEditingController(text: (it.qty ?? 1).toString());

    shipping = it.shipping;
    status = it.status;
  }

  @override
  void dispose() {
    buySarCtrl.dispose();
    sellSarCtrl.dispose();
    rateCtrl.dispose();
    extraProfitCtrl.dispose();
    noteCtrl.dispose();
    sizeCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  double _d(String s) => double.tryParse(s.trim().replaceAll(",", ".")) ?? 0;
  int _i(String s) => int.tryParse(s.trim()) ?? 0;

  OrderItem _currentItem() {
    final it = widget.item;

    final q = _i(qtyCtrl.text);
    final safeQ = q < 1 ? 1 : q;

    return it.copyWith(
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      buyPriceSar: _d(buySarCtrl.text),
      priceSar: _d(sellSarCtrl.text),
      rateEgp: _d(rateCtrl.text),
      profitEgp: _d(extraProfitCtrl.text),
      shipping: shipping,
      status: status,
      size: (status == ItemStatus.confirmed && sizeCtrl.text.trim().isNotEmpty) ? sizeCtrl.text.trim() : null,
      qty: (status == ItemStatus.confirmed) ? safeQ : (it.qty ?? 1),
    );
  }

  String _buildMessage(OrderItem it) {
    final name = widget.customer.name;
    final ship = it.shipping == ShippingType.air ? "جوي" : "بري";
    final days = it.shipping == ShippingType.air ? AppConstants.shippingDaysAir : AppConstants.shippingDaysLand;

    final unitSell = (it.priceSar * it.rateEgp) + it.profitEgp;

    return "أ/ $name\n"
        "سعر القطعة: ${fmtMoney(unitSell)} جنيه\n"
        "الشحن: $ship — الوصول خلال $days يوم\n"
        "لو مناسب ابعت: المقاس + الكمية ✅";
  }

  @override
  Widget build(BuildContext context) {
    final it = _currentItem();

    final unitSell = (it.priceSar * it.rateEgp) + it.profitEgp;
    final unitCost = (it.buyPriceSar * it.rateEgp);

    final revenue = it.revenueEgp;
    final cost = it.costEgp;
    final gross = it.grossProfitEgp;

    Color statusColor;
    String statusText;
    switch (status) {
      case ItemStatus.confirmed:
        statusColor = Colors.green;
        statusText = "مؤكد";
        break;
      case ItemStatus.cancelled:
        statusColor = Colors.red;
        statusText = "ملغي";
        break;
      default:
        statusColor = Colors.orange;
        statusText = "معلق";
    }

    final days = shipping == ShippingType.air ? AppConstants.shippingDaysAir : AppConstants.shippingDaysLand;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(widget.item.imagePath), width: 86, height: 86, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("منتج #${widget.item.id}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                        child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      Text("بيع/قطعة: ${fmtMoney(unitSell)} EGP", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("شراء/قطعة: ${fmtMoney(unitCost)} EGP"),
                      Text("مدة الوصول: $days يوم"),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async => widget.onDelete(widget.item.id!),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),

            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: "ملاحظة (اختياري) مثل اسم/وصف المنتج"),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: buySarCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "سعر الشراء بالريال (Buy SAR)"),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: sellSarCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "سعر البيع بالريال (Sell SAR)"),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "سعر الريال بالجنيه"),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: extraProfitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "ربح إضافي/قطعة (جنيه)"),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<ShippingType>(
                    segments: const [
                      ButtonSegment(value: ShippingType.air, label: Text("جوي (20 يوم)"), icon: Icon(Icons.flight_takeoff)),
                      ButtonSegment(value: ShippingType.land, label: Text("بري (40 يوم)"), icon: Icon(Icons.local_shipping)),
                    ],
                    selected: {shipping},
                    onSelectionChanged: (s) => setState(() => shipping = s.first),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final msg = _buildMessage(it);
                      await shareToWhatsApp(message: msg, imagePath: widget.item.imagePath);
                      await widget.onChanged(it);
                    },
                    icon: const Icon(Icons.send),
                    label: const Text("إرسال"),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => status = ItemStatus.confirmed);
                    final q = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                    if (q < 1) qtyCtrl.text = "1";
                    await widget.onChanged(_currentItem());
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("تأكيد"),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => status = ItemStatus.cancelled);
                    await widget.onChanged(_currentItem());
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("إلغاء"),
                ),
              ],
            ),

            if (status == ItemStatus.confirmed) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sizeCtrl,
                      decoration: const InputDecoration(labelText: "المقاس"),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: "نقص",
                          onPressed: () {
                            final cur = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                            final next = (cur - 1) < 1 ? 1 : (cur - 1);
                            setState(() => qtyCtrl.text = next.toString());
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "الكمية"),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          tooltip: "زيادة",
                          onPressed: () {
                            final cur = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                            final next = cur + 1;
                            setState(() => qtyCtrl.text = next.toString());
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("إيراد الصنف: ${fmtMoney(revenue)} EGP"),
                      Text("تكلفة الصنف: ${fmtMoney(cost)} EGP"),
                      Text("الربح الإجمالي: ${fmtMoney(gross)} EGP", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
