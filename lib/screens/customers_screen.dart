import "package:flutter/material.dart";
import "../models.dart";
import "../repo.dart";
import "orders_screen.dart";

class العملاءScreen extends StatefulWidget {
  const العملاءScreen({super.key});

  @override
  State<العملاءScreen> createState() => _العملاءScreenState();
}

class _العملاءScreenState extends State<العملاءScreen> {
  List<Customer> customers = [];
  String q = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Repo.instance.listالعملاء();
    setState(() => customers = list);
  }

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController();
    final waCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة عميل"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "اسم الزبون *")),
            TextField(controller: waCtrl, decoration: const InputDecoration(labelText: "واتساب (اختياري)")),
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
      await Repo.instance.addCustomer(
        Customer(
          name: nameCtrl.text.trim(),
          whatsapp: waCtrl.text.trim().isEmpty ? null : waCtrl.text.trim(),
        ),
      );
      await _load();
    }
  }

  Future<void> _deleteCustomer(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف العميل؟"),
        content: Text("حذف ${c.name} وكل طلباته؟"),
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
          IconButton(onPressed: _addCustomer, icon: const Icon(Icons.person_add_alt_1)),
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
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final c = filtered[i];
                return ListTile(
                  title: Text(c.name),
                  subtitle: (c.whatsapp ?? "").trim().isEmpty ? null : Text("WhatsApp: ${c.whatsapp}"),
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
