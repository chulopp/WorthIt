import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthit_app/controllers/analyze_controller.dart';
import 'package:worthit_app/controllers/dashboard_controller.dart';
import 'package:worthit_app/controllers/favorite_controller.dart';
import 'package:worthit_app/controllers/history_controller.dart';
import 'package:worthit_app/controllers/product_detail_controller.dart';
import 'package:worthit_app/controllers/profile_controller.dart';
import 'package:worthit_app/controllers/repository_providers.dart';
import 'package:worthit_app/controllers/shopping_list_controller.dart';
import 'package:worthit_app/controllers/tracker_controller.dart';
import 'package:worthit_app/models/api/api_models.dart';
import 'package:worthit_app/repositories/dashboard_repository.dart';
import 'package:worthit_app/repositories/history_repository.dart';
import 'package:worthit_app/repositories/product_repository.dart';
import 'package:worthit_app/repositories/scanner_repository.dart';
import 'package:worthit_app/repositories/shopping_list_repository.dart';
import 'package:worthit_app/repositories/tracker_repository.dart';
import 'package:worthit_app/repositories/user_repository.dart';
import 'package:worthit_app/services/api_client.dart';

void main() {
  group('ShoppingListController', () {
    test('fetches current list and refreshes after add', () async {
      final repository = _FakeShoppingListRepository();
      final container = ProviderContainer(
        overrides: [
          shoppingListRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        shoppingListControllerProvider.notifier,
      );

      await controller.fetchCurrentList();
      expect(
        container.read(shoppingListControllerProvider).data?.items,
        isEmpty,
      );

      await controller.addItem('product-1', 2);
      final state = container.read(shoppingListControllerProvider);

      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.data?.items.single.productId, equals('product-1'));
      expect(repository.getCurrentCalls, equals(1));
      expect(repository.lastAddedQuantity, equals(2));
    });
  });

  group('AnalyzeController', () {
    test('scans, analyzes, and records a purchase', () async {
      final scannerRepository = _FakeScannerRepository();
      final historyRepository = _FakeHistoryRepository();
      final container = ProviderContainer(
        overrides: [
          scannerRepositoryProvider.overrideWithValue(scannerRepository),
          historyRepositoryProvider.overrideWithValue(historyRepository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(analyzeControllerProvider.notifier);

      await controller.scanReceipt(File('receipt.jpg'));
      controller.setUrgency(9);
      await controller.analyzeProduct();
      await controller.buyProduct();

      final state = container.read(analyzeControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.dbProductId, equals('product-1'));
      expect(state.scannedPrice, equals(12000));
      expect(state.weightGram, equals(68));
      expect(state.urgency, equals(3));
      expect(state.data?.productId, equals('product-1'));
      expect(state.purchase?.productId, equals('product-1'));
      expect(historyRepository.lastPurchasePrice, equals(12000));
    });

    test('returns a validation error when scan state is incomplete', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(analyzeControllerProvider.notifier).analyzeProduct();

      final state = container.read(analyzeControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, contains('belum lengkap'));
    });
  });

  group('ProductDetailController', () {
    test('searches products and loads product detail with history', () async {
      final repository = _FakeProductRepository();
      final container = ProviderContainer(
        overrides: [productRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        productDetailControllerProvider.notifier,
      );

      await controller.searchProducts('chitato');
      await controller.loadProductDetail('product-1');

      final state = container.read(productDetailControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.searchResults.single.name, equals('Chitato'));
      expect(state.data?.history, hasLength(2));
    });
  });

  group('HistoryController', () {
    test('fetches scans and purchases independently', () async {
      final repository = _FakeHistoryRepository();
      final container = ProviderContainer(
        overrides: [historyRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(historyControllerProvider.notifier);

      await controller.fetchPurchases();
      await controller.fetchScans();

      final state = container.read(historyControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.data?.purchases.single.month, equals('Mei 2026'));
      expect(state.data?.scans.single.productId, equals('product-1'));
    });
  });

  group('ProfileController', () {
    test('updates budget and stores API errors', () async {
      final repository = _FakeUserRepository();
      final container = ProviderContainer(
        overrides: [userRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);

      await controller.updateBudget(500000);
      expect(
        container.read(profileControllerProvider).data?.monthlyBudget,
        equals(500000),
      );

      repository.shouldFailBudget = true;
      await controller.updateBudget(0);

      final state = container.read(profileControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, equals('Budget tidak valid.'));
    });
  });

  group('FavoriteController', () {
    test(
      'fetches favorites and rolls back a failed optimistic remove',
      () async {
        final repository = _FakeUserRepository();
        repository.favorites = [_favorite('product-1')];
        repository.shouldFailRemoveFavorite = true;
        final container = ProviderContainer(
          overrides: [userRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final controller = container.read(favoriteControllerProvider.notifier);

        await controller.fetchFavorites();
        await controller.toggleFavorite('product-1');
        await _flushAsyncWork();

        final state = container.read(favoriteControllerProvider);
        expect(state.isLoading, isFalse);
        expect(state.errorMessage, equals('Gagal menghapus favorit.'));
        expect(state.isFavorite('product-1'), isTrue);
        expect(state.data?.single.productId, equals('product-1'));
      },
    );

    test('adds favorites optimistically and stores confirmed data', () async {
      final repository = _FakeUserRepository();
      final container = ProviderContainer(
        overrides: [userRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final controller = container.read(favoriteControllerProvider.notifier);

      await controller.fetchFavorites();
      await controller.toggleFavorite('product-2');
      await _flushAsyncWork();

      final state = container.read(favoriteControllerProvider);
      expect(state.errorMessage, isNull);
      expect(state.isFavorite('product-2'), isTrue);
      expect(state.data?.single.favoriteId, equals('favorite-product-2'));
    });
  });

  group('DashboardController', () {
    test('fetches dashboard data from repository', () async {
      final repository = _FakeDashboardRepository();
      final container = ProviderContainer(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(dashboardControllerProvider.notifier)
          .fetchDashboard();

      final state = container.read(dashboardControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.data?.moneySaved, equals(125000));
      expect(state.data?.recentActivities.single.productName, equals('Beras'));
    });
  });

  group('TrackerController', () {
    test('fetches tracker data from repository', () async {
      final repository = _FakeTrackerRepository();
      final container = ProviderContainer(
        overrides: [trackerRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(trackerControllerProvider.notifier).fetchTracker();

      final state = container.read(trackerControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.data?.totalSpent, equals(120000));
      expect(state.data?.byCategory.single.category, equals('sembako'));
    });
  });
}

ApiResult<T> _success<T>(T data) => ApiResult.success(data);

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

ApiResult<T> _failure<T>(String message) {
  return ApiResult.failure(ApiException(message: message));
}

MonthlyShoppingListModel _shoppingList({
  List<ShoppingItemModel> items = const <ShoppingItemModel>[],
}) {
  return MonthlyShoppingListModel(
    listId: 'list-1',
    periodMonth: '2026-05',
    totalBudget: 500000,
    totalEstimatedPrice: items.fold<double>(
      0,
      (total, item) => total + (item.currentPrice * item.quantity),
    ),
    items: items,
  );
}

FavoriteModel _favorite(String productId) {
  return FavoriteModel(
    favoriteId: 'favorite-$productId',
    productId: productId,
    productName: 'Chitato',
  );
}

AnalyzeResponseModel _analysis() {
  return const AnalyzeResponseModel(
    productId: 'product-1',
    score: 82,
    decision: 'WorthIt',
    productName: 'Chitato',
    scannedPrice: 12000,
    normalPrice: 12500,
    category: 'snack',
    urgency: 3,
    weightGram: 68,
    explanations: <String>['Harga masih wajar'],
    metrics: AnalyzeMetricsModel(
      wmaPrice: 12500,
      support: 11000,
      resistance: 13000,
      srPosition: 0.4,
      priceDeltaPercent: -4,
      pricePerUnit: 176.47,
      historyPoints: 6,
      historyMonths: 6,
      volatilityPercent: 3,
      fairUpperBound: 13000,
    ),
    tier: AnalyzeTierModel(
      name: 'FREE',
      scanPeriod: 'weekly',
      remainingScans: 8,
    ),
  );
}

PurchaseItemModel _purchaseItem() {
  return const PurchaseItemModel(
    id: 'purchase-1',
    productId: 'product-1',
    productName: 'Chitato',
    purchasedPrice: 12000,
    quantity: 1,
    totalPrice: 12000,
    purchasedAt: '2026-05-18T00:00:00Z',
  );
}

class _FakeShoppingListRepository extends ShoppingListRepository {
  MonthlyShoppingListModel current = _shoppingList();
  int getCurrentCalls = 0;
  int? lastAddedQuantity;

  @override
  Future<ApiResult<MonthlyShoppingListModel>> getCurrent() async {
    getCurrentCalls += 1;
    return _success(current);
  }

  @override
  Future<ApiResult<MonthlyShoppingListModel>> addItem(
    String productId, {
    int quantity = 1,
  }) async {
    lastAddedQuantity = quantity;
    current = _shoppingList(
      items: [
        ShoppingItemModel(
          id: 'item-1',
          productId: productId,
          productName: 'Chitato',
          category: 'snack',
          currentPrice: 12000,
          quantity: quantity,
        ),
      ],
    );
    return _success(current);
  }
}

class _FakeScannerRepository extends ScannerRepository {
  AnalyzeRequestModel? lastAnalyzeRequest;

  @override
  Future<ApiResult<ScanResultModel>> uploadReceipt(File image) async {
    return _success(
      const ScanResultModel(
        productName: 'Chitato',
        price: 12000,
        scannedPrice: 12000,
        weightGram: 68,
        category: 'snack',
        dbProductId: 'product-1',
      ),
    );
  }

  @override
  Future<ApiResult<AnalyzeResponseModel>> analyzeProduct(
    AnalyzeRequestModel payload,
  ) async {
    lastAnalyzeRequest = payload;
    return _success(_analysis());
  }
}

class _FakeProductRepository extends ProductRepository {
  @override
  Future<ApiResult<List<ProductSummaryModel>>> searchProducts(
    String keyword, {
    int limit = 50,
  }) async {
    return _success([
      const ProductSummaryModel(id: 'product-1', name: 'Chitato'),
    ]);
  }

  @override
  Future<ApiResult<ProductDetailModel>> getProductDetail(String id) async {
    return _success(
      const ProductDetailModel(
        id: 'product-1',
        name: 'Chitato',
        history: [
          PriceHistoryModel(month: '2026-04', price: 11500),
          PriceHistoryModel(month: '2026-05', price: 12000),
        ],
      ),
    );
  }
}

class _FakeHistoryRepository extends HistoryRepository {
  int? lastPurchasePrice;

  @override
  Future<ApiResult<List<ScanHistoryItemModel>>> getScanHistory({
    String? productId,
  }) async {
    return _success([
      ScanHistoryItemModel(
        id: 'scan-1',
        productId: 'product-1',
        productName: 'Chitato',
        scannedAt: '2026-05-18T00:00:00Z',
        analysis: _analysis(),
      ),
    ]);
  }

  @override
  Future<ApiResult<List<PurchaseHistoryModel>>> getPurchaseHistory() async {
    return _success([
      PurchaseHistoryModel(
        month: 'Mei 2026',
        totalActualSpending: 12000,
        items: [_purchaseItem()],
      ),
    ]);
  }

  @override
  Future<ApiResult<PurchaseItemModel>> createPurchase({
    required String productId,
    required int purchasedPrice,
    int quantity = 1,
  }) async {
    lastPurchasePrice = purchasedPrice;
    return _success(_purchaseItem());
  }
}

class _FakeUserRepository extends UserRepository {
  List<FavoriteModel> favorites = const <FavoriteModel>[];
  bool shouldFailBudget = false;
  bool shouldFailRemoveFavorite = false;

  @override
  Future<ApiResult<BudgetUpdateModel>> updateBudget(int newBudget) async {
    if (shouldFailBudget) return _failure('Budget tidak valid.');
    return _success(
      BudgetUpdateModel(userId: 'user-1', monthlyBudget: newBudget),
    );
  }

  @override
  Future<ApiResult<List<FavoriteModel>>> getFavorites() async {
    return _success(favorites);
  }

  @override
  Future<ApiResult<FavoriteModel>> addFavorite(String productId) async {
    final favorite = _favorite(productId);
    favorites = [...favorites, favorite];
    return _success(favorite);
  }

  @override
  Future<ApiResult<bool>> removeFavorite(String productId) async {
    if (shouldFailRemoveFavorite) {
      return _failure('Gagal menghapus favorit.');
    }
    favorites = favorites
        .where((favorite) => favorite.productId != productId)
        .toList(growable: false);
    return _success(true);
  }
}

class _FakeDashboardRepository extends DashboardRepository {
  @override
  Future<ApiResult<DashboardModel>> getDashboard() async {
    return _success(
      const DashboardModel(
        monthlyBudget: 2000000,
        budgetRemaining: 1500000,
        moneySaved: 125000,
        recentActivities: <RecentActivityModel>[
          RecentActivityModel(
            productName: 'Beras',
            price: 65000,
            decision: 'BUY',
            color: 'green',
            timestamp: '2026-05-18T00:00:00Z',
          ),
        ],
      ),
    );
  }
}

class _FakeTrackerRepository extends TrackerRepository {
  @override
  Future<ApiResult<TrackerModel>> getTracker({String? month}) async {
    return _success(
      const TrackerModel(
        totalSpent: 120000,
        totalItems: 2,
        avgPerItem: 60000,
        byCategory: <CategorySpendModel>[
          CategorySpendModel(
            category: 'sembako',
            amount: 120000,
            percentage: 100,
          ),
        ],
        items: <TrackerItemModel>[
          TrackerItemModel(
            productName: 'Beras',
            pricePaid: 65000,
            date: '2026-05-18',
            decisionScore: 80,
            actionTaken: 'BUY',
          ),
        ],
      ),
    );
  }
}
