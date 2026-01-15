import "db.dart";
import "models.dart";
import "models/dashboard_summary.dart";

class Repo {
  Repo._();
  static final Repo instance = Repo._();

 // ---------- Customers ----------
Future<List<Customer>> listCustomers() async {
  final d = await AppDb.instance.db;
  final res = await d.query("customers", where: "is_archived=0", orderBy: "name ASC");
  return res.map(Customer.fromMap).toList();
}

Future<Customer> getCustomer(int id) async {
  final d = await AppDb.instance.db;
  final res = await d.query("customers", where: "id=?", whereArgs: [id]);
  return Customer.fromMap(res.first);
}

Future<int> addCustomer(Customer c) async {
  final d = await AppDb.instance.db;

  final w = _normWhats(c.whatsapp);
  if (w.isNotEmpty) {
    final dup = await d.query(
      "customers",
      columns: ["id", "name"],
      where: "whatsapp=? AND is_archived=0",
      whereArgs: [w],
      limit: 1,
    );
    if (dup.isNotEmpty) {
      final existingName = dup.first["name"] as String? ?? "";
      throw Exception("رقم الواتساب مكرر مع العميل: $existingName");
    }
  }

  return d.insert("customers", {
    "name": c.name,
    "whatsapp": w.isEmpty ? null : w,
    "delivery_address": c.deliveryAddress,
    "is_archived": 0,
  });
}

Future<void> updateCustomerDeliveryAddress(int customerId, String? address) async {
  final d = await AppDb.instance.db;
  await d.update(
    "customers",
    {"delivery_address": (address ?? "").trim()},
    where: "id=?",
    whereArgs: [customerId],
  );
}

Future<bool> customerHasAnyOrders(int customerId) async {
  final d = await AppDb.instance.db;
  final r = await d.rawQuery("SELECT COUNT(*) AS c FROM orders WHERE customer_id=?", [customerId]);
  return ((r.first["c"] as num).toInt() > 0);
}

Future<double> customerDebtDeliveredOnly(int customerId) async {
  final d = await AppDb.instance.db;

  final rev = await d.rawQuery("""
    SELECT COALESCE(SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),0) AS total
    FROM items i
    JOIN orders o ON o.id=i.order_id
    WHERE o.customer_id=? AND o.delivered_at IS NOT NULL AND i.status='confirmed'
  """, [customerId]);
  final revenue = (rev.first["total"] as num).toDouble();

  final pay = await d.rawQuery("""
    SELECT COALESCE(SUM(amount_egp),0) AS total
    FROM payments
    WHERE customer_id=?
  """, [customerId]);
  final paid = (pay.first["total"] as num).toDouble();

  final bal = revenue - paid;
  return bal < 0 ? 0 : bal;
}

// ✅ دي اللي الشاشة بتنده عليها (حل سريع)
Future<void> deleteCustomer(int customerId) async {
  final hasOrders = await customerHasAnyOrders(customerId);
  final debt = await customerDebtDeliveredOnly(customerId);

  final d = await AppDb.instance.db;

  if (hasOrders || debt > 0.0001) {
    // أرشفة بدل الحذف
    await d.update("customers", {"is_archived": 1}, where: "id=?", whereArgs: [customerId]);
    throw Exception("لا يمكن حذف العميل لأنه لديه طلبات أو مديونية. تم أرشفته بدلًا من ذلك.");
  } else {
    // حذف فعلي
    await d.delete("customers", where: "id=?", whereArgs: [customerId]);
  }
}

// لو عايز زر “أرشفة” منفصل
Future<void> archiveCustomer(int customerId) async {
  final d = await AppDb.instance.db;
  await d.update("customers", {"is_archived": 1}, where: "id=?", whereArgs: [customerId]);
}



Future<int?> mergePendingOrdersToOneConfirmed(int customerId) async {
  final d = await AppDb.instance.db;

  return await d.transaction<int?>((txn) async {
    final oldOrders = await txn.query(
      "orders",
      where: "customer_id=? AND delivered_at IS NULL AND status='pending'",
      whereArgs: [customerId],
      orderBy: "created_at ASC",
    );

    if (oldOrders.isEmpty) return null;

    final last = oldOrders.last;
    final defaultRate = (last["default_rate"] as num?)?.toDouble() ?? 0;

    final newOrderId = await txn.insert("orders", {
      "customer_id": customerId,
      "created_at": DateTime.now().millisecondsSinceEpoch,
      "default_rate": defaultRate,
      "delivered_at": null,
      "status": "confirmed",
      "merged_into_order_id": null,
    });

    for (final o in oldOrders) {
      final oldId = (o["id"] as num).toInt();

      // نقل المنتجات للطلب الجديد
      await txn.update(
        "items",
        {"order_id": newOrderId},
        where: "order_id=?",
        whereArgs: [oldId],
      );

      // تعليم الطلب القديم أنه merged
      await txn.update(
        "orders",
        {"status": "merged", "merged_into_order_id": newOrderId},
        where: "id=?",
        whereArgs: [oldId],
      );
    }

    return newOrderId;
  });
}

Future<int> confirmAllPendingOrdersForCustomer(int customerId) async {
  final d = await AppDb.instance.db;

  // أكّد كل الطلبات المعلقة غير المسلمة
  final updated = await d.update(
    "orders",
    {"status": "confirmed"},
    where: "customer_id=? AND delivered_at IS NULL AND status='pending'",
    whereArgs: [customerId],
  );

  return updated; // عدد الطلبات اللي اتأكدت
}

    if (oldOrders.isEmpty) return null;

    // استخدم default_rate من أحدث طلب أو أول طلب (اختيار منطقي)
    final last = oldOrders.last;
    final defaultRate = (last["default_rate"] as num?)?.toDouble() ?? 0;

    // أنشئ طلب جديد مؤكد
    final newOrderId = await txn.insert("orders", {
      "customer_id": customerId,
      "created_at": DateTime.now().millisecondsSinceEpoch,
      "default_rate": defaultRate,
      "delivered_at": null,
      "status": "confirmed",
      "merged_into_order_id": null,
    });

    // انقل كل items للطلب الجديد
    for (final o in oldOrders) {
      final oldId = (o["id"] as num).toInt();

      await txn.update(
        "items",
        {"order_id": newOrderId},
        where: "order_id=?",
        whereArgs: [oldId],
      );

      // علّم الطلب القديم انه merged
      await txn.update(
        "orders",
        {"status": "merged", "merged_into_order_id": newOrderId},
        where: "id=?",
        whereArgs: [oldId],
      );
    }

    return newOrderId;
  });
}


  Future<List<OrderHeader>> listOrdersForCustomer(int customerId) async {
    final d = await AppDb.instance.db;
    final res = await d.query(
      "orders",
      where: "customer_id=?",
      whereArgs: [customerId],
      orderBy: "created_at DESC",
    );
    return res.map(OrderHeader.fromMap).toList();
  }

  Future<OrderHeader> getOrder(int id) async {
    final d = await AppDb.instance.db;
    final res = await d.query("orders", where: "id=?", whereArgs: [id]);
    return OrderHeader.fromMap(res.first);
  }

  Future<void> updateOrderDefaultRate(int orderId, double rate) async {
    final d = await AppDb.instance.db;
    await d.update("orders", {"default_rate": rate}, where: "id=?", whereArgs: [orderId]);
  }

  // ✅ زر التسليم
  Future<void> markOrderDelivered(int orderId) async {
    final d = await AppDb.instance.db;
    await d.update(
      "orders",
      {"delivered_at": DateTime.now().millisecondsSinceEpoch},
      where: "id=?",
      whereArgs: [orderId],
    );
  }

  // ---------- Items ----------
  Future<List<OrderItem>> listItems(int orderId) async {
    final d = await AppDb.instance.db;
    final res = await d.query("items", where: "order_id=?", whereArgs: [orderId], orderBy: "id ASC");
    return res.map(OrderItem.fromMap).toList();
  }

  Future<int> addItem(OrderItem it) async {
    final d = await AppDb.instance.db;
    return d.insert("items", it.toMap());
  }

  Future<void> updateItem(OrderItem it) async {
    final d = await AppDb.instance.db;
    await d.update("items", it.toMap(), where: "id=?", whereArgs: [it.id]);
  }

  Future<void> deleteItem(int id) async {
    final d = await AppDb.instance.db;
    await d.delete("items", where: "id=?", whereArgs: [id]);
  }

  // ---------- Expenses ----------
  Future<int> addExpense({
    int? orderId,
    int? customerId,
    required double amountEgp,
    required String type,
    String? note,
    DateTime? date,
  }) async {
    final d = await AppDb.instance.db;
    return d.insert("expenses", {
      "order_id": orderId,
      "customer_id": customerId,
      "amount_egp": amountEgp,
      "type": type,
      "note": note,
      "created_at": (date ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }

  Future<double> sumExpensesBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      "SELECT COALESCE(SUM(amount_egp),0) AS total FROM expenses WHERE created_at BETWEEN ? AND ?",
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (res.first["total"] as num).toDouble();
  }

  // ---------- Payments ----------
  Future<int> addPayment({
    required int customerId,
    int? orderId, // null => دفعة تحت الحساب
    required double amountEgp,
    String? note,
    DateTime? date,
  }) async {
    final d = await AppDb.instance.db;
    return d.insert("payments", {
      "customer_id": customerId,
      "order_id": orderId,
      "amount_egp": amountEgp,
      "note": note,
      "created_at": (date ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }

  Future<double> sumPaymentsBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      "SELECT COALESCE(SUM(amount_egp),0) AS total FROM payments WHERE created_at BETWEEN ? AND ?",
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (res.first["total"] as num).toDouble();
  }

  Future<double> sumPaymentsForCustomer(int customerId) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      "SELECT COALESCE(SUM(amount_egp),0) AS total FROM payments WHERE customer_id=?",
      [customerId],
    );
    return (res.first["total"] as num).toDouble();
  }

  // ---------- Delivered Revenue/Cost ----------
  Future<double> sumDeliveredRevenueBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      """
      SELECT COALESCE(SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),0) AS total
      FROM items i JOIN orders o ON o.id=i.order_id
      WHERE i.status='confirmed' AND o.delivered_at IS NOT NULL
        AND o.created_at BETWEEN ? AND ?
      """,
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (res.first["total"] as num).toDouble();
  }

  Future<double> sumDeliveredCostBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      """
      SELECT COALESCE(SUM((i.buy_price_sar * i.rate_egp) * COALESCE(i.qty,0)),0) AS total
      FROM items i JOIN orders o ON o.id=i.order_id
      WHERE i.status='confirmed' AND o.delivered_at IS NOT NULL
        AND o.created_at BETWEEN ? AND ?
      """,
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (res.first["total"] as num).toDouble();
  }

  // ---------- Debts delivered only ----------
  Future<List<Map<String, Object?>>> debtsDeliveredOnly() async {
    final d = await AppDb.instance.db;

    final revRows = await d.rawQuery("""
      SELECT o.customer_id AS customer_id,
             COALESCE(SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),0) AS revenue
      FROM orders o
      LEFT JOIN items i ON i.order_id=o.id AND i.status='confirmed'
      WHERE o.delivered_at IS NOT NULL
      GROUP BY o.customer_id
    """);

    final payRows = await d.rawQuery("""
      SELECT customer_id, COALESCE(SUM(amount_egp),0) AS paid
      FROM payments
      GROUP BY customer_id
    """);

    final paidMap = <int, double>{};
    for (final r in payRows) {
      paidMap[(r["customer_id"] as num).toInt()] = (r["paid"] as num).toDouble();
    }

    final out = <Map<String, Object?>>[];
    for (final r in revRows) {
      final cid = (r["customer_id"] as num).toInt();
      final revenue = (r["revenue"] as num).toDouble();
      final paid = paidMap[cid] ?? 0;
      final bal = revenue - paid;
      if (bal > 0.0001) out.add({"customer_id": cid, "revenue": revenue, "paid": paid, "balance": bal});
    }
    out.sort((a, b) => (b["balance"] as double).compareTo(a["balance"] as double));
    return out;
  }

  // ---------- Dashboard orders summary (Map) ----------
  Future<Map<String, Object>> ordersSummary(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;

    Future<int> _count(String status) async {
      final r = await d.rawQuery(
        """
        SELECT COALESCE(COUNT(*),0) AS cnt
        FROM items i JOIN orders o ON o.id=i.order_id
        WHERE i.status=? AND o.created_at BETWEEN ? AND ?
        """,
        [status, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      );
      return (r.first["cnt"] as num).toInt();
    }

    Future<double> _sum(String status) async {
      final r = await d.rawQuery(
        """
        SELECT COALESCE(SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),0) AS total
        FROM items i JOIN orders o ON o.id=i.order_id
        WHERE i.status=? AND o.created_at BETWEEN ? AND ?
        """,
        [status, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      );
      return (r.first["total"] as num).toDouble();
    }

    final allOrders = await d.rawQuery(
      "SELECT COALESCE(COUNT(*),0) AS cnt FROM orders WHERE created_at BETWEEN ? AND ?",
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );

    final deliveredOrders = await d.rawQuery(
      "SELECT COALESCE(COUNT(*),0) AS cnt FROM orders WHERE delivered_at IS NOT NULL AND created_at BETWEEN ? AND ?",
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );

    return {
      "orders_all": (allOrders.first["cnt"] as num).toInt(),
      "orders_delivered": (deliveredOrders.first["cnt"] as num).toInt(),
      "pending_count": await _count("pending"),
      "pending_total": await _sum("pending"),
      "confirmed_count": await _count("confirmed"),
      "confirmed_total": await _sum("confirmed"),
      "cancelled_count": await _count("cancelled"),
      "cancelled_total": await _sum("cancelled"),
    };
  }

  // =========================
  // Customer Statement (Ledger)
  // =========================
  Future<List<Map<String, Object?>>> customerLedger(int customerId) async {
    final d = await AppDb.instance.db;

    final orders = await d.rawQuery("""
      SELECT 
        o.created_at AS created_at,
        o.id AS order_id,
        COALESCE(SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),0) AS amount
      FROM orders o
      LEFT JOIN items i ON i.order_id=o.id AND i.status='confirmed'
      WHERE o.customer_id=? AND o.delivered_at IS NOT NULL
      GROUP BY o.id
    """, [customerId]);

    final pays = await d.rawQuery("""
      SELECT 
        created_at AS created_at,
        order_id AS order_id,
        amount_egp AS amount,
        note AS note
      FROM payments
      WHERE customer_id=?
    """, [customerId]);

    final out = <Map<String, Object?>>[];

    for (final r in orders) {
      out.add({
        "type": "order",
        "created_at": r["created_at"],
        "order_id": r["order_id"],
        "amount": (r["amount"] as num).toDouble(),
        "note": "أوردر مُسلّم",
      });
    }

    for (final r in pays) {
      out.add({
        "type": "payment",
        "created_at": r["created_at"],
        "order_id": r["order_id"],
        "amount": (r["amount"] as num).toDouble(),
        "note": r["note"],
      });
    }

    out.sort((a, b) => (a["created_at"] as int).compareTo(b["created_at"] as int));
    return out;
  }

  Future<double> customerDeliveredRevenue(int customerId) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery("""
      SELECT COALESCE(SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),0) AS total
      FROM items i JOIN orders o ON o.id=i.order_id
      WHERE o.customer_id=? AND o.delivered_at IS NOT NULL AND i.status='confirmed'
    """, [customerId]);
    return (res.first["total"] as num).toDouble();
  }

  // =========================
  // Cash Drawer
  // =========================
  Future<int> addCashTxn({
    required String type, // opening, customer_payment, supplier_purchase, shipping_expense, expense, profit_distribution
    required double amountEgp, // + دخل, - صرف
    String? note,
    int? customerId,
    int? orderId,
    DateTime? date,
  }) async {
    final d = await AppDb.instance.db;
    return d.insert("cash_txns", {
      "created_at": (date ?? DateTime.now()).millisecondsSinceEpoch,
      "type": type,
      "amount_egp": amountEgp,
      "note": note,
      "customer_id": customerId,
      "order_id": orderId,
    });
  }

  Future<double> cashBalance() async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery("SELECT COALESCE(SUM(amount_egp),0) AS total FROM cash_txns");
    return (res.first["total"] as num).toDouble();
  }

  Future<List<Map<String, Object?>>> listCashTxns({int limit = 200}) async {
    final d = await AppDb.instance.db;
    return d.query("cash_txns", orderBy: "created_at DESC", limit: limit);
  }

  Future<double> cashSumBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      "SELECT COALESCE(SUM(amount_egp),0) AS total FROM cash_txns WHERE created_at BETWEEN ? AND ?",
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (res.first["total"] as num).toDouble();
  }

  Future<double> sumConfirmedCostAllOpenOrders() async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery("""
      SELECT COALESCE(SUM((i.buy_price_sar * i.rate_egp) * COALESCE(i.qty,0)),0) AS total
      FROM items i
      JOIN orders o ON o.id=i.order_id
      WHERE i.status='confirmed'
    """);
    return (res.first["total"] as num).toDouble();
  }

  // =========================
  // DashboardSummary (typed)
  // =========================
  Future<DashboardSummary> dashboardSummary(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;

    Future<int> _count(String status) async {
      final r = await d.rawQuery("SELECT COUNT(*) AS c FROM items WHERE status=?", [status]);
      return (r.first["c"] as num).toInt();
    }

    Future<double> _sumSell(String status) async {
      final r = await d.rawQuery("""
        SELECT COALESCE(SUM(((price_sar*rate_egp)+profit_egp)*COALESCE(qty,0)),0) AS total
        FROM items
        WHERE status=?
      """, [status]);
      return (r.first["total"] as num).toDouble();
    }

    final pendingCount = await _count("pending");
    final confirmedCount = await _count("confirmed");
    final cancelledCount = await _count("cancelled");

    final pendingTotal = await _sumSell("pending");
    final confirmedTotal = await _sumSell("confirmed");
    final cancelledTotal = await _sumSell("cancelled");

    final delivered = await d.rawQuery("SELECT COUNT(*) AS c FROM orders WHERE delivered_at IS NOT NULL");
    final deliveredOrders = (delivered.first["c"] as num).toInt();

    final deliveredRevenue = await sumDeliveredRevenueBetween(from, to);
    final deliveredCost = await sumDeliveredCostBetween(from, to);
    final orderExpenses = await sumExpensesBetween(from, to);
    final payments = await sumPaymentsBetween(from, to);

    return DashboardSummary(
      pendingCount: pendingCount,
      confirmedCount: confirmedCount,
      cancelledCount: cancelledCount,
      pendingTotal: pendingTotal,
      confirmedTotal: confirmedTotal,
      cancelledTotal: cancelledTotal,
      deliveredOrders: deliveredOrders,
      deliveredRevenue: deliveredRevenue,
      deliveredCost: deliveredCost,
      orderExpenses: orderExpenses,
      payments: payments,
    );
  }
  // For Finance screen: revenue for a customer (delivered orders only)
Future<double> sumRevenueForCustomerDelivered(int customerId) async {
  final d = await AppDb.instance.db;
  final res = await d.rawQuery("""
    SELECT COALESCE(SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),0) AS total
    FROM items i
    JOIN orders o ON o.id = i.order_id
    WHERE o.customer_id = ?
      AND o.delivered_at IS NOT NULL
      AND i.status = 'confirmed'
  """, [customerId]);

  return (res.first["total"] as num).toDouble();
}

// For Dashboard: confirmed cost for all items (supplier need)
Future<double> sumConfirmedCostAll() async {
  final d = await AppDb.instance.db;
  final res = await d.rawQuery("""
    SELECT COALESCE(SUM((buy_price_sar * rate_egp) * COALESCE(qty,0)),0) AS total
    FROM items
    WHERE status='confirmed'
  """);
  return (res.first["total"] as num).toDouble();
}
  String _normWhats(String? w) {
  if (w == null) return "";
  var s = w.trim();
  s = s.replaceAll(" ", "");
  s = s.replaceAll("-", "");
  s = s.replaceAll("(", "");
  s = s.replaceAll(")", "");
  // شيل + و 00
  if (s.startsWith("+")) s = s.substring(1);
  if (s.startsWith("00")) s = s.substring(2);
  return s;
}
 // هل للعميل طلبات؟
Future<bool> customerHasOrders(int customerId) async {
  final d = await AppDb.instance.db;
  final r = await d.rawQuery(
    "SELECT COUNT(*) AS c FROM orders WHERE customer_id=?",
    [customerId],
  );
  return (r.first["c"] as int) > 0;
}

// رصيد العميل
Future<double> customerBalance(int customerId) async {
  final revenue = await customerDeliveredRevenue(customerId);
  final paid = await sumPaymentsForCustomer(customerId);
  return revenue - paid;
}

 Future<Customer?> findCustomerByWhatsapp(String whatsapp) async {
  final d = await AppDb.instance.db;
  final norm = _normWhats(whatsapp);
  final res = await d.rawQuery("""
    SELECT * FROM customers
    WHERE whatsapp IS NOT NULL
  """);

  for (final r in res) {
    if (_normWhats(r["whatsapp"] as String?) == norm) {
      return Customer.fromMap(r);
    }
  }
  return null;
}

}

