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
  String customerName = "";
  List<Map<String, Object?>> ledger = [];

  double debit = 0;
  double credit = 0;
  double balance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final c = await Repo.instance.getCustomer(widget.customerId);
    final rows = await Repo.instance.customerLedger(widget.customerId);

    double d = 0;
    double cr = 0;

    for (final r in rows) {
      final type = r["type"] as String;
      final amount = (r["amount"] as double);
      if (type == "order") d += amount; else cr += amount;
    }

    setState(() {
      customerName = c.name;
      ledger = rows;
      debit = d;
      credit = cr;
      balance = d - cr;
      loading = false;
    });
  }

  String _fmtDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("كشف حساب: $customerName"),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _row("إجمالي مدين (طلبات مُسلّمة)", debit),
                          const SizedBox(height: 6),
                          _row("إجمالي دائن (مدفوعات)", credit),
                          const Divider(),
                          _row("الرصيد", balance, bold: true),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ledger.isEmpty
                      ? const Center(child: Text("لا توجد حركات"))
                      : ListView.separated(
                          itemCount: ledger.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final r = ledger[i];
                            final type = r["type"] as String;
                            final date = _fmtDate(r["created_at"] as int);
                            final orderId = r["order_id"];
                            final amount = (r["amount"] as double);
                            final note = (r["note"] ?? "") as String;

                            final isDebit = type == "order";
                            return ListTile(
                              title: Text(isDebit ? "أوردر مُسلّم #$orderId" : "دفعة ${orderId == null ? "(تحت الحساب)" : "على أوردر #$orderId"}"),
                              subtitle: Text("$date  •  $note"),
                              trailing: Text(
                                "${isDebit ? "+" : "-"}${fmtMoney(amount)} EGP",
                                style: TextStyle(fontWeight: FontWeight.bold, color: isDebit ? Colors.red : Colors.green),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _row(String t, double v, {bool bold = false}) {
    return Row(
      children: [
        Expanded(child: Text(t, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600))),
        Text("${fmtMoney(v)} EGP", style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}
