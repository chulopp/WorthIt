import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api/api_models.dart';
import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';

final favoriteControllerProvider =
    NotifierProvider<FavoriteController, FavoriteState>(FavoriteController.new);

class FavoriteController extends Notifier<FavoriteState> {
  @override
  FavoriteState build() {
    return const FavoriteState(data: <FavoriteModel>[]);
  }

  Future<void> fetchFavorites() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref.read(userRepositoryProvider).getFavorites();
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
        );
        return;
      }

      final favorites = result.requireData;
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        data: favorites,
        favoriteProductIds: favorites.map((item) => item.productId).toSet(),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }

  Future<void> toggleFavorite(String productId, {FavoriteModel? product}) {
    if (state.isFavorite(productId)) {
      return removeFavorite(productId);
    }
    return addFavorite(productId, product: product);
  }

  Future<void> addFavorite(String productId, {FavoriteModel? product}) {
    final currentFavorites = state.data ?? const <FavoriteModel>[];
    if (state.isFavorite(productId)) return Future.value();

    final optimisticFavorite =
        product ??
        FavoriteModel(
          favoriteId: 'optimistic-$productId',
          productId: productId,
          productName: 'Produk',
          favoritedAt: DateTime.now().toIso8601String(),
        );
    final optimisticFavorites = <FavoriteModel>[
      ...currentFavorites,
      optimisticFavorite,
    ];
    state = state.copyWith(
      isLoading: false,
      errorMessage: null,
      data: optimisticFavorites,
      favoriteProductIds: optimisticFavorites
          .map((item) => item.productId)
          .toSet(),
    );

    unawaited(_commitAddFavorite(productId));
    return Future.value();
  }

  Future<void> removeFavorite(String productId) {
    final currentFavorites = state.data ?? const <FavoriteModel>[];
    FavoriteModel? removedFavorite;
    for (final favorite in currentFavorites) {
      if (favorite.productId == productId) {
        removedFavorite = favorite;
        break;
      }
    }
    if (removedFavorite == null && !state.isFavorite(productId)) {
      return Future.value();
    }

    final optimisticFavorites = currentFavorites
        .where((favorite) => favorite.productId != productId)
        .toList(growable: false);
    state = state.copyWith(
      isLoading: false,
      errorMessage: null,
      data: optimisticFavorites,
      favoriteProductIds: optimisticFavorites
          .map((item) => item.productId)
          .toSet(),
    );

    unawaited(_commitRemoveFavorite(productId, removedFavorite));
    return Future.value();
  }

  Future<void> _commitAddFavorite(String productId) async {
    try {
      final result = await ref
          .read(userRepositoryProvider)
          .addFavorite(productId);
      if (result.isFailure) {
        _rollbackAddedFavorite(productId, apiErrorMessage(result.error));
        return;
      }

      final confirmedFavorite = result.requireData;
      final currentFavorites = state.data ?? const <FavoriteModel>[];
      final confirmedFavorites = currentFavorites
          .map(
            (favorite) =>
                favorite.productId == productId ? confirmedFavorite : favorite,
          )
          .toList(growable: false);
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        data: confirmedFavorites,
        favoriteProductIds: confirmedFavorites
            .map((item) => item.productId)
            .toSet(),
      );
    } catch (error) {
      _rollbackAddedFavorite(productId, unexpectedErrorMessage(error));
    }
  }

  Future<void> _commitRemoveFavorite(
    String productId,
    FavoriteModel? removedFavorite,
  ) async {
    try {
      final result = await ref
          .read(userRepositoryProvider)
          .removeFavorite(productId);
      if (result.isFailure) {
        _rollbackRemovedFavorite(
          removedFavorite,
          apiErrorMessage(result.error),
        );
        return;
      }
      state = state.copyWith(isLoading: false, errorMessage: null);
    } catch (error) {
      _rollbackRemovedFavorite(removedFavorite, unexpectedErrorMessage(error));
    }
  }

  void _rollbackAddedFavorite(String productId, String message) {
    final rolledBackFavorites = (state.data ?? const <FavoriteModel>[])
        .where((favorite) => favorite.productId != productId)
        .toList(growable: false);
    state = state.copyWith(
      isLoading: false,
      errorMessage: message,
      data: rolledBackFavorites,
      favoriteProductIds: rolledBackFavorites
          .map((item) => item.productId)
          .toSet(),
    );
  }

  void _rollbackRemovedFavorite(
    FavoriteModel? removedFavorite,
    String message,
  ) {
    final currentFavorites = state.data ?? const <FavoriteModel>[];
    final shouldRestore =
        removedFavorite != null &&
        !currentFavorites.any(
          (favorite) => favorite.productId == removedFavorite.productId,
        );
    final rolledBackFavorites = shouldRestore
        ? <FavoriteModel>[...currentFavorites, removedFavorite]
        : currentFavorites;

    state = state.copyWith(
      isLoading: false,
      errorMessage: message,
      data: rolledBackFavorites,
      favoriteProductIds: rolledBackFavorites
          .map((item) => item.productId)
          .toSet(),
    );
  }
}
