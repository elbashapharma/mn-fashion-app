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

  // orders status summary
  int pendingCount = 0;
  int confirmedCount = 0;
  int cancelledCount = 0;
  int deliveredOrders = 0;

  double pendingTotal = 0;
  double confirmedTotal = 0;
  double cancelledTotal = 0;

  // money
  double cash = 0;
  double supplierNeed = 0;

  double revenueDelivered = 0;
  double costDelivered = 0;
  double expenses = 0;
  double payments = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(context: context, initialDate: from, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) {
      setState(() => from = DateTime(d.year, d.month, d.day, 0, 0, 0));
      await _load();
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(context: context, initialDate: to, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) {
      setState(() => to = DateTime(d.year, d.month, d.day, 23, 59, 59));
      await _load();
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);

    // لازم تكون عندك موجودة أو أضفتها قبل كده
    final summary = await Repo.instance.ordersSummary(from, to);

    final cashBal = await Repo.instance.cashBalance();
    final need = await Repo.instance.sumConfirmedCostAllOpenOrders();

    final rev = await Repo.instance.sumDeliveredRevenueBetween(from, to);
    final cost = await Repo.instance.sumDeliveredCostBetween(from, to);
    final exp = await Repo.instance.sumExpensesBetween(from, to);
    final pay = await Repo.instance.sumPaymentsBetween(from, to);

    setState(() {
      pendingCount = summary["pending_count"] as int;
      confirmedCount = summary["confirmed_count"] as int;
      cancelledCount = summary["cancelled_count"] as int;

      pendingTotal = summary["pending_total"] as double;
      confirmedTotal = summary["confirmed_total"] as double;
      cancelledTotal = summary["cancelled_total"] as double;

      deliveredOrders = summary["orders_delivered"] as int;

      cash = cashBal;
      supplierNeed = need;

      revenueDelivered = rev;
      costDelivered = cost;
      expenses = exp;
      payments = pay;

      loading = false;
    });
  }

  double get grossProfit => revenueDelivered - costDelivered;
  double get netProfit => grossProfit - expenses;

  Future<void> _openingBalance() async {
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("رصيد أول مدة (الدرج)"),
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
      await Repo.instance.addCashTxn(type: "opening", amountEgp: v, note: "رصيد أول مدة");
      await _load();
    }
  }

  Future<void> _paySupplier() async {
    // دفع للمورد = خصم من الدرج
    final amount = supplierNeed;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا يوجد مؤكد بتكلفة للشراء")));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("دفع للمورد"),
        content: Text("سيتم تسجيل دفع للمورد بقيمة:\n${fmtMoney(amount)} EGP"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("تأكيد")),
        ],
      ),
    );

    if (ok == true) {
      await Repo.instance.addCashTxn(
        type: "supplier_purchase",
        amountEgp: -amount,
        note: "دفع للمورد (إجمالي تكلفة المؤكد)",
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
        title: const Text("إضافة مصروف"),
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
      // ده غير expenses table (مصروفات الطلبات)، ده مصروفات عامة
      await _load();
    }
  }

  Future<void> _withdrawProfit() async {
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("توزيع/سحب أرباح"),
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
                  _card("رصيد الدرج الحالي", cash, bold: true),
                  _card("مطلوب دفعه للمورد (تكلفة المؤكد)", supplierNeed, bold: true),

                  const SizedBox(height: 8),
                  _sectionTitle("الطلبات"),
                  _small("معلّق: $pendingCount — إجمالي: ${fmtMoney(pendingTotal)}"),
                  _small("مؤكد: $confirmedCount — إجمالي: ${fmtMoney(confirmedTotal)}"),
                  _small("ملغي: $cancelledCount — إجمالي: ${fmtMoney(cancelledTotal)}"),
                  _small("طلبات مُسلّمة: $deliveredOrders"),

                  const SizedBox(height: 8),
                  _sectionTitle("التحصيل والمصروفات (داخل المدة)"),
                  _card("تحصيل العملاء", payments),
                  _card("مصروفات (شحن/غيره على الطلبات)", expenses),

                  const SizedBox(height: 8),
                  _sectionTitle("الربحية (طلبات مُسلّمة داخل المدة)"),
                  _card("إيرادات", revenueDelivered),
                  _card("تكلفة شراء", costDelivered),
                  _card("ربح إجمالي", grossProfit, bold: true),
                  _card("صافي الربح", netProfit, bold: true),

                  const SizedBox(height: 12),
                  _sectionTitle("حركات سريعة"),
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

  Widget _sectionTitle(String t) => Padding(
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
