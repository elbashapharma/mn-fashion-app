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
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final c = await Repo.instance.getCustomer(widget.customerId);
    final o = await Repo.instance.listOrdersForCustomer(widget.customerId);

    if (!mounted) return;
    setState(() {
      customer = c;
      orders = o;
      loading = false;
    });
  }

  String _fmtRate(num? v) {
    final x = (v ?? 0).toDouble();
    final s = x.toStringAsFixed(2);
    return s.endsWith(".00") ? s.substring(0, s.length - 3) : s;
  }

  String _fmtDate(dynamic createdAt) {
    final s = (createdAt ?? "").toString().trim();
    if (s.isEmpty) return "-";

    final dt = DateTime.tryParse(s.replaceAll(" ", "T"));
    if (dt == null) return s;

    String two(int n) => n.toString().padLeft(2, "0");
    return "${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}";
  }

  Future<void> _newOrder() async {
    final rateCtrl = TextEditingController(text: "0");
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("طلب جديد"),
        content: TextField(
          controller: rateCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: "سعر الريال الافتراضي (يمكن تغييره لكل منتج)",
            hintText: "مثال: 13.5",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("إنشاء")),
        ],
      ),
    );

    if (ok == true) {
      final rate = double.tryParse(rateCtrl.text.trim().replaceAll(",", ".")) ?? 0;
      final id = await Repo.instance.createOrder(widget.customerId, rate);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
      );
      await _load();
    }
  }

  Future<void> _confirmAll() async {
    final n = await Repo.instance.confirmAllPendingOrdersForCustomer(widget.customerId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم تأكيد $n طلب/طلبات ✅")),
    );
    await _load();
  }

  Future<void> _mergeAll() async {
    final newId = await Repo.instance.mergePendingOrdersToOneConfirmed(widget.customerId);
    if (!mounted) return;

    if (newId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لا توجد طلبات معلقة للدمج")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم الدمج في طلب #$newId ✅")),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: newId)),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = customer;

    return Scaffold(
      appBar: AppBar(
        title: Text(c == null ? "الطلبات" : "الطلبات - ${c.name}"),
        actions: [
          IconButton(
            tooltip: "تأكيد كل الطلبات المعلقة",
            icon: const Icon(Icons.done_all),
            onPressed: _confirmAll,
          ),
          IconButton(
            tooltip: "دمج المعلق في طلب واحد",
            icon: const Icon(Icons.merge_type),
            onPressed: _mergeAll,
          ),
          IconButton(
            tooltip: "تحديث",
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? const Center(child: Text("لا توجد طلبات بعد"))
              : ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final o = orders[i];
                    return ListTile(
                      title: Text("طلب #${o.id ?? "-"}"),
                      subtitle: Text("تاريخ: ${_fmtDate(o.createdAt)}  |  سعر الريال: ${_fmtRate(o.defaultRate)}"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        if (o.id == null) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id!)),
                        );
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
