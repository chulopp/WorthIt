import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';

final historyControllerProvider =
    NotifierProvider<HistoryController, BaseControllerState<HistoryData>>(
      HistoryController.new,
    );

class HistoryController extends Notifier<BaseControllerState<HistoryData>> {
  bool _isFetchingScans = false;
  bool _isFetchingPurchases = false;

  @override
  BaseControllerState<HistoryData> build() {
    // Do NOT read `state` here — it is not yet initialised on first build.
    final authState = ref.watch(authProvider);
    if (authState.isAuthenticated) {
      Future.microtask(() {
        final d = state.data;
        final isEmpty = d == null || (d.scans.isEmpty && d.purchases.isEmpty);
        if (isEmpty && !state.isLoading && !_isFetchingScans && !_isFetchingPurchases) {
          fetchScans();
          fetchPurchases();
        }
      });
    }
    return const BaseControllerState<HistoryData>(data: HistoryData());
  }

  Future<void> fetchScans() async {
    if (_isFetchingScans) return;
    _isFetchingScans = true;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref.read(historyRepositoryProvider).getScanHistory();
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: _isFetchingPurchases,
          errorMessage: apiErrorMessage(result.error),
        );
        return;
      }

      state = state.copyWith(
        isLoading: _isFetchingPurchases,
        errorMessage: null,
        data: (state.data ?? const HistoryData()).copyWith(
          scans: result.requireData,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: _isFetchingPurchases,
        errorMessage: unexpectedErrorMessage(error),
      );
    } finally {
      _isFetchingScans = false;
    }
  }

  Future<void> fetchPurchases() async {
    if (_isFetchingPurchases) return;
    _isFetchingPurchases = true;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref
          .read(historyRepositoryProvider)
          .getPurchaseHistory();
      if (result.isFailure) {
        state = state.copyWith(
          isLoading: _isFetchingScans,
          errorMessage: apiErrorMessage(result.error),
        );
        return;
      }

      state = state.copyWith(
        isLoading: _isFetchingScans,
        errorMessage: null,
        data: (state.data ?? const HistoryData()).copyWith(
          purchases: result.requireData,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: _isFetchingScans,
        errorMessage: unexpectedErrorMessage(error),
      );
    } finally {
      _isFetchingPurchases = false;
    }
  }
}
