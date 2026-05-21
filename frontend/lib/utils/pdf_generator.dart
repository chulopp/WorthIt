import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart' show DateFormat;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/dashboard_data.dart';

/// Generates a professional A4 PDF expense report entirely locally.
/// Uses the `pdf` package widget tree — no UI screenshots.
class PdfGenerator {
  // ── Brand colours ──────────────────────────────────────────────
  static final PdfColor _darkGreen = PdfColor.fromHex('#304423');
  static final PdfColor _accentGreen = PdfColor.fromHex('#6B8F3C');
  static final PdfColor _lightGreenBg = PdfColor.fromHex('#F0F5E8');
  static final PdfColor _white = PdfColor.fromHex('#FFFFFF');
  static final PdfColor _textPrimary = PdfColor.fromHex('#1E293B');
  static final PdfColor _textSecondary = PdfColor.fromHex('#64748B');
  static final PdfColor _borderColor = PdfColor.fromHex('#E2E8F0');

  // ── Localisation maps ──────────────────────────────────────────
  // Keys supplied from the caller (via .tr()) so the PDF respects
  // the active app locale.
  static Future<Uint8List> generateExpenseReport({
    required List<RecentActivity> items,
    required double totalExpense,
    required double savedExpense,
    // Localised strings passed from the UI layer
    required String headerTitle,
    required String printDateLabel,
    required String totalExpensesLabel,
    required String savedExpensesLabel,
    required String colNo,
    required String colDate,
    required String colItemName,
    required String colCategory,
    required String colQuantity,
    required String colPrice,
    required String colTotalPrice,
    required String footerText,
    required String categoryFallback,
  }) async {
    final now = DateTime.now();
    final dateFormatted = DateFormat('dd MMMM yyyy, HH:mm').format(now);
    final imageBytes = (await rootBundle.load(
      'assets/images/FULL.png',
    )).buffer.asUint8List();
    final logo = pw.MemoryImage(imageBytes);

    return _buildDocumentBytes(
      items: items,
      totalExpense: totalExpense,
      savedExpense: savedExpense,
      headerTitle: headerTitle,
      printDateLabel: printDateLabel,
      totalExpensesLabel: totalExpensesLabel,
      savedExpensesLabel: savedExpensesLabel,
      colNo: colNo,
      colDate: colDate,
      colItemName: colItemName,
      colCategory: colCategory,
      colQuantity: colQuantity,
      colPrice: colPrice,
      colTotalPrice: colTotalPrice,
      footerText: footerText,
      categoryFallback: categoryFallback,
      dateFormatted: dateFormatted,
      logo: logo,
    );
  }

  static Future<Uint8List> _buildDocumentBytes({
    required List<RecentActivity> items,
    required double totalExpense,
    required double savedExpense,
    required String headerTitle,
    required String printDateLabel,
    required String totalExpensesLabel,
    required String savedExpensesLabel,
    required String colNo,
    required String colDate,
    required String colItemName,
    required String colCategory,
    required String colQuantity,
    required String colPrice,
    required String colTotalPrice,
    required String footerText,
    required String categoryFallback,
    required String dateFormatted,
    required pw.MemoryImage logo,
  }) async {
    final pdf = pw.Document(
      title: 'WorthIt Expense Report',
      author: 'WorthIt App',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (context) => _buildHeader(
          logo: logo,
          headerTitle: headerTitle,
          printDateLabel: printDateLabel,
          dateFormatted: dateFormatted,
        ),
        footer: (context) => _buildFooter(
          footerText: footerText,
          pageNumber: context.pageNumber,
          pagesCount: context.pagesCount,
        ),
        build: (context) => [
          _buildSummaryBox(
            totalExpensesLabel: totalExpensesLabel,
            savedExpensesLabel: savedExpensesLabel,
            totalExpense: totalExpense,
            savedExpense: savedExpense,
          ),
          pw.SizedBox(height: 24),
          _buildExpenseTable(
            items: items,
            colNo: colNo,
            colDate: colDate,
            colItemName: colItemName,
            colCategory: colCategory,
            colQuantity: colQuantity,
            colPrice: colPrice,
            colTotalPrice: colTotalPrice,
            categoryFallback: categoryFallback,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildHeader({
    required pw.MemoryImage logo,
    required String headerTitle,
    required String printDateLabel,
    required String dateFormatted,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo / Title
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  alignment: pw.Alignment.topLeft,
                  child: pw.Image(logo, width: 120),
                ),
                pw.Text(
                  headerTitle,
                  style: pw.TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
            // Print date
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                color: _lightGreenBg,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                '$printDateLabel: $dateFormatted',
                style: pw.TextStyle(fontSize: 9, color: _darkGreen),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        // Divider line
        pw.Container(
          height: 2,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_darkGreen, _accentGreen, PdfColor.fromHex('#C9E88A')],
            ),
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SUMMARY BOX
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildSummaryBox({
    required String totalExpensesLabel,
    required String savedExpensesLabel,
    required double totalExpense,
    required double savedExpense,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _darkGreen,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        children: [
          // Total Expenses
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  totalExpensesLabel,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#FFFFFFB3'), // white70
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  _formatRp(totalExpense),
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _white,
                  ),
                ),
              ],
            ),
          ),
          // Vertical divider
          pw.Container(
            width: 1,
            height: 50,
            color: PdfColor.fromHex('#FFFFFF33'),
          ),
          pw.SizedBox(width: 20),
          // Saved Expenses
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  savedExpensesLabel,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#FFFFFFB3'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  _formatRp(savedExpense),
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#C9E88A'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATA TABLE
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildExpenseTable({
    required List<RecentActivity> items,
    required String colNo,
    required String colDate,
    required String colItemName,
    required String colCategory,
    required String colQuantity,
    required String colPrice,
    required String colTotalPrice,
    required String categoryFallback,
  }) {
    final grouped = _groupItems(items);
    final headers = [
      colNo,
      colDate,
      colItemName,
      colCategory,
      colQuantity,
      colPrice,
      colTotalPrice,
    ];

    final data = List<List<String>>.generate(grouped.length, (i) {
      final item = grouped[i];
      final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
      return [
        '${i + 1}',
        date,
        item.name,
        item.category.isEmpty ? categoryFallback : item.category,
        item.quantity.toString(),
        _formatRp(item.unitPrice),
        _formatRp(item.totalPrice),
      ];
    });

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: pw.BoxDecoration(
        color: _darkGreen,
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(8),
          topRight: pw.Radius.circular(8),
        ),
      ),
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: _white,
      ),
      cellStyle: pw.TextStyle(fontSize: 10, color: _textPrimary),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      columnWidths: {
        0: const pw.FixedColumnWidth(36), // No
        1: const pw.FixedColumnWidth(70), // Date
        2: const pw.FlexColumnWidth(3), // Item Name
        3: const pw.FlexColumnWidth(1.6), // Category
        4: const pw.FixedColumnWidth(48), // Quantity
        5: const pw.FixedColumnWidth(82), // Unit Price
        6: const pw.FixedColumnWidth(92), // Total Price
      },
      oddRowDecoration: pw.BoxDecoration(color: _lightGreenBg),
      headers: headers,
      data: data,
    );
  }

  static List<_PdfExpenseRow> _groupItems(List<RecentActivity> items) {
    final grouped = <String, _PdfExpenseRow>{};
    for (final item in items) {
      final keySource = item.productId?.trim().isNotEmpty == true
          ? item.productId!.trim()
          : item.name.trim().toLowerCase();
      final key = keySource.isEmpty ? item.name.toLowerCase() : keySource;
      final quantity = item.quantity <= 0 ? 1 : item.quantity;
      final unitPrice = item.unitPrice ?? (item.price / quantity);
      final totalPrice = unitPrice * quantity;
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = _PdfExpenseRow(
          name: item.name,
          category: item.category,
          quantity: quantity,
          unitPrice: unitPrice,
          totalPrice: totalPrice,
        );
      } else {
        existing.quantity += quantity;
        existing.totalPrice += totalPrice;
      }
    }
    return grouped.values.toList(growable: false);
  }

  // ═══════════════════════════════════════════════════════════════
  //  FOOTER
  // ═══════════════════════════════════════════════════════════════
  static pw.Widget _buildFooter({
    required String footerText,
    required int pageNumber,
    required int pagesCount,
  }) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 12),
        pw.Container(height: 1, color: _borderColor),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              footerText,
              style: pw.TextStyle(
                fontSize: 8,
                color: _textSecondary,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
            pw.Text(
              '$pageNumber / $pagesCount',
              style: pw.TextStyle(fontSize: 8, color: _textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════
  static String _formatRp(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }
}

class _PdfExpenseRow {
  final String name;
  final String category;
  int quantity;
  final double unitPrice;
  double totalPrice;

  _PdfExpenseRow({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}
