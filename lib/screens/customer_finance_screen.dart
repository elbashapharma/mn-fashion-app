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
  double revenue = 0;
  double paid = 0;
  double balance = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final c = await Repo.instance.getCustomer(widget.customerId);
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

  Future<void> _addPayment() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة دفعة"),
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
                  _card("إجمالي المدفوعات", paid),
                  const SizedBox(height: 10),
                  _card("الرصيد", balance, bold: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _addPayment,
                          icon: const Icon(Icons.payments),
                          label: const Text("إضافة دفعة"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
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
                      ),
                    ],
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
