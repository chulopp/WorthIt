import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/api/api_models.dart';
import 'controller_helpers.dart';
import 'controller_state.dart';
import 'repository_providers.dart';

String? _nonEmptyString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String extractNameFromEmail(String? email) {
  final value = email?.trim();
  if (value == null || value.isEmpty) return '';
  final atIndex = value.indexOf('@');
  final name = atIndex > 0 ? value.substring(0, atIndex) : value;
  return name.trim();
}

String userNameFromAuth(User? user) {
  if (user == null) return '';
  final metadata = user.userMetadata;
  return _nonEmptyString(metadata?['name']) ??
      _nonEmptyString(metadata?['full_name']) ??
      extractNameFromEmail(user.email);
}

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
    if (user == null) return '';

    final authName = userNameFromAuth(user);
    if (authName.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', authName);
      try {
        await Supabase.instance.client
            .from('users')
            .update({'full_name': authName})
            .eq('id', user.id);
      } catch (_) {}
      return authName;
    }

    return '';
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
