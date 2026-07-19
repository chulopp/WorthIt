import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/api/api_models.dart';
import 'auth_controller.dart';
import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';

final dashboardControllerProvider =
    NotifierProvider<DashboardController, BaseControllerState<DashboardModel>>(
      DashboardController.new,
    );

class DashboardController
    extends Notifier<BaseControllerState<DashboardModel>> {
  @override
  BaseControllerState<DashboardModel> build() {
    // Auto-fetch when auth state resolves to authenticated.
    // Do NOT read `state` here — it is not yet initialised on first build.
    final authState = ref.watch(authProvider);
    if (authState.isAuthenticated) {
      Future.microtask(() {
        // Guard inside the microtask where `state` is already live.
        if (state.data == null && !state.isLoading) fetchDashboard();
      });
    }
    return const BaseControllerState<DashboardModel>();
  }

  Future<void> fetchDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await ref.read(dashboardRepositoryProvider).getDashboard();
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
