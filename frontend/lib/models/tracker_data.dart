class CategorySummary {
  final String category;
  final double amount;
  final double percentage;

  CategorySummary({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

class TrackerItem {
  final String productName;
  final double pricePaid;
  final String date;
  final int decisionScore;

  TrackerItem({
    required this.productName,
    required this.pricePaid,
    required this.date,
    required this.decisionScore,
  });
}

class TrackerData {
  final double totalSpent;
  final int totalItems;
  final double avgPerItem;
  final List<CategorySummary> byCategory;
  final List<TrackerItem> items;

  TrackerData({
    required this.totalSpent,
    required this.totalItems,
    required this.avgPerItem,
    required this.byCategory,
    required this.items,
  });
}
