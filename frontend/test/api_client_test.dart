import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worthit_app/services/api_client.dart';

void main() {
  group('ApiClient interceptor', () {
    test('does not attach auth header to public product search', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: <String, dynamic>{'status': 'success', 'data': <dynamic>[]},
      );
      final client = _client(adapter, token: 'token-123');

      await client.get('/v1/products/search');

      expect(adapter.lastOptions?.headers['Authorization'], isNull);
    });

    test('does not attach auth header to public product detail', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: <String, dynamic>{
          'status': 'success',
          'data': <String, dynamic>{
            'id': 'product-1',
            'name': 'Produk',
            'history': <dynamic>[],
          },
        },
      );
      final client = _client(adapter, token: 'token-123');

      await client.get('/v1/products/product-1');

      expect(adapter.lastOptions?.headers['Authorization'], isNull);
    });

    test('attaches auth header to protected endpoints', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: <String, dynamic>{'status': 'success', 'data': <dynamic>[]},
      );
      final client = _client(adapter, token: 'token-123');

      await client.get('/v1/history/purchases');

      expect(
        adapter.lastOptions?.headers['Authorization'],
        equals('Bearer token-123'),
      );
    });

    test(
      'returns login-required failure when protected endpoint has no token',
      () async {
        final adapter = _FakeAdapter(
          statusCode: 200,
          body: <String, dynamic>{'status': 'success'},
        );
        final client = _client(adapter);

        final result = await client.run(
          () => client.get('/v1/history/purchases'),
        );

        expect(result.isFailure, isTrue);
        expect(result.error?.code, equals('LOGIN_REQUIRED'));
        expect(adapter.lastOptions, isNull);
      },
    );

    test('maps FastAPI standard error response', () async {
      final adapter = _FakeAdapter(
        statusCode: 422,
        body: <String, dynamic>{
          'status': 'error',
          'error': <String, dynamic>{
            'code': 'INVALID_INPUT',
            'message': 'Input tidak valid.',
            'suggestion': 'Periksa payload.',
          },
        },
      );
      final client = _client(adapter, token: 'token-123');

      final result = await client.run(() => client.post('/v1/analyze'));

      expect(result.isFailure, isTrue);
      expect(result.error?.statusCode, equals(422));
      expect(result.error?.code, equals('INVALID_INPUT'));
      expect(result.error?.message, equals('Input tidak valid.'));
      expect(result.error?.suggestion, equals('Periksa payload.'));
    });

    test('maps FastAPI HTTPException detail response', () async {
      final adapter = _FakeAdapter(
        statusCode: 404,
        body: <String, dynamic>{
          'detail': <String, dynamic>{
            'code': 'PRODUCT_NOT_FOUND',
            'message': 'Produk tidak ditemukan.',
            'suggestion': 'Pilih produk dari katalog.',
          },
        },
      );
      final client = _client(adapter, token: 'token-123');

      final result = await client.run(() => client.get('/v1/products/missing'));

      expect(result.isFailure, isTrue);
      expect(result.error?.code, equals('PRODUCT_NOT_FOUND'));
      expect(result.error?.message, equals('Produk tidak ditemukan.'));
      expect(result.error?.suggestion, equals('Pilih produk dari katalog.'));
    });

    test('maps scan error response', () async {
      final adapter = _FakeAdapter(
        statusCode: 404,
        body: <String, dynamic>{
          'status': 'error',
          'message': 'Produk tidak terdeteksi pada gambar',
        },
      );
      final client = _client(adapter, token: 'token-123');

      final result = await client.run(() => client.post('/v1/scan'));

      expect(result.isFailure, isTrue);
      expect(result.error?.statusCode, equals(404));
      expect(result.error?.code, equals('SCAN_ERROR'));
      expect(
        result.error?.message,
        equals('Produk tidak terdeteksi pada gambar'),
      );
    });
  });
}

ApiClient _client(_FakeAdapter adapter, {String? token}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://worthit.test',
      responseType: ResponseType.json,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = adapter;

  return ApiClient(
    dio: dio,
    accessTokenProvider: () => token,
    unauthorizedHandler: () {},
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Object body;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
