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

  double revenue = 0;
  double expenses = 0;
  bool loading = false;

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: from,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => from = DateTime(d.year, d.month, d.day, 0, 0, 0));
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => to = DateTime(d.year, d.month, d.day, 23, 59, 59));
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final r = await Repo.instance.sumRevenueBetween(from, to);
    final e = await Repo.instance.sumExpensesBetween(from, to);
    setState(() {
      revenue = r;
      expenses = e;
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final net = revenue - expenses;

    return Scaffold(
      appBar: AppBar(title: const Text("تقرير الأرباح العام")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await _pickFrom();
                      await _load();
                    },
                    child: Text("من: ${from.year}-${from.month}-${from.day}"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await _pickTo();
                      await _load();
                    },
                    child: Text("إلى: ${to.year}-${to.month}-${to.day}"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 16),

            _card("إجمالي الإيرادات", revenue),
            const SizedBox(height: 10),
            _card("إجمالي المصروفات", expenses),
            const SizedBox(height: 10),
            _card("صافي الربح", net, bold: true),

            const Spacer(),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text("تحديث"),
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
