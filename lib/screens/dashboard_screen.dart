import "package:flutter/material.dart";
import "../repo.dart";
import "../utils.dart";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime from = DateTime.now().subtract(const Duration(days: 30));
  DateTime to = DateTime.now();

  bool loading = true;

  // counts
  int pendingItems = 0;
  int confirmedItems = 0;
  int cancelledItems = 0;

  int deliveredOrders = 0;

  // totals (confirmed revenue etc)
  double pendingTotal = 0;
  double confirmedTotal = 0;
  double cancelledTotal = 0;

  // business metrics
  double cashBalance = 0;         // درج النقدية
  double supplierNeed = 0;        // تكلفة شراء المؤكد (قبل التسليم)
  double deliveredRevenue = 0;    // إيراد الطلبات المسلمة داخل المدة
  double deliveredCost = 0;       // تكلفة شراء الطلبات المسلمة داخل المدة
  double orderExpenses = 0;       // مصروفات شحن/مصروفات مرتبطة بالطلبات داخل المدة
  double payments = 0;            // تحصيل العملاء داخل المدة (من payments table)

  double get grossProfit => deliveredRevenue - deliveredCost;
  double get netProfit => grossProfit - orderExpenses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: from,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => from = DateTime(d.year, d.month, d.day, 0, 0, 0));
      await _load();
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => to = DateTime(d.year, d.month, d.day, 23, 59, 59));
      await _load();
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final summary = await Repo.instance.dashboardSummary(from, to);
    final cash = await Repo.instance.cashBalance();
    final need = await Repo.instance.sumConfirmedCostAll();

    setState(() {
      pendingItems = summary.pendingCount;
      confirmedItems = summary.confirmedCount;
      cancelledItems = summary.cancelledCount;

      pendingTotal = summary.pendingTotal;
      confirmedTotal = summary.confirmedTotal;
      cancelledTotal = summary.cancelledTotal;

      deliveredOrders = summary.deliveredOrders;

      deliveredRevenue = summary.deliveredRevenue;
      deliveredCost = summary.deliveredCost;
      orderExpenses = summary.orderExpenses;
      payments = summary.payments;

      cashBalance = cash;
      supplierNeed = need;

      loading = false;
    });
  }

  Future<void> _openingBalance() async {
    final amountCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("رصيد أول مدة (درج النقدية)"),
        content: TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "المبلغ بالجنيه"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حفظ")),
        ],
      ),
    );

    if (ok == true) {
      final v = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (v <= 0) return;
      await Repo.instance.addCashTxn(
        type: "opening",
        amountEgp: v,
        note: "رصيد أول مدة",
      );
      await _load();
    }
  }

  Future<void> _paySupplier() async {
    if (supplierNeed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد منتجات مؤكدة بتكلفة للشراء")));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("دفع للمورد"),
        content: Text("سيتم خصم مبلغ تكلفة شراء المؤكد من الدرج:\n${fmtMoney(supplierNeed)} EGP"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("تأكيد")),
        ],
      ),
    );

    if (ok == true) {
      await Repo.instance.addCashTxn(
        type: "supplier_purchase",
        amountEgp: -supplierNeed,
        note: "دفع للمورد (تكلفة المؤكد)",
      );
      await _load();
    }
  }

  Future<void> _addGeneralExpense() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: "مصروف");

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("مصروف عام من الدرج"),
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
              decoration: const InputDecoration(labelText: "ملاحظة"),
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
      final v = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (v <= 0) return;
      await Repo.instance.addCashTxn(type: "expense", amountEgp: -v, note: noteCtrl.text.trim());
      await _load();
    }
  }

  Future<void> _withdrawProfit() async {
    final amountCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("سحب/توزيع أرباح من الدرج"),
        content: TextField(
          controller: amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "المبلغ بالجنيه"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حفظ")),
        ],
      ),
    );

    if (ok == true) {
      final v = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (v <= 0) return;
      await Repo.instance.addCashTxn(type: "profit_distribution", amountEgp: -v, note: "سحب أرباح");
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _pickFrom, child: Text("من: ${from.year}-${from.month}-${from.day}"))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: _pickTo, child: Text("إلى: ${to.year}-${to.month}-${to.day}"))),
              ],
            ),
            const SizedBox(height: 10),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                children: [
                  _card("رصيد الدرج الحالي", cashBalance, bold: true),
                  _card("مطلوب دفعه للمورد (تكلفة المؤكد)", supplierNeed, bold: true),

                  const SizedBox(height: 10),
                  _title("حالة المنتجات"),
                  _small("معلّق: $pendingItems — إجمالي بيع (متوقع): ${fmtMoney(pendingTotal)}"),
                  _small("مؤكد: $confirmedItems — إجمالي بيع: ${fmtMoney(confirmedTotal)}"),
                  _small("ملغي: $cancelledItems — إجمالي: ${fmtMoney(cancelledTotal)}"),
                  _small("طلبات مُسلّمة: $deliveredOrders"),

                  const SizedBox(height: 10),
                  _title("التحصيل والمصروفات (داخل المدة)"),
                  _card("تحصيل العملاء", payments),
                  _card("مصروفات الطلبات (شحن/مصروف)", orderExpenses),

                  const SizedBox(height: 10),
                  _title("ربحية الطلبات المُسلّمة (داخل المدة)"),
                  _card("إيرادات", deliveredRevenue),
                  _card("تكلفة شراء", deliveredCost),
                  _card("ربح إجمالي", grossProfit, bold: true),
                  _card("صافي الربح", netProfit, bold: true),

                  const SizedBox(height: 12),
                  _title("حركات سريعة (الدرج)"),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(onPressed: _openingBalance, icon: const Icon(Icons.account_balance_wallet), label: const Text("رصيد أول مدة")),
                      FilledButton.icon(onPressed: _paySupplier, icon: const Icon(Icons.store), label: const Text("دفع للمورد")),
                      OutlinedButton.icon(onPressed: _addGeneralExpense, icon: const Icon(Icons.receipt_long), label: const Text("مصروف عام")),
                      OutlinedButton.icon(onPressed: _withdrawProfit, icon: const Icon(Icons.savings), label: const Text("سحب أرباح")),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );

  Widget _small(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Align(alignment: Alignment.centerRight, child: Text(t)),
      );

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
