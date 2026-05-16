import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyService {
  static final PrivacyService _instance = PrivacyService._internal();
  factory PrivacyService() => _instance;
  PrivacyService._internal();

  final ValueNotifier<bool> isExpenseObscured = ValueNotifier<bool>(false);
  static const String _obscureKey = 'is_expense_obscured';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isExpenseObscured.value = prefs.getBool(_obscureKey) ?? false;
  }

  Future<void> toggleObscured() async {
    isExpenseObscured.value = !isExpenseObscured.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_obscureKey, isExpenseObscured.value);
  }
}
