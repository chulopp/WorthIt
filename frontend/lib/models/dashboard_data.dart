class RecentActivity {
  final String? productId;
  final String name;
  final double price;
  final String color; // "green", "yellow", "red"
  final String date;
  final String category;
  final String? imageUrl;
  final String? unitLabel;
  final int quantity;
  final double? unitPrice;

  RecentActivity({
    this.productId,
    required this.name,
    required this.price,
    required this.color,
    required this.date,
    this.category = 'Sembako',
    this.imageUrl,
    this.unitLabel,
    this.quantity = 1,
    this.unitPrice,
  });
}

class ExpensePoint {
  final String purchasedAt;
  final double amount;

  const ExpensePoint({required this.purchasedAt, required this.amount});
}

class DashboardData {
  final double monthlyBudget;
  final double budgetRemaining;
  final double moneySaved;
  final List<RecentActivity> recentItems;
  final List<double> dailyExpenses;
  final List<ExpensePoint> expensePoints;
  final String marketInsight;
  final String? marketInsightKey;
  final Map<String, String> marketInsightParams;

  DashboardData({
    required this.monthlyBudget,
    required this.budgetRemaining,
    required this.moneySaved,
    required this.recentItems,
    this.dailyExpenses = const [],
    this.expensePoints = const [],
    this.marketInsight = '',
    this.marketInsightKey,
    this.marketInsightParams = const <String, String>{},
  });
}
