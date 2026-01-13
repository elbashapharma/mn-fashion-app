import "package:flutter/material.dart";
import "../repo.dart";
import "../utils.dart";

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  DateTime from = DateTime.now().subtract(const Duration(days: 30));
  DateTime to = DateTime.now();

  bool loading = true;
  double revenue = 0;
  double cost = 0;
  double expenses = 0;

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

    final r = await Repo.instance.sumDeliveredRevenueBetween(from, to);
    final c = await Repo.instance.sumDeliveredCostBetween(from, to);
    final e = await Repo.instance.sumExpensesBetween(from, to);

    setState(() {
      revenue = r;
      cost = c;
      expenses = e;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gross = revenue - cost;
    final net = gross - expenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text("تقرير الأرباح"),
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
            _card("إجمالي الإيرادات (طلبات مُسلّمة)", revenue),
            _card("إجمالي تكلفة الشراء", cost),
            _card("الربح الإجمالي", gross, bold: true),
            _card("إجمالي المصروفات", expenses),
            _card("صافي الربح", net, bold: true),
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
