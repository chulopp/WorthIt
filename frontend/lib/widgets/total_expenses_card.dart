import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/privacy_service.dart';

class TotalExpensesCard extends StatefulWidget {
  final double amount;

  /// Jumlah belanja di bawah harga normal bulan ini (menggantikan savedAmount lama).
  final double totalBelowNormalPrice;

  /// Pesan kosong saat totalBelowNormalPrice == 0 (ditampilkan sebagai hint).
  final String totalBelowNormalMessage;

  /// Jika true, konten dibungkus Container hijau tua (untuk layar dengan background putih).
  /// Jika false (default), konten transparan langsung di atas background hijau dashboard.
  final bool showCard;

  const TotalExpensesCard({
    super.key,
    required this.amount,
    required this.totalBelowNormalPrice,
    this.totalBelowNormalMessage = '',
    this.showCard = false,
  });

  @override
  State<TotalExpensesCard> createState() => _TotalExpensesCardState();
}

class _TotalExpensesCardState extends State<TotalExpensesCard> {
  String _formatRp(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Widget _buildContent() {
    return ValueListenableBuilder<bool>(
      valueListenable: PrivacyService().isExpenseObscured,
      builder: (context, isObscured, child) {
        final bool isBudgetVisible = !isObscured;
        final bool hasBelowNormal = widget.totalBelowNormalPrice > 0;

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

            // ── Total Belanja di Bawah Harga Normal ──
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: isBudgetVisible ? null : 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: hasBelowNormal
                      ? RichText(
                          text: TextSpan(
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: const Icon(
                                  Icons.trending_down_rounded,
                                  color: Color(0xFFC9E88A),
                                  size: 16,
                                ),
                              ),
                              const WidgetSpan(child: SizedBox(width: 4)),
                              TextSpan(
                                text: '${'total_below_normal_price'.tr()}: ',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white70,
                                ),
                              ),
                              TextSpan(
                                text: _formatRp(widget.totalBelowNormalPrice),
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFC9E88A),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          widget.totalBelowNormalMessage.isNotEmpty
                              ? widget.totalBelowNormalMessage
                              : 'total_below_normal_price_empty'.tr(),
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.white38,
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
