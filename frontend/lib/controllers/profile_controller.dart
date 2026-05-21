import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

final profileUsernameProvider =
    AsyncNotifierProvider<ProfileUsernameNotifier, String>(
      ProfileUsernameNotifier.new,
    );

class ProfileUsernameNotifier extends AsyncNotifier<String> {
  @override
  FutureOr<String> build() async {
    return fetchUsername();
  }

  Future<String> fetchUsername() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'imameeee_if';

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      final dbName = data?['full_name'] as String?;
      if (dbName != null && dbName.trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', dbName.trim());
        return dbName.trim();
      }
    } catch (_) {}

    // Fallback 1: Google metadata
    final googleName =
        user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
    if (googleName != null && googleName.toString().trim().isNotEmpty) {
      final name = googleName.toString().trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', name);
      try {
        await Supabase.instance.client
            .from('users')
            .update({'full_name': name})
            .eq('id', user.id);
      } catch (_) {}
      return name;
    }

    // Fallback 2: SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('username');
    if (savedName != null && savedName.trim().isNotEmpty) {
      return savedName.trim();
    }

    // Fallback 3: Email prefix
    final emailName = user.email?.split('@').first;
    final finalFallback = emailName ?? 'imameeee_if';
    await prefs.setString('username', finalFallback);
    return finalFallback;
  }

  Future<void> updateUsername(String newName) async {
    state = const AsyncValue.loading();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'full_name': newName})
            .eq('id', user.id);
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', newName);
    state = AsyncValue.data(newName);
  }
}
