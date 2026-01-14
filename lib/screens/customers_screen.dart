import "package:flutter/material.dart";
import "../repo.dart";
import "../models.dart";
import "orders_screen.dart";
import "customer_finance_screen.dart";
import "profit_report_screen.dart";
import "dashboard_screen.dart";

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool loading = true;
  List<Customer> customers = [];

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
  final addrCtrl = TextEditingController(); // ✅ جديد

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("إضافة عميل"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: "اسم العميل"),
          ),
          TextField(
            controller: waCtrl,
            decoration: const InputDecoration(labelText: "واتساب (اختياري)"),
            keyboardType: TextInputType.phone,
          ),
          TextField(
            controller: addrCtrl,
            decoration: const InputDecoration(
              labelText: "عنوان التوصيل (اختياري)",
              hintText: "المحافظة - المدينة - الشارع - علامة مميزة",
            ),
            maxLines: 2,
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
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    try {
      await Repo.instance.addCustomer(
        Customer(
          name: name,
          whatsapp: waCtrl.text.trim().isEmpty ? null : waCtrl.text.trim(),
          deliveryAddress: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(), // ✅ جديد
        ),
      );
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }
}


  Future<void> _deleteCustomer(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف العميل"),
        content: Text("تأكيد حذف العميل: ${c.name} ؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حذف")),
        ],
      ),
    );

    if (ok == true) {
     try {
  await Repo.instance.deleteCustomer(c.id!);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
  );
}

      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("العملاء"),
        actions: [
          // ✅ Dashboard
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: "Dashboard",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            },
          ),

          // ✅ Profit report
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: "تقرير الأرباح",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfitReportScreen()),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "تحديث",
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomer,
        child: const Icon(Icons.person_add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : customers.isEmpty
              ? const Center(child: Text("لا يوجد عملاء بعد. اضغط + لإضافة عميل."))
              : ListView.separated(
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final c = customers[i];
                    return ListTile(
                      isThreeLine: true,
                      title: Text(c.name),
                    subtitle: (() {
  final wa = (c.whatsapp ?? "").trim();
  final addr = (c.deliveryAddress ?? "").trim();

  if (wa.isEmpty && addr.isEmpty) return null;

  final lines = <String>[];
  if (wa.isNotEmpty) lines.add("WhatsApp: $wa");
  if (addr.isNotEmpty) lines.add("عنوان: $addr");

  return Text(lines.join("\n"));
})(),
                      
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == "orders") {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => OrdersScreen(customerId: c.id!)),
                            );
                            await _load();
                          } else if (v == "finance") {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CustomerFinanceScreen(customerId: c.id!)),
                            );
                            await _load();
                          } else if (v == "delete") {
                            await _deleteCustomer(c);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: "orders", child: Text("الطلبات")),
                          PopupMenuItem(value: "finance", child: Text("مالية العميل")),
                          PopupMenuDivider(),
                          PopupMenuItem(value: "delete", child: Text("حذف")),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => OrdersScreen(customerId: c.id!)),
                        );
                        await _load();
                      },
                    );
                  },
                ),
    );
  }
}
