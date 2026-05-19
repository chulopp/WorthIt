typedef JsonMap = Map<String, dynamic>;

String _stringValue(Object? value, {String fallback = ''}) =>
    value?.toString() ?? fallback;

String? _nullableString(Object? value) => value?.toString();

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _doubleValue(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool? _nullableBool(Object? value) {
  if (value is bool) return value;
  if (value == null) return null;
  return bool.tryParse(value.toString());
}

bool _boolValue(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return bool.tryParse(value?.toString() ?? '') ?? fallback;
}

List<JsonMap> _jsonList(Object? value) {
  if (value is! List) return <JsonMap>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

class ProductSummaryModel {
  final String id;
  final String name;
  final String? imageUrl;
  final String? category;
  final String? brand;
  final double? currentPrice;

  const ProductSummaryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.category,
    this.brand,
    this.currentPrice,
  });

  factory ProductSummaryModel.fromJson(JsonMap json) {
    return ProductSummaryModel(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      imageUrl: _nullableString(json['image_url']),
      category: _nullableString(json['category']),
      brand: _nullableString(json['brand']),
      currentPrice: json['current_price'] == null
          ? null
          : _doubleValue(json['current_price']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'image_url': imageUrl,
    'category': category,
    'brand': brand,
    'current_price': currentPrice,
  };
}

class PriceHistoryModel {
  final String month;
  final int price;

  const PriceHistoryModel({required this.month, required this.price});

  factory PriceHistoryModel.fromJson(JsonMap json) {
    return PriceHistoryModel(
      month: _stringValue(json['month'] ?? json['recorded_at']),
      price: _intValue(json['price']),
    );
  }

  JsonMap toJson() => <String, dynamic>{'month': month, 'price': price};
}

class ProductDetailModel extends ProductSummaryModel {
  final double baseWeightGram;
  final List<PriceHistoryModel> history;

  const ProductDetailModel({
    required super.id,
    required super.name,
    super.imageUrl,
    super.category,
    super.brand,
    super.currentPrice,
    this.baseWeightGram = 0,
    this.history = const <PriceHistoryModel>[],
  });

  factory ProductDetailModel.fromJson(JsonMap json) {
    return ProductDetailModel(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      imageUrl: _nullableString(json['image_url']),
      category: _nullableString(json['category']),
      brand: _nullableString(json['brand']),
      baseWeightGram: _doubleValue(json['base_weight_gram']),
      history: _jsonList(
        json['history'],
      ).map(PriceHistoryModel.fromJson).toList(growable: false),
    );
  }

  @override
  JsonMap toJson() => <String, dynamic>{
    ...super.toJson(),
    'brand': brand,
    'base_weight_gram': baseWeightGram,
    'history': history.map((item) => item.toJson()).toList(),
  };
}

class ShoppingItemModel {
  final String id;
  final String productId;
  final String productName;
  final String? imageUrl;
  final String category;
  final double currentPrice;
  final int quantity;
  final bool isBought;

  const ShoppingItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.imageUrl,
    required this.category,
    required this.currentPrice,
    required this.quantity,
    this.isBought = false,
  });

  factory ShoppingItemModel.fromJson(JsonMap json) {
    return ShoppingItemModel(
      id: _stringValue(json['id']),
      productId: _stringValue(json['product_id']),
      productName: _stringValue(json['product_name']),
      imageUrl: _nullableString(json['image_url']),
      category: _stringValue(json['category']),
      currentPrice: _doubleValue(json['current_price']),
      quantity: _intValue(json['quantity'], fallback: 1),
      isBought: _boolValue(json['is_bought']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'image_url': imageUrl,
    'category': category,
    'current_price': currentPrice,
    'quantity': quantity,
    'is_bought': isBought,
  };
}

class MonthlyShoppingListModel {
  final String listId;
  final String periodMonth;
  final int totalBudget;
  final double totalEstimatedPrice;
  final List<ShoppingItemModel> items;

  const MonthlyShoppingListModel({
    required this.listId,
    required this.periodMonth,
    required this.totalBudget,
    required this.totalEstimatedPrice,
    required this.items,
  });

  factory MonthlyShoppingListModel.fromJson(JsonMap json) {
    return MonthlyShoppingListModel(
      listId: _stringValue(json['list_id']),
      periodMonth: _stringValue(json['period_month']),
      totalBudget: _intValue(json['total_budget']),
      totalEstimatedPrice: _doubleValue(json['total_estimated_price']),
      items: _jsonList(
        json['items'],
      ).map(ShoppingItemModel.fromJson).toList(growable: false),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'list_id': listId,
    'period_month': periodMonth,
    'total_budget': totalBudget,
    'total_estimated_price': totalEstimatedPrice,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class PurchaseItemModel {
  final String id;
  final String productId;
  final String productName;
  final String? imageUrl;
  final String? category;
  final int purchasedPrice;
  final int quantity;
  final int totalPrice;
  final String purchasedAt;

  const PurchaseItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.imageUrl,
    this.category,
    required this.purchasedPrice,
    required this.quantity,
    required this.totalPrice,
    required this.purchasedAt,
  });

  factory PurchaseItemModel.fromJson(JsonMap json) {
    return PurchaseItemModel(
      id: _stringValue(json['id']),
      productId: _stringValue(json['product_id']),
      productName: _stringValue(json['product_name']),
      imageUrl: _nullableString(json['image_url']),
      category: _nullableString(json['category']),
      purchasedPrice: _intValue(json['purchased_price']),
      quantity: _intValue(json['quantity'], fallback: 1),
      totalPrice: _intValue(json['total_price']),
      purchasedAt: _stringValue(json['purchased_at']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'image_url': imageUrl,
    'category': category,
    'purchased_price': purchasedPrice,
    'quantity': quantity,
    'total_price': totalPrice,
    'purchased_at': purchasedAt,
  };
}

class PurchaseHistoryModel {
  final String month;
  final int totalActualSpending;
  final List<PurchaseItemModel> items;

  const PurchaseHistoryModel({
    required this.month,
    required this.totalActualSpending,
    required this.items,
  });

  factory PurchaseHistoryModel.fromJson(JsonMap json) {
    return PurchaseHistoryModel(
      month: _stringValue(json['month']),
      totalActualSpending: _intValue(json['total_actual_spending']),
      items: _jsonList(
        json['items'],
      ).map(PurchaseItemModel.fromJson).toList(growable: false),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'month': month,
    'total_actual_spending': totalActualSpending,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class ScanResultModel {
  final String productName;
  final int price;
  final int scannedPrice;
  final int weightGram;
  final String category;
  final String dbProductId;

  const ScanResultModel({
    required this.productName,
    required this.price,
    required this.scannedPrice,
    required this.weightGram,
    required this.category,
    required this.dbProductId,
  });

  factory ScanResultModel.fromJson(JsonMap json) {
    return ScanResultModel(
      productName: _stringValue(json['product_name']),
      price: _intValue(json['price']),
      scannedPrice: _intValue(json['scanned_price'] ?? json['price']),
      weightGram: _intValue(json['weight_gram']),
      category: _stringValue(json['category']),
      dbProductId: _stringValue(json['db_product_id']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'product_name': productName,
    'price': price,
    'scanned_price': scannedPrice,
    'weight_gram': weightGram,
    'category': category,
    'db_product_id': dbProductId,
  };
}

class AnalyzeRequestModel {
  final String dbProductId;
  final double scannedPrice;
  final double weightGram;
  final int urgency;

  const AnalyzeRequestModel({
    required this.dbProductId,
    required this.scannedPrice,
    required this.weightGram,
    required this.urgency,
  });

  JsonMap toJson() => <String, dynamic>{
    'db_product_id': dbProductId,
    'scanned_price': scannedPrice,
    'weight_gram': weightGram,
    'urgency': urgency,
  };
}

class AnalyzeMetricsModel {
  final double wmaPrice;
  final double support;
  final double resistance;
  final double srPosition;
  final double priceDeltaPercent;
  final double pricePerUnit;
  final int historyPoints;
  final int historyMonths;
  final double volatilityPercent;
  final double fairUpperBound;
  final bool? shrinkflation;
  final bool? priceAnomaly;

  const AnalyzeMetricsModel({
    required this.wmaPrice,
    required this.support,
    required this.resistance,
    required this.srPosition,
    required this.priceDeltaPercent,
    required this.pricePerUnit,
    required this.historyPoints,
    required this.historyMonths,
    required this.volatilityPercent,
    required this.fairUpperBound,
    this.shrinkflation,
    this.priceAnomaly,
  });

  factory AnalyzeMetricsModel.fromJson(JsonMap json) {
    return AnalyzeMetricsModel(
      wmaPrice: _doubleValue(json['wma_price']),
      support: _doubleValue(json['support']),
      resistance: _doubleValue(json['resistance']),
      srPosition: _doubleValue(json['sr_position']),
      priceDeltaPercent: _doubleValue(json['price_delta_percent']),
      pricePerUnit: _doubleValue(json['price_per_unit']),
      historyPoints: _intValue(json['history_points']),
      historyMonths: _intValue(json['history_months']),
      volatilityPercent: _doubleValue(json['volatility_percent']),
      fairUpperBound: _doubleValue(json['fair_upper_bound']),
      shrinkflation: _nullableBool(json['shrinkflation']),
      priceAnomaly: _nullableBool(json['price_anomaly']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'wma_price': wmaPrice,
    'support': support,
    'resistance': resistance,
    'sr_position': srPosition,
    'price_delta_percent': priceDeltaPercent,
    'price_per_unit': pricePerUnit,
    'history_points': historyPoints,
    'history_months': historyMonths,
    'volatility_percent': volatilityPercent,
    'fair_upper_bound': fairUpperBound,
    'shrinkflation': shrinkflation,
    'price_anomaly': priceAnomaly,
  };
}

class AnalyzeTierModel {
  final String name;
  final int? scanLimit;
  final String scanPeriod;
  final int? remainingScans;
  final List<String> lockedFeatures;

  const AnalyzeTierModel({
    required this.name,
    this.scanLimit,
    required this.scanPeriod,
    this.remainingScans,
    this.lockedFeatures = const <String>[],
  });

  factory AnalyzeTierModel.fromJson(JsonMap json) {
    return AnalyzeTierModel(
      name: _stringValue(json['name']),
      scanLimit: json['scan_limit'] == null
          ? null
          : _intValue(json['scan_limit']),
      scanPeriod: _stringValue(json['scan_period']),
      remainingScans: json['remaining_scans'] == null
          ? null
          : _intValue(json['remaining_scans']),
      lockedFeatures: (json['locked_features'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'name': name,
    'scan_limit': scanLimit,
    'scan_period': scanPeriod,
    'remaining_scans': remainingScans,
    'locked_features': lockedFeatures,
  };
}

class AnalyzeResponseModel {
  final String productId;
  final String? imageUrl;
  final int score;
  final String decision;
  final String productName;
  final double scannedPrice;
  final double normalPrice;
  final String category;
  final int urgency;
  final double weightGram;
  final List<String> explanations;
  final List<AnalyzeExplanationModel> explanationItems;
  final AnalyzeMetricsModel metrics;
  final AnalyzeTierModel tier;

  const AnalyzeResponseModel({
    required this.productId,
    this.imageUrl,
    required this.score,
    required this.decision,
    required this.productName,
    required this.scannedPrice,
    required this.normalPrice,
    required this.category,
    required this.urgency,
    required this.weightGram,
    required this.explanations,
    this.explanationItems = const <AnalyzeExplanationModel>[],
    required this.metrics,
    required this.tier,
  });

  factory AnalyzeResponseModel.fromJson(JsonMap json) {
    final metrics = json['metrics'];
    final tier = json['tier'];
    final rawExplanations = json['explanations'];
    final rawExplanationList = rawExplanations is List
        ? rawExplanations
        : <dynamic>[];
    final explanationItems = rawExplanationList
        .map(AnalyzeExplanationModel.fromDynamic)
        .where((item) => item.description.isNotEmpty)
        .toList(growable: false);
    return AnalyzeResponseModel(
      productId: _stringValue(json['product_id']),
      imageUrl: _nullableString(json['image_url']),
      score: _intValue(json['score']),
      decision: _stringValue(json['decision']),
      productName: _stringValue(json['product_name']),
      scannedPrice: _doubleValue(json['scanned_price']),
      normalPrice: _doubleValue(json['normal_price']),
      category: _stringValue(json['category']),
      urgency: _intValue(json['urgency']),
      weightGram: _doubleValue(json['weight_gram']),
      explanations: explanationItems
          .map((item) => item.description)
          .toList(growable: false),
      explanationItems: explanationItems,
      metrics: AnalyzeMetricsModel.fromJson(
        metrics is Map
            ? Map<String, dynamic>.from(metrics)
            : <String, dynamic>{},
      ),
      tier: AnalyzeTierModel.fromJson(
        tier is Map ? Map<String, dynamic>.from(tier) : <String, dynamic>{},
      ),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'product_id': productId,
    'image_url': imageUrl,
    'score': score,
    'decision': decision,
    'product_name': productName,
    'scanned_price': scannedPrice,
    'normal_price': normalPrice,
    'category': category,
    'urgency': urgency,
    'weight_gram': weightGram,
    'explanations': explanationItems.isEmpty
        ? explanations
        : explanationItems.map((item) => item.toJson()).toList(growable: false),
    'metrics': metrics.toJson(),
    'tier': tier.toJson(),
  };
}

class AnalyzeExplanationModel {
  final String title;
  final String description;

  const AnalyzeExplanationModel({
    required this.title,
    required this.description,
  });

  factory AnalyzeExplanationModel.fromDynamic(dynamic value) {
    if (value is AnalyzeExplanationModel) return value;
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      final title =
          _nullableString(json['title']) ??
          _nullableString(json['category']) ??
          _nullableString(json['type']) ??
          _nullableString(json['label']) ??
          '';
      final description =
          _nullableString(json['description']) ??
          _nullableString(json['message']) ??
          _nullableString(json['text']) ??
          _nullableString(json['content']) ??
          _nullableString(json['reason']) ??
          '';
      return AnalyzeExplanationModel(
        title: title,
        description: description,
      );
    }
    return AnalyzeExplanationModel(
      title: '',
      description: value?.toString() ?? '',
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'title': title,
    'description': description,
  };
}

class ScanHistoryItemModel {
  final String id;
  final String? productId;
  final String productName;
  final String? imageUrl;
  final String? category;
  final String scannedAt;
  final int? score;
  final String? decision;
  final double? scannedPrice;
  final double? normalPrice;
  final AnalyzeResponseModel analysis;

  const ScanHistoryItemModel({
    required this.id,
    this.productId,
    required this.productName,
    this.imageUrl,
    this.category,
    required this.scannedAt,
    this.score,
    this.decision,
    this.scannedPrice,
    this.normalPrice,
    required this.analysis,
  });

  factory ScanHistoryItemModel.fromJson(JsonMap json) {
    final analysis = json['analysis'];
    return ScanHistoryItemModel(
      id: _stringValue(json['id']),
      productId: _nullableString(json['product_id']),
      productName: _stringValue(json['product_name']),
      imageUrl: _nullableString(json['image_url']),
      category: _nullableString(json['category']),
      scannedAt: _stringValue(json['scanned_at']),
      score: json['score'] == null ? null : _intValue(json['score']),
      decision: _nullableString(json['decision']),
      scannedPrice: json['scanned_price'] == null
          ? null
          : _doubleValue(json['scanned_price']),
      normalPrice: json['normal_price'] == null
          ? null
          : _doubleValue(json['normal_price']),
      analysis: AnalyzeResponseModel.fromJson(
        analysis is Map
            ? Map<String, dynamic>.from(analysis)
            : <String, dynamic>{},
      ),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'image_url': imageUrl,
    'category': category,
    'scanned_at': scannedAt,
    'score': score,
    'decision': decision,
    'scanned_price': scannedPrice,
    'normal_price': normalPrice,
    'analysis': analysis.toJson(),
  };
}

class FavoriteModel {
  final String favoriteId;
  final String productId;
  final String productName;
  final String? imageUrl;
  final String? category;
  final double? currentPrice;
  final String? favoritedAt;

  const FavoriteModel({
    required this.favoriteId,
    required this.productId,
    required this.productName,
    this.imageUrl,
    this.category,
    this.currentPrice,
    this.favoritedAt,
  });

  factory FavoriteModel.fromJson(JsonMap json) {
    return FavoriteModel(
      favoriteId: _stringValue(json['favorite_id']),
      productId: _stringValue(json['product_id']),
      productName: _stringValue(json['product_name']),
      imageUrl: _nullableString(json['image_url']),
      category: _nullableString(json['category']),
      currentPrice: json['current_price'] == null
          ? null
          : _doubleValue(json['current_price']),
      favoritedAt: _nullableString(json['favorited_at']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'favorite_id': favoriteId,
    'product_id': productId,
    'product_name': productName,
    'image_url': imageUrl,
    'category': category,
    'current_price': currentPrice,
    'favorited_at': favoritedAt,
  };
}

class RecentActivityModel {
  final String productName;
  final double price;
  final String decision;
  final String color;
  final String timestamp;

  const RecentActivityModel({
    required this.productName,
    required this.price,
    required this.decision,
    required this.color,
    required this.timestamp,
  });

  factory RecentActivityModel.fromJson(JsonMap json) {
    return RecentActivityModel(
      productName: _stringValue(json['product_name']),
      price: _doubleValue(json['price']),
      decision: _stringValue(json['decision']),
      color: _stringValue(json['color'], fallback: 'green'),
      timestamp: _stringValue(json['timestamp']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'product_name': productName,
    'price': price,
    'decision': decision,
    'color': color,
    'timestamp': timestamp,
  };
}

class DashboardModel {
  final double monthlyBudget;
  final double budgetRemaining;
  final double moneySaved;
  final List<RecentActivityModel> recentActivities;

  const DashboardModel({
    required this.monthlyBudget,
    required this.budgetRemaining,
    required this.moneySaved,
    required this.recentActivities,
  });

  factory DashboardModel.fromJson(JsonMap json) {
    return DashboardModel(
      monthlyBudget: _doubleValue(json['monthly_budget']),
      budgetRemaining: _doubleValue(json['budget_remaining']),
      moneySaved: _doubleValue(json['money_saved']),
      recentActivities: _jsonList(json['recent_activities'])
          .map(RecentActivityModel.fromJson)
          .toList(growable: false),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'monthly_budget': monthlyBudget,
    'budget_remaining': budgetRemaining,
    'money_saved': moneySaved,
    'recent_activities': recentActivities
        .map((item) => item.toJson())
        .toList(growable: false),
  };
}

class CategorySpendModel {
  final String category;
  final double amount;
  final double percentage;

  const CategorySpendModel({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  factory CategorySpendModel.fromJson(JsonMap json) {
    return CategorySpendModel(
      category: _stringValue(json['category']),
      amount: _doubleValue(json['amount']),
      percentage: _doubleValue(json['percentage']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'category': category,
    'amount': amount,
    'percentage': percentage,
  };
}

class TrackerItemModel {
  final String productName;
  final double pricePaid;
  final String date;
  final int? decisionScore;
  final String actionTaken;

  const TrackerItemModel({
    required this.productName,
    required this.pricePaid,
    required this.date,
    this.decisionScore,
    required this.actionTaken,
  });

  factory TrackerItemModel.fromJson(JsonMap json) {
    return TrackerItemModel(
      productName: _stringValue(json['product_name']),
      pricePaid: _doubleValue(json['price_paid']),
      date: _stringValue(json['date']),
      decisionScore: json['decision_score'] == null
          ? null
          : _intValue(json['decision_score']),
      actionTaken: _stringValue(json['action_taken']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'product_name': productName,
    'price_paid': pricePaid,
    'date': date,
    'decision_score': decisionScore,
    'action_taken': actionTaken,
  };
}

class TrackerModel {
  final double totalSpent;
  final int totalItems;
  final double avgPerItem;
  final List<CategorySpendModel> byCategory;
  final List<TrackerItemModel> items;

  const TrackerModel({
    required this.totalSpent,
    required this.totalItems,
    required this.avgPerItem,
    required this.byCategory,
    required this.items,
  });

  factory TrackerModel.fromJson(JsonMap json) {
    return TrackerModel(
      totalSpent: _doubleValue(json['total_spent']),
      totalItems: _intValue(json['total_items']),
      avgPerItem: _doubleValue(json['avg_per_item']),
      byCategory: _jsonList(json['by_category'])
          .map(CategorySpendModel.fromJson)
          .toList(growable: false),
      items: _jsonList(json['items'])
          .map(TrackerItemModel.fromJson)
          .toList(growable: false),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'total_spent': totalSpent,
    'total_items': totalItems,
    'avg_per_item': avgPerItem,
    'by_category': byCategory
        .map((item) => item.toJson())
        .toList(growable: false),
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };
}

class BudgetUpdateModel {
  final String userId;
  final int monthlyBudget;

  const BudgetUpdateModel({required this.userId, required this.monthlyBudget});

  factory BudgetUpdateModel.fromJson(JsonMap json) {
    return BudgetUpdateModel(
      userId: _stringValue(json['user_id']),
      monthlyBudget: _intValue(json['monthly_budget']),
    );
  }

  JsonMap toJson() => <String, dynamic>{
    'user_id': userId,
    'monthly_budget': monthlyBudget,
  };
}
