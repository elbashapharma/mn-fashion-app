import "db.dart";
import "models.dart";
import 'models/dashboard_summary.dart';

class Repo {
  Repo._();
  static final Repo instance = Repo._();

  // ---------- Customers ----------
  Future<List<Customer>> listCustomers() async {
    final d = await AppDb.instance.db;
    final res = await d.query("customers", orderBy: "name ASC");
    return res.map(Customer.fromMap).toList();
  }

  Future<Customer> getCustomer(int id) async {
    final d = await AppDb.instance.db;
    final res = await d.query("customers", where: "id=?", whereArgs: [id]);
    return Customer.fromMap(res.first);
  }

  Future<int> addCustomer(Customer c) async {
    final d = await AppDb.instance.db;
    return d.insert("customers", c.toMap());
  }

  Future<void> deleteCustomer(int id) async {
    final d = await AppDb.instance.db;
    await d.delete("customers", where: "id=?", whereArgs: [id]);
  }

  // ---------- Orders ----------
  Future<int> createOrder(int customerId, double defaultRate) async {
    final d = await AppDb.instance.db;
    return d.insert("orders", {
      "customer_id": customerId,
      "created_at": DateTime.now().millisecondsSinceEpoch,
      "default_rate": defaultRate,
      "delivered_at": null,
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

  // ✅ ---------- PAYMENTS ----------
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

  // ---------- Dashboard summary ----------
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
      // =========================
  // Customer Statement (Ledger)
  // =========================

  // returns list of maps:
  // {type: 'order'|'payment' , created_at:int , order_id:int? , amount:double , note:String? }
  Future<List<Map<String, Object?>>> customerLedger(int customerId) async {
    final d = await AppDb.instance.db;

    // orders (delivered only) as DEBIT
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

    // payments (all) as CREDIT
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
  // Profit calculations
  // =========================
  Future<double> sumDeliveredRevenueBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery("""
      SELECT COALESCE(SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),0) AS total
      FROM items i JOIN orders o ON o.id=i.order_id
      WHERE i.status='confirmed' AND o.delivered_at IS NOT NULL
        AND o.created_at BETWEEN ? AND ?
    """, [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]);
    return (res.first["total"] as num).toDouble();
  }

  Future<double> sumDeliveredCostBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery("""
      SELECT COALESCE(SUM((i.buy_price_sar * i.rate_egp) * COALESCE(i.qty,0)),0) AS total
      FROM items i JOIN orders o ON o.id=i.order_id
      WHERE i.status='confirmed' AND o.delivered_at IS NOT NULL
        AND o.created_at BETWEEN ? AND ?
    """, [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]);
    return (res.first["total"] as num).toDouble();
  }

  }
    // =========================
  // Customer delivered revenue (for Finance screen)
  // =========================
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

  // =========================
  // Customer ledger (statement)
  // orders delivered => DEBIT
  // payments => CREDIT (order_id may be null = تحت الحساب)
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
// ======== DASHBOARD MODELS ========

class DashboardSummary {
  final int pendingCount;
  final int confirmedCount;
  final int cancelledCount;

  final double pendingTotal;
  final double confirmedTotal;
  final double cancelledTotal;

  final int deliveredOrders;

  final double deliveredRevenue;
  final double deliveredCost;
  final double orderExpenses;
  final double payments;

  DashboardSummary({
    required this.pendingCount,
    required this.confirmedCount,
    required this.cancelledCount,
    required this.pendingTotal,
    required this.confirmedTotal,
    required this.cancelledTotal,
    required this.deliveredOrders,
    required this.deliveredRevenue,
    required this.deliveredCost,
    required this.orderExpenses,
    required this.payments,
  });
}

// ======== CASH ========

Future<int> addCashTxn({
  required String type,
  required double amountEgp,
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

// ======== CONFIRMED COST (supplier need) ========

Future<double> sumConfirmedCostAll() async {
  final d = await AppDb.instance.db;
  final res = await d.rawQuery("""
    SELECT COALESCE(SUM((buy_price_sar * rate_egp) * COALESCE(qty,0)),0) AS total
    FROM items
    WHERE status='confirmed'
  """);
  return (res.first["total"] as num).toDouble();
}

// ======== PAYMENTS SUM BETWEEN ========

Future<double> sumPaymentsBetween(DateTime from, DateTime to) async {
  final d = await AppDb.instance.db;
  final res = await d.rawQuery(
    "SELECT COALESCE(SUM(amount_egp),0) AS total FROM payments WHERE created_at BETWEEN ? AND ?",
    [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
  );
  return (res.first["total"] as num).toDouble();
}

// ======== EXPENSES SUM BETWEEN (orders expenses table) ========

Future<double> sumExpensesBetween(DateTime from, DateTime to) async {
  final d = await AppDb.instance.db;
  final res = await d.rawQuery(
    "SELECT COALESCE(SUM(amount_egp),0) AS total FROM expenses WHERE created_at BETWEEN ? AND ?",
    [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
  );
  return (res.first["total"] as num).toDouble();
}

// ======== DELIVERED REVENUE/COST BETWEEN ========

Future<double> sumDeliveredRevenueBetween(DateTime from, DateTime to) async {
  final d = await AppDb.instance.db;
  final res = await d.rawQuery("""
    SELECT COALESCE(SUM(((price_sar*rate_egp)+profit_egp)*COALESCE(qty,0)),0) AS total
    FROM items i
    JOIN orders o ON o.id=i.order_id
    WHERE i.status='confirmed'
      AND o.delivered_at IS NOT NULL
      AND o.created_at BETWEEN ? AND ?
  """, [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]);
  return (res.first["total"] as num).toDouble();
}

Future<double> sumDeliveredCostBetween(DateTime from, DateTime to) async {
  final d = await AppDb.instance.db;
  final res = await d.rawQuery("""
    SELECT COALESCE(SUM((buy_price_sar*rate_egp)*COALESCE(qty,0)),0) AS total
    FROM items i
    JOIN orders o ON o.id=i.order_id
    WHERE i.status='confirmed'
      AND o.delivered_at IS NOT NULL
      AND o.created_at BETWEEN ? AND ?
  """, [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]);
  return (res.first["total"] as num).toDouble();
}

// ======== DASHBOARD SUMMARY ========

Future<DashboardSummary> dashboardSummary(DateTime from, DateTime to) async {
  final d = await AppDb.instance.db;

  // counts by status
  Future<int> _count(String status) async {
    final r = await d.rawQuery("SELECT COUNT(*) AS c FROM items WHERE status=?", [status]);
    return (r.first["c"] as int);
  }

  Future<double> _sumSell(String status) async {
    // sum sell in EGP for items status (requires qty)
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

  final delivered = await d.rawQuery("""
    SELECT COUNT(*) AS c
    FROM orders
    WHERE delivered_at IS NOT NULL
  """);
  final deliveredOrders = (delivered.first["c"] as int);

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

}
