import '../models/api/api_models.dart';
import '../services/api_client.dart';
import 'repository_helpers.dart';

class DashboardRepository {
  DashboardRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResult<DashboardModel>> getDashboard() {
    return _apiClient.run(() async {
      final response = await _apiClient.get('/v1/dashboard');
      return DashboardModel.fromJson(responseDataMap(response));
    });
  }
}
