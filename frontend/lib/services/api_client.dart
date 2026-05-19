import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide Headers, MultipartFile;

import '../config/local_config.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';

typedef AccessTokenProvider = FutureOr<String?> Function();
typedef UnauthorizedHandler = FutureOr<void> Function();

class LoginRequiredException implements Exception {
  const LoginRequiredException();

  @override
  String toString() => 'LoginRequiredException';
}

class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;
  final String? suggestion;
  final Object? cause;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code = 'API_ERROR',
    this.suggestion,
    this.cause,
  });

  factory ApiException.fromResponse(Response<dynamic>? response) {
    final data = response?.data;
    final statusCode = response?.statusCode;

    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        return ApiException(
          statusCode: statusCode,
          code: error['code']?.toString() ?? 'API_ERROR',
          message: error['message']?.toString() ?? 'Terjadi kesalahan.',
          suggestion: error['suggestion']?.toString(),
        );
      }

      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        return ApiException(
          statusCode: statusCode,
          code: detail['code']?.toString() ?? 'API_ERROR',
          message: detail['message']?.toString() ?? 'Terjadi kesalahan.',
          suggestion: detail['suggestion']?.toString(),
        );
      }

      final scanMessage = data['message'];
      if (scanMessage != null) {
        return ApiException(
          statusCode: statusCode,
          code: 'SCAN_ERROR',
          message: scanMessage.toString(),
        );
      }
    }

    return ApiException(
      statusCode: statusCode,
      code: 'HTTP_${statusCode ?? 'ERROR'}',
      message: response?.statusMessage ?? 'Terjadi kesalahan jaringan.',
    );
  }

  factory ApiException.fromDio(DioException error) {
    final cause = error.error;
    if (cause is LoginRequiredException) {
      return const ApiException(
        statusCode: 401,
        code: 'LOGIN_REQUIRED',
        message: 'Login diperlukan untuk mengakses fitur ini.',
      );
    }

    if (error.response != null) {
      return ApiException.fromResponse(error.response);
    }

    return ApiException(
      code: 'NETWORK_ERROR',
      message: error.message ?? 'Gagal terhubung ke server.',
      cause: error,
    );
  }

  @override
  String toString() => 'ApiException($code, $message)';
}

class ApiResult<T> {
  final T? data;
  final ApiException? error;

  const ApiResult._({this.data, this.error});

  factory ApiResult.success(T data) => ApiResult._(data: data);

  factory ApiResult.failure(ApiException error) => ApiResult._(error: error);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  T get requireData {
    final value = data;
    if (value == null) {
      throw StateError('ApiResult does not contain data.');
    }
    return value;
  }
}

class ApiClient {
  ApiClient({
    Dio? dio,
    AccessTokenProvider? accessTokenProvider,
    UnauthorizedHandler? unauthorizedHandler,
    String? baseUrlOverride,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrlOverride ?? baseUrl,
               connectTimeout: const Duration(seconds: 60),
               receiveTimeout: const Duration(seconds: 60),
               sendTimeout: const Duration(seconds: 60),
               responseType: ResponseType.json,
               headers: const <String, dynamic>{
                 Headers.acceptHeader: 'application/json',
                 Headers.contentTypeHeader: 'application/json',
               },
             ),
           ),
       _accessTokenProvider = accessTokenProvider ?? _defaultAccessToken,
       _unauthorizedHandler = unauthorizedHandler ?? _defaultUnauthorized {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _handleRequest, onError: _handleError),
    );
  }

  static final ApiClient instance = ApiClient();

  final Dio _dio;
  final AccessTokenProvider _accessTokenProvider;
  final UnauthorizedHandler _unauthorizedHandler;

  Dio get dio => _dio;

  static String get baseUrl {
    const configuredBaseUrl = String.fromEnvironment(
      'WORTHIT_API_BASE_URL',
      defaultValue: LocalConfig.apiBaseUrl,
    );
    final trimmedBaseUrl = configuredBaseUrl.trim();
    if (trimmedBaseUrl.isNotEmpty) {
      if (trimmedBaseUrl.startsWith('http://') ||
          trimmedBaseUrl.startsWith('https://')) {
        return trimmedBaseUrl;
      }
      return 'http://$trimmedBaseUrl';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static Session? get _session {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentSession;
  }

  static String? _defaultAccessToken() => _session?.accessToken;

  static Future<void> _defaultUnauthorized() async {
    if (!SupabaseConfig.isConfigured) return;
    await AuthService().logout();
  }

  static Future<Map<String, String>> headers({
    bool requireAuth = false,
    bool json = true,
  }) async {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    final token = _session?.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      return headers;
    }

    if (requireAuth) {
      throw const LoginRequiredException();
    }

    return headers;
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<dynamic>> uploadFile(
    String path, {
    required String fieldName,
    required String filePath,
    String? fileName,
    Map<String, dynamic>? fields,
  }) {
    final formData = FormData.fromMap(<String, dynamic>{
      ...?fields,
      fieldName: MultipartFile.fromFileSync(filePath, filename: fileName),
    });

    return _dio.post<dynamic>(
      path,
      data: formData,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
  }

  Future<Response<dynamic>> uploadBytes(
    String path, {
    required String fieldName,
    required List<int> fileBytes,
    required String fileName,
    Map<String, dynamic>? fields,
  }) {
    final formData = FormData.fromMap(<String, dynamic>{
      ...?fields,
      fieldName: MultipartFile.fromBytes(fileBytes, filename: fileName),
    });

    return _dio.post<dynamic>(
      path,
      data: formData,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
  }

  Future<ApiResult<T>> run<T>(Future<T> Function() request) async {
    try {
      return ApiResult.success(await request());
    } on DioException catch (error) {
      return ApiResult.failure(ApiException.fromDio(error));
    } on LoginRequiredException catch (error) {
      return ApiResult.failure(
        ApiException(
          statusCode: 401,
          code: 'LOGIN_REQUIRED',
          message: 'Login diperlukan untuk mengakses fitur ini.',
          cause: error,
        ),
      );
    } on ApiException catch (error) {
      return ApiResult.failure(error);
    } catch (error) {
      return ApiResult.failure(
        ApiException(
          code: 'UNKNOWN_ERROR',
          message: 'Terjadi kesalahan yang tidak diketahui.',
          cause: error,
        ),
      );
    }
  }

  Future<void> _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicEndpoint(options)) {
      handler.next(options);
      return;
    }

    final token = await _accessTokenProvider();
    if (token == null || token.isEmpty) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const LoginRequiredException(),
        ),
      );
      return;
    }

    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode == 401) {
      await _unauthorizedHandler();
    }
    handler.next(error);
  }

  bool _isPublicEndpoint(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;

    final path = _normalizedPath(options.path);
    if (path == '/v1/products') return true;
    if (path == '/v1/products/search') return true;

    final productDetailPattern = RegExp(r'^/v1/products/[^/]+$');
    return productDetailPattern.hasMatch(path);
  }

  String _normalizedPath(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      return uri.path;
    }
    final path = value.split('?').first;
    return path.startsWith('/') ? path : '/$path';
  }
}
