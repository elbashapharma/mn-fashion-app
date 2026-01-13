import "db.dart";
import "models.dart";

class Repo {
  Repo._();
  static final Repo instance = Repo._();

  // ---------------- Customers ----------------
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

  // ---------------- Orders ----------------
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
    await d.update(
      "orders",
      {"default_rate": rate},
      where: "id=?",
      whereArgs: [orderId],
    );
  }

  // ✅ زر تم التسليم
  Future<void> markOrderDelivered(int orderId, DateTime deliveredAt) async {
    final d = await AppDb.instance.db;
    await d.update(
      "orders",
      {"delivered_at": deliveredAt.millisecondsSinceEpoch},
      where: "id=?",
      whereArgs: [orderId],
    );
  }

  // ---------------- Items ----------------
  Future<List<OrderItem>> listItems(int orderId) async {
    final d = await AppDb.instance.db;
    final res = await d.query(
      "items",
      where: "order_id=?",
      whereArgs: [orderId],
      orderBy: "id ASC",
    );
    return res.map(OrderItem.fromMap).toList();
  }

  Future<int> addItem(OrderItem it) async {
    final d = await AppDb.instance.db;
    return d.insert("items", it.toMap());
  }

  Future<void> updateItem(OrderItem it) async {
    final d = await AppDb.instance.db;
    await d.update(
      "items",
      it.toMap(),
      where: "id=?",
      whereArgs: [it.id],
    );
  }

  Future<void> deleteItem(int id) async {
    final d = await AppDb.instance.db;
    await d.delete("items", where: "id=?", whereArgs: [id]);
  }

  // ---------------- Expenses ----------------
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

  // ---------------- Payments ----------------
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

  Future<double> sumPaymentsForCustomer(int customerId) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      "SELECT COALESCE(SUM(amount_egp),0) AS total FROM payments WHERE customer_id=?",
      [customerId],
    );
    return (res.first["total"] as num).toDouble();
  }

  // ---------------- Revenue / Profit Between Dates ----------------
  // ✅ Revenue based on SellSAR + ExtraProfit (confirmed items) for delivered orders within period
  Future<double> sumRevenueBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;
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

  // ✅ Cost based on BuySAR for delivered orders within period
  Future<double> sumCostBetween(DateTime from, DateTime to) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      """
      SELECT COALESCE(SUM( (i.buy_price_sar * i.rate_egp) * COALESCE(i.qty,0) ),0) AS total
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

  // ---------------- Customer Balance ----------------
  Future<double> sumRevenueForCustomerDelivered(int customerId) async {
    final d = await AppDb.instance.db;
    final res = await d.rawQuery(
      """
      SELECT COALESCE(
        SUM(((i.price_sar * i.rate_egp) + i.profit_egp) * COALESCE(i.qty,0)),
        0
      ) AS total
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
    return revenue - paid;
  }

  // ---------------- Statement helpers ----------------
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
