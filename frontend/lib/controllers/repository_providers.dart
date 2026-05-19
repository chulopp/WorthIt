import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/dashboard_repository.dart';
import '../repositories/history_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/scanner_repository.dart';
import '../repositories/shopping_list_repository.dart';
import '../repositories/tracker_repository.dart';
import '../repositories/user_repository.dart';

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>(
  (ref) => ShoppingListRepository(),
);

final scannerRepositoryProvider = Provider<ScannerRepository>(
  (ref) => ScannerRepository(),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(),
);

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(),
);

final trackerRepositoryProvider = Provider<TrackerRepository>(
  (ref) => TrackerRepository(),
);
