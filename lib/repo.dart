import "package:sqflite/sqflite.dart";
import "db.dart";
import "models.dart";

class Repo {
  Repo._();
  static final Repo instance = Repo._();

  Future<int> addCustomer(Customer c) async {
    final Database d = await AppDb.instance.db;
    return d.insert("customers", c.toMap()..remove("id"));
  }

  Future<List<Customer>> listCustomers() async {
    final d = await AppDb.instance.db;
    final rows = await d.query("customers", orderBy: "id DESC");
    return rows.map(Customer.fromMap).toList();
  }

  Future<void> deleteCustomer(int id) async {
    final d = await AppDb.instance.db;
    await d.delete("customers", where: "id=?", whereArgs: [id]);
  }

  Future<int> createOrder(int customerId, double defaultRate) async {
    final d = await AppDb.instance.db;
    return d.insert("orders", {
      "customer_id": customerId,
      "created_at": DateTime.now().millisecondsSinceEpoch,
      "default_rate": defaultRate,
    });
  }

  Future<void> updateOrderDefaultRate(int orderId, double defaultRate) async {
    final d = await AppDb.instance.db;
    await d.update("orders", {"default_rate": defaultRate}, where: "id=?", whereArgs: [orderId]);
  }

  Future<List<OrderHeader>> listOrdersForCustomer(int customerId) async {
    final d = await AppDb.instance.db;
    final rows = await d.query(
      "orders",
      where: "customer_id=?",
      whereArgs: [customerId],
      orderBy: "id DESC",
    );
    return rows.map(OrderHeader.fromMap).toList();
  }

  Future<OrderHeader> getOrder(int orderId) async {
    final d = await AppDb.instance.db;
    final rows = await d.query("orders", where: "id=?", whereArgs: [orderId], limit: 1);
    return OrderHeader.fromMap(rows.first);
  }

  Future<Customer> getCustomer(int customerId) async {
    final d = await AppDb.instance.db;
    final rows = await d.query("customers", where: "id=?", whereArgs: [customerId], limit: 1);
    return Customer.fromMap(rows.first);
  }

  Future<int> addItem(OrderItem item) async {
    final d = await AppDb.instance.db;
    return d.insert("items", item.toMap()..remove("id"));
  }

  Future<void> updateItem(OrderItem item) async {
    final d = await AppDb.instance.db;
    await d.update("items", item.toMap()..remove("id"), where: "id=?", whereArgs: [item.id]);
  }

  Future<void> deleteItem(int itemId) async {
    final d = await AppDb.instance.db;
    await d.delete("items", where: "id=?", whereArgs: [itemId]);
  }

  Future<List<OrderItem>> listItems(int orderId) async {
    final d = await AppDb.instance.db;
    final rows = await d.query(
      "items",
      where: "order_id=?",
      whereArgs: [orderId],
      orderBy: "id ASC",
    );
    return rows.map(OrderItem.fromMap).toList();
  }
    // --------- Delivery ----------
  Future<void> markOrderDelivered(int orderId, DateTime deliveredAt) async {
    final d = await AppDb.instance.db;
    await d.update(
      "orders",
      {"delivered_at": deliveredAt.millisecondsSinceEpoch},
      where: "id=?",
      whereArgs: [orderId],
    );
  }

  // --------- Expenses ----------
  Future<int> addExpense({
    int? orderId,
    int? customerId,
    required double amountEgp,
    required String type, // shipping / other
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
      """
      SELECT COALESCE(SUM(amount_egp),0) AS total
      FROM expenses
      WHERE created_at BETWEEN ? AND ?
      """,
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (res.first["total"] as num).toDouble();
  }

  // --------- Revenue (Delivered orders only) ----------
  Future<double> sumRevenueBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;

    // الإيراد = مجموع (سعر القطعة بالجنيه * الكمية) للأصناف المؤكدة
    // وسعر القطعة بالجنيه عندك = (price_sar * rate_egp) + profit_egp
    final res = await d.rawQuery(
      """
      SELECT COALESCE(SUM( ((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0) ),0) AS total
      FROM items i
      JOIN orders o ON o.id = i.order_id
      WHERE i.status = 'confirmed'
        AND o.delivered_at IS NOT NULL
        AND o.delivered_at BETWEEN ? AND ?
      """,
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return (res.first["total"] as num).toDouble();
  }
  // ---------- Payments ----------
  Future<int> addPayment({
    required int customerId,
    int? orderId,
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
      """
      SELECT COALESCE(SUM(amount_egp),0) AS total
      FROM payments
      WHERE created_at BETWEEN ? AND ?
      """,
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

  // ---------- Revenue: delivered orders only ----------
  Future<double> sumRevenueForCustomerDelivered(int customerId) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      """
      SELECT COALESCE(SUM( ((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0) ),0) AS total
      FROM items i
      JOIN orders o ON o.id = i.order_id
      WHERE o.customer_id = ?
        AND i.status = 'confirmed'
        AND o.delivered_at IS NOT NULL
      """,
      [customerId],
    );
    return (res.first["total"] as num).toDouble();
  }

  Future<double> customerBalance(int customerId) async {
    final revenue = await sumRevenueForCustomerDelivered(customerId);
    final paid = await sumPaymentsForCustomer(customerId);
    return revenue - paid; // لو + يبقى عليه فلوس
  }

 Future<List<Map<String, Object?>>> deliveredOrdersForCustomer(int customerId) async {
  final d = await AppDb.instance.db;
  return d.rawQuery(
    """
    SELECT 
      o.id AS order_id,
      o.delivered_at AS delivered_at,
      COALESCE(SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),0) AS amount
    FROM orders o
    LEFT JOIN items i ON i.order_id = o.id AND i.status='confirmed'
    WHERE o.customer_id = ?
      AND o.delivered_at IS NOT NULL
    GROUP BY o.id, o.delivered_at
    ORDER BY o.delivered_at ASC
    """,
    [customerId],
  );
}

Future<List<Map<String, Object?>>> paymentsForCustomer(int customerId) async {
  final d = await AppDb.instance.db;
  return d.query(
    "payments",
    where: "customer_id=?",
    whereArgs: [customerId],
    orderBy: "created_at ASC",
  );
}


}
