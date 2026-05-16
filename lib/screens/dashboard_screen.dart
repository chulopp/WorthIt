import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/snackbar_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/dummy_data.dart';
import '../services/auth_service.dart';
import '../models/dashboard_data.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'favorite_screen.dart';
import 'expense_history_screen.dart';
import '../widgets/total_expenses_card.dart';
import '../services/shopping_list_service.dart';
import '../services/history_service.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/product_analysis_sheet.dart';
import '../widgets/decision_badge.dart';
import '../utils/dialog_helper.dart';
import '../services/privacy_service.dart';
import '../utils/date_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ShoppingListService _shoppingListService = ShoppingListService();

  static const List<String> dummyCatalog = [
    'Beras Maknyuss 5kg',
    'Minyak Goreng Bimoli 2L',
    'Telur Ayam 1kg',
    'Indomie Goreng',
    'Susu Ultra 1L',
  ];

  int _currentIndex = 0;

  OverlayEntry? _currentOverlay;

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
    final name = AuthService().isLoggedIn.value ? 'user'.tr() : 'guest'.tr();
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                                                backgroundColor: const Color(
                                                  0xFF304423,
                                                ),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                              child: Text(
                                                'Batal',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w600,
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
                                              onPressed: () {
                                                _shoppingListService
                                                    .clearList();
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop();
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
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                              child: Text(
                                                'Ya, Hapus',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w600,
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
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return dummyCatalog.where((String option) {
                          return option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          );
                        });
                      },
                      onSelected: (String selection) {
                        if (selection.trim().isNotEmpty) {
                          _shoppingListService.addItem(selection.trim());
                          _showTopSuccess(context, 'item_added_success'.tr());

                          Future.microtask(() {
                            currentFieldController?.clear();
                          });
                        }
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
                              onSubmitted: (value) {
                                if (!dummyCatalog.contains(value)) {
                                  _showTopError(
                                    context,
                                    'select_from_catalog_error'.tr(),
                                  );
                                  return;
                                }
                                if (value.trim().isNotEmpty) {
                                  _shoppingListService.addItem(value.trim());
                                  setModalState(() {
                                    textEditingController.clear();
                                  });
                                  _showTopSuccess(
                                    context,
                                    'item_added_success'.tr(),
                                  );
                                }
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
                                    color: Colors.black.withOpacity(0.05),
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
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(
                                    index,
                                  );
                                  return InkWell(
                                    onTap: () {
                                      onSelected(option);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        option,
                                        style: GoogleFonts.bricolageGrotesque(
                                          color: const Color(0xFF1E293B),
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
                      child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: _shoppingListService.shoppingList,
                        builder: (context, shoppingList, child) {
                          return ListView.builder(
                            itemCount: shoppingList.length,
                            itemBuilder: (context, index) {
                              final item = shoppingList[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 1,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Checkbox(
                                      value: item['isDone'],
                                      activeColor: const Color(0xFF304423),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (bool? value) {
                                        _shoppingListService.toggleItem(
                                          index,
                                          value ?? false,
                                        );
                                      },
                                    ),
                                    Expanded(
                                      child: Text(
                                        item['name'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.bricolageGrotesque(
                                          fontSize: 14,
                                          color: item['isDone']
                                              ? Colors.grey
                                              : const Color(0xFF1E293B),
                                          decoration: item['isDone']
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red.shade300,
                                        size: 20,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () {
                                        _shoppingListService.removeItem(index);
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
                      label: item.name.tr(),
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
    final data = DummyDataService.getDummyDashboard();
    final remaining = data.budgetRemaining;

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
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
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
                                      MediaQuery.sizeOf(context).width < 360 ||
                                      constraints.maxWidth < 128;
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
                                    builder: (_) => const NotificationScreen(),
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
                if (!AuthService().isLoggedIn.value) ...[
                  // ── Guest Mode Banner ────────────────────────────
                  Padding(
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
                            const Color(0xFFC9E88A).withValues(alpha: 0.18),
                            const Color(0xFF304423).withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFC9E88A).withValues(alpha: 0.3),
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
                              onPressed: () {
                                // Direct Google Sign-In (one-click)
                                AuthService().login();
                                setState(() {});
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
                                backgroundColor: const Color(0xFF304423),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // ── Normal Budget Component ──────────────────────
                  ValueListenableBuilder<bool>(
                    valueListenable: PrivacyService().isExpenseObscured,
                    builder: (context, isObscured, child) {
                      final bool isBudgetVisible = !isObscured;
                      return Column(
                        children: [
                          TotalExpensesCard(
                            amount: remaining,
                            savedAmount: 'Rp 187.500 (15%)',
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
                            child: isBudgetVisible
                                ? Padding(
                                    key: const ValueKey('chart_visible'),
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
                                          titlesData: const FlTitlesData(
                                            show: false,
                                          ),
                                          borderData: FlBorderData(show: false),
                                          lineTouchData: const LineTouchData(
                                            enabled: false,
                                          ),
                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: const [
                                                FlSpot(0, 3),
                                                FlSpot(1, 3.5),
                                                FlSpot(2, 3.2),
                                                FlSpot(3, 4.1),
                                                FlSpot(4, 3.8),
                                                FlSpot(5, 4.5),
                                                FlSpot(6, 4.2),
                                                FlSpot(7, 5),
                                                FlSpot(8, 4.7),
                                                FlSpot(9, 5.3),
                                                FlSpot(10, 5.1),
                                              ],
                                              isCurved: true,
                                              curveSmoothness: 0.35,
                                              color: const Color(0xFFC9E88A),
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
                                          minY: 2,
                                          maxY: 6,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('chart_hidden'),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ],

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
                              final dummyExpenses = const [
                                ExpenseCategory(
                                  name: 'groceries',
                                  amount: 450000,
                                  icon: Icons.shopping_cart,
                                ),
                                ExpenseCategory(
                                  name: 'snacks',
                                  amount: 200000,
                                  icon: Icons.cookie,
                                ),
                                ExpenseCategory(
                                  name: 'filter_toiletries',
                                  amount: 100000,
                                  icon: Icons.soap,
                                ),
                              ];
                              _showExpensesSheet(dummyExpenses);
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
                              colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
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
                                'shrinkflation_warning'.tr(),
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.90),
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
                          final isGuest = !AuthService().isLoggedIn.value;
                          final aktivitasList =
                              data.recentItems.take(5).toList();

                          if (isGuest || aktivitasList.isEmpty) {
                            return const _EmptyActivityState();
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

class _EmptyActivityState extends StatelessWidget {
  const _EmptyActivityState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFEDF2F7),
                shape: BoxShape.circle,
              ),
              child: const FittedBox(
                fit: BoxFit.contain,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 32,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'empty_activity_title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'empty_activity_desc'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
                height: 1.45,
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
    final parsedDate = DateTime.tryParse(item.date);
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
        showProductAnalysisSheet(
          context,
          item: {
            'name': item.name,
            'price': item.price.toInt().toString(),
            'status': item.color,
            'score': decisionCode == kDecisionBuy
                ? '85'
                : decisionCode == kDecisionSubstitute
                ? '65'
                : '35',
            'decisionCode': decisionCode,
            'category': item.category,
            'urgency': 'Tinggi',
            'weight': '1 kg',
            'icon': _getItemIcon(item.name),
          },
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
              child: Image.asset(
                'assets/images/${(item.name.hashCode.abs() % 3) + 1}.jpg',
                fit: BoxFit.cover,
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
  final String name;
  final String brand;
  final double price;
  final String category;
  final IconData icon;

  const ItemKatalog({
    required this.name,
    required this.brand,
    required this.price,
    required this.category,
    required this.icon,
  });
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String searchQuery = '';
  String selectedCategory = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  final List<ItemKatalog> dummyKatalog = const [
    ItemKatalog(
      name: 'Beras Maknyuss 5kg',
      brand: 'Maknyuss',
      price: 65000,
      category: 'Sembako',
      icon: Icons.rice_bowl,
    ),
    ItemKatalog(
      name: 'Bimoli Minyak Goreng 2L',
      brand: 'Bimoli',
      price: 35000,
      category: 'Sembako',
      icon: Icons.water_drop,
    ),
    ItemKatalog(
      name: 'Gula Pasir Gulaku 1kg',
      brand: 'Gulaku',
      price: 15000,
      category: 'Sembako',
      icon: Icons.grain,
    ),
    ItemKatalog(
      name: 'Indomie Goreng',
      brand: 'Indofood',
      price: 3500,
      category: 'Mie Instan',
      icon: Icons.fastfood,
    ),
    ItemKatalog(
      name: 'Mie Sedap Kuah Soto',
      brand: 'Wings Food',
      price: 3000,
      category: 'Mie Instan',
      icon: Icons.fastfood,
    ),
    ItemKatalog(
      name: 'Bear Brand Milk 189ml',
      brand: 'Nestle',
      price: 10500,
      category: 'Susu',
      icon: Icons.emoji_food_beverage,
    ),
    ItemKatalog(
      name: 'Susu Ultra Full Cream 1L',
      brand: 'Ultra Jaya',
      price: 18000,
      category: 'Susu',
      icon: Icons.emoji_food_beverage,
    ),
    ItemKatalog(
      name: 'Chitato Sapi Panggang 68g',
      brand: 'Indofood',
      price: 11000,
      category: 'Cemilan',
      icon: Icons.cookie,
    ),
    ItemKatalog(
      name: 'Taro Snack Net 65g',
      brand: 'Taro',
      price: 8000,
      category: 'Cemilan',
      icon: Icons.cookie,
    ),
    ItemKatalog(
      name: 'Sabun Cair Lifebuoy 450ml',
      brand: 'Unilever',
      price: 24000,
      category: 'Alat Mandi',
      icon: Icons.soap,
    ),
  ];

  final List<String> categories = [
    'Semua',
    'Sembako',
    'Mie Instan',
    'Susu',
    'Cemilan',
    'Alat Mandi',
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

  List<ItemKatalog> get filteredKatalog {
    return dummyKatalog.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.brand.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == 'Semua' || item.category == selectedCategory;
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Katalog',
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
                    },
                    child: _FilterChip(
                      label: cat == 'Semua'
                          ? 'all'.tr()
                          : cat == 'Sembako'
                          ? 'groceries'.tr()
                          : cat == 'Cemilan'
                          ? 'snacks'.tr()
                          : cat == 'Mie Instan'
                          ? 'filter_instant_noodle'.tr()
                          : cat == 'Susu'
                          ? 'filter_milk'.tr()
                          : cat == 'Alat Mandi'
                          ? 'filter_toiletries'.tr()
                          : cat,
                      isSelected: selectedCategory == cat,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredKatalog.isEmpty
                ? Center(
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
                  )
                : ListView.builder(
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
                                child: Image.asset(
                                  'assets/images/${(item.name.hashCode.abs() % 3) + 1}.jpg',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
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
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String searchQuery = '';
  String selectedCategory = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  final List<ItemKatalog> dummyKatalog = const [
    ItemKatalog(
      name: 'Beras Maknyuss 5kg',
      brand: 'Maknyuss',
      price: 65000,
      category: 'Sembako',
      icon: Icons.rice_bowl,
    ),
    ItemKatalog(
      name: 'Bimoli Minyak Goreng 2L',
      brand: 'Bimoli',
      price: 35000,
      category: 'Sembako',
      icon: Icons.water_drop,
    ),
    ItemKatalog(
      name: 'Gula Pasir Gulaku 1kg',
      brand: 'Gulaku',
      price: 15000,
      category: 'Sembako',
      icon: Icons.grain,
    ),
    ItemKatalog(
      name: 'Indomie Goreng',
      brand: 'Indofood',
      price: 3500,
      category: 'Mie Instan',
      icon: Icons.fastfood,
    ),
    ItemKatalog(
      name: 'Mie Sedap Kuah Soto',
      brand: 'Wings Food',
      price: 3000,
      category: 'Mie Instan',
      icon: Icons.fastfood,
    ),
    ItemKatalog(
      name: 'Bear Brand Milk 189ml',
      brand: 'Nestle',
      price: 10500,
      category: 'Susu',
      icon: Icons.emoji_food_beverage,
    ),
    ItemKatalog(
      name: 'Susu Ultra Full Cream 1L',
      brand: 'Ultra Jaya',
      price: 18000,
      category: 'Susu',
      icon: Icons.emoji_food_beverage,
    ),
    ItemKatalog(
      name: 'Chitato Sapi Panggang 68g',
      brand: 'Indofood',
      price: 11000,
      category: 'Cemilan',
      icon: Icons.cookie,
    ),
    ItemKatalog(
      name: 'Taro Snack Net 65g',
      brand: 'Taro',
      price: 8000,
      category: 'Cemilan',
      icon: Icons.cookie,
    ),
    ItemKatalog(
      name: 'Sabun Cair Lifebuoy 450ml',
      brand: 'Unilever',
      price: 24000,
      category: 'Alat Mandi',
      icon: Icons.soap,
    ),
  ];

  final List<String> categories = [
    'Semua',
    'Sembako',
    'Mie Instan',
    'Susu',
    'Cemilan',
    'Alat Mandi',
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

  List<ItemKatalog> get filteredKatalog {
    return dummyKatalog.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.brand.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == 'Semua' || item.category == selectedCategory;
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
                      },
                      child: _FilterChip(
                        label: cat == 'Semua'
                            ? 'all'.tr()
                            : cat == 'Sembako'
                            ? 'groceries'.tr()
                            : cat == 'Cemilan'
                            ? 'snacks'.tr()
                            : cat == 'Mie Instan'
                            ? 'filter_instant_noodle'.tr()
                            : cat == 'Susu'
                            ? 'filter_milk'.tr()
                            : cat == 'Alat Mandi'
                            ? 'filter_toiletries'.tr()
                            : cat,
                        isSelected: selectedCategory == cat,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredKatalog.isEmpty
                  ? Center(
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
                    )
                  : ListView.builder(
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
                                  child: Image.asset(
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

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TUGAS 1: Dummy Data for Tren Pengeluaran (dengan kondisi 0)
    final List<double> monthlyExpenses = [300, 450, 0, 500, 0, 600];

    // TUGAS 3: Dummy Data for Donut Chart (Expenditure Categories) - Monochromatic Green Palette
    final List<Map<String, dynamic>> expenses = [
      {
        'category': 'Sembako',
        'color': const Color(0xFF304423),
        'percent': 40,
        'amount': 'Rp 800.000',
      },
      {
        'category': 'Susu & Bayi',
        'color': const Color(0xFF5C7A4A),
        'percent': 30,
        'amount': 'Rp 600.000',
      },
      {
        'category': 'Cemilan',
        'color': const Color(0xFFC9E88A),
        'percent': 15,
        'amount': 'Rp 300.000',
      },
      {
        'category': 'Lain-lain',
        'color': const Color(0xFFA3B18A),
        'percent': 15,
        'amount': 'Rp 300.000',
      },
    ];

    // TUGAS 3: Dummy Data for Top 3 Expenses
    final List<Map<String, dynamic>> topExpenses = [
      {
        'name': 'Beras Maknyuss 5kg',
        'icon': Icons.rice_bowl,
        'amount': 'Rp 195.000',
        'percent': '15%',
        'weight': '5 kg',
        'category': 'Sembako',
        'currentPrice': 195000.0,
        'historicalAvgPrice': 205000.0,
      },
      {
        'name': 'Susu UHT 1 Dus',
        'icon': Icons.local_drink,
        'amount': 'Rp 120.000',
        'percent': '10%',
        'weight': '1 dus',
        'category': 'Susu',
        'currentPrice': 120000.0,
        'historicalAvgPrice': 129000.0,
      },
      {
        'name': 'Minyak Goreng 2L',
        'icon': Icons.water_drop,
        'amount': 'Rp 80.000',
        'percent': '5%',
        'weight': '2 L',
        'category': 'Sembako',
        'currentPrice': 80000.0,
        'historicalAvgPrice': 86000.0,
      },
    ];

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
      body: SingleChildScrollView(
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
                  color: const Color(0xFFFFC107).withOpacity(0.3),
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
                          'insight_stat_desc'.tr(),
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
                    color: Colors.black.withOpacity(0.03),
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
                            centerSpaceRadius: 65, // Diperlebar agar teks muat
                            sections: expenses
                                .map(
                                  (e) => PieChartSectionData(
                                    color: e['color'] as Color,
                                    value: (e['percent'] as int).toDouble(),
                                    title: '${e['percent']}%',
                                    radius: 25, // Ditipiskan agar elegan
                                    titleStyle: GoogleFonts.bricolageGrotesque(
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
                                'Rp 2.000.000',
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
                              (e['category'] as String).tr(),
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
                    color: Colors.black.withOpacity(0.03),
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
                                const months = [
                                  'Jan',
                                  'Feb',
                                  'Mar',
                                  'Apr',
                                  'Mei',
                                  'Jun',
                                ];
                                if (value.toInt() >= 0 &&
                                    value.toInt() < months.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      months[value.toInt()],
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
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final double actualValue =
                                  monthlyExpenses[groupIndex];
                              final String text = actualValue == 0
                                  ? 'Rp 0'
                                  : 'Rp ${actualValue.toInt()}k';
                              final bool isLast =
                                  groupIndex == monthlyExpenses.length - 1;
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
                        barGroups: monthlyExpenses.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final double value = entry.value;
                          final bool isZero = value == 0;

                          // Highlight ONLY the last bar (June)
                          final isLast = index == monthlyExpenses.length - 1;

                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: isZero
                                    ? 15
                                    : value, // minimum height for 0
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
                    'monthly_trend_desc'.tr(),
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
                    color: Colors.black.withOpacity(0.03),
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
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
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
