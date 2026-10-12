class DashboardStats {
  final double totalDebtsInYer; // إجمالي الديون المستحقة على العملاء
  final double collectedCapitalInYer; // رأس المال المحصل المقبوض فعلياً
  final double remainingCapitalInYer; // رأس المال المتبقي في السوق / بضائع
  final double totalCapitalInYer; // رأس المال الإجمالي (المحصل + المتبقي)
  final double netProfitInYer; // صافي الأرباح الإجمالية
  final int totalOrdersCount;
  final int pendingOrdersCount;
  final int activeShipmentsCount;
  final int totalCustomersCount;
  final int debtorsCount; // عدد العملاء المدينين

  DashboardStats({
    required this.totalDebtsInYer,
    required this.collectedCapitalInYer,
    required this.remainingCapitalInYer,
    required this.totalCapitalInYer,
    required this.netProfitInYer,
    required this.totalOrdersCount,
    required this.pendingOrdersCount,
    required this.activeShipmentsCount,
    required this.totalCustomersCount,
    required this.debtorsCount,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalDebtsInYer: 0,
      collectedCapitalInYer: 0,
      remainingCapitalInYer: 0,
      totalCapitalInYer: 0,
      netProfitInYer: 0,
      totalOrdersCount: 0,
      pendingOrdersCount: 0,
      activeShipmentsCount: 0,
      totalCustomersCount: 0,
      debtorsCount: 0,
    );
  }
}
