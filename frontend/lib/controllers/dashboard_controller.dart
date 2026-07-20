import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/api/api_models.dart';
import '../services/notification_service.dart';
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

      final data = result.requireData;
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        data: data,
      );

      // Check over budget notification trigger
      if (data.monthlyBudget > 0) {
        final totalSpent = data.monthlyBudget - data.budgetRemaining;
        if (totalSpent >= data.monthlyBudget) {
          NotificationService().notifyOverBudget(
            totalSpending: totalSpent,
            monthlyBudget: data.monthlyBudget,
          );
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            try {
              await Supabase.instance.client.from('notifications').insert({
                'user_id': user.id,
                'title': 'Peringatan Batas Anggaran',
                'body':
                    'Pengeluaran bulan ini (Rp ${totalSpent.round()}) telah melebihi batas anggaran bulanan Anda (Rp ${data.monthlyBudget.round()}).',
                'type': 'OVER_BUDGET',
                'is_read': false,
              });
            } catch (_) {}
          }
        }
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: unexpectedErrorMessage(error),
      );
    }
  }
}
