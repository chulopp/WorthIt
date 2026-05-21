import '../models/api/api_models.dart';
import '../services/api_client.dart';
import 'repository_helpers.dart';

class HistoryRepository {
  HistoryRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResult<List<ScanHistoryItemModel>>> getScanHistory({
    String? productId,
  }) {
    return _apiClient.run(() async {
      final response = await _apiClient.get(
        '/v1/history/scans',
        queryParameters: productId == null
            ? null
            : <String, dynamic>{'product_id': productId},
      );
      return responseDataList(
        response,
      ).map(ScanHistoryItemModel.fromJson).toList(growable: false);
    });
  }

  Future<ApiResult<List<PurchaseHistoryModel>>> getPurchaseHistory() {
    return _apiClient.run(() async {
      final response = await _apiClient.get('/v1/history/purchases');
      return responseDataList(
        response,
      ).map(PurchaseHistoryModel.fromJson).toList(growable: false);
    });
  }

  Future<ApiResult<PurchaseItemModel>> createPurchase({
    required String productId,
    required int purchasedPrice,
    int quantity = 1,
  }) {
    return _apiClient.run(() async {
      final response = await _apiClient.post(
        '/v1/history/purchases',
        data: <String, dynamic>{
          'product_id': productId,
          'purchased_price': purchasedPrice,
          'quantity': quantity,
        },
      );
      return PurchaseItemModel.fromJson(responseDataMap(response));
    });
  }
}
