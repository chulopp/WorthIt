import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api/api_models.dart';
import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';

final profileControllerProvider =
    NotifierProvider<ProfileController, BaseControllerState<BudgetUpdateModel>>(
      ProfileController.new,
    );

class ProfileController
    extends Notifier<BaseControllerState<BudgetUpdateModel>> {
  @override
  BaseControllerState<BudgetUpdateModel> build() {
    return const BaseControllerState<BudgetUpdateModel>();
  }

  Future<void> updateBudget(int newBudget) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref
          .read(userRepositoryProvider)
          .updateBudget(newBudget);
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
