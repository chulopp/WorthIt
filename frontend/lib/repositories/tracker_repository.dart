import '../models/api/api_models.dart';
import '../services/api_client.dart';
import 'repository_helpers.dart';

class TrackerRepository {
  TrackerRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<ApiResult<TrackerModel>> getTracker({String? month}) {
    return _apiClient.run(() async {
      final response = await _apiClient.get(
        '/v1/tracker',
        queryParameters: month == null ? null : <String, dynamic>{'month': month},
      );
      return TrackerModel.fromJson(responseDataMap(response));
    });
  }
}
