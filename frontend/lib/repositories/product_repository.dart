import '../models/api/api_models.dart';
import '../services/api_client.dart';
import 'repository_helpers.dart';

class ProductRepository {
  ProductRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  static const int productFetchLimit = 100;

  final ApiClient _apiClient;

  int _boundedLimit(int limit) => limit.clamp(1, productFetchLimit).toInt();

  Future<ApiResult<List<ProductSummaryModel>>> listProducts({
    String? category,
    int limit = productFetchLimit,
    int offset = 0,
  }) {
    return _apiClient.run(() async {
      final response = await _apiClient.get(
        '/v1/products',
        queryParameters: <String, dynamic>{
          if (category != null && category.isNotEmpty) 'category': category,
          'limit': _boundedLimit(limit),
          'offset': offset,
        },
      );
      return responseDataList(
        response,
      ).map(ProductSummaryModel.fromJson).toList(growable: false);
    });
  }

  Future<ApiResult<List<ProductSummaryModel>>> searchProducts(
    String keyword, {
    int limit = productFetchLimit,
  }) {
    return _apiClient.run(() async {
      final response = await _apiClient.get(
        '/v1/products/search',
        queryParameters: <String, dynamic>{
          'keyword': keyword,
          'limit': _boundedLimit(limit),
        },
      );
      return responseDataList(
        response,
      ).map(ProductSummaryModel.fromJson).toList(growable: false);
    });
  }

  Future<ApiResult<ProductDetailModel>> getProductDetail(String id) {
    return _apiClient.run(() async {
      final response = await _apiClient.get('/v1/products/$id');
      return ProductDetailModel.fromJson(responseDataMap(response));
    });
  }
}
