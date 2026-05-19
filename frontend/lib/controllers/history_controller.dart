import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';

final historyControllerProvider =
    NotifierProvider<HistoryController, BaseControllerState<HistoryData>>(
      HistoryController.new,
    );

class HistoryController extends Notifier<BaseControllerState<HistoryData>> {
  @override
  BaseControllerState<HistoryData> build() {
    return const BaseControllerState<HistoryData>(data: HistoryData());
  }

  Future<void> fetchScans() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref.read(historyRepositoryProvider).getScanHistory();
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
        data: (state.data ?? const HistoryData()).copyWith(
          scans: result.requireData,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }

  Future<void> fetchPurchases() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref
          .read(historyRepositoryProvider)
          .getPurchaseHistory();
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
        data: (state.data ?? const HistoryData()).copyWith(
          purchases: result.requireData,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }
}
