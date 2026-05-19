import '../models/api/api_models.dart';
import '../services/api_client.dart';
import 'repository_helpers.dart';

class ShoppingListRepository {
  ShoppingListRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResult<MonthlyShoppingListModel>> getCurrent() {
    return _apiClient.run(() async {
      final response = await _apiClient.get('/v1/shopping-list/current');
      return MonthlyShoppingListModel.fromJson(responseMap(response));
    });
  }

  Future<ApiResult<MonthlyShoppingListModel>> addItem(
    String productId, {
    int quantity = 1,
  }) {
    return _apiClient.run(() async {
      final response = await _apiClient.post(
        '/v1/shopping-list/current/items',
        data: <String, dynamic>{
          'product_id': productId,
          'quantity': quantity,
        },
      );
      return MonthlyShoppingListModel.fromJson(responseMap(response));
    });
  }

  Future<ApiResult<MonthlyShoppingListModel>> deleteItem(String itemId) {
    return _apiClient.run(() async {
      final response = await _apiClient.delete(
        '/v1/shopping-list/current/items/$itemId',
      );
      return MonthlyShoppingListModel.fromJson(responseMap(response));
    });
  }

  Future<ApiResult<MonthlyShoppingListModel>> toggleItem(String itemId) {
    return _apiClient.run(() async {
      final response = await _apiClient.patch(
        '/v1/shopping-list/current/items/$itemId/toggle',
      );
      return MonthlyShoppingListModel.fromJson(responseMap(response));
    });
  }

  Future<ApiResult<MonthlyShoppingListModel>> clearCurrent() {
    return _apiClient.run(() async {
      final response = await _apiClient.delete(
        '/v1/shopping-list/current/items',
      );
      return MonthlyShoppingListModel.fromJson(responseMap(response));
    });
  }
}
