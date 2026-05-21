import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/privacy_service.dart';

class TotalExpensesCard extends StatefulWidget {
  final double amount;
  final double savedAmount;

  /// Jika true, konten dibungkus Container hijau tua (untuk layar dengan background putih).
  /// Jika false (default), konten transparan langsung di atas background hijau dashboard.
  final bool showCard;
  const TotalExpensesCard({
    super.key,
    required this.amount,
    required this.savedAmount,
    this.showCard = false,
  });

  @override
  State<TotalExpensesCard> createState() => _TotalExpensesCardState();
}

class _TotalExpensesCardState extends State<TotalExpensesCard> {
  String _formatRp(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  double get _savedPercentage {
    final double total = widget.amount + widget.savedAmount;
    if (total == 0) return 0.0;
    return (widget.savedAmount / total) * 100;
  }

  Widget _buildContent() {
    return ValueListenableBuilder<bool>(
      valueListenable: PrivacyService().isExpenseObscured,
      builder: (context, isObscured, child) {
        final bool isBudgetVisible = !isObscured;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Label "Total Expenses" ──
            Text(
              'dashboard.total_expenses'.tr(),
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 8),

            // ── Nominal + Eye Icon ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      if (isBudgetVisible)
                        TextSpan(
                          text: 'Rp',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      TextSpan(
                        // Tampilkan angka atau bullet sesuai state
                        text: isBudgetVisible
                            ? _formatRp(widget.amount).replaceFirst('Rp ', '')
                            : '*********',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: isBudgetVisible ? 0 : 2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await PrivacyService().toggleObscured();
                  },
                  icon: Icon(
                    isBudgetVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),

            // ── Saved Expenses: AnimatedSize untuk efek slide-up smooth ──
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: SizedBox(
                // Saat hidden → tinggi 0, elemen di bawah "tertarik naik"
                height: isBudgetVisible ? null : 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${'saved_expenses'.tr()}: ',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${_formatRp(widget.savedAmount)} (${_savedPercentage.toStringAsFixed(0)}%)',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFC9E88A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showCard) {
      // Untuk layar dengan background putih (ExpenseHistoryScreen)
      const Color darkGreen = Color(0xFF304423);
      return Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: darkGreen,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: darkGreen.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _buildContent(),
      );
    }

    // Default: transparan di atas background hijau dashboard
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: _buildContent(),
    );
  }
}
