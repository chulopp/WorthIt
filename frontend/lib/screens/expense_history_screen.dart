import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/history_controller.dart';
import '../models/dashboard_data.dart';
import '../models/api/api_models.dart';
import '../widgets/total_expenses_card.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/decision_badge.dart';
import '../widgets/empty_activity_state.dart';
import '../services/notification_service.dart';
import '../utils/pdf_generator.dart';
import '../utils/date_helper.dart';

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  ConsumerState<ExpenseHistoryScreen> createState() =>
      _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(historyControllerProvider.notifier).fetchPurchases();
      ref.read(historyControllerProvider.notifier).fetchScans();
      ref.read(dashboardControllerProvider.notifier).fetchDashboard();
    });
  }

  /// Pull-to-refresh: re-fetch expenses data from backend.
  Future<void> _refreshExpenses() async {
    await Future.wait([
      ref.read(historyControllerProvider.notifier).fetchPurchases(),
      ref.read(historyControllerProvider.notifier).fetchScans(),
      ref.read(dashboardControllerProvider.notifier).fetchDashboard(),
    ]);
  }

  /// Generates and opens the native PDF share/save dialog.
  Future<void> _exportPdf(BuildContext context, DashboardData data) async {
    final filteredItems = data.recentItems
        .where((item) => DateHelper.isCurrentMonth(item.date))
        .toList();
    final items = filteredItems;
    final totalExpense = filteredItems.fold(
      0.0,
      (sum, item) => sum + item.price,
    );
    final savedExpense = data.moneySaved;

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await PdfGenerator.generateExpenseReport(
          items: items,
          totalExpense: totalExpense,
          savedExpense: savedExpense,
          // Localised strings — respect active app language
          headerTitle: 'pdf_header_title'.tr(),
          printDateLabel: 'pdf_print_date'.tr(),
          totalExpensesLabel: 'dashboard.total_expenses'.tr(),
          savedExpensesLabel: 'saved_expenses'.tr(),
          colNo: 'pdf_col_no'.tr(),
          colDate: 'pdf_col_date'.tr(),
          colItemName: 'pdf_col_item_name'.tr(),
          colCategory: 'pdf_col_category'.tr(),
          colQuantity: 'pdf_col_quantity'.tr(),
          colPrice: 'pdf_col_price'.tr(),
          colTotalPrice: 'pdf_col_total_price'.tr(),
          footerText: 'pdf_footer'.tr(),
          categoryFallback: 'groceries'.tr(),
        );
      },
      name: 'WorthIt_Expense_Report',
    );
    NotificationService().notifyPdfDownloadSuccess();
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

  DashboardData _dashboardFromPurchases(
    List<PurchaseHistoryModel> purchaseGroups,
    double savedAmount,
  ) {
    final items = purchaseGroups
        .expand((group) => group.items)
        .map(
          (item) => RecentActivity(
            productId: item.productId,
            name: item.productName,
            price: item.totalPrice.toDouble(),
            color: 'green',
            date: item.purchasedAt,
            category: item.category ?? 'Lainnya',
            imageUrl: item.imageUrl,
            unitLabel: item.unitLabel,
            quantity: item.quantity,
            unitPrice: item.purchasedPrice.toDouble(),
          ),
        )
        .toList(growable: false);
    return DashboardData(
      monthlyBudget: 0,
      budgetRemaining: 0,
      moneySaved: savedAmount,
      recentItems: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyControllerProvider);
    final dashboardState = ref.watch(dashboardControllerProvider);
    final data = _dashboardFromPurchases(
      historyState.data?.purchases ?? const <PurchaseHistoryModel>[],
      historyState.data?.totalPengeluaranTersimpan ??
          dashboardState.data?.moneySaved ??
          0,
    );
    const Color textPrimary = Color(0xFF1E293B);

    final filteredItems = data.recentItems
        .where((item) => DateHelper.isCurrentMonth(item.date))
        .toList();
    final calculatedTotal = filteredItems.fold(
      0.0,
      (sum, item) => sum + item.price,
    );
    final calculatedSaved = data.moneySaved;
    final historyErrorMessage = historyState.errorMessage;
    final shouldShowHistoryError =
        historyErrorMessage != null &&
        !historyErrorMessage.toLowerCase().contains('login');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'my_expenses_title'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'export_pdf_tooltip'.tr(),
              onPressed: () => _exportPdf(context, data),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshExpenses,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Expenses Card
              TotalExpensesCard(
                amount: calculatedTotal,
                savedAmount: calculatedSaved,
                showCard: true,
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  'shopping_activity'.tr(),
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),

              if (historyState.isLoading && filteredItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (shouldShowHistoryError)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48.0,
                    horizontal: 24,
                  ),
                  child: Center(
                    child: Text(
                      historyErrorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              else if (filteredItems.isEmpty)
                const EmptyActivityState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _ActivityTile(item: item);
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
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
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            _getItemIcon(item.name),
                            color: Colors.grey.shade400,
                            size: 24,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
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
