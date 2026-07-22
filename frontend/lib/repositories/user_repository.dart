import '../models/api/api_models.dart';
import '../services/api_client.dart';
import 'repository_helpers.dart';

class UserRepository {
  UserRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResult<BudgetUpdateModel>> updateBudget(int newBudget) {
    return _apiClient.run(() async {
      final response = await _apiClient.patch(
        '/v1/users/me/budget',
        data: <String, dynamic>{'new_budget': newBudget},
      );
      return BudgetUpdateModel.fromJson(responseMap(response));
    });
  }

  Future<ApiResult<bool>> updateUsername(String displayName) {
    return _apiClient.run(() async {
      final response = await _apiClient.patch(
        '/v1/users/me/username',
        data: <String, dynamic>{'display_name': displayName},
      );
      final map = responseMap(response);
      return map['status'] == 'success';
    });
  }

  Future<ApiResult<String>> getDisplayName() {
    return _apiClient.run(() async {
      final response = await _apiClient.get('/v1/users/me');
      final map = responseMap(response);
      return (map['display_name'] as String?) ?? '';
    });
  }

  Future<ApiResult<String>> getSubscriptionTier() {
    return _apiClient.run(() async {
      final response = await _apiClient.get('/v1/users/me');
      final map = responseMap(response);
      return ((map['subscription_tier'] as String?) ?? 'FREE').toUpperCase();
    });
  }

  Future<ApiResult<bool>> upgradeToProTier() {
    return _apiClient.run(() async {
      final response = await _apiClient.post('/v1/users/me/upgrade', data: {});
      final map = responseMap(response);
      return (map['subscription_tier'] as String?)?.toUpperCase() == 'PRO';
    });
  }

  Future<ApiResult<List<FavoriteModel>>> getFavorites() {
    return _apiClient.run(() async {
      final response = await _apiClient.get('/v1/favorites');
      return responseDataList(
        response,
      ).map(FavoriteModel.fromJson).toList(growable: false);
    });
  }

  Future<ApiResult<FavoriteModel>> addFavorite(String productId) {
    return _apiClient.run(() async {
      final response = await _apiClient.post(
        '/v1/favorites',
        data: <String, dynamic>{'product_id': productId},
      );
      return FavoriteModel.fromJson(responseDataMap(response));
    });
  }

  Future<ApiResult<bool>> removeFavorite(String productId) {
    return _apiClient.run(() async {
      final response = await _apiClient.delete('/v1/favorites/$productId');
      final map = responseMap(response);
      return map['deleted'] == true;
    });
  }
}
