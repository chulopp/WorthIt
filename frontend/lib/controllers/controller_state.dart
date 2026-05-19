import '../models/api/api_models.dart';

const Object _unchanged = Object();

class BaseControllerState<T> {
  final bool isLoading;
  final String? errorMessage;
  final T? data;

  const BaseControllerState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
  });

  BaseControllerState<T> copyWith({
    bool? isLoading,
    Object? errorMessage = _unchanged,
    Object? data = _unchanged,
  }) {
    return BaseControllerState<T>(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
      data: identical(data, _unchanged) ? this.data : data as T?,
    );
  }
}

class AnalyzeState {
  final bool isLoading;
  final String? errorMessage;
  final AnalyzeResponseModel? data;
  final ScanResultModel? scanResult;
  final String? dbProductId;
  final double? scannedPrice;
  final double? weightGram;
  final int urgency;
  final PurchaseItemModel? purchase;

  const AnalyzeState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
    this.scanResult,
    this.dbProductId,
    this.scannedPrice,
    this.weightGram,
    this.urgency = 2,
    this.purchase,
  });

  AnalyzeState copyWith({
    bool? isLoading,
    Object? errorMessage = _unchanged,
    Object? data = _unchanged,
    Object? scanResult = _unchanged,
    Object? dbProductId = _unchanged,
    Object? scannedPrice = _unchanged,
    Object? weightGram = _unchanged,
    int? urgency,
    Object? purchase = _unchanged,
  }) {
    return AnalyzeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
      data: identical(data, _unchanged)
          ? this.data
          : data as AnalyzeResponseModel?,
      scanResult: identical(scanResult, _unchanged)
          ? this.scanResult
          : scanResult as ScanResultModel?,
      dbProductId: identical(dbProductId, _unchanged)
          ? this.dbProductId
          : dbProductId as String?,
      scannedPrice: identical(scannedPrice, _unchanged)
          ? this.scannedPrice
          : scannedPrice as double?,
      weightGram: identical(weightGram, _unchanged)
          ? this.weightGram
          : weightGram as double?,
      urgency: urgency ?? this.urgency,
      purchase: identical(purchase, _unchanged)
          ? this.purchase
          : purchase as PurchaseItemModel?,
    );
  }
}

class ProductDetailState {
  final bool isLoading;
  final String? errorMessage;
  final ProductDetailModel? data;
  final List<ProductSummaryModel> searchResults;

  const ProductDetailState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
    this.searchResults = const <ProductSummaryModel>[],
  });

  ProductDetailState copyWith({
    bool? isLoading,
    Object? errorMessage = _unchanged,
    Object? data = _unchanged,
    List<ProductSummaryModel>? searchResults,
  }) {
    return ProductDetailState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
      data: identical(data, _unchanged)
          ? this.data
          : data as ProductDetailModel?,
      searchResults: searchResults ?? this.searchResults,
    );
  }
}

class HistoryData {
  final List<ScanHistoryItemModel> scans;
  final List<PurchaseHistoryModel> purchases;

  const HistoryData({
    this.scans = const <ScanHistoryItemModel>[],
    this.purchases = const <PurchaseHistoryModel>[],
  });

  HistoryData copyWith({
    List<ScanHistoryItemModel>? scans,
    List<PurchaseHistoryModel>? purchases,
  }) {
    return HistoryData(
      scans: scans ?? this.scans,
      purchases: purchases ?? this.purchases,
    );
  }

  double get totalPengeluaranTersimpan {
    var total = 0.0;
    for (final item in scans) {
      final decision = (item.decision ?? '').trim().toLowerCase();
      final scannedPrice = item.scannedPrice;
      final normalPrice = item.normalPrice;
      if (decision == 'worthit' &&
          scannedPrice != null &&
          normalPrice != null &&
          scannedPrice < normalPrice) {
        total += normalPrice - scannedPrice;
      }
    }
    return total;
  }
}

class FavoriteState {
  final bool isLoading;
  final String? errorMessage;
  final List<FavoriteModel>? data;
  final Set<String> favoriteProductIds;

  const FavoriteState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
    this.favoriteProductIds = const <String>{},
  });

  bool isFavorite(String productId) => favoriteProductIds.contains(productId);

  FavoriteState copyWith({
    bool? isLoading,
    Object? errorMessage = _unchanged,
    Object? data = _unchanged,
    Set<String>? favoriteProductIds,
  }) {
    final nextData = identical(data, _unchanged)
        ? this.data
        : data as List<FavoriteModel>?;
    return FavoriteState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
      data: nextData,
      favoriteProductIds:
          favoriteProductIds ??
          (nextData == null
              ? this.favoriteProductIds
              : nextData.map((item) => item.productId).toSet()),
    );
  }
}
