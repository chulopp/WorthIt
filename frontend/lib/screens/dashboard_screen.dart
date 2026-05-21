import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../services/auth_service.dart';
import '../models/dashboard_data.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'favorite_screen.dart';
import 'expense_history_screen.dart';
import '../widgets/total_expenses_card.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/history_controller.dart';
import '../controllers/product_detail_controller.dart';
import '../controllers/shopping_list_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/auth_controller.dart';
import '../config/product_categories.dart';
import '../models/api/api_models.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/decision_badge.dart';
import '../widgets/empty_activity_state.dart';
import '../utils/dialog_helper.dart';
import '../utils/date_helper.dart';
import '../services/privacy_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  OverlayEntry? _currentOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !AuthService().isLoggedIn.value) return;
      ref.read(dashboardControllerProvider.notifier).fetchDashboard();
      ref.read(historyControllerProvider.notifier).fetchPurchases();
      ref.read(historyControllerProvider.notifier).fetchScans();
      ref.read(trackerControllerProvider.notifier).fetchTracker();
    });
  }

  /// Pull-to-refresh: re-fetch all dashboard data from backend.
  Future<void> _refreshDashboard() async {
    await Future.wait([
      ref.read(dashboardControllerProvider.notifier).fetchDashboard(),
      ref.read(historyControllerProvider.notifier).fetchPurchases(),
      ref.read(historyControllerProvider.notifier).fetchScans(),
      ref.read(trackerControllerProvider.notifier).fetchTracker(),
    ]);
  }

  void _showNotification(
    BuildContext context,
    String message,
    Color bgColor,
    IconData icon,
    Color iconColor,
    Color textColor,
  ) {
    if (_currentOverlay != null) {
      _currentOverlay?.remove();
      _currentOverlay = null;
    }

    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _TopNotification(
          message: message,
          backgroundColor: bgColor,
          icon: icon,
          iconColor: iconColor,
          textColor: textColor,
          onDismissed: () {
            if (_currentOverlay == overlayEntry) {
              _currentOverlay?.remove();
              _currentOverlay = null;
            }
          },
        );
      },
    );

    _currentOverlay = overlayEntry;
    overlayState.insert(overlayEntry);
  }

  void _showTopError(BuildContext context, String message) {
    _showNotification(
      context,
      message,
      const Color(0xFFC9E88A),
      Icons.warning_amber_rounded,
      const Color(0xFF304423),
      const Color(0xFF304423),
    );
  }

  void _showTopSuccess(BuildContext context, String message) {
    _showNotification(
      context,
      message,
      const Color(0xFFC9E88A),
      Icons.check_circle,
      const Color(0xFF304423),
      const Color(0xFF304423),
    );
  }

  void _showTopDeleteSuccess(BuildContext context, String message) {
    _showNotification(
      context,
      message,
      const Color(0xFFC9E88A),
      Icons.delete_outline,
      const Color(0xFF304423),
      const Color(0xFF304423),
    );
  }

  String _formatRp(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  String _localizedMarketInsight(DashboardData data) {
    final key = data.marketInsightKey;
    if (key != null && key.isNotEmpty) {
      final args = Map<String, String>.from(data.marketInsightParams);
      final category = args['category'];
      if (category != null) {
        args['category'] = _localizedDashboardCategory(category);
      }
      return key.tr(namedArgs: args);
    }
    return data.marketInsight.isNotEmpty
        ? data.marketInsight
        : 'dashboard.market_insight_messages.stable'.tr();
  }

  String _localizedDashboardCategory(String rawCategory) {
    return displayProductCategory(rawCategory);
  }

  DashboardData _dashboardDataFromApi(DashboardModel? model) {
    if (model == null) {
      return DashboardData(
        monthlyBudget: 0,
        budgetRemaining: 0,
        moneySaved: 0,
        recentItems: const <RecentActivity>[],
        dailyExpenses: const <double>[],
        expensePoints: const <ExpensePoint>[],
        marketInsight: '',
      );
    }

    return DashboardData(
      monthlyBudget: model.monthlyBudget,
      budgetRemaining: model.budgetRemaining,
      moneySaved: model.moneySaved,
      dailyExpenses: model.dailyExpenses,
      expensePoints: model.expensePoints
          .map(
            (item) => ExpensePoint(
              purchasedAt: item.purchasedAt,
              amount: item.amount,
            ),
          )
          .toList(growable: false),
      marketInsight: model.marketInsight,
      marketInsightKey: model.marketInsightKey,
      marketInsightParams: model.marketInsightParams,
      recentItems: model.recentActivities
          .map(
            (item) => RecentActivity(
              productId: item.productId,
              name: item.productName,
              price: item.price,
              color: item.color,
              date: item.timestamp,
              category: item.category ?? 'Lainnya',
              imageUrl: item.imageUrl,
              unitLabel: item.unitLabel,
            ),
          )
          .toList(growable: false),
    );
  }

  IconData _expenseIconForCategory(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('snack') || normalized.contains('cemilan')) {
      return Icons.cookie;
    }
    if (normalized.contains('mandi') || normalized.contains('toiletries')) {
      return Icons.soap;
    }
    if (normalized.contains('minum') || normalized.contains('susu')) {
      return Icons.local_drink;
    }
    if (normalized.contains('mie') || normalized.contains('food')) {
      return Icons.fastfood;
    }
    return Icons.shopping_cart;
  }

  List<ExpenseCategory> _expenseCategoriesFromTracker(TrackerModel? tracker) {
    return (tracker?.byCategory ?? const <CategorySpendModel>[])
        .map(
          (item) => ExpenseCategory(
            name: item.category,
            amount: item.amount,
            icon: _expenseIconForCategory(item.category),
          ),
        )
        .toList(growable: false);
  }

  double _totalCurrentMonthPurchases(List<PurchaseHistoryModel> groups) {
    return groups
        .expand((group) => group.items)
        .fold<double>(
          0,
          (sum, item) => DateHelper.isCurrentMonth(item.purchasedAt)
              ? sum + item.totalPrice
              : sum,
        );
  }

  IconData _categoryIcon(String color) => switch (color) {
    'green' => Icons.check_circle_outline,
    'red' => Icons.warning_amber_rounded,
    _ => Icons.info_outline,
  };

  Color _dotColor(String c) => switch (c) {
    'green' => const Color(0xFFC9E88A),
    'red' => const Color(0xFFEF4444),
    _ => const Color(0xFFFBBF24),
  };

  String _buildGreeting({bool compact = false}) {
    final hour = DateTime.now().hour;
    final String greetingText;
    if (hour >= 4 && hour < 12) {
      greetingText = 'greeting_morning'.tr();
    } else if (hour >= 12 && hour < 15) {
      greetingText = 'greeting_afternoon'.tr();
    } else if (hour >= 15 && hour < 19) {
      greetingText = 'greeting_evening'.tr();
    } else {
      greetingText = 'greeting_night'.tr();
    }
    final authService = AuthService();
    final name = authService.isLoggedIn.value
        ? (authService.displayName ??
              authService.userEmail.value ??
              'user'.tr())
        : 'guest'.tr();
    final displayGreeting = compact
        ? greetingText.replaceFirst(RegExp(r'^(Selamat|Good)\s+'), '')
        : greetingText;
    return '$displayGreeting, $name';
  }

  // ── Shopping List Bottom Sheet ──
  void _showShoppingListSheet() {
    // ── Soft-Gate: Guest → standardized sheet ──
    if (!AuthService().isLoggedIn.value) {
      showGuestLoginBottomSheet(context, 'dashboard.shopping_list'.tr());
      return;
    }

    TextEditingController? currentFieldController;
    ref.read(shoppingListControllerProvider.notifier).fetchCurrentList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, modalRef, _) {
            final shoppingState = modalRef.watch(
              shoppingListControllerProvider,
            );
            final productState = modalRef.watch(
              productDetailControllerProvider,
            );
            final shoppingItems =
                shoppingState.data?.items ?? const <ShoppingItemModel>[];
            modalRef.listen(shoppingListControllerProvider, (previous, next) {
              final message = next.errorMessage;
              if (message == null || previous?.errorMessage == message) return;
              _showTopError(context, message);
            });

            Future<ProductSummaryModel?> resolveProduct(String value) async {
              final keyword = value.trim();
              if (keyword.isEmpty) return null;

              ProductSummaryModel? exactMatch(
                List<ProductSummaryModel> results,
              ) {
                for (final item in results) {
                  if (item.name.toLowerCase() == keyword.toLowerCase()) {
                    return item;
                  }
                }
                return null;
              }

              var results = modalRef
                  .read(productDetailControllerProvider)
                  .searchResults;
              var match = exactMatch(results);

              if (match != null) return match;

              await modalRef
                  .read(productDetailControllerProvider.notifier)
                  .searchProducts(keyword);
              results = modalRef
                  .read(productDetailControllerProvider)
                  .searchResults;
              if (results.isEmpty) return null;

              match = exactMatch(results);
              return match ?? results.first;
            }

            Future<void> addProduct(ProductSummaryModel product) async {
              await modalRef
                  .read(shoppingListControllerProvider.notifier)
                  .addItem(product.id, 1, product: product);
              final nextShoppingState = modalRef.read(
                shoppingListControllerProvider,
              );
              if (!context.mounted) return;
              if (nextShoppingState.errorMessage != null) return;
              _showTopSuccess(context, 'item_added_success'.tr());
              Future.microtask(() {
                currentFieldController?.clear();
              });
            }

            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.55,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'dashboard.shopping_list'.tr(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      contentPadding: const EdgeInsets.fromLTRB(
                                        28,
                                        24,
                                        28,
                                        8,
                                      ),
                                      actionsPadding: const EdgeInsets.fromLTRB(
                                        28,
                                        0,
                                        28,
                                        24,
                                      ),

                                      // ── Icon ──────────────────────────────────
                                      icon: Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 32,
                                          ),
                                        ),
                                      ),

                                      // ── Title ─────────────────────────────────
                                      title: Text(
                                        'delete_all'.tr(),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF1E293B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),

                                      // ── Content ───────────────────────────────
                                      content: Text(
                                        'delete_all_confirmation'.tr(),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          color: Colors.grey.shade600,
                                          fontSize: 15,
                                          height: 1.5,
                                        ),
                                      ),

                                      // ── Actions ───────────────────────────────
                                      actions: [
                                        Row(
                                          children: [
                                            // Cancel
                                            Expanded(
                                              child: SizedBox(
                                                height: 48,
                                                child: ElevatedButton(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF304423),
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Batal',
                                                    style: GoogleFonts.outfit(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            // Confirm delete
                                            Expanded(
                                              child: SizedBox(
                                                height: 48,
                                                child: TextButton(
                                                  onPressed: () async {
                                                    await modalRef
                                                        .read(
                                                          shoppingListControllerProvider
                                                              .notifier,
                                                        )
                                                        .clearAll();
                                                    if (!context.mounted)
                                                      return;
                                                    final updatedState =
                                                        modalRef.read(
                                                          shoppingListControllerProvider,
                                                        );
                                                    Navigator.of(
                                                      dialogContext,
                                                    ).pop();
                                                    if (updatedState
                                                            .errorMessage !=
                                                        null) {
                                                      _showTopError(
                                                        context,
                                                        updatedState
                                                            .errorMessage!,
                                                      );
                                                      return;
                                                    }
                                                    _showTopDeleteSuccess(
                                                      context,
                                                      'shopping_list_cleared_success'
                                                          .tr(),
                                                    );
                                                  },
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Ya, Hapus',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              icon: Icon(
                                Icons.delete_sweep,
                                color: Colors.red.shade300,
                                size: 20,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${'shopping_list_total_price'.tr()}: ${_formatRp(shoppingState.data?.totalEstimatedPrice ?? 0)}',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF304423),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Autocomplete<ProductSummaryModel>(
                          displayStringForOption: (option) => option.name,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<
                                ProductSummaryModel
                              >.empty();
                            }
                            return productState.searchResults.where((option) {
                              return option.name.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              );
                            });
                          },
                          onSelected: (ProductSummaryModel selection) {
                            addProduct(selection);
                          },
                          fieldViewBuilder:
                              (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                currentFieldController = textEditingController;
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  onChanged: (value) {
                                    modalRef
                                        .read(
                                          productDetailControllerProvider
                                              .notifier,
                                        )
                                        .searchProducts(value);
                                  },
                                  onSubmitted: (value) async {
                                    final product = await resolveProduct(value);
                                    if (!context.mounted) return;
                                    if (product == null) {
                                      _showTopError(
                                        context,
                                        'select_from_catalog_error'.tr(),
                                      );
                                      return;
                                    }
                                    addProduct(product);
                                    setModalState(textEditingController.clear);
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'search_in_list'.tr(),
                                    hintStyle: GoogleFonts.bricolageGrotesque(
                                      color: Colors.grey.shade400,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: Color(0xFF304423),
                                      size: 20,
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width: MediaQuery.of(context).size.width - 48,
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final option = options.elementAt(
                                            index,
                                          );
                                          return InkWell(
                                            onTap: () {
                                              onSelected(option);
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              child: Text(
                                                option.name,
                                                style:
                                                    GoogleFonts.bricolageGrotesque(
                                                      color: const Color(
                                                        0xFF1E293B,
                                                      ),
                                                      fontSize: 13,
                                                    ),
                                              ),
                                            ),
                                          );
                                        },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: shoppingState.isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF304423),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: shoppingItems.length,
                                  itemBuilder: (context, index) {
                                    final item = shoppingItems[index];
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        10,
                                        6,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Checkbox(
                                              value: item.isBought,
                                              activeColor: const Color(
                                                0xFF304423,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              onChanged: (_) {
                                                modalRef
                                                    .read(
                                                      shoppingListControllerProvider
                                                          .notifier,
                                                    )
                                                    .toggleItem(item.id);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${item.productName} x${item.quantity}',
                                                  softWrap: true,
                                                  style:
                                                      GoogleFonts.bricolageGrotesque(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        height: 1.25,
                                                        color: const Color(
                                                          0xFF1E293B,
                                                        ),
                                                        decoration:
                                                            item.isBought
                                                            ? TextDecoration
                                                                  .lineThrough
                                                            : TextDecoration
                                                                  .none,
                                                      ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  _formatRp(item.currentPrice),
                                                  softWrap: true,
                                                  style:
                                                      GoogleFonts.bricolageGrotesque(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                          0xFF64748B,
                                                        ),
                                                        decoration:
                                                            item.isBought
                                                            ? TextDecoration
                                                                  .lineThrough
                                                            : TextDecoration
                                                                  .none,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red.shade300,
                                              size: 20,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            onPressed: () async {
                                              await modalRef
                                                  .read(
                                                    shoppingListControllerProvider
                                                        .notifier,
                                                  )
                                                  .removeItem(item.id);
                                              if (!context.mounted) return;
                                              final updatedState = modalRef.read(
                                                shoppingListControllerProvider,
                                              );
                                              if (updatedState.errorMessage !=
                                                  null) {
                                                _showTopError(
                                                  context,
                                                  updatedState.errorMessage!,
                                                );
                                                return;
                                              }
                                              _showTopDeleteSuccess(
                                                context,
                                                'item_deleted_success'.tr(),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Expenses Bottom Sheet ──
  void _showExpensesSheet(List<ExpenseCategory> expenses) {
    final totalPengeluaran = expenses.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'dashboard.expenses_this_month'.tr(),
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatRp(totalPengeluaran),
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF304423),
                ),
              ),
              const SizedBox(height: 24),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final item = expenses[index];
                  final ratio = totalPengeluaran > 0
                      ? (item.amount / totalPengeluaran)
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExpenseRow(
                      label: displayProductCategory(item.name),
                      amount: _formatRp(item.amount),
                      icon: item.icon,
                      ratio: ratio,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StatisticsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.pie_chart_outline,
                    color: Color(0xFF304423),
                  ),
                  label: Text(
                    'view_full_analysis'.tr(),
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF304423),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF304423)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppAuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated &&
          previous?.status != AuthStatus.authenticated) {
        ref.read(dashboardControllerProvider.notifier).fetchDashboard();
        ref.read(historyControllerProvider.notifier).fetchPurchases();
        ref.read(historyControllerProvider.notifier).fetchScans();
        ref.read(trackerControllerProvider.notifier).fetchTracker();
      }
    });

    final dashboardState = ref.watch(dashboardControllerProvider);
    final historyState = ref.watch(historyControllerProvider);
    final trackerState = ref.watch(trackerControllerProvider);
    final data = _dashboardDataFromApi(dashboardState.data);
    final dashboardTotalPengeluaran = _totalCurrentMonthPurchases(
      historyState.data?.purchases ?? const <PurchaseHistoryModel>[],
    );
    final totalPengeluaranTersimpan =
        historyState.data?.totalPengeluaranTersimpan ?? data.moneySaved;

    const Color accentGreen = Color(0xFFC9E88A);
    const Color textPrimary = Color(0xFF1E293B);
    const Color textSecondary = Color(0xFF64748B);
    const Color sheetWhite = Color(0xFFFFFFFF);

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF304423),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RefreshIndicator(
            onRefresh: _refreshDashboard,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. TOP HEADER ──
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 48,
                      left: 24,
                      right: 16,
                      bottom: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Left: Logo + Dynamic Greeting ──
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/svg/ICON.svg',
                                height: 24,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFFC9E88A),
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isNarrow =
                                        MediaQuery.sizeOf(context).width <
                                            360 ||
                                        constraints.maxWidth < 128;

                                    if (dashboardState.isLoading ||
                                        historyState.isLoading) {
                                      return Shimmer.fromColors(
                                        baseColor: Colors.grey.shade400
                                            .withValues(alpha: 0.2),
                                        highlightColor: Colors.grey.shade300
                                            .withValues(alpha: 0.1),
                                        child: Container(
                                          height: 18,
                                          width: 150,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return Text(
                                      _buildGreeting(compact: isNarrow),
                                      maxLines: 2,
                                      softWrap: true,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        // ── Right: Action Icons ──
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SearchScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.search),
                              color: Colors.white,
                              iconSize: 24,
                              splashRadius: 18,
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (!AuthService().isLoggedIn.value) {
                                  showGuestLoginBottomSheet(
                                    context,
                                    'feature_notifications'.tr(),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const NotificationScreen(),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.notifications_none),
                              color: Colors.white,
                              iconSize: 24,
                              splashRadius: 18,
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                            IconButton(
                              onPressed: () => guardAction(
                                context,
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                ),
                                featureName: 'feature_profile'.tr(),
                              ),
                              icon: const Icon(Icons.person_outline),
                              color: Colors.white,
                              iconSize: 24,
                              splashRadius: 18,
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── 2. BUDGET / GUEST BANNER ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: !AuthService().isLoggedIn.value
                        ? Padding(
                            key: const ValueKey('guest_banner'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(
                                      0xFFC9E88A,
                                    ).withValues(alpha: 0.18),
                                    const Color(
                                      0xFF304423,
                                    ).withValues(alpha: 0.12),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFFC9E88A,
                                  ).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFC9E88A,
                                      ).withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                      color: Color(0xFFC9E88A),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'register_now'.tr(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'guest_login_desc'.tr(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await AuthService()
                                              .nativeGoogleSignIn();
                                          if (mounted) setState(() {});
                                        } catch (error) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(error.toString()),
                                            ),
                                          );
                                        }
                                      },
                                      icon: Image.asset(
                                        'assets/images/google_logo.png',
                                        height: 24,
                                      ),
                                      label: Text(
                                        'login_with_google'.tr(),
                                        style: GoogleFonts.bricolageGrotesque(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF304423,
                                        ),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ValueListenableBuilder<bool>(
                            key: const ValueKey('budget_component'),
                            valueListenable: PrivacyService().isExpenseObscured,
                            builder: (context, isObscured, child) {
                              final bool isBudgetVisible = !isObscured;

                              final List<double> dailyExpenses =
                                  data.dailyExpenses;
                              final nonZeroDailyCount = dailyExpenses
                                  .where((value) => value > 0)
                                  .length;
                              final bool usePurchasePoints =
                                  nonZeroDailyCount < 2 &&
                                  data.expensePoints.isNotEmpty;
                              final List<double> expenses = usePurchasePoints
                                  ? data.expensePoints
                                        .map((point) => point.amount)
                                        .toList()
                                  : dailyExpenses;
                              final double highestSpending = expenses.isEmpty
                                  ? 0
                                  : expenses.reduce((a, b) => a > b ? a : b);
                              final double dynamicMaxY = highestSpending == 0
                                  ? 100
                                  : highestSpending * 1.2;

                              final List<FlSpot> chartSpots = expenses.isEmpty
                                  ? const [FlSpot(1, 0), FlSpot(2, 0)]
                                  : expenses.length == 1
                                  ? [FlSpot(1, 0), FlSpot(2, expenses.first)]
                                  : expenses.asMap().entries.map((e) {
                                      return FlSpot(
                                        (e.key + 1).toDouble(),
                                        e.value,
                                      );
                                    }).toList();
                              final double chartMaxX = expenses.length <= 1
                                  ? 2
                                  : expenses.length.toDouble();

                              return Column(
                                children: [
                                  if (dashboardState.isLoading ||
                                      historyState.isLoading)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 8,
                                      ),
                                      child: Shimmer.fromColors(
                                        baseColor: const Color(
                                          0xFFC9E88A,
                                        ).withValues(alpha: 0.1),
                                        highlightColor: const Color(
                                          0xFFC9E88A,
                                        ).withValues(alpha: 0.05),
                                        child: Container(
                                          width: double.infinity,
                                          height: 180,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    TotalExpensesCard(
                                      amount: dashboardTotalPengeluaran,
                                      savedAmount: totalPengeluaranTersimpan,
                                    ),

                                  // ── 3. LINE CHART (Pure Line) ──
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, animation) =>
                                        SizeTransition(
                                          sizeFactor: animation,
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        ),
                                    child: !isBudgetVisible
                                        ? const SizedBox.shrink(
                                            key: ValueKey('chart_hidden'),
                                          )
                                        : dashboardState.isLoading ||
                                              historyState.isLoading
                                        ? Padding(
                                            key: const ValueKey(
                                              'chart_loading',
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 10,
                                            ),
                                            child: Shimmer.fromColors(
                                              baseColor: Colors.grey.shade400
                                                  .withValues(alpha: 0.2),
                                              highlightColor: Colors
                                                  .grey
                                                  .shade300
                                                  .withValues(alpha: 0.1),
                                              child: Container(
                                                height: 70,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Padding(
                                            key: const ValueKey(
                                              'chart_visible',
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            child: SizedBox(
                                              height: 90,
                                              child: LineChart(
                                                LineChartData(
                                                  gridData: const FlGridData(
                                                    show: false,
                                                  ),
                                                  titlesData:
                                                      const FlTitlesData(
                                                        show: false,
                                                      ),
                                                  borderData: FlBorderData(
                                                    show: false,
                                                  ),
                                                  lineTouchData:
                                                      const LineTouchData(
                                                        enabled: false,
                                                      ),
                                                  lineBarsData: [
                                                    LineChartBarData(
                                                      spots: chartSpots,
                                                      isCurved: true,
                                                      curveSmoothness: 0.35,
                                                      color: const Color(
                                                        0xFFC9E88A,
                                                      ),
                                                      barWidth: 2.5,
                                                      isStrokeCapRound: true,
                                                      dotData: const FlDotData(
                                                        show: false,
                                                      ),
                                                      belowBarData: BarAreaData(
                                                        show: false,
                                                      ),
                                                    ),
                                                  ],
                                                  minX: 1,
                                                  maxX: chartMaxX,
                                                  minY: 0,
                                                  maxY: dynamicMaxY,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 5),

                  // ── 4. CAPSULE BUTTONS ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showShoppingListSheet,
                            icon: const Icon(Icons.checklist, size: 18),
                            label: Text('dashboard.shopping_list'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.9,
                              ),
                              foregroundColor: textPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: const StadiumBorder(),
                              textStyle: GoogleFonts.bricolageGrotesque(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              guardAction(context, () {
                                _showExpensesSheet(
                                  _expenseCategoriesFromTracker(
                                    trackerState.data,
                                  ),
                                );
                              }, featureName: 'feature_expenses'.tr());
                            },
                            icon: const Icon(Icons.receipt_long, size: 18),
                            label: Text('dashboard.expenses'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.9,
                              ),
                              foregroundColor: textPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: const StadiumBorder(),
                              textStyle: GoogleFonts.bricolageGrotesque(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── 5. QUICK ACTIONS (5 Circular Icons) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: _QuickAction(
                            icon: Icons.inventory_2,
                            label: 'dashboard.catalog'.tr(),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CatalogScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: _QuickAction(
                            icon: Icons.pie_chart,
                            label: 'dashboard.statistics'.tr(),
                            onTap: () => guardAction(
                              context,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StatisticsScreen(),
                                ),
                              ),
                              featureName: 'feature_statistics'.tr(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: _QuickAction(
                            icon: Icons.qr_code_scanner,
                            label: 'dashboard.scan'.tr(),
                            onTap: () => guardAction(
                              context,
                              () => Navigator.pushNamed(context, '/scanner'),
                              featureName: 'feature_scan'.tr(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: _QuickAction(
                            icon: Icons.history,
                            label: 'dashboard.history'.tr(),
                            onTap: () => guardAction(
                              context,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HistoryScreen(),
                                ),
                              ),
                              featureName: 'feature_history'.tr(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: _QuickAction(
                            icon: Icons.star,
                            label: 'dashboard.favorites'.tr(),
                            onTap: () => guardAction(
                              context,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FavoriteScreen(),
                                ),
                              ),
                              featureName: 'feature_favorites'.tr(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── 6. INSIGHT BANNER ──
                  if (!AuthService().isLoggedIn.value)
                    const SizedBox.shrink()
                  else if (dashboardState.isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey.shade400.withValues(alpha: 0.2),
                        highlightColor: Colors.grey.shade300.withValues(
                          alpha: 0.1,
                        ),
                        child: Container(
                          width: double.infinity,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              const Color(0xFFC9E88A).withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0.06),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.20),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFC9E88A,
                              ).withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Golden gradient icon circle
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFDE68A),
                                    Color(0xFFF59E0B),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.40),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.bolt,
                                  color: Color(0xFF7C3400),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'market_insight'.tr(),
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.30,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dashboardState.errorMessage != null
                                        ? dashboardState.errorMessage!
                                        : _localizedMarketInsight(data),
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: dashboardState.errorMessage != null
                                          ? Colors.red.shade200
                                          : Colors.white.withValues(
                                              alpha: 0.90,
                                            ),
                                      height: 1.4,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.20,
                                          ),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── 7. OVERLAPPING WHITE SHEET ──
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    decoration: const BoxDecoration(
                      color: sheetWhite,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
                          child: Text(
                            'shopping_activity'.tr(),
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            if (dashboardState.isLoading ||
                                historyState.isLoading) {
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ).copyWith(bottom: 120),
                                itemCount: 4,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (_, __) => Shimmer.fromColors(
                                  baseColor: Colors.grey.shade300.withValues(
                                    alpha: 0.2,
                                  ),
                                  highlightColor: Colors.grey.shade100
                                      .withValues(alpha: 0.1),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              height: 14,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              height: 12,
                                              width: 100,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        height: 16,
                                        width: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final isGuest = !AuthService().isLoggedIn.value;
                            final aktivitasList = data.recentItems
                                .take(5)
                                .toList();

                            if (isGuest || aktivitasList.isEmpty) {
                              return const EmptyActivityState();
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 120),
                              itemCount: aktivitasList.length,
                              itemBuilder: (context, index) {
                                final item = aktivitasList[index];
                                return _ActivityTile(item: item);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ExpenseHistoryScreen(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: sheetWhite,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  Icons.home_filled,
                  color: _currentIndex == 0
                      ? const Color(0xFF304423)
                      : textSecondary.withValues(alpha: 0.5),
                ),
                iconSize: 28,
                onPressed: () => setState(() => _currentIndex = 0),
              ),
              GestureDetector(
                onTap: () => guardAction(
                  context,
                  () => Navigator.pushNamed(context, '/scanner'),
                  featureName: 'feature_scan'.tr(),
                ),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF304423),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF304423).withValues(alpha: 0.40),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.receipt_long,
                  color: _currentIndex == 1
                      ? const Color(0xFF304423)
                      : textSecondary.withValues(alpha: 0.5),
                ),
                iconSize: 28,
                tooltip: 'nav_expenses'.tr(),
                onPressed: () => guardAction(
                  context,
                  () => setState(() => _currentIndex = 1),
                  featureName: 'feature_expenses'.tr(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 25),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.2,
                  ),
                  softWrap: false,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final RecentActivity item;

  const _ActivityTile({required this.item});

  String _formatRp(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  IconData _getItemIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('mie')) return Icons.fastfood;
    if (n.contains('susu')) return Icons.emoji_food_beverage;
    if (n.contains('keripik') || n.contains('snack') || n.contains('chitato'))
      return Icons.cookie;
    if (n.contains('minyak')) return Icons.water_drop;
    if (n.contains('kopi')) return Icons.coffee;
    if (n.contains('beras')) return Icons.rice_bowl;
    return Icons.shopping_bag; // fallback
  }

  String _formattedDate(BuildContext context) {
    final parsedDate = DateTime.tryParse(item.date)?.toLocal();
    if (parsedDate == null) return item.date;
    return DateFormat(
      'E, d MMM HH:mm',
      context.locale.toString(),
    ).format(parsedDate);
  }

  @override
  Widget build(BuildContext context) {
    const Color textPrimary = Color(0xFF1E293B);
    final decisionCode = decisionCodeFromColor(item.color);

    return InkWell(
      onTap: () {
        showProductDetailBottomSheet(
          context,
          productName: item.name,
          productWeight: item.unitLabel ?? '',
          productCategory: item.category,
          currentPrice: item.unitPrice ?? item.price,
          historicalAvgPrice: item.unitPrice ?? item.price,
          imageUrl: item.imageUrl,
          productId: item.productId,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            _getItemIcon(item.name),
                            color: Colors.grey.shade400,
                            size: 24,
                          ),
                        );
                      },
                      placeholder: (context, url) {
                        return Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: const Color(0xFF304423),
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        _getItemIcon(item.name),
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,

                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formattedDate(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatRp(item.price),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingCheckItem extends StatefulWidget {
  final String title;
  final bool checked;
  const _ShoppingCheckItem({required this.title, required this.checked});

  @override
  State<_ShoppingCheckItem> createState() => _ShoppingCheckItemState();
}

class _ShoppingCheckItemState extends State<_ShoppingCheckItem> {
  late bool _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.checked;
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: _checked,
      onChanged: (v) => setState(() => _checked = v ?? false),
      title: Text(
        widget.title,
        style: GoogleFonts.bricolageGrotesque(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1E293B),
          decoration: _checked ? TextDecoration.lineThrough : null,
        ),
        softWrap: true,
      ),
      activeColor: const Color(0xFF304423),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final double ratio;

  const _ExpenseRow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF304423).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF304423), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: RichText(
                  textAlign: TextAlign.end,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: amount,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      TextSpan(
                        text: ' (${(ratio * 100).toStringAsFixed(0)}%)',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF304423),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUB-SCREENS (Navigator Targets)
// ═════════════════════════════════════════════════════════════════════════════

class ItemKatalog {
  final String id;
  final String name;
  final String brand;
  final double price;
  final String rawCategory;
  final String category;
  final IconData icon;
  final String? imageUrl;

  const ItemKatalog({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.rawCategory,
    required this.category,
    required this.icon,
    this.imageUrl,
  });
}

class _ProductListSkeleton extends StatelessWidget {
  const _ProductListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0).withValues(alpha: 0.2),
      highlightColor: const Color(0xFFF8FAFC).withValues(alpha: 0.1),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (_, __) => Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 16,
              width: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String searchQuery = '';
  String selectedCategory = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  final List<String> categories = const [
    allProductCategoryLabel,
    ...officialProductCategories,
  ];

  String _formatRp(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(productDetailControllerProvider.notifier).listProducts();
      }
    });
  }

  IconData _catalogIcon(String category, String name) {
    final value = '$category $name'.toLowerCase();
    if (value.contains('beras')) return Icons.rice_bowl;
    if (value.contains('minyak')) return Icons.water_drop;
    if (value.contains('mie')) return Icons.fastfood;
    if (value.contains('susu') || value.contains('milk')) {
      return Icons.emoji_food_beverage;
    }
    if (value.contains('snack') || value.contains('cemilan')) {
      return Icons.cookie;
    }
    if (value.contains('mandi') || value.contains('soap')) return Icons.soap;
    return Icons.shopping_bag;
  }

  String _displayCategory(String? category) {
    return displayProductCategory(category);
  }

  ItemKatalog _itemFromProduct(ProductSummaryModel product) {
    final rawCategory = product.category ?? 'Lainnya';
    final category = _displayCategory(rawCategory);
    return ItemKatalog(
      id: product.id,
      name: product.name,
      brand: product.brand ?? product.category ?? '-',
      price: product.currentPrice ?? 0,
      rawCategory: rawCategory,
      category: category,
      icon: _catalogIcon(category, product.name),
      imageUrl: product.imageUrl,
    );
  }

  List<ItemKatalog> _filteredKatalogFrom(
    List<ProductSummaryModel> productSummaries,
  ) {
    final products = productSummaries
        .map(_itemFromProduct)
        .toList(growable: false);
    return products.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.brand.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == allProductCategoryLabel ||
          item.rawCategory == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productDetailControllerProvider);
    final filteredKatalog = _filteredKatalogFrom(productState.searchResults);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'dashboard.catalog'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      // OPEN ACCESS: Catalog is visible to all users (Guest & Logged-in)
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
                if (value.trim().isEmpty) {
                  ref
                      .read(productDetailControllerProvider.notifier)
                      .listProducts(
                        category: selectedCategory == allProductCategoryLabel
                            ? null
                            : selectedCategory,
                      );
                } else {
                  ref
                      .read(productDetailControllerProvider.notifier)
                      .searchProducts(value.trim());
                }
              },
              decoration: InputDecoration(
                hintText: 'catalog_search_hint'.tr(),
                hintStyle: GoogleFonts.bricolageGrotesque(
                  color: Colors.grey.shade400,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchQuery = '';
                          });
                          ref
                              .read(productDetailControllerProvider.notifier)
                              .listProducts(
                                category:
                                    selectedCategory == allProductCategoryLabel
                                    ? null
                                    : selectedCategory,
                              );
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: categories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = cat;
                      });
                      ref
                          .read(productDetailControllerProvider.notifier)
                          .listProducts(
                            category: cat == allProductCategoryLabel
                                ? null
                                : cat,
                          );
                    },
                    child: _FilterChip(
                      label: displayProductCategory(cat),
                      isSelected: selectedCategory == cat,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF304423),
              onRefresh: () async {
                await ref
                    .read(productDetailControllerProvider.notifier)
                    .listProducts(
                      category: selectedCategory == allProductCategoryLabel
                          ? null
                          : selectedCategory,
                    );
              },
              child: productState.isLoading
                  ? const _ProductListSkeleton()
                  : filteredKatalog.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'item_not_found'.tr(),
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      itemCount: filteredKatalog.length,
                      itemBuilder: (context, index) {
                        final item = filteredKatalog[index];
                        return InkWell(
                          onTap: () {
                            showProductDetailSheet(
                              context,
                              productName: item.name,
                              currentPrice: item.price,
                              productCategory: item.category,
                              imageUrl: item.imageUrl,
                              productId: item.id,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16.0,
                              horizontal: 24.0,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child:
                                      item.imageUrl != null &&
                                          item.imageUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: item.imageUrl!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Image.asset(
                                            'assets/images/${(item.name.hashCode.abs() % 3) + 1}.jpg',
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          ),
                                          errorWidget: (_, __, ___) => Image.asset(
                                            'assets/images/${(item.name.hashCode.abs() % 3) + 1}.jpg',
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/images/${(item.name.hashCode.abs() % 3) + 1}.jpg',
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.bricolageGrotesque(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.category,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.bricolageGrotesque(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatRp(item.price),
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String searchQuery = '';
  String selectedCategory = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  final List<String> categories = const [
    allProductCategoryLabel,
    ...officialProductCategories,
  ];

  String _formatRp(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(productDetailControllerProvider.notifier).listProducts();
      }
    });
  }

  IconData _catalogIcon(String category, String name) {
    final value = '$category $name'.toLowerCase();
    if (value.contains('beras')) return Icons.rice_bowl;
    if (value.contains('minyak')) return Icons.water_drop;
    if (value.contains('mie')) return Icons.fastfood;
    if (value.contains('susu') || value.contains('milk')) {
      return Icons.emoji_food_beverage;
    }
    if (value.contains('snack') || value.contains('cemilan')) {
      return Icons.cookie;
    }
    if (value.contains('mandi') || value.contains('soap')) return Icons.soap;
    return Icons.shopping_bag;
  }

  String _displayCategory(String? category) {
    return displayProductCategory(category);
  }

  ItemKatalog _itemFromProduct(ProductSummaryModel product) {
    final rawCategory = product.category ?? 'Lainnya';
    final category = _displayCategory(rawCategory);
    return ItemKatalog(
      id: product.id,
      name: product.name,
      brand: product.brand ?? product.category ?? '-',
      price: product.currentPrice ?? 0,
      rawCategory: rawCategory,
      category: category,
      icon: _catalogIcon(category, product.name),
      imageUrl: product.imageUrl,
    );
  }

  List<ItemKatalog> _filteredKatalogFrom(
    List<ProductSummaryModel> productSummaries,
  ) {
    final products = productSummaries
        .map(_itemFromProduct)
        .toList(growable: false);
    return products.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.brand.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == allProductCategoryLabel ||
          item.rawCategory == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productDetailControllerProvider);
    final filteredKatalog = _filteredKatalogFrom(productState.searchResults);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: false,
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                        if (value.trim().isEmpty) {
                          ref
                              .read(productDetailControllerProvider.notifier)
                              .listProducts(
                                category:
                                    selectedCategory == allProductCategoryLabel
                                    ? null
                                    : selectedCategory,
                              );
                        } else {
                          ref
                              .read(productDetailControllerProvider.notifier)
                              .searchProducts(value.trim());
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'search_hint'.tr(),
                        hintStyle: GoogleFonts.bricolageGrotesque(
                          color: Colors.grey.shade400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    searchQuery = '';
                                  });
                                  ref
                                      .read(
                                        productDetailControllerProvider
                                            .notifier,
                                      )
                                      .listProducts(
                                        category:
                                            selectedCategory ==
                                                allProductCategoryLabel
                                            ? null
                                            : selectedCategory,
                                      );
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'cancel'.tr(),
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = cat;
                        });
                        ref
                            .read(productDetailControllerProvider.notifier)
                            .listProducts(
                              category: cat == allProductCategoryLabel
                                  ? null
                                  : cat,
                            );
                      },
                      child: _FilterChip(
                        label: cat == allProductCategoryLabel
                            ? 'all'.tr()
                            : displayProductCategory(cat),
                        isSelected: selectedCategory == cat,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF304423),
                onRefresh: () async {
                  await ref
                      .read(productDetailControllerProvider.notifier)
                      .listProducts(
                        category: selectedCategory == allProductCategoryLabel
                            ? null
                            : selectedCategory,
                      );
                },
                child: productState.isLoading
                    ? const _ProductListSkeleton()
                    : filteredKatalog.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'item_not_found'.tr(),
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: filteredKatalog.length,
                        itemBuilder: (context, index) {
                          final item = filteredKatalog[index];
                          return InkWell(
                            onTap: () {
                              showProductDetailSheet(
                                context,
                                productName: item.name,
                                currentPrice: item.price,
                                productCategory: item.category,
                                imageUrl: item.imageUrl,
                                productId: item.id,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                                horizontal: 24.0,
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child:
                                        item.imageUrl != null &&
                                            item.imageUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: item.imageUrl!,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                Image.asset(
                                                  'assets/images/${(item.name.hashCode.abs() % 3) + 1}.jpg',
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                ),
                                            errorWidget: (_, __, ___) =>
                                                Image.asset(
                                                  'assets/images/${(item.name.hashCode.abs() % 3) + 1}.jpg',
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                ),
                                          )
                                        : Image.asset(
                                            'assets/images/${(item.name.hashCode.abs() % 3) + 1}.jpg',
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.bricolageGrotesque(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.category,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.bricolageGrotesque(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatRp(item.price),
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  const _FilterChip({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF304423) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.bricolageGrotesque(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(trackerControllerProvider.notifier).fetchTracker();
    });
  }

  String _formatRp(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  IconData _iconForCategory(String category) {
    final value = category.toLowerCase();
    if (value.contains('beras')) return Icons.rice_bowl;
    if (value.contains('minyak')) return Icons.water_drop;
    if (value.contains('susu') || value.contains('minum')) {
      return Icons.local_drink;
    }
    if (value.contains('snack') || value.contains('cemilan')) {
      return Icons.cookie;
    }
    return Icons.shopping_bag;
  }

  static const categoryTranslation = {
    'snack': 'snacks',
    'cemilan': 'snacks',
    'mandi': 'filter_toiletries',
    'toiletries': 'filter_toiletries',
    'minum': 'beverages',
    'susu': 'filter_milk',
    'mie': 'filter_instant_noodle',
    'food': 'groceries',
    'beras': 'groceries',
    'minyak': 'groceries',
    'kopi': 'beverages',
    'sembako': 'groceries',
    'lain': 'cat_lainnya',
  };

  String _translateCategory(String cat) {
    final lower = cat.toLowerCase();
    for (final entry in categoryTranslation.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return productCategoryTranslationKey(cat);
  }

  String _historyMonthKey(PurchaseHistoryModel group) {
    if (group.monthKey.isNotEmpty) return group.monthKey;
    for (final item in group.items) {
      final parsed = DateTime.tryParse(item.purchasedAt)?.toLocal();
      if (parsed != null) return DateFormat('yyyy-MM').format(parsed);
    }
    return group.month;
  }

  @override
  Widget build(BuildContext context) {
    final trackerState = ref.watch(trackerControllerProvider);
    final tracker = trackerState.data;
    final historyState = ref.watch(historyControllerProvider);
    final purchases = historyState.data?.purchases ?? [];

    final now = DateTime.now();
    final thisMonthStr = DateFormat('yyyy-MM').format(now);
    final lastMonthDate = DateTime(now.year, now.month - 1);
    final lastMonthStr = DateFormat('yyyy-MM').format(lastMonthDate);

    double thisMonthTotal = 0;
    double lastMonthTotal = 0;

    for (var p in purchases) {
      final key = _historyMonthKey(p);
      if (key == thisMonthStr)
        thisMonthTotal = p.totalActualSpending.toDouble();
      if (key == lastMonthStr)
        lastMonthTotal = p.totalActualSpending.toDouble();
    }

    String insightText = 'statistics.insight_stable'.tr();
    if (lastMonthTotal > 0) {
      final diff = thisMonthTotal - lastMonthTotal;
      final percent = ((diff.abs() / lastMonthTotal) * 100).toStringAsFixed(1);
      final week = (now.day / 7).ceil();

      final categories = tracker?.byCategory ?? [];
      final topCat = categories.isNotEmpty
          ? categories.first.category
          : 'Lainnya';
      final mappedTopCat = _translateCategory(topCat).tr();
      final args = {'percent': percent, 'category': mappedTopCat};

      if (week == 1) {
        insightText = diff < 0
            ? 'statistics.insight_month_down'.tr(namedArgs: args)
            : 'statistics.insight_month_up'.tr(namedArgs: args);
      } else if (week == 2) {
        insightText = diff < 0
            ? 'statistics.insight_category_down'.tr(namedArgs: args)
            : 'statistics.insight_category_up'.tr(namedArgs: args);
      } else if (week == 3) {
        insightText = diff < 0
            ? 'statistics.insight_month_down'.tr(namedArgs: args)
            : 'statistics.insight_month_up'.tr(namedArgs: args);
      } else {
        insightText = diff < 0
            ? 'statistics.insight_category_down'.tr(namedArgs: args)
            : 'statistics.insight_category_up'.tr(namedArgs: args);
      }
    }

    final monthsLabels = <String>[];
    final monthlyExpenses = <double>[];

    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      monthsLabels.add(DateFormat.MMM(context.locale.toString()).format(d));
      final monthStr = DateFormat('yyyy-MM').format(d);

      final match = purchases.firstWhere(
        (p) => _historyMonthKey(p) == monthStr,
        orElse: () => const PurchaseHistoryModel(
          month: '',
          totalActualSpending: 0,
          items: [],
        ),
      );
      monthlyExpenses.add(match.totalActualSpending.toDouble());
    }

    double maxExp = 0;
    int maxIndex = -1;
    for (int i = 0; i < monthlyExpenses.length; i++) {
      if (monthlyExpenses[i] >= maxExp) {
        maxExp = monthlyExpenses[i];
        maxIndex = i;
      }
    }
    String trendText = maxIndex != -1 && maxExp > 0
        ? 'statistics.trend_highest_month'.tr(
            namedArgs: {'month': monthsLabels[maxIndex]},
          )
        : 'statistics.trend_not_enough_data'.tr();

    final chartMaxY = maxExp == 0 ? 1.0 : maxExp * 1.2;
    final palette = [
      const Color(0xFF304423),
      const Color(0xFF5C7A4A),
      const Color(0xFFC9E88A),
      const Color(0xFFA3B18A),
      const Color(0xFF64748B),
    ];
    final expenses = (tracker?.byCategory ?? const <CategorySpendModel>[])
        .asMap()
        .entries
        .map(
          (entry) => {
            'category': entry.value.category,
            'color': palette[entry.key % palette.length],
            'percent': entry.value.percentage.round(),
            'amount': _formatRp(entry.value.amount),
          },
        )
        .toList(growable: false);

    String? getImageUrl(String name) {
      for (var p in purchases) {
        for (var item in p.items) {
          if (item.productName == name && item.imageUrl != null) {
            return item.imageUrl;
          }
        }
      }
      return null;
    }

    final topExpenses = (tracker?.items ?? const <TrackerItemModel>[])
        .take(3)
        .map(
          (item) => {
            'name': item.productName,
            'icon': _iconForCategory(item.productName),
            'imageUrl': getImageUrl(item.productName),
            'amount': _formatRp(item.pricePaid),
            'percent': '',
            'weight': '1 Pcs',
            'category': _translateCategory(item.productName),
            'currentPrice': item.pricePaid,
            'historicalAvgPrice': item.pricePaid,
          },
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'statistics_title'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF304423),
        onRefresh: () async {
          await Future.wait([
            ref.read(trackerControllerProvider.notifier).fetchTracker(),
            ref.read(historyControllerProvider.notifier).fetchPurchases(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TASK 2: Insight Card (Cream/Soft Yellow + Sparkles Icon)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1), // Cream/Soft Yellow
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFFFC107)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'insight_stat_title'.tr(),
                            style: GoogleFonts.bricolageGrotesque(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF304423),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            insightText,
                            style: GoogleFonts.bricolageGrotesque(
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF304423),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // TUGAS 1: PERBAIKAN DIAGRAM DONAT
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'expense_categories'.tr(),
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius:
                                  60, // Diperlebar agar teks muat
                              sections: expenses
                                  .map(
                                    (e) => PieChartSectionData(
                                      color: e['color'] as Color,
                                      value: (e['percent'] as int).toDouble(),
                                      title: '${e['percent']}%',
                                      radius: 45, // Diperlebar agar teks muat
                                      titlePositionPercentageOffset: 0.55,
                                      titleStyle:
                                          GoogleFonts.bricolageGrotesque(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatRp(tracker?.totalSpent ?? 0),
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'total_this_month'.tr(),
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Legend Vertical List
                    Column(
                      children: expenses.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: e['color'] as Color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                displayProductCategory(e['category'] as String),
                                style: GoogleFonts.bricolageGrotesque(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    e['amount'] as String,
                                    style: GoogleFonts.bricolageGrotesque(
                                      color: const Color(0xFF1E293B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${e['percent']}%',
                                    style: GoogleFonts.bricolageGrotesque(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // TUGAS 2: ROMBAK GRAFIK "TREN SISA ANGGARAN"
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'expense_trends'.tr(),
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 48), // Extra space for top titles
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          maxY: chartMaxY,
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            show: true,
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < monthsLabels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        monthsLabels[value.toInt()],
                                        style: GoogleFonts.bricolageGrotesque(
                                          color: const Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => Colors
                                  .transparent, // Transparent to look like just text above
                              tooltipPadding: EdgeInsets.zero,
                              tooltipMargin: 8,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                    final double actualValue =
                                        monthlyExpenses[groupIndex];
                                    final String text = _formatRp(actualValue);
                                    final bool isLast =
                                        groupIndex ==
                                        monthlyExpenses.length - 1;
                                    final Color textColor = isLast
                                        ? const Color(0xFF304423)
                                        : const Color(0xFF64748B);
                                    return BarTooltipItem(
                                      text,
                                      GoogleFonts.bricolageGrotesque(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    );
                                  },
                            ),
                          ),
                          barGroups: monthlyExpenses.asMap().entries.map((
                            entry,
                          ) {
                            final int index = entry.key;
                            final double value = entry.value;

                            // Highlight ONLY the last bar (June)
                            final isLast = index == monthlyExpenses.length - 1;

                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: value,
                                  color: isLast
                                      ? const Color(0xFF304423)
                                      : const Color(0x33304423),
                                  width: 14,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                              showingTooltipIndicators: [0],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      trendText,
                      style: GoogleFonts.bricolageGrotesque(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // TUGAS 3: TOP 3 PENGELUARAN TERBESAR
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'top_expenses_title'.tr(),
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: topExpenses.map((item) {
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => showProductDetailBottomSheet(
                              context,
                              productName: item['name'] as String,
                              productWeight: item['weight'] as String,
                              productCategory: item['category'] as String,
                              currentPrice: item['currentPrice'] as double,
                              historicalAvgPrice:
                                  item['historicalAvgPrice'] as double,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    padding: const EdgeInsets.all(0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: item['imageUrl'] != null
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                item['imageUrl'] as String,
                                            fit: BoxFit.cover,
                                            errorWidget: (ctx, err, stack) =>
                                                Icon(
                                                  item['icon'] as IconData,
                                                  color: const Color(
                                                    0xFF475569,
                                                  ),
                                                  size: 24,
                                                ),
                                            placeholder: (ctx, url) => Icon(
                                              item['icon'] as IconData,
                                              color: const Color(0xFF475569),
                                              size: 24,
                                            ),
                                          )
                                        : Icon(
                                            item['icon'] as IconData,
                                            color: const Color(0xFF475569),
                                            size: 24,
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      item['name'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.bricolageGrotesque(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        item['amount'] as String,
                                        style: GoogleFonts.bricolageGrotesque(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                          fontSize: 14,
                                        ),
                                      ),
                                      if ((item['percent'] as String)
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item['percent'] as String,
                                          style: GoogleFonts.bricolageGrotesque(
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpenseCategory {
  final String name;
  final double amount;
  final IconData icon;

  const ExpenseCategory({
    required this.name,
    required this.amount,
    required this.icon,
  });
}

class _TopNotification extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onDismissed;

  const _TopNotification({
    Key? key,
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.onDismissed,
  }) : super(key: key);

  @override
  State<_TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<_TopNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _animation = Tween<double>(begin: -100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 2, milliseconds: 500), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Dismissible(
          key: ValueKey('dashboard-top-notification-${widget.message}'),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismissed(),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _animation.value),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: widget.backgroundColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        color: widget.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
