class RecentActivity {
  final String name;
  final double price;
  final String color; // "green", "yellow", "red"

  RecentActivity({
    required this.name,
    required this.price,
    required this.color,
  });
}

class DashboardData {
  final double monthlyBudget;
  final double budgetRemaining;
  final double moneySaved;
  final List<RecentActivity> recentItems;

  DashboardData({
    required this.monthlyBudget,
    required this.budgetRemaining,
    required this.moneySaved,
    required this.recentItems,
  });
}
