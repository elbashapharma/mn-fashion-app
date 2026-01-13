import "package:flutter/material.dart";
import "../repo.dart";
import "../utils.dart";
import "../models.dart";
import "customer_statement_screen.dart";

class CustomerFinanceScreen extends StatefulWidget {
  final int customerId;
  const CustomerFinanceScreen({super.key, required this.customerId});

  @override
  State<CustomerFinanceScreen> createState() => _CustomerFinanceScreenState();
}

class _CustomerFinanceScreenState extends State<CustomerFinanceScreen> {
  Customer? customer;
  double revenue = 0; // مستحقات (طلبات مسلّمة)
  double paid = 0;    // كل المدفوعات (تحت الحساب + على أوردر)
  double balance = 0; // revenue - paid
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final c = await Repo.instance.getCustomer(widget.customerId);

    // ⚠️ لازم تكون موجودة في Repo عندك (لو مش موجودة قولّي)
    final r = await Repo.instance.sumRevenueForCustomerDelivered(widget.customerId);
    final p = await Repo.instance.sumPaymentsForCustomer(widget.customerId);

    setState(() {
      customer = c;
      revenue = r;
      paid = p;
      balance = r - p;
      loading = false;
    });
  }

  Future<void> _addPaymentOnAccount() async {
    // دفعة تحت الحساب (order_id = null)
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: "دفعة تحت الحساب");

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("دفعة تحت الحساب"),
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
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (amount <= 0) return;

      await Repo.instance.addPayment(
        customerId: widget.customerId,
        orderId: null, // ✅ تحت الحساب
        amountEgp: amount,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );

      await _load();
    }
  }

  Future<void> _addPaymentForOrder() async {
    // اختيار أوردر ثم دفع عليه
    final orders = await Repo.instance.listOrdersForCustomer(widget.customerId);
    if (!mounted) return;

    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد طلبات لهذا العميل")));
      return;
    }

    OrderHeader? selected = orders.first;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: "دفعة على أوردر");

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("دفعة على أوردر"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<OrderHeader>(
              value: selected,
              items: orders
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text("طلب #${o.id} ${o.deliveredAt == null ? "(غير مُسلّم)" : "(مُسلّم)"}"),
                    ),
                  )
                  .toList(),
              onChanged: (v) => selected = v,
              decoration: const InputDecoration(labelText: "اختر الأوردر"),
            ),
            const SizedBox(height: 10),
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

    if (ok == true && selected != null) {
      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (amount <= 0) return;

      await Repo.instance.addPayment(
        customerId: widget.customerId,
        orderId: selected!.id, // ✅ على أوردر محدد
        amountEgp: amount,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );

      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Scaffold(
      appBar: AppBar(title: Text(c == null ? "مالية العميل" : "مالية: ${c.name}")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _card("إجمالي مستحقات (طلبات مُسلّمة)", revenue),
                  const SizedBox(height: 10),
                  _card("إجمالي المدفوعات (تحت الحساب + على أوردر)", paid),
                  const SizedBox(height: 10),
                  _card("الرصيد", balance, bold: true),
                  const SizedBox(height: 16),

                  // ✅ أزرار التحصيل
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _addPaymentOnAccount,
                          icon: const Icon(Icons.savings),
                          label: const Text("دفعة تحت الحساب"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _addPaymentForOrder,
                          icon: const Icon(Icons.shopping_bag),
                          label: const Text("دفعة على أوردر"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CustomerStatementScreen(customerId: widget.customerId)),
                      );
                      await _load();
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text("كشف حساب"),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _card(String title, double value, {bool bold = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600))),
            Text("${fmtMoney(value)} EGP", style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
