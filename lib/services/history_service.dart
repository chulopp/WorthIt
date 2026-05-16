import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  static const String _keyShoppingHistory = 'shopping_history';
  static const String _keyScanHistory = 'scan_history';

  final ValueNotifier<List<Map<String, dynamic>>> scanHistory = ValueNotifier([]);

  Future<List<Map<String, dynamic>>> getShoppingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyShoppingHistory);
    if (data == null) return [];
    final List<dynamic> decoded = json.decode(data);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addShoppingHistory(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> current = await getShoppingHistory();
    
    current.insert(0, item); // Add to start (newest first)
    
    if (current.length > 10) {
      current.removeLast(); // Remove oldest
    }
    
    await prefs.setString(_keyShoppingHistory, json.encode(current));
  }

  Future<List<Map<String, dynamic>>> getScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyScanHistory);
    if (data == null) return [];
    final List<dynamic> decoded = json.decode(data);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> loadScanHistory() async {
    scanHistory.value = await getScanHistory();
  }

  Future<void> addScanHistory(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> current = await getScanHistory();
    
    current.insert(0, item); // Add to start
    
    if (current.length > 20) {
      current.removeLast();
    }
    
    await prefs.setString(_keyScanHistory, json.encode(current));
    scanHistory.value = current; // Update notifier
  }

  Future<void> addScanResult(Map<String, dynamic> item) async {
    await addScanHistory(item);
  }
}

