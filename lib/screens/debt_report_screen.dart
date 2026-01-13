import "package:flutter/material.dart";
import "../repo.dart";
import "../utils.dart";
import "../models.dart";

class DebtReportScreen extends StatefulWidget {
  const DebtReportScreen({super.key});

  @override
  State<DebtReportScreen> createState() => _DebtReportScreenState();
}

class _DebtReportScreenState extends State<DebtReportScreen> {
  bool loading = true;
  List<_DebtRow> rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final customers = await Repo.instance.listCustomers();

    final tmp = <_DebtRow>[];
    for (final c in customers) {
      final rev = await Repo.instance.sumRevenueForCustomerDelivered(c.id!);
      final paid = await Repo.instance.sumPaymentsForCustomer(c.id!);
      final bal = rev - paid;
      if (bal > 0.0001) {
        tmp.add(_DebtRow(customer: c, balance: bal));
      }
    }

    tmp.sort((a, b) => b.balance.compareTo(a.balance));

    setState(() {
      rows = tmp;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("مديونية العملاء")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(child: Text("لا توجد مديونيات"))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = rows[i];
                    return ListTile(
                      title: Text(r.customer.name),
                      subtitle: (r.customer.whatsapp ?? "").trim().isEmpty ? null : Text("واتساب: ${r.customer.whatsapp}"),
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

class _DebtRow {
  final Customer customer;
  final double balance;
  _DebtRow({required this.customer, required this.balance});
}
