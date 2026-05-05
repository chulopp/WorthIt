class Substitution {
  final String productName;
  final double price;
  final double weightGram;
  final double pricePerGram;
  final double savingsPercent;

  Substitution({
    required this.productName,
    required this.price,
    required this.weightGram,
    required this.pricePerGram,
    required this.savingsPercent,
  });
}

class ProductAnalysis {
  final String decision; // "BUY", "SUBSTITUTE", "DONT_BUY"
  final String color; // "green", "yellow", "red"
  final int score;
  final List<String> insights;
  final String reasoning;
  final Substitution? substitution;

  ProductAnalysis({
    required this.decision,
    required this.color,
    required this.score,
    required this.insights,
    required this.reasoning,
    this.substitution,
  });
}
