import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import '../services/favorite_service.dart';
import '../utils/snackbar_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — Call this to show the Product Detail sheet
// ═══════════════════════════════════════════════════════════════════════════════

void showProductDetailSheet(
  BuildContext context, {
  String productName = 'Chitato Potato Chips',
  String productWeight = '68g',
  String productCategory = 'Snack & Biskuit',
  double currentPrice = 12500,
  double historicalAvgPrice = 14200,
  String? imageUrl,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProductDetailSheet(
      productName: productName,
      productWeight: productWeight,
      productCategory: productCategory,
      currentPrice: currentPrice,
      historicalAvgPrice: historicalAvgPrice,
      imageUrl: imageUrl,
    ),
  );
}

void showProductDetailBottomSheet(
  BuildContext context, {
  String productName = 'Chitato Potato Chips',
  String productWeight = '68g',
  String productCategory = 'Snack & Biskuit',
  double currentPrice = 12500,
  double historicalAvgPrice = 14200,
  String? imageUrl,
}) {
  showProductDetailSheet(
    context,
    productName: productName,
    productWeight: productWeight,
    productCategory: productCategory,
    currentPrice: currentPrice,
    historicalAvgPrice: historicalAvgPrice,
    imageUrl: imageUrl,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductDetailSheet extends StatefulWidget {
  final String productName;
  final String productWeight;
  final String productCategory;
  final double currentPrice;
  final double historicalAvgPrice;
  final String? imageUrl;

  const _ProductDetailSheet({
    required this.productName,
    required this.productWeight,
    required this.productCategory,
    required this.currentPrice,
    required this.historicalAvgPrice,
    this.imageUrl,
  });

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  bool _isFavorite = false;
  bool _isInList = false;
  final FavoriteService _favoriteService = FavoriteService();

  // ── Design tokens ──
  static const Color _accentGreen = Color(0xFFC9E88A);
  static const Color _darkGreen = Color(0xFF304423);
  static const Color _darkText = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);

  // ── Dummy 6-month price data (Dec → May) ──
  static const List<double> _priceHistory = [
    13800,
    14500,
    14200,
    13500,
    13000,
    12500,
  ];

  void _showGuestLoginSnackbar() {
    SnackbarHelper.showTopSnackbar(
      context,
      'must_login_first'.tr(),
      isDarkContext: false,
      icon: Icons.warning_amber_rounded,
    );
  }

  Future<void> _toggleFavorite() async {
    final isGuest = !AuthService().isLoggedIn.value;
    if (isGuest) {
      _showGuestLoginSnackbar();
      return;
    }

    final nextIsFavorite = !_isFavorite;
    final activity = _favoriteService.activityFromProduct(
      name: widget.productName,
      price: widget.currentPrice,
      category: widget.productCategory,
    );
    await _favoriteService.toggleFavorite(activity);
    if (!mounted) return;
    setState(() => _isFavorite = nextIsFavorite);
    SnackbarHelper.showTopSnackbar(
      context,
      nextIsFavorite
          ? 'favorite_added_success'.tr()
          : 'favorite_removed_success'.tr(),
      isDarkContext: nextIsFavorite,
    );
  }

  @override
  void initState() {
    super.initState();
    final activity = _favoriteService.activityFromProduct(
      name: widget.productName,
      price: widget.currentPrice,
      category: widget.productCategory,
    );
    _isFavorite = _favoriteService.contains(activity);
  }

  List<String> get _monthLabels => [
    'product_detail.months.dec'.tr(),
    'product_detail.months.jan'.tr(),
    'product_detail.months.feb'.tr(),
    'product_detail.months.mar'.tr(),
    'product_detail.months.apr'.tr(),
    'product_detail.months.may'.tr(),
  ];

  String _formatRupiah(double value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  double get _savingsPercent {
    if (widget.historicalAvgPrice <= 0) return 0;
    return ((widget.historicalAvgPrice - widget.currentPrice) /
        widget.historicalAvgPrice *
        100);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: screenHeight * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // ══════════════════════════════════════════════════════════
          // STICKY TOP HEADER
          // ══════════════════════════════════════════════════════════
          _buildStickyHeader(),

          // ══════════════════════════════════════════════════════════
          // SCROLLABLE CONTENT
          // ══════════════════════════════════════════════════════════
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero Image ──
                  _buildHeroImage(),
                  const SizedBox(height: 20),

                  // ── Product Title & Favorite ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.productName,
                      style: GoogleFonts.urbanist(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                        height: 1.2,
                      ),
                      softWrap: true,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Metadata Row ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 6,
                      children: [
                        Text(
                          widget.productWeight,
                          style: GoogleFonts.urbanist(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _mutedText,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 14,
                              color: _mutedText.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Text(
                          widget.productCategory,
                          style: GoogleFonts.urbanist(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _mutedText,
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Price Engine ──
                  _buildPriceEngine(),
                  const SizedBox(height: 24),

                  // ── Glossy Insight Banner ──
                  _buildGlossyInsightBanner(),
                  const SizedBox(height: 28),

                  // ── 6-Month Price Trend Chart ──
                  _buildPriceTrendSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ══════════════════════════════════════════════════════════
          // STICKY BOTTOM ACTION BUTTON — Add to Shopping List
          // ══════════════════════════════════════════════════════════
          _buildStickyBottomButton(bottomPadding),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STICKY HEADER — Close + Title
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStickyHeader() {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Drag handle
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        // Navigation row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 24),
                color: _darkText,
                splashRadius: 22,
                tooltip: 'product_detail.close'.tr(),
              ),
              // Centered title — "Product Details"
              Expanded(
                child: Text(
                  'product_detail.title'.tr(),
                  style: GoogleFonts.urbanist(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _toggleFavorite,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isFavorite ? Icons.star : Icons.star_border,
                    key: ValueKey<bool>(_isFavorite),
                    size: 24,
                    color: const Color(0xFFFBBF24),
                  ),
                ),
                color: _darkText,
                splashRadius: 22,
                tooltip: _isFavorite
                    ? 'product_detail.remove_from_favorites'.tr()
                    : 'product_detail.add_to_favorites'.tr(),
              ),
            ],
          ),
        ),
        // Subtle divider
        Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO IMAGE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeroImage() {
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey.shade50,
      child: Image.asset(
        'assets/images/${(widget.productName.hashCode.abs() % 3) + 1}.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: _accentGreen.withValues(alpha: 0.08),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 56,
                  color: _accentGreen.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 8),
                Text(
                  'product_detail.image_unavailable'.tr(),
                  style: GoogleFonts.urbanist(fontSize: 13, color: _mutedText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRICE ENGINE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPriceEngine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current price + historical avg in a row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 40,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatRupiah(widget.currentPrice),
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.urbanist(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _darkGreen,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${'product_detail.normal_price'.tr()}: ${_formatRupiah(widget.historicalAvgPrice)}',
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _mutedText,
                    ),
                    softWrap: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Footnote
          Text(
            'product_detail.based_on_6_months'.tr(),
            style: GoogleFonts.urbanist(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _mutedText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GLOSSY INSIGHT BANNER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGlossyInsightBanner() {
    final percent = _savingsPercent.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9E7), Color(0xFFFFFFFF)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sparkle icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFFFBBF24),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Insight text
            Expanded(
              child: Text(
                'product_detail.insight_banner'.tr(
                  namedArgs: {'percent': percent},
                ),
                style: GoogleFonts.urbanist(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _darkText,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6-MONTH PRICE TREND CHART
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPriceTrendSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text(
            'product_detail.price_trend_title'.tr(),
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 20),
          // Chart container
          SizedBox(height: 220, child: _buildLineChart()),
        ],
      ),
    );
  }

  /// Compute a clean, round interval for the Y axis based on the price range.
  double _computeYInterval(double range) {
    if (range <= 0) return 1000;
    // Pick the largest "nice" step that gives us 4-6 grid lines
    const steps = [500, 1000, 2000, 2500, 5000, 10000, 20000, 50000];
    for (final s in steps) {
      if (range / s <= 6) return s.toDouble();
    }
    return 50000;
  }

  Widget _buildLineChart() {
    final labels = _monthLabels;
    // Calculate dynamic Y range
    final minPrice = _priceHistory.reduce((a, b) => a < b ? a : b);
    final maxPrice = _priceHistory.reduce((a, b) => a > b ? a : b);
    final range = maxPrice - minPrice;
    final interval = _computeYInterval(range);

    // Snap yMin / yMax to multiples of the interval for clean labels
    final yMin = (minPrice / interval).floorToDouble() * interval;
    final yMax = (maxPrice / interval).ceilToDouble() * interval;

    // Build FlSpots
    final spots = List.generate(
      _priceHistory.length,
      (i) => FlSpot(i.toDouble(), _priceHistory[i]),
    );

    return LineChart(
      LineChartData(
        minY: yMin,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value < yMin || value > yMax) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _formatCompactPrice(value),
                    style: GoogleFonts.urbanist(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _mutedText,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 ||
                    idx >= labels.length ||
                    value != idx.toDouble()) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    labels[idx],
                    style: GoogleFonts.urbanist(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: idx == labels.length - 1 ? _darkGreen : _mutedText,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: Colors.grey, width: 1.5),
            left: BorderSide(color: Colors.grey, width: 1.5),
            right: BorderSide.none,
            top: BorderSide.none,
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _darkText,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  _formatRupiah(spot.y),
                  GoogleFonts.urbanist(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _darkGreen,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (index == _priceHistory.length - 1) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: Colors.white,
                    strokeWidth: 3,
                    strokeColor: _darkGreen,
                  );
                }
                return FlDotCirclePainter(
                  radius: 0,
                  color: Colors.transparent,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _accentGreen.withValues(alpha: 0.25),
                  _accentGreen.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  String _formatCompactPrice(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}rb';
    }
    return value.toStringAsFixed(0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STICKY BOTTOM ACTION BUTTON — "Add to Shopping List"
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStickyBottomButton(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 14, 24, 14 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final isGuest = !AuthService().isLoggedIn.value;
            if (isGuest) {
              _showGuestLoginSnackbar();
              return;
            }
            setState(() => _isInList = !_isInList);
            SnackbarHelper.showTopSnackbar(
              context,
              _isInList
                  ? 'item_added_success'.tr()
                  : 'item_deleted_success'.tr(),
              backgroundColor: const Color(0xFFC9E88A),
              textColor: const Color(0xFF304423),
              iconColor: const Color(0xFF304423),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _isInList ? const Color(0xFF64748B) : _darkGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isInList ? Icons.playlist_remove : Icons.playlist_add,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                _isInList
                    ? 'product_detail.remove_from_list'.tr()
                    : 'product_detail.add_to_list'.tr(),
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
