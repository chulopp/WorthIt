import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';
import '../models/api/api_models.dart';

const int _pageSize = 20;

final productCatalogProvider = FutureProvider<List<ProductSummaryModel>>((
  ref,
) async {
  final result = await ref.read(productRepositoryProvider).listProducts();
  if (result.isFailure) {
    throw Exception(apiErrorMessage(result.error));
  }
  return result.requireData;
});

final productDetailControllerProvider =
    NotifierProvider<ProductDetailController, ProductDetailState>(
      ProductDetailController.new,
    );

class ProductDetailController extends Notifier<ProductDetailState> {
  int _productListRequestId = 0;

  // Infinite scroll state for catalog
  int _catalogOffset = 0;
  bool _catalogHasMore = true;
  bool _isLoadingMore = false;
  String? _currentCategory;

  // Infinite scroll state for search
  int _searchOffset = 0;
  bool _searchHasMore = true;
  String _currentKeyword = '';

  @override
  ProductDetailState build() {
    return const ProductDetailState();
  }

  Future<void> searchProducts(String keyword) async {
    final requestId = ++_productListRequestId;
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        data: null,
        searchResults: const [],
      );
      return;
    }

    // Reset search pagination on new keyword
    _currentKeyword = trimmedKeyword;
    _searchOffset = 0;
    _searchHasMore = true;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      data: null,
      searchResults: const [],
    );
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .searchProducts(trimmedKeyword, limit: _pageSize, offset: 0);
      if (requestId != _productListRequestId) return;
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
        );
        return;
      }

      final data = result.requireData;
      _searchOffset = data.length;
      _searchHasMore = data.length >= _pageSize;

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        searchResults: data,
      );
    } catch (error) {
      if (requestId != _productListRequestId) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }

  Future<void> loadMoreSearchResults() async {
    if (!_searchHasMore || _isLoadingMore || _currentKeyword.isEmpty) return;
    _isLoadingMore = true;
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .searchProducts(_currentKeyword, limit: _pageSize, offset: _searchOffset);
      if (result.isSuccess) {
        final data = result.requireData;
        _searchOffset += data.length;
        _searchHasMore = data.length >= _pageSize;
        state = state.copyWith(
          searchResults: <ProductSummaryModel>[...state.searchResults, ...data],
        );
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> listProducts({String? category, int limit = _pageSize}) async {
    final requestId = ++_productListRequestId;

    // Reset catalog pagination
    _currentCategory = category;
    _catalogOffset = 0;
    _catalogHasMore = true;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      data: null,
      searchResults: const [],
    );
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .listProducts(category: category, limit: limit, offset: 0);
      if (requestId != _productListRequestId) return;
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
        );
        return;
      }

      final data = result.requireData;
      _catalogOffset = data.length;
      _catalogHasMore = data.length >= limit;

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        searchResults: data,
      );
    } catch (error) {
      if (requestId != _productListRequestId) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }

  Future<void> loadMoreCatalog() async {
    if (!_catalogHasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .listProducts(
            category: _currentCategory,
            limit: _pageSize,
            offset: _catalogOffset,
          );
      if (result.isSuccess) {
        final data = result.requireData;
        _catalogOffset += data.length;
        _catalogHasMore = data.length >= _pageSize;
        state = state.copyWith(
          searchResults: <ProductSummaryModel>[...state.searchResults, ...data],
        );
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  bool get catalogHasMore => _catalogHasMore;
  bool get searchHasMore => _searchHasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadProductDetail(String productId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, data: null);
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .getProductDetail(productId);
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        data: result.requireData,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }
}
