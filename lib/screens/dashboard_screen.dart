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

  int ordersAll = 0;
  int ordersDelivered = 0;

  int pendingCount = 0;
  double pendingTotal = 0;

  int confirmedCount = 0;
  double confirmedTotal = 0;

  int cancelledCount = 0;
  double cancelledTotal = 0;

  double deliveredRevenue = 0;
  double deliveredCost = 0;
  double expenses = 0;
  double collected = 0;

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

    final s = await Repo.instance.ordersSummary(from, to);

    final rev = await Repo.instance.sumDeliveredRevenueBetween(from, to);
    final cost = await Repo.instance.sumDeliveredCostBetween(from, to);
    final exp = await Repo.instance.sumExpensesBetween(from, to);
    final pay = await Repo.instance.sumPaymentsBetween(from, to);

    setState(() {
      ordersAll = s["orders_all"] as int;
      ordersDelivered = s["orders_delivered"] as int;

      pendingCount = s["pending_count"] as int;
      pendingTotal = s["pending_total"] as double;

      confirmedCount = s["confirmed_count"] as int;
      confirmedTotal = s["confirmed_total"] as double;

      cancelledCount = s["cancelled_count"] as int;
      cancelledTotal = s["cancelled_total"] as double;

      deliveredRevenue = rev;
      deliveredCost = cost;
      expenses = exp;
      collected = pay;

      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final grossProfit = deliveredRevenue - deliveredCost;
    final netProfit = grossProfit - expenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
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
            const SizedBox(height: 12),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: [
                  _kpi("عدد الطلبات", ordersAll.toDouble(), isInt: true),
                  _kpi("عدد الطلبات المُسلّمة", ordersDelivered.toDouble(), isInt: true),

                  const SizedBox(height: 10),
                  _title("حالات المنتجات"),
                  _kpi("عدد المعلّق", pendingCount.toDouble(), isInt: true),
                  _kpi("إجمالي المعلّق", pendingTotal),
                  _kpi("عدد المؤكد", confirmedCount.toDouble(), isInt: true),
                  _kpi("إجمالي المؤكد", confirmedTotal),
                  _kpi("عدد الملغي", cancelledCount.toDouble(), isInt: true),
                  _kpi("إجمالي الملغي", cancelledTotal),

                  const SizedBox(height: 10),
                  _title("المُسلّم (الحسابات الفعلية)"),
                  _kpi("إيرادات (Revenue)", deliveredRevenue, bold: true),
                  _kpi("تكلفة شراء (COGS)", deliveredCost),
                  _kpi("ربح إجمالي (Gross)", grossProfit, bold: true),
                  _kpi("مصروفات (شحن وغيره)", expenses),
                  _kpi("صافي ربح (Net)", netProfit, bold: true),

                  const SizedBox(height: 10),
                  _title("التحصيل"),
                  _kpi("إجمالي التحصيل", collected, bold: true),
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
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget _kpi(String title, double value, {bool bold = false, bool isInt = false}) {
    final txt = isInt ? value.toInt().toString() : "${fmtMoney(value)} EGP";
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600))),
            Text(txt, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
