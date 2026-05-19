import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api/api_models.dart';
import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';

final shoppingListControllerProvider =
    NotifierProvider<
      ShoppingListController,
      BaseControllerState<MonthlyShoppingListModel>
    >(ShoppingListController.new);

class ShoppingListController
    extends Notifier<BaseControllerState<MonthlyShoppingListModel>> {
  @override
  BaseControllerState<MonthlyShoppingListModel> build() {
    return const BaseControllerState<MonthlyShoppingListModel>();
  }

  Future<void> fetchCurrentList() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref
          .read(shoppingListRepositoryProvider)
          .getCurrent();
      if (result.isFailure) {
        if (result.error?.statusCode == 404) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: null,
            data: _emptyCurrentList(),
          );
          return;
        }

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

  MonthlyShoppingListModel _emptyCurrentList() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return MonthlyShoppingListModel(
      listId: '',
      periodMonth: '${now.year}-$month',
      totalBudget: 0,
      totalEstimatedPrice: 0,
      items: const <ShoppingItemModel>[],
    );
  }

  Future<void> addItem(
    String productId,
    int quantity, {
    ProductSummaryModel? product,
  }) async {
    final previousList = state.data ?? _emptyCurrentList();
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      data: previousList,
    );

    try {
      final result = await ref
          .read(shoppingListRepositoryProvider)
          .addItem(productId, quantity: quantity);
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
          data: previousList,
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
        data: previousList,
      );
    }
  }

  MonthlyShoppingListModel _copyList(
    MonthlyShoppingListModel list, {
    required List<ShoppingItemModel> items,
  }) {
    final total = items.fold<double>(
      0,
      (sum, item) => sum + (item.currentPrice * item.quantity),
    );
    return MonthlyShoppingListModel(
      listId: list.listId,
      periodMonth: list.periodMonth,
      totalBudget: list.totalBudget,
      totalEstimatedPrice: total,
      items: items,
    );
  }

  Future<void> removeItem(String itemId) async {
    final previousList = state.data ?? _emptyCurrentList();
    final optimisticItems = previousList.items
        .where((item) => item.id != itemId)
        .toList(growable: false);
    state = state.copyWith(
      isLoading: false,
      errorMessage: null,
      data: _copyList(previousList, items: optimisticItems),
    );
    try {
      final result = await ref
          .read(shoppingListRepositoryProvider)
          .deleteItem(itemId);
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
          data: previousList,
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
        data: previousList,
      );
    }
  }

  Future<void> toggleItem(String itemId) async {
    final previousList = state.data ?? _emptyCurrentList();
    final optimisticItems = previousList.items
        .map(
          (item) => item.id == itemId
              ? ShoppingItemModel(
                  id: item.id,
                  productId: item.productId,
                  productName: item.productName,
                  imageUrl: item.imageUrl,
                  category: item.category,
                  currentPrice: item.currentPrice,
                  quantity: item.quantity,
                  isBought: !item.isBought,
                )
              : item,
        )
        .toList(growable: false);
    state = state.copyWith(
      isLoading: false,
      errorMessage: null,
      data: _copyList(previousList, items: optimisticItems),
    );

    try {
      final result = await ref
          .read(shoppingListRepositoryProvider)
          .toggleItem(itemId);
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
          data: previousList,
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
        data: previousList,
      );
    }
  }

  Future<void> clearAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref
          .read(shoppingListRepositoryProvider)
          .clearCurrent();
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: apiErrorMessage(result.error),
        );
        return;
      }
      await fetchCurrentList();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }
}
