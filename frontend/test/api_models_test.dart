import 'package:flutter_test/flutter_test.dart';
import 'package:worthit_app/models/api/api_models.dart';

void main() {
  group('API models', () {
    test('parses product detail', () {
      final model = ProductDetailModel.fromJson(<String, dynamic>{
        'id': 'product-1',
        'name': 'Chitato',
        'image_url': 'https://example.com/chitato.webp',
        'category': 'snack',
        'brand': 'Chitato',
        'base_weight_gram': 68,
        'history': <Map<String, dynamic>>[
          <String, dynamic>{'month': '2026-05', 'price': 12000},
          <String, dynamic>{'month': '2026-06', 'price': 12500},
        ],
      });

      expect(model.id, equals('product-1'));
      expect(model.history, hasLength(2));
      expect(model.history.last.price, equals(12500));
    });

    test('parses monthly shopping list', () {
      final model = MonthlyShoppingListModel.fromJson(<String, dynamic>{
        'status': 'success',
        'list_id': 'list-1',
        'period_month': '2026-05',
        'total_budget': 500000,
        'total_estimated_price': 25000,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'item-1',
            'product_id': 'product-1',
            'product_name': 'Beras',
            'image_url': null,
            'category': 'sembako',
            'current_price': 25000,
            'quantity': 1,
          },
        ],
      });

      expect(model.listId, equals('list-1'));
      expect(model.items.single.productName, equals('Beras'));
      expect(model.totalEstimatedPrice, equals(25000));
    });

    test('parses analyze response', () {
      final model = AnalyzeResponseModel.fromJson(<String, dynamic>{
        'product_id': 'product-1',
        'score': 82,
        'decision': 'WorthIt',
        'product_name': 'Susu',
        'scanned_price': 18000,
        'normal_price': 19000,
        'category': 'minuman',
        'urgency': 2,
        'weight_gram': 1000,
        'explanations': <String>['Harga masih wajar'],
        'metrics': <String, dynamic>{
          'wma_price': 18500,
          'support': 17000,
          'resistance': 20000,
          'sr_position': 0.4,
          'price_delta_percent': -5.2,
          'price_per_unit': 18,
          'history_points': 6,
          'history_months': 6,
          'volatility_percent': 4.1,
          'fair_upper_bound': 19500,
          'shrinkflation': false,
          'price_anomaly': false,
        },
        'tier': <String, dynamic>{
          'name': 'FREE',
          'scan_limit': 10,
          'scan_period': 'weekly',
          'remaining_scans': 8,
          'locked_features': <String>['support_resistance'],
        },
      });

      expect(model.decision, equals('WorthIt'));
      expect(model.metrics.historyMonths, equals(6));
      expect(model.tier.remainingScans, equals(8));
    });

    test('parses purchase history', () {
      final model = PurchaseHistoryModel.fromJson(<String, dynamic>{
        'month': 'Mei 2026',
        'total_actual_spending': 36000,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'purchase-1',
            'product_id': 'product-1',
            'product_name': 'Indomie',
            'purchased_price': 3000,
            'quantity': 12,
            'total_price': 36000,
            'purchased_at': '2026-05-17T10:00:00Z',
          },
        ],
      });

      expect(model.month, equals('Mei 2026'));
      expect(model.items.single.quantity, equals(12));
      expect(model.totalActualSpending, equals(36000));
    });

    test('parses dashboard response data', () {
      final model = DashboardModel.fromJson(<String, dynamic>{
        'monthly_budget': 2000000,
        'budget_remaining': 1500000,
        'money_saved': 125000,
        'recent_activities': <Map<String, dynamic>>[
          <String, dynamic>{
            'product_name': 'Beras',
            'price': 65000,
            'decision': 'BUY',
            'color': 'green',
            'timestamp': '2026-05-18T00:00:00Z',
          },
        ],
      });

      expect(model.budgetRemaining, equals(1500000));
      expect(model.recentActivities.single.productName, equals('Beras'));
    });

    test('parses tracker response data', () {
      final model = TrackerModel.fromJson(<String, dynamic>{
        'total_spent': 120000,
        'total_items': 2,
        'avg_per_item': 60000,
        'by_category': <Map<String, dynamic>>[
          <String, dynamic>{
            'category': 'sembako',
            'amount': 90000,
            'percentage': 75,
          },
        ],
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'product_name': 'Minyak',
            'price_paid': 35000,
            'date': '2026-05-18',
            'decision_score': 80,
            'action_taken': 'BUY',
          },
        ],
      });

      expect(model.totalItems, equals(2));
      expect(model.byCategory.single.percentage, equals(75));
      expect(model.items.single.actionTaken, equals('BUY'));
    });
  });
}
