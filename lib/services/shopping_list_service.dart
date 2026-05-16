import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShoppingListService {
  static final ShoppingListService _instance = ShoppingListService._internal();
  factory ShoppingListService() => _instance;
  ShoppingListService._internal();

  final ValueNotifier<List<Map<String, dynamic>>> shoppingList = ValueNotifier([
    {'name': 'Sabun Cair', 'isDone': false},
    {'name': 'Mie Instan', 'isDone': true}
  ]);

  Future<void> init() async {
    await checkAndResetMonthlyList();
  }

  Future<void> checkAndResetMonthlyList() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final int currentMonth = now.month;
    final int currentYear = now.year;
    
    final int? lastOpenedMonth = prefs.getInt('last_opened_month');
    final int? lastOpenedYear = prefs.getInt('last_opened_year');

    if (lastOpenedMonth == null || lastOpenedMonth != currentMonth || lastOpenedYear != currentYear) {
      // New month detected (or first app open)
      shoppingList.value = [];
      
      // Update stored date
      await prefs.setInt('last_opened_month', currentMonth);
      await prefs.setInt('last_opened_year', currentYear);
    }
  }

  Future<void> _saveCurrentMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt('last_opened_month', now.month);
    await prefs.setInt('last_opened_year', now.year);
  }

  void addItem(String name) {
    final current = List<Map<String, dynamic>>.from(shoppingList.value);
    current.add({'name': name, 'isDone': false});
    shoppingList.value = current;
    _saveCurrentMonth();
  }

  void toggleItem(int index, bool value) {
    final current = List<Map<String, dynamic>>.from(shoppingList.value);
    current[index]['isDone'] = value;
    shoppingList.value = current;
    _saveCurrentMonth();
  }

  void removeItem(int index) {
    final current = List<Map<String, dynamic>>.from(shoppingList.value);
    current.removeAt(index);
    shoppingList.value = current;
    _saveCurrentMonth();
  }

  void clearList() {
    shoppingList.value = [];
    _saveCurrentMonth();
  }
}
