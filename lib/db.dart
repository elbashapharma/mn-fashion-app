import "dart:async";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sqflite/sqflite.dart";

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, "shein_pricing.db");

    return openDatabase(
      path,
      version: 3,
      onCreate: (database, version) async {
        await database.execute("""
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            whatsapp TEXT
          );
        """);

        await database.execute("""
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            default_rate REAL NOT NULL DEFAULT 0,
            delivered_at INTEGER,
            FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
          );
        """);

        await database.execute("""
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            image_path TEXT NOT NULL,
            note TEXT,
            price_sar REAL NOT NULL DEFAULT 0,
            rate_egp REAL NOT NULL DEFAULT 0,
            profit_egp REAL NOT NULL DEFAULT 0,
            shipping TEXT NOT NULL DEFAULT 'air',
            status TEXT NOT NULL DEFAULT 'pending',
            size TEXT,
            qty INTEGER,
            FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
          );
        """);

        await database.execute("""
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER,
            customer_id INTEGER,
            amount_egp REAL NOT NULL,
            type TEXT NOT NULL,
            note TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
          );
        """);

        // ✅ NEW: payments
        await database.execute("""
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            order_id INTEGER,
            amount_egp REAL NOT NULL,
            note TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE,
            FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE SET NULL
          );
        """);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE orders ADD COLUMN delivered_at INTEGER;");

          await db.execute("""
            CREATE TABLE IF NOT EXISTS expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              order_id INTEGER,
              customer_id INTEGER,
              amount_egp REAL NOT NULL,
              type TEXT NOT NULL,
              note TEXT,
              created_at INTEGER NOT NULL,
              FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
              FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
            );
          """);
        }

        if (oldVersion < 3) {
          await db.execute("""
            CREATE TABLE IF NOT EXISTS payments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customer_id INTEGER NOT NULL,
              order_id INTEGER,
              amount_egp REAL NOT NULL,
              note TEXT,
              created_at INTEGER NOT NULL,
              FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE,
              FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE SET NULL
            );
          """);
        }
      },
    );
  }
}
