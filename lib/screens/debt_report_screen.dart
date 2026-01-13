import "package:flutter/material.dart";
import "../repo.dart";
import "../utils.dart";

class DebtReportScreen extends StatefulWidget {
  const DebtReportScreen({super.key});

  @override
  State<DebtReportScreen> createState() => _DebtReportScreenState();
}

class _DebtReportScreenState extends State<DebtReportScreen> {
  bool loading = true;
  List<_Row> rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final list = await Repo.instance.debtsDeliveredOnly();

    final tmp = <_Row>[];
    for (final r in list) {
      final cid = r["customer_id"] as int;
      final c = await Repo.instance.getCustomer(cid);
      tmp.add(_Row(
        name: c.name,
        whatsapp: c.whatsapp,
        revenue: (r["revenue"] as double),
        paid: (r["paid"] as double),
        balance: (r["balance"] as double),
      ));
    }

    setState(() {
      rows = tmp;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("مديونية العملاء (طلبات مُسلّمة)")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(child: Text("لا توجد مديونيات.\n(تأكد: Qty + Confirm + تم التسليم)"))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = rows[i];
                    return ListTile(
                      title: Text(r.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((r.whatsapp ?? "").trim().isNotEmpty) Text("واتساب: ${r.whatsapp}"),
                          Text("مستحق: ${fmtMoney(r.revenue)} | مدفوع: ${fmtMoney(r.paid)}"),
                        ],
                      ),
                      trailing: Text("${fmtMoney(r.balance)} EGP", style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text("تحديث"),
      ),
    );
  }
}

class _Row {
  final String name;
  final String? whatsapp;
  final double revenue;
  final double paid;
  final double balance;

  _Row({required this.name, required this.whatsapp, required this.revenue, required this.paid, required this.balance});
}
