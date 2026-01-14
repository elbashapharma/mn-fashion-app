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
      version: 7, // ✅ v7: customers archive/address + whatsapp unique + orders status/merge + purchase flow tables
      onCreate: (database, version) async {
        // -----------------
        // Customers
        // -----------------
        await database.execute("""
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            whatsapp TEXT,
            delivery_address TEXT,
            is_archived INTEGER NOT NULL DEFAULT 0
          );
        """);

        // whatsapp unique (null allowed)
        await database.execute("""
          CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_whatsapp
          ON customers(whatsapp);
        """);

        // -----------------
        // Orders
        // -----------------
        await database.execute("""
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            default_rate REAL NOT NULL DEFAULT 0,
            delivered_at INTEGER,
            status TEXT NOT NULL DEFAULT 'pending', -- pending/confirmed/merged/cancelled
            merged_into_order_id INTEGER,
            FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
          );
        """);

        // -----------------
        // Items
        // -----------------
        await database.execute("""
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            image_path TEXT NOT NULL,
            note TEXT,
            buy_price_sar REAL NOT NULL DEFAULT 0,
            price_sar REAL NOT NULL DEFAULT 0,
            rate_egp REAL NOT NULL DEFAULT 0,
            profit_egp REAL NOT NULL DEFAULT 0,
            shipping TEXT NOT NULL DEFAULT 'air',
            status TEXT NOT NULL DEFAULT 'pending',
            size TEXT,
            qty INTEGER NOT NULL DEFAULT 1,

            -- Receiving/Delivery tracking
            received_qty INTEGER NOT NULL DEFAULT 0,
            delivered_qty INTEGER NOT NULL DEFAULT 0,
            missing_qty INTEGER NOT NULL DEFAULT 0,

            -- Purchase link
            po_id INTEGER,
            po_item_id INTEGER,

            -- Availability flag (cancelled from PO / not available)
            is_cancelled INTEGER NOT NULL DEFAULT 0,

            FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE
          );
        """);

        // -----------------
        // Expenses
        // -----------------
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

        // -----------------
        // Payments
        // -----------------
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

        // -----------------
        // Cash Drawer (opening + all movements)
        // -----------------
        await database.execute("""
          CREATE TABLE cash_txns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at INTEGER NOT NULL,
            type TEXT NOT NULL,
            amount_egp REAL NOT NULL,
            note TEXT,
            customer_id INTEGER,
            order_id INTEGER
          );
        """);

        // -----------------
        // Suppliers + Purchase Orders (Shein)
        // -----------------
        await database.execute("""
          CREATE TABLE suppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
          );
        """);

        await database.execute("""
          CREATE TABLE purchase_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_id INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'draft', -- draft/sent/received_partial/closed
            created_at INTEGER NOT NULL,
            rate_egp REAL NOT NULL DEFAULT 0,
            note TEXT,
            FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
          );
        """);

        await database.execute("""
          CREATE TABLE purchase_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            po_id INTEGER NOT NULL,
            image_path TEXT NOT NULL,
            buy_price_sar REAL NOT NULL DEFAULT 0,
            rate_egp REAL NOT NULL DEFAULT 0,
            qty_requested INTEGER NOT NULL DEFAULT 0,
            qty_received INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'open', -- open/cancelled/backorder
            note TEXT,
            FOREIGN KEY(po_id) REFERENCES purchase_orders(id) ON DELETE CASCADE
          );
        """);

        await database.execute("""
          CREATE TABLE purchase_item_allocations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            po_item_id INTEGER NOT NULL,
            order_item_id INTEGER NOT NULL,
            qty_allocated INTEGER NOT NULL DEFAULT 0,
            qty_received INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(po_item_id) REFERENCES purchase_items(id) ON DELETE CASCADE,
            FOREIGN KEY(order_item_id) REFERENCES items(id) ON DELETE CASCADE
          );
        """);

        // Ensure supplier "Shein" exists
        await database.execute("INSERT OR IGNORE INTO suppliers(name) VALUES ('Shein');");
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // =========================
        // Existing upgrades (safe)
        // =========================

        // delivered_at
        try {
          await db.execute("ALTER TABLE orders ADD COLUMN delivered_at INTEGER;");
        } catch (_) {}

        // buy_price_sar
        try {
          await db.execute("ALTER TABLE items ADD COLUMN buy_price_sar REAL NOT NULL DEFAULT 0;");
        } catch (_) {}

        // expenses
        await db.execute("""
          CREATE TABLE IF NOT EXISTS expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER,
            customer_id INTEGER,
            amount_egp REAL NOT NULL,
            type TEXT NOT NULL,
            note TEXT,
            created_at INTEGER NOT NULL
          );
        """);

        // payments
        await db.execute("""
          CREATE TABLE IF NOT EXISTS payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            order_id INTEGER,
            amount_egp REAL NOT NULL,
            note TEXT,
            created_at INTEGER NOT NULL
          );
        """);

        // cash_txns
        await db.execute("""
          CREATE TABLE IF NOT EXISTS cash_txns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at INTEGER NOT NULL,
            type TEXT NOT NULL,
            amount_egp REAL NOT NULL,
            note TEXT,
            customer_id INTEGER,
            order_id INTEGER
          );
        """);

        // =========================
        // v7 Migration
        // =========================

        // customers: delivery_address + archived
        try {
          await db.execute("ALTER TABLE customers ADD COLUMN delivery_address TEXT;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE customers ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0;");
        } catch (_) {}

        // whatsapp unique (null allowed)
        try {
          await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_whatsapp ON customers(whatsapp);");
        } catch (_) {}

        // orders: status + merge link
        try {
          await db.execute("ALTER TABLE orders ADD COLUMN status TEXT NOT NULL DEFAULT 'pending';");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE orders ADD COLUMN merged_into_order_id INTEGER;");
        } catch (_) {}

        // items: qty defaults + receive/deliver tracking + purchase link
        try {
          await db.execute("ALTER TABLE items ADD COLUMN received_qty INTEGER NOT NULL DEFAULT 0;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE items ADD COLUMN delivered_qty INTEGER NOT NULL DEFAULT 0;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE items ADD COLUMN missing_qty INTEGER NOT NULL DEFAULT 0;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE items ADD COLUMN po_id INTEGER;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE items ADD COLUMN po_item_id INTEGER;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE items ADD COLUMN is_cancelled INTEGER NOT NULL DEFAULT 0;");
        } catch (_) {}

        // Ensure qty not null + not less than 1 (for old DBs where qty was nullable)
        try {
          await db.execute("UPDATE items SET qty=1 WHERE qty IS NULL OR qty<1;");
        } catch (_) {}

        // Suppliers + Purchase tables
        await db.execute("""
          CREATE TABLE IF NOT EXISTS suppliers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
          );
        """);

        await db.execute("""
          CREATE TABLE IF NOT EXISTS purchase_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_id INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'draft', -- draft/sent/received_partial/closed
            created_at INTEGER NOT NULL,
            rate_egp REAL NOT NULL DEFAULT 0,
            note TEXT,
            FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
          );
        """);

        await db.execute("""
          CREATE TABLE IF NOT EXISTS purchase_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            po_id INTEGER NOT NULL,
            image_path TEXT NOT NULL,
            buy_price_sar REAL NOT NULL DEFAULT 0,
            rate_egp REAL NOT NULL DEFAULT 0,
            qty_requested INTEGER NOT NULL DEFAULT 0,
            qty_received INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'open', -- open/cancelled/backorder
            note TEXT,
            FOREIGN KEY(po_id) REFERENCES purchase_orders(id) ON DELETE CASCADE
          );
        """);

        await db.execute("""
          CREATE TABLE IF NOT EXISTS purchase_item_allocations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            po_item_id INTEGER NOT NULL,
            order_item_id INTEGER NOT NULL,
            qty_allocated INTEGER NOT NULL DEFAULT 0,
            qty_received INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(po_item_id) REFERENCES purchase_items(id) ON DELETE CASCADE,
            FOREIGN KEY(order_item_id) REFERENCES items(id) ON DELETE CASCADE
          );
        """);

        // Ensure supplier "Shein" exists
        await db.execute("INSERT OR IGNORE INTO suppliers(name) VALUES ('Shein');");
      },
    );
  }
}
