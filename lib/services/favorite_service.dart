import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_data.dart';

class FavoriteService {
  FavoriteService._internal() {
    loadFavorites();
  }

  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;

  static const String _keyFavorites = 'favorite_products';

  final ValueNotifier<List<RecentActivity>> favoriteProducts =
      ValueNotifier<List<RecentActivity>>(<RecentActivity>[]);

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFavorites);
    if (raw == null || raw.isEmpty) {
      favoriteProducts.value = <RecentActivity>[];
      return;
    }

    final decoded = json.decode(raw) as List<dynamic>;
    favoriteProducts.value = decoded
        .map((entry) => _fromMap(Map<String, dynamic>.from(entry)))
        .toList();
  }

  Future<void> toggleFavorite(RecentActivity item) async {
    final current = List<RecentActivity>.from(favoriteProducts.value);
    final index = current.indexWhere((entry) => _sameItem(entry, item));

    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.insert(0, item);
    }

    await _save(current);
  }

  Future<void> removeFavorite(RecentActivity item) async {
    final current = List<RecentActivity>.from(favoriteProducts.value)
      ..removeWhere((entry) => _sameItem(entry, item));
    await _save(current);
  }

  bool contains(RecentActivity item) {
    return favoriteProducts.value.any((entry) => _sameItem(entry, item));
  }

  RecentActivity activityFromMap(
    Map<String, dynamic> item, {
    String fallbackColor = 'green',
  }) {
    final dynamic rawPrice = item['price'];
    final dynamic rawStatus = item['status'] ?? item['color'];
    return RecentActivity(
      name: (item['name'] ?? 'Produk').toString(),
      price: _parsePrice(rawPrice),
      color: rawStatus?.toString().isNotEmpty == true
          ? rawStatus.toString()
          : fallbackColor,
      date: DateTime.now().toIso8601String(),
      category: (item['category'] ?? 'Sembako').toString(),
    );
  }

  RecentActivity activityFromProduct({
    required String name,
    required double price,
    String color = 'green',
    String category = 'Sembako',
  }) {
    return RecentActivity(
      name: name,
      price: price,
      color: color,
      date: DateTime.now().toIso8601String(),
      category: category,
    );
  }

  Future<void> _save(List<RecentActivity> items) async {
    // TODO: Hapus local storage dan ganti dengan fetch DB ketika backend siap
    final prefs = await SharedPreferences.getInstance();
    favoriteProducts.value = items;
    await prefs.setString(
      _keyFavorites,
      json.encode(items.map(_toMap).toList()),
    );
  }

  Map<String, dynamic> _toMap(RecentActivity item) {
    return <String, dynamic>{
      'name': item.name,
      'price': item.price,
      'color': item.color,
      'date': item.date,
      'category': item.category,
    };
  }

  RecentActivity _fromMap(Map<String, dynamic> map) {
    return RecentActivity(
      name: (map['name'] ?? 'Produk').toString(),
      price: _parsePrice(map['price']),
      color: (map['color'] ?? 'green').toString(),
      date: (map['date'] ?? DateTime.now().toIso8601String()).toString(),
      category: (map['category'] ?? 'Sembako').toString(),
    );
  }

  bool _sameItem(RecentActivity a, RecentActivity b) {
    return a.name == b.name && a.price == b.price;
  }

  double _parsePrice(dynamic value) {
    if (value is num) return value.toDouble();
    final normalized = value
            ?.toString()
            .replaceAll('Rp', '')
            .replaceAll('rp', '')
            .replaceAll('.', '')
            .replaceAll(',', '')
            .trim() ??
        '0';
    return double.tryParse(normalized) ?? 0;
  }
}
