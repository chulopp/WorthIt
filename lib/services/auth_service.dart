import 'package:flutter/material.dart';

/// Lightweight singleton auth service.
///
/// Stores login state via [ValueNotifier] so any widget can listen reactively.
class AuthService {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ── State ──────────────────────────────────────────────────────────────
  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPro = ValueNotifier<bool>(false);

  // ── Actions ────────────────────────────────────────────────────────────
  void login() => isLoggedIn.value = true;

  void loginAsGuest() => isLoggedIn.value = false;

  void logout() {
    isLoggedIn.value = false;
    isPro.value = false;
  }
}
