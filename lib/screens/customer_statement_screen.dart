import "package:flutter/material.dart";
import "../repo.dart";
import "../utils.dart";

class CustomerStatementScreen extends StatefulWidget {
  final int customerId;
  const CustomerStatementScreen({super.key, required this.customerId});

  @override
  State<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  bool loading = true;

  List<_Row> rows = [];
  double balance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final delivered = await Repo.instance.deliveredOrdersForCustomer(widget.customerId);
    final pays = await Repo.instance.paymentsForCustomer(widget.customerId);

    final tmp = <_Row>[];

    for (final r in delivered) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r["delivered_at"] as int);
      final amount = (r["amount"] as num).toDouble();
      final orderId = r["order_id"] as int;
      tmp.add(_Row(date: dt, title: "طلب مُسلّم #$orderId", debit: amount, credit: 0));
    }

    for (final p in pays) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p["created_at"] as int);
      final amount = (p["amount_egp"] as num).toDouble();
      final note = (p["note"] as String?) ?? "";
      tmp.add(_Row(date: dt, title: note.trim().isEmpty ? "دفعة" : "دفعة: $note", debit: 0, credit: amount));
    }

    tmp.sort((a, b) => a.date.compareTo(b.date));

    double running = 0;
    for (final r in tmp) {
      running += r.debit;
      running -= r.credit;
      r.runningBalance = running;
    }

    setState(() {
      rows = tmp;
      balance = running;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("كشف حساب العميل")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Expanded(child: Text("الرصيد الحالي", style: TextStyle(fontWeight: FontWeight.bold))),
                          Text("${fmtMoney(balance)} EGP", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(child: Text("لا توجد حركات"))
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final r = rows[i];
                            return ListTile(
                              title: Text(r.title),
                              subtitle: Text("${r.date.year}-${r.date.month}-${r.date.day}"),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("مدين: ${fmtMoney(r.debit)}"),
                                  Text("دائن: ${fmtMoney(r.credit)}"),
                                  Text("رصيد: ${fmtMoney(r.runningBalance)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _Row {
  final DateTime date;
  final String title;
  final double debit;
  final double credit;
  double runningBalance = 0;

  _Row({
    required this.date,
    required this.title,
    required this.debit,
    required this.credit,
  });
}
