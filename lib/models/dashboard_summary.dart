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
