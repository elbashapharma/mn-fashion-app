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
    final rows = await d.query("orders", where: "customer_id=?", whereArgs: [customerId], orderBy: "id DESC");
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
    final rows = await d.query("items", where: "order_id=?", whereArgs: [orderId], orderBy: "id ASC");
    return rows.map(OrderItem.fromMap).toList();
  }
}
