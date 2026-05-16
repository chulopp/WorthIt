import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/dashboard_data.dart';
import '../services/dummy_data.dart';
import '../widgets/total_expenses_card.dart';
import '../widgets/product_analysis_sheet.dart';
import '../widgets/decision_badge.dart';
import '../utils/pdf_generator.dart';
import '../utils/date_helper.dart';

class ExpenseHistoryScreen extends StatelessWidget {
  const ExpenseHistoryScreen({super.key});

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
    final savedExpense = totalExpense * 0.15;

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
          colPrice: 'pdf_col_price'.tr(),
          footerText: 'pdf_footer'.tr(),
          categoryFallback: 'groceries'.tr(),
        );
      },
      name: 'WorthIt_Expense_Report',
    );
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

  @override
  Widget build(BuildContext context) {
    final data = DummyDataService.getDummyDashboard();
    const Color textPrimary = Color(0xFF1E293B);

    final filteredItems = data.recentItems
        .where((item) => DateHelper.isCurrentMonth(item.date))
        .toList();
    final calculatedTotal = filteredItems.fold(
      0.0,
      (sum, item) => sum + item.price,
    );
    final calculatedSaved = calculatedTotal * 0.15;

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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Expenses Card
            TotalExpensesCard(
              amount: calculatedTotal,
              savedAmount: '${_formatRp(calculatedSaved)} (15%)',
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

            if (filteredItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 48.0,
                  horizontal: 24,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada catatan pengeluaran bulan ini',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
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
