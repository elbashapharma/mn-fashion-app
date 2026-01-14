enum ShippingType { air, land }
enum ItemStatus { pending, confirmed, cancelled }

class Customer {
  final int? id;
  final String name;
  final String? whatsapp;
  final String? deliveryAddress;
  final int isArchived; // 0 or 1

  Customer({
    this.id,
    required this.name,
    this.whatsapp,
    this.deliveryAddress,
    this.isArchived = 0,
  });

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
        id: (m["id"] as num?)?.toInt(),
        name: (m["name"] as String?) ?? "",
        whatsapp: m["whatsapp"] as String?,
        deliveryAddress: m["delivery_address"] as String?,
        isArchived: (m["is_archived"] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toMap() => {
        "id": id,
        "name": name,
        "whatsapp": whatsapp,
        "delivery_address": deliveryAddress,
        "is_archived": isArchived,
      };
}


class OrderHeader {
  final int? id;
  final int customerId;
  final DateTime createdAt;
  final double defaultRate;
  final DateTime? deliveredAt;

  OrderHeader({
    this.id,
    required this.customerId,
    required this.createdAt,
    required this.defaultRate,
    this.deliveredAt,
  });

  static OrderHeader fromMap(Map<String, Object?> m) => OrderHeader(
        id: m["id"] as int?,
        customerId: m["customer_id"] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m["created_at"] as int),
        defaultRate: (m["default_rate"] as num).toDouble(),
        deliveredAt: (m["delivered_at"] == null) ? null : DateTime.fromMillisecondsSinceEpoch(m["delivered_at"] as int),
      );
}

class OrderItem {
  final int? id;
  final int orderId;

  final String imagePath;
  final String? note;

  final double buyPriceSar; // Buy SAR
  final double priceSar; // Sell SAR

  final double rateEgp;
  final double profitEgp; // extra profit per piece (EGP)

  final ShippingType shipping;
  final ItemStatus status;

  final String? size;
  final int? qty;

  OrderItem({
    this.id,
    required this.orderId,
    required this.imagePath,
    this.note,
    required this.buyPriceSar,
    required this.priceSar,
    required this.rateEgp,
    required this.profitEgp,
    required this.shipping,
    required this.status,
    this.size,
    this.qty,
  });

  int get q => qty ?? 0;

  // ✅ حسابات
  double get revenueEgp => (priceSar * rateEgp) * q;
  double get costEgp => (buyPriceSar * rateEgp) * q;
  double get extraProfitEgpTotal => profitEgp * q;
  double get grossProfitEgp => (revenueEgp - costEgp) + extraProfitEgpTotal;

  // ✅ Backward compatibility (PDF/شاشات قديمة)
  double get unitPriceEgp => ((priceSar * rateEgp) + profitEgp);
  double get lineTotal => unitPriceEgp * q;

  OrderItem copyWith({
    double? buyPriceSar,
    double? priceSar,
    double? rateEgp,
    double? profitEgp,
    ShippingType? shipping,
    ItemStatus? status,
    String? note,
    String? size,
    int? qty,
  }) =>
      OrderItem(
        id: id,
        orderId: orderId,
        imagePath: imagePath,
        note: note ?? this.note,
        buyPriceSar: buyPriceSar ?? this.buyPriceSar,
        priceSar: priceSar ?? this.priceSar,
        rateEgp: rateEgp ?? this.rateEgp,
        profitEgp: profitEgp ?? this.profitEgp,
        shipping: shipping ?? this.shipping,
        status: status ?? this.status,
        size: size ?? this.size,
        qty: qty ?? this.qty,
      );

  Map<String, Object?> toMap() => {
        "id": id,
        "order_id": orderId,
        "image_path": imagePath,
        "note": note,
        "buy_price_sar": buyPriceSar,
        "price_sar": priceSar,
        "rate_egp": rateEgp,
        "profit_egp": profitEgp,
        "shipping": shipping.name,
        "status": status.name,
        "size": size,
        "qty": qty,
      };

  static ShippingType _shipFrom(String s) => s == "land" ? ShippingType.land : ShippingType.air;

  static ItemStatus _statusFrom(String s) {
    switch (s) {
      case "confirmed":
        return ItemStatus.confirmed;
      case "cancelled":
        return ItemStatus.cancelled;
      default:
        return ItemStatus.pending;
    }
  }

  static OrderItem fromMap(Map<String, Object?> m) => OrderItem(
        id: m["id"] as int?,
        orderId: m["order_id"] as int,
        imagePath: m["image_path"] as String,
        note: m["note"] as String?,
        buyPriceSar: (m["buy_price_sar"] as num).toDouble(),
        priceSar: (m["price_sar"] as num).toDouble(),
        rateEgp: (m["rate_egp"] as num).toDouble(),
        profitEgp: (m["profit_egp"] as num).toDouble(),
        shipping: _shipFrom(m["shipping"] as String),
        status: _statusFrom(m["status"] as String),
        size: m["size"] as String?,
        qty: m["qty"] as int?,
      );
}
