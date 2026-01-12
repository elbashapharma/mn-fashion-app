import "package:flutter/material.dart";
import "../models.dart";
import "../repo.dart";
import "order_detail_screen.dart";

class OrdersScreen extends StatefulWidget {
  final int customerId;
  const OrdersScreen({super.key, required this.customerId});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Customer? customer;
  List<OrderHeader> orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await Repo.instance.getCustomer(widget.customerId);
    final o = await Repo.instance.listOrdersForCustomer(widget.customerId);
    setState(() {
      customer = c;
      orders = o;
    });
  }

  Future<void> _newOrder() async {
    final rateCtrl = TextEditingController(text: "0");
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("طلب جديد"),
        content: TextField(
          controller: rateCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "سعر الريال الافتراضي (يمكن تغييره لكل منتج)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("إنشاء")),
        ],
      ),
    );
    if (ok == true) {
      final rate = double.tryParse(rateCtrl.text.trim()) ?? 0;
      final id = await Repo.instance.createOrder(widget.customerId, rate);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Scaffold(
      appBar: AppBar(
        title: Text(c == null ? "الطلبات" : "الطلبات - ${c.name}"),
      ),
      body: ListView.separated(
        itemCount: orders.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final o = orders[i];
          return ListTile(
            title: Text("طلب #${o.id}"),
            subtitle: Text("تاريخ: ${o.createdAt}  |  سعر الريال: ${o.defaultRate}"),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id!)));
              await _load();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(Icons.add),
        label: const Text("طلب جديد"),
      ),
    );
  }
}
