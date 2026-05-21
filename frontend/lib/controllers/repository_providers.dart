import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/dashboard_repository.dart';
import '../repositories/history_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/scanner_repository.dart';
import '../repositories/shopping_list_repository.dart';
import '../repositories/tracker_repository.dart';
import '../repositories/user_repository.dart';
import '../services/api_client.dart';

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ShoppingListRepository(apiClient: apiClient);
});

final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ScannerRepository(apiClient: apiClient);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProductRepository(apiClient: apiClient);
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HistoryRepository(apiClient: apiClient);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UserRepository(apiClient: apiClient);
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardRepository(apiClient: apiClient);
});

final trackerRepositoryProvider = Provider<TrackerRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TrackerRepository(apiClient: apiClient);
});
