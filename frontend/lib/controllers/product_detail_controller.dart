import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';
import '../models/api/api_models.dart';

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

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      data: null,
      searchResults: const [],
    );
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .searchProducts(trimmedKeyword);
      if (requestId != _productListRequestId) return;
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
        searchResults: result.requireData,
      );
    } catch (error) {
      if (requestId != _productListRequestId) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }

  Future<void> listProducts({String? category, int limit = 20}) async {
    final requestId = ++_productListRequestId;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      data: null,
      searchResults: const [],
    );
    try {
      final result = await ref
          .read(productRepositoryProvider)
          .listProducts(category: category, limit: limit);
      if (requestId != _productListRequestId) return;
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
        searchResults: result.requireData,
      );
    } catch (error) {
      if (requestId != _productListRequestId) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }

  Future<void> loadProductDetail(String productId) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      data: null,
    );
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
