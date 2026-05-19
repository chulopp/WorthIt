import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  bool get isLoggedIn => _client?.auth.currentSession != null;

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<ApiResult<String?>> currentAccessToken() {
    return _apiClient.run(() async => _client?.auth.currentSession?.accessToken);
  }

  Future<ApiResult<bool>> logout() {
    return _apiClient.run(() async {
      await AuthService().logout();
      return true;
    });
  }

  Future<ApiResult<bool>> deleteAccount() {
    return _apiClient.run(() async {
      await _apiClient.delete('/v1/users/me');
      await AuthService().logout();
      return true;
    });
  }
}
