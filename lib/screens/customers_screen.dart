import "package:flutter/material.dart";
import "../models.dart";
import "../repo.dart";
import "orders_screen.dart";
import "debt_report_screen.dart";
import "profit_report_screen.dart";
import "dashboard_screen.dart";

class CustomersScreen extends StatefulWidget {
  CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> customers = [];
  String q = "";
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final list = await Repo.instance.listCustomers();
    setState(() {
      customers = list;
      loading = false;
    });
  }

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController();
    final waCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة زبون"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "اسم الزبون *")),
            TextField(controller: waCtrl, decoration: const InputDecoration(labelText: "رقم واتساب (اختياري)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await Repo.instance.addCustomer(Customer(name: nameCtrl.text.trim(), whatsapp: waCtrl.text.trim().isEmpty ? null : waCtrl.text.trim()));
      await _load();
    }
  }

  Future<void> _deleteCustomer(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف الزبون؟"),
        content: Text("هل تريد حذف ${c.name} وكل طلباته؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("لا")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("نعم")),
        ],
      ),
    );
    if (ok == true) {
      await Repo.instance.deleteCustomer(c.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = customers.where((c) => c.name.toLowerCase().contains(q.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
  title: const Text("العملاء"),
  actions: [
    IconButton(
      icon: const Icon(Icons.bar_chart),
      tooltip: "تقرير الأرباح",
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProfitReportScreen(),
          ),
        );
      },
    ),
  ],
),

          IconButton(
            tooltip: "مديونية العملاء",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtReportScreen())),
            icon: const Icon(Icons.account_balance_wallet),
          ),
          IconButton(onPressed: _addCustomer, icon: const Icon(Icons.person_add_alt_1)),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: "بحث بالاسم"),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text("لا يوجد عملاء"))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final c = filtered[i];
                          return ListTile(
                            title: Text(c.name),
                            subtitle: (c.whatsapp ?? "").trim().isNotEmpty ? Text("واتساب: ${c.whatsapp}") : null,
                            leading: const Icon(Icons.person),
                            trailing: IconButton(onPressed: () => _deleteCustomer(c), icon: const Icon(Icons.delete_outline)),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(customerId: c.id!))),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.add),
        label: const Text("إضافة"),
      ),
    );
  }
}
