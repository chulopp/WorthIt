import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/favorite_controller.dart';
import '../controllers/product_detail_controller.dart';
import '../controllers/shopping_list_controller.dart';
import '../config/product_categories.dart';
import '../models/api/api_models.dart';
import '../services/auth_service.dart';
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
  String? productId,
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
      productId: productId,
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
  String? productId,
}) {
  showProductDetailSheet(
    context,
    productName: productName,
    productWeight: productWeight,
    productCategory: productCategory,
    currentPrice: currentPrice,
    historicalAvgPrice: historicalAvgPrice,
    imageUrl: imageUrl,
    productId: productId,
  );
}

class _PriceInsightData {
  final String text;
  final Color iconColor;
  final Color iconBgColor;
  final List<Color> bgGradient;
  final Color borderColor;

  const _PriceInsightData({
    required this.text,
    required this.iconColor,
    required this.iconBgColor,
    required this.bgGradient,
    required this.borderColor,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductDetailSheet extends ConsumerStatefulWidget {
  final String productName;
  final String productWeight;
  final String productCategory;
  final double currentPrice;
  final double historicalAvgPrice;
  final String? imageUrl;
  final String? productId;

  const _ProductDetailSheet({
    required this.productName,
    required this.productWeight,
    required this.productCategory,
    required this.currentPrice,
    required this.historicalAvgPrice,
    this.imageUrl,
    this.productId,
  });

  @override
  ConsumerState<_ProductDetailSheet> createState() =>
      _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<_ProductDetailSheet> {
  bool _isFavorite = false;
  bool _isInList = false;

  // ── Design tokens ──
  static const Color _accentGreen = Color(0xFFC9E88A);
  static const Color _darkGreen = Color(0xFF304423);
  static const Color _darkText = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);

  String? _resolvedProductId;

  ProductDetailModel? get _detail =>
      ref.read(productDetailControllerProvider).data;

  String get _displayName => _detail?.name ?? widget.productName;
  String get _displayCategory => _detail?.category ?? widget.productCategory;
  String get _localizedDisplayCategory =>
      displayProductCategory(_displayCategory);
  String get _displayWeight {
    final weight = _detail?.baseWeightGram ?? 0;
    if (weight <= 0) return widget.productWeight;
    return '${weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 1)}g';
  }

  List<PriceHistoryModel> get _detailHistory => _detail?.history ?? const [];
  List<double> get _priceHistory => _detailHistory.isEmpty
      ? List<double>.filled(6, widget.currentPrice)
      : _detailHistory.map((item) => item.price.toDouble()).toList();

  double get _displayCurrentPrice => _detailHistory.isEmpty
      ? widget.currentPrice
      : _detailHistory.last.price.toDouble();

  double get _displayHistoricalAvgPrice {
    if (_detailHistory.isEmpty) return widget.currentPrice;
    final total = _detailHistory.fold<double>(
      0,
      (sum, item) => sum + item.price,
    );
    return total / _detailHistory.length;
  }

  Future<void> _loadProductDetail() async {
    final controller = ref.read(productDetailControllerProvider.notifier);
    final explicitId = widget.productId;
    if (explicitId != null && explicitId.isNotEmpty) {
      _resolvedProductId = explicitId;
      await controller.loadProductDetail(explicitId);
      await _syncFavoriteState();
      return;
    }

    await controller.searchProducts(widget.productName);
    final state = ref.read(productDetailControllerProvider);
    final lowerName = widget.productName.toLowerCase();
    final match = state.searchResults.firstWhere(
      (item) => item.name.toLowerCase() == lowerName,
      orElse: () => state.searchResults.isEmpty
          ? const ProductSummaryModel(id: '', name: '')
          : state.searchResults.first,
    );
    if (match.id.isNotEmpty) {
      _resolvedProductId = match.id;
      await controller.loadProductDetail(match.id);
      await _syncFavoriteState();
    }
  }

  Future<void> _syncFavoriteState() async {
    if (!AuthService().isLoggedIn.value) return;
    await ref.read(favoriteControllerProvider.notifier).fetchFavorites();
    final productId = _resolvedProductId;
    if (!mounted || productId == null || productId.isEmpty) return;
    final isFavorite = ref
        .read(favoriteControllerProvider)
        .isFavorite(productId);
    setState(() => _isFavorite = isFavorite);
  }

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

    final productId = _resolvedProductId ?? _detail?.id;
    if (productId == null || productId.isEmpty) {
      SnackbarHelper.showTopSnackbar(
        context,
        'Produk belum siap ditambahkan ke favorit.',
        isDarkContext: false,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final nextIsFavorite = !_isFavorite;
    final favorite = FavoriteModel(
      favoriteId: 'optimistic-$productId',
      productId: productId,
      productName: _displayName,
      imageUrl: _detail?.imageUrl ?? widget.imageUrl,
      category: _displayCategory,
      currentPrice: _displayCurrentPrice,
      favoritedAt: DateTime.now().toIso8601String(),
    );
    ref
        .read(favoriteControllerProvider.notifier)
        .toggleFavorite(productId, product: favorite);
    setState(() => _isFavorite = nextIsFavorite);
    SnackbarHelper.showTopSnackbar(
      context,
      nextIsFavorite
          ? 'favorite_added_success'.tr()
          : 'favorite_removed_success'.tr(),
      isDarkContext: nextIsFavorite,
    );
  }

  ProductSummaryModel _currentProductSummary(String productId) {
    return ProductSummaryModel(
      id: productId,
      name: _displayName,
      imageUrl: _detail?.imageUrl ?? widget.imageUrl,
      category: _displayCategory,
      currentPrice: _displayCurrentPrice,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProductDetail();
    });
  }

  List<String> get _monthLabels {
    if (_detailHistory.isNotEmpty) {
      return _detailHistory.map((item) => item.month).toList(growable: false);
    }
    return [
      'product_detail.months.dec'.tr(),
      'product_detail.months.jan'.tr(),
      'product_detail.months.feb'.tr(),
      'product_detail.months.mar'.tr(),
      'product_detail.months.apr'.tr(),
      'product_detail.months.may'.tr(),
    ];
  }

  String _formatRupiah(double value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  _PriceInsightData get _priceComparisonInsightData {
    if (_displayHistoricalAvgPrice <= 0) {
      return _PriceInsightData(
        text: 'product_detail.insight_compare_unavailable'.tr(),
        iconColor: const Color(0xFF64748B),
        iconBgColor: const Color(0xFFF1F5F9),
        bgGradient: const [Color(0xFFF8F9FA), Color(0xFFFFFFFF)],
        borderColor: const Color(0xFFE2E8F0),
      );
    }
    final diff =
        ((_displayCurrentPrice - _displayHistoricalAvgPrice) /
            _displayHistoricalAvgPrice) *
        100;

    if (diff >= -1.0 && diff <= 1.0) {
      // KONDISI 2: STABIL / SAMA PERSIS
      return _PriceInsightData(
        text: 'product_detail.insight_stable'.tr(),
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF3C7),
        bgGradient: const [Color(0xFFFFFBEB), Color(0xFFFFFFFF)],
        borderColor: const Color(0xFFFDE68A),
      );
    } else if (diff < -1.0) {
      // KONDISI 1: LEBIH MURAH
      final pct = diff.abs().toStringAsFixed(0);
      return _PriceInsightData(
        text: 'product_detail.insight_cheaper'.tr(
          namedArgs: {'percent': pct},
        ),
        iconColor: const Color(0xFF15803D),
        iconBgColor: const Color(0xFFDCFCE7),
        bgGradient: const [Color(0xFFF0FDF4), Color(0xFFFFFFFF)],
        borderColor: const Color(0xFFBBF7D0),
      );
    } else {
      // KONDISI 3: LEBIH MAHAL
      final pct = diff.toStringAsFixed(0);
      return _PriceInsightData(
        text: 'product_detail.insight_expensive'.tr(
          namedArgs: {'percent': pct},
        ),
        iconColor: Colors.red[700]!,
        iconBgColor: Colors.red[100]!,
        bgGradient: [Colors.red[50]!, Colors.white],
        borderColor: Colors.red[300]!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(productDetailControllerProvider);
    final shoppingState = ref.watch(shoppingListControllerProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    ref.listen(favoriteControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && previous?.errorMessage != message) {
        SnackbarHelper.showTopSnackbar(
          context,
          message,
          isDarkContext: false,
          icon: Icons.warning_amber_rounded,
        );
      }

      final productId = _resolvedProductId ?? widget.productId ?? _detail?.id;
      if (productId == null || productId.isEmpty || !mounted) return;
      final nextIsFavorite = next.isFavorite(productId);
      if (_isFavorite != nextIsFavorite) {
        setState(() => _isFavorite = nextIsFavorite);
      }
    });
    ref.listen(shoppingListControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && previous?.errorMessage != message) {
        SnackbarHelper.showTopSnackbar(
          context,
          message,
          backgroundColor: const Color(0xFFC9E88A),
          textColor: const Color(0xFF304423),
          iconColor: const Color(0xFF304423),
        );
      }

      final productId = _resolvedProductId ?? widget.productId ?? _detail?.id;
      if (productId == null || productId.isEmpty || !mounted) return;
      final nextIsInList =
          next.data?.items.any((item) => item.productId == productId) ?? false;
      if (_isInList != nextIsInList) {
        setState(() => _isInList = nextIsInList);
      }
    });

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
            child: detailState.isLoading
                ? _buildLoadingSkeleton()
                : SingleChildScrollView(
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
                            _displayName,
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
                                _displayWeight,
                                style: GoogleFonts.urbanist(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _mutedText,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _mutedText.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              Text(
                                _localizedDisplayCategory,
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
                        if (detailState.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                            child: Text(
                              detailState.errorMessage!,
                              style: GoogleFonts.urbanist(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ),
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
          _buildStickyBottomButton(
            bottomPadding,
            isLoading: detailState.isLoading || shoppingState.isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!.withValues(alpha: 0.2),
      highlightColor: Colors.grey[100]!.withValues(alpha: 0.1),
      period: const Duration(milliseconds: 1400),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 250, width: double.infinity, color: Colors.white),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonBlock(width: 240, height: 32, radius: 12),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildSkeletonBlock(width: 52, height: 14, radius: 8),
                      const SizedBox(width: 10),
                      _buildSkeletonBlock(width: 140, height: 14, radius: 8),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildSkeletonBlock(width: 150, height: 38, radius: 12),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSkeletonBlock(height: 18, radius: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildSkeletonBlock(width: 170, height: 12, radius: 8),
                  const SizedBox(height: 26),
                  _buildSkeletonBlock(height: 86, radius: 18),
                  const SizedBox(height: 30),
                  _buildSkeletonBlock(width: 190, height: 24, radius: 10),
                  const SizedBox(height: 18),
                  _buildSkeletonBlock(height: 210, radius: 22),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBlock({
    double? width,
    required double height,
    double radius = 16,
  }) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
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
    final imageUrl = _detail?.imageUrl ?? widget.imageUrl;

    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey.shade50,
      child: imageUrl == null || imageUrl.isEmpty
          ? _buildHeroImageFallback()
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => _buildHeroImageSkeleton(),
              errorWidget: (_, __, ___) => _buildHeroImageFallback(),
            ),
    );
  }

  Widget _buildHeroImageSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Container(color: Colors.white),
    );
  }

  Widget _buildHeroImageFallback() {
    return Container(
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
                      _formatRupiah(_displayCurrentPrice),
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
                    '${'product_detail.normal_price'.tr()}: ${_formatRupiah(_displayHistoricalAvgPrice)}',
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
    final insight = _priceComparisonInsightData;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: insight.bgGradient,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: insight.borderColor, width: 1.5),
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
                color: insight.iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: insight.iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Insight text
            Expanded(
              child: Text(
                insight.text,
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
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
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
              reservedSize: 48,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 ||
                    idx >= labels.length ||
                    value != idx.toDouble()) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Transform.rotate(
                    angle: -0.45,
                    child: Text(
                      labels[idx],
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.urbanist(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: idx == labels.length - 1
                            ? _darkGreen
                            : _mutedText,
                      ),
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
  Widget _buildStickyBottomButton(
    double bottomPadding, {
    bool isLoading = false,
  }) {
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
          onPressed: isLoading
              ? null
              : () async {
                  final isGuest = !AuthService().isLoggedIn.value;
                  if (isGuest) {
                    _showGuestLoginSnackbar();
                    return;
                  }

                  final productId = _resolvedProductId ?? widget.productId;
                  if (productId == null || productId.isEmpty) {
                    SnackbarHelper.showTopSnackbar(
                      context,
                      'select_from_catalog_error'.tr(),
                      backgroundColor: const Color(0xFFC9E88A),
                      textColor: const Color(0xFF304423),
                      iconColor: const Color(0xFF304423),
                    );
                    return;
                  }

                  await ref
                      .read(shoppingListControllerProvider.notifier)
                      .addItem(
                        productId,
                        1,
                        product: _currentProductSummary(productId),
                      );
                  if (!context.mounted) return;
                  final shoppingState = ref.read(
                    shoppingListControllerProvider,
                  );
                  if (shoppingState.errorMessage != null) return;
                  SnackbarHelper.showTopSnackbar(
                    context,
                    'item_added_success'.tr(),
                    backgroundColor: const Color(0xFFC9E88A),
                    textColor: const Color(0xFF304423),
                    iconColor: const Color(0xFF304423),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: _isInList ? const Color(0xFF64748B) : _darkGreen,
            disabledBackgroundColor: _darkGreen.withValues(alpha: 0.45),
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
