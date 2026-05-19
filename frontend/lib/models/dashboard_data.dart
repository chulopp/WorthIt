class RecentActivity {
  final String name;
  final double price;
  final String color; // "green", "yellow", "red"
  final String date;
  final String category;
  final String? imageUrl;

  RecentActivity({
    required this.name,
    required this.price,
    required this.color,
    required this.date,
    this.category = 'Sembako',
    this.imageUrl,
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
