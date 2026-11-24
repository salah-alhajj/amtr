class DashboardStats {
  final double totalDebtsInYer; // إجمالي الديون المستحقة على العملاء
  final double collectedCapitalInYer; // رأس المال المحصل المقبوض فعلياً
  final double netCashInHandInYer; // صافي الكاش بيدك بعد المصاريف والمسحوبات
  final double remainingCapitalInYer; // رأس المال المتبقي في السوق / بضائع
  final double totalCapitalInYer; // رأس المال الإجمالي (المحصل + المتبقي)
  final double netProfitInYer; // صافي الأرباح الإجمالية (بعد المصاريف)
  final double totalExpensesInYer; // إجمالي المصاريف التشغيلية
  final double personalDrawingsInYer; // إجمالي المسحوبات الشخصية (للبيت)
  final double todayCashInYer; // المقبوضات النقدية اليوم
  final double todaySalesInYer; // مبيعات اليوم
  final double todayBusinessExpensesInYer; // مصاريف الشغل اليوم
  final int totalOrdersCount;
  final int pendingOrdersCount;
  final int todayOrdersCount;
  final int lowStockCount;
  final int activeShipmentsCount;
  final int totalCustomersCount;
  final int debtorsCount; // عدد العملاء المدينين
  final List<double> weeklySalesInYer; // مبيعات الأيام السبعة الماضية الحقيقية بالريال اليمني
  final List<String> weeklySalesDayKeys; // مفاتيح أيام الأسبوع للأيام السبعة

  DashboardStats({
    required this.totalDebtsInYer,
    required this.collectedCapitalInYer,
    this.netCashInHandInYer = 0,
    required this.remainingCapitalInYer,
    required this.totalCapitalInYer,
    required this.netProfitInYer,
    this.totalExpensesInYer = 0,
    this.personalDrawingsInYer = 0,
    this.todayCashInYer = 0,
    this.todaySalesInYer = 0,
    this.todayBusinessExpensesInYer = 0,
    required this.totalOrdersCount,
    required this.pendingOrdersCount,
    this.todayOrdersCount = 0,
    this.lowStockCount = 0,
    required this.activeShipmentsCount,
    required this.totalCustomersCount,
    required this.debtorsCount,
    this.weeklySalesInYer = const [0, 0, 0, 0, 0, 0, 0],
    this.weeklySalesDayKeys = const [],
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalDebtsInYer: 0,
      collectedCapitalInYer: 0,
      netCashInHandInYer: 0,
      remainingCapitalInYer: 0,
      totalCapitalInYer: 0,
      netProfitInYer: 0,
      totalExpensesInYer: 0,
      personalDrawingsInYer: 0,
      todayCashInYer: 0,
      todaySalesInYer: 0,
      todayBusinessExpensesInYer: 0,
      totalOrdersCount: 0,
      pendingOrdersCount: 0,
      activeShipmentsCount: 0,
      totalCustomersCount: 0,
      debtorsCount: 0,
      weeklySalesInYer: const [0, 0, 0, 0, 0, 0, 0],
      weeklySalesDayKeys: const [],
    );
  }
}
