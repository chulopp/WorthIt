
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../controllers/analyze_controller.dart';
import '../config/product_categories.dart';
import '../controllers/controller_state.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/favorite_controller.dart';
import '../controllers/history_controller.dart';
import '../controllers/tracker_controller.dart';
import '../models/api/api_models.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/decision_badge.dart';
import '../widgets/skeleton_analysis_card.dart';

/// Premium analysis result screen – fully overhauled UI.
class AnalysisResultScreen extends ConsumerStatefulWidget {
  final String productName;
  final String price;
  final String weight;
  final String urgency;
  final String category;

  const AnalysisResultScreen({
    super.key,
    this.productName = '',
    this.price = '',
    this.weight = '',
    this.urgency = 'Sedang',
    this.category = 'Sembako',
  });

  @override
  ConsumerState<AnalysisResultScreen> createState() =>
      _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends ConsumerState<AnalysisResultScreen> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(favoriteControllerProvider.notifier).fetchFavorites();
      final productId = ref.read(analyzeControllerProvider).data?.productId;
      if (!mounted || productId == null || productId.isEmpty) return;
      setState(() {
        isFavorite = ref.read(favoriteControllerProvider).isFavorite(productId);
      });
    });
  }

  static const Color _accentGreen = Color(0xFF304423);
  static const Color _darkText = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF94A3B8);

  String get _displayName =>
      widget.productName.isEmpty ? 'Produk' : widget.productName;

  double get _numericPrice {
    if (widget.price.isEmpty) return 0;
    final cleaned = widget.price.replaceAll('.', '');
    return double.tryParse(cleaned) ?? 0;
  }

  AnalyzeResponseModel _fallbackAnalysis() {
    final urgencyLevel = switch (widget.urgency) {
      'high' || 'Tinggi' => 3,
      'low' || 'Rendah' => 1,
      _ => 2,
    };
    return AnalyzeResponseModel(
      productId: '',
      score: 78,
      decision: decisionCodeFromScore(78),
      productName: _displayName,
      scannedPrice: _numericPrice,
      normalPrice: _numericPrice,
      category: widget.category,
      urgency: urgencyLevel,
      weightGram: 0,
      explanations: const <String>[],
      metrics: const AnalyzeMetricsModel(
        wmaPrice: 0,
        support: 0,
        resistance: 0,
        srPosition: 0,
        priceDeltaPercent: 0,
        pricePerUnit: 0,
        historyPoints: 0,
        historyMonths: 0,
        volatilityPercent: 0,
        fairUpperBound: 0,
      ),
      tier: const AnalyzeTierModel(name: 'FREE', scanPeriod: 'weekly'),
      explanationItems: const <AnalyzeExplanationModel>[],
    );
  }

  AsyncValue<AnalyzeResponseModel> _analysisValue(AnalyzeState state) {
    if (state.data != null) return AsyncValue.data(state.data!);
    if (state.isLoading) return const AsyncValue.loading();
    if (state.errorMessage != null) {
      return AsyncValue.error(state.errorMessage!, StackTrace.current);
    }
    return AsyncValue.data(_fallbackAnalysis());
  }

  String _formatPrice(double price) {
    final digits = price.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return 'Rp $buffer';
  }

  String _localizedCategory(String rawCategory) {
    if (officialProductCategories.contains(rawCategory)) return rawCategory;
    switch (rawCategory) {
      case 'groceries':
      case 'cat_sembako':
      case 'Sembako':
        return 'groceries'.tr();
      case 'snacks':
      case 'cat_cemilan':
      case 'Cemilan':
        return 'snacks'.tr();
      case 'filter_instant_noodle':
      case 'Mie Instan':
        return 'filter_instant_noodle'.tr();
      case 'filter_milk':
      case 'Susu':
        return 'filter_milk'.tr();
      case 'beverages':
      case 'cat_minuman':
      case 'Minuman':
        return 'beverages'.tr();
      case 'filter_toiletries':
      case 'cat_alat_mandi':
      case 'Alat Mandi':
        return 'filter_toiletries'.tr();
      case 'cat_lainnya':
        return 'cat_lainnya'.tr();
      default:
        return rawCategory;
    }
  }

  String _localizedUrgency(String rawUrgency) {
    switch (rawUrgency) {
      case 'high':
      case 'Tinggi':
        return 'high'.tr();
      case 'medium':
      case 'Sedang':
        return 'medium'.tr();
      case 'low':
      case 'Rendah':
        return 'low'.tr();
      default:
        return rawUrgency;
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyzeState = ref.watch(analyzeControllerProvider);
    final analysisValue = _analysisValue(analyzeState);
    final titleName = analyzeState.data?.productName ?? _displayName;
    ref.listen(favoriteControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && previous?.errorMessage != message) {
        SnackbarHelper.showTopSnackbar(context, message, isDarkContext: false);
      }
      final productId =
          analyzeState.data?.productId ??
          analysisValue.maybeWhen(
            data: (analysis) => analysis.productId,
            orElse: () => '',
          );
      if (productId == null || productId.isEmpty || !mounted) return;
      final nextIsFavorite = next.isFavorite(productId);
      if (isFavorite != nextIsFavorite) {
        setState(() => isFavorite = nextIsFavorite);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),

      // ── TUGAS 1: APPBAR DINAMIS ──
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            size: 20,
            color: Color(0xFF1E293B),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${'analysis_header'.tr()} $titleName',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.urbanist(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        centerTitle: false,
      ),

      body: analysisValue.when(
        loading: () => const SkeletonAnalysisCard(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _darkText,
              ),
            ),
          ),
        ),
        data: (analysis) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TUGAS 2: HERO IMAGE SECTION ──
              _buildHeroImage(analysis),

              const SizedBox(height: 20),

              // ── TUGAS 3: SCORE BANNER HORIZONTAL ──
              _buildScoreBanner(analysis),

              const SizedBox(height: 28),

              // ── TUGAS 4: PRODUCT DETAILS ──
              _buildProductDetails(analysis),

              const SizedBox(height: 8),

              // ── TUGAS 5: BRAIN INSIGHTS ──
              _buildBrainInsights(analysis),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: analyzeState.isLoading && analyzeState.data == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _showBuyConfirmationSheet(
                      context,
                      analyzeState.data ?? _fallbackAnalysis(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'btn_confirm_buy'.tr(),
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── TUGAS 2: HERO IMAGE ──
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeroImage(AnalyzeResponseModel analysis) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Container(
        height: 290,
        width: double.infinity,
        color: Colors.grey.shade100,
        child: analysis.imageUrl != null && analysis.imageUrl!.isNotEmpty
            ? Image.network(
                analysis.imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _heroImageFallback(),
              )
            : Image.asset(
                'assets/images/chitao_700x.webp',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _heroImageFallback(),
              ),
      ),
    );
  }

  Widget _heroImageFallback() {
    return Container(
      color: _accentGreen.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: _accentGreen.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── TUGAS 3: SCORE BANNER ──
  // ═══════════════════════════════════════════════════════════
  Widget _buildScoreBanner(AnalyzeResponseModel analysis) {
    final int score = analysis.score;
    final decisionCode = analysis.decision;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _accentGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _accentGreen.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left icon
          SvgPicture.asset(
            'assets/svg/ICON.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(
              Color(0xFFC9E88A),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 14),

          // Score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'worthit_score_label'.tr(),
                  style: GoogleFonts.urbanist(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$score / 100',
                  style: GoogleFonts.urbanist(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Decision — Expanded is direct child of Row; Align/Container live inside Expanded.
          DecisionBadge(
            decisionCode: decisionCode,
            padding: kFinalDecisionBadgePadding,
            borderRadius: kFinalDecisionBadgeBorderRadius,
            fontSize: kFinalDecisionBadgeFontSize,
            letterSpacing: kFinalDecisionBadgeLetterSpacing,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── TUGAS 4: PRODUCT DETAILS ──
  // ═══════════════════════════════════════════════════════════
  Widget _buildProductDetails(AnalyzeResponseModel analysis) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product name and Favorite Icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  analysis.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.urbanist(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _darkText,
                    height: 1.2,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  if (analysis.productId.isEmpty) {
                    SnackbarHelper.showTopSnackbar(
                      context,
                      'Produk belum siap ditambahkan ke favorit.',
                      isDarkContext: false,
                    );
                    return;
                  }
                  ref
                      .read(favoriteControllerProvider.notifier)
                      .toggleFavorite(
                        analysis.productId,
                        product: FavoriteModel(
                          favoriteId: 'optimistic-${analysis.productId}',
                          productId: analysis.productId,
                          productName: analysis.productName,
                          imageUrl: analysis.imageUrl,
                          category: analysis.category,
                          currentPrice: analysis.normalPrice,
                          favoritedAt: DateTime.now().toIso8601String(),
                        ),
                      );
                  setState(() {
                    isFavorite = !isFavorite;
                  });
                  SnackbarHelper.showTopSnackbar(
                    context,
                    isFavorite
                        ? 'favorite_added_success'.tr()
                        : 'favorite_removed_success'.tr(),
                    isDarkContext: isFavorite,
                  );
                },
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFBBF24),
                  size: 28,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Price
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
                      _formatPrice(analysis.scannedPrice),
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.urbanist(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _accentGreen,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${'product_detail.normal_price'.tr()}: ${_formatPrice(analysis.normalPrice)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _mutedText.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Category & Urgency row
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 0,
            runSpacing: 6,
            children: [
              Text(
                analysis.category.isEmpty
                    ? 'cat_lainnya'.tr()
                    : _localizedCategory(analysis.category),
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
                    color: _mutedText.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Text(
                '${'urgency_level'.tr()}: ${_localizedUrgency(analysis.urgency == 3
                    ? 'high'
                    : analysis.urgency == 1
                    ? 'low'
                    : 'medium')}',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _mutedText,
                ),
              ),
              if (widget.weight.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 14,
                      color: _mutedText.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Text(
                  widget.weight,
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _mutedText,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── TUGAS 5: BRAIN INSIGHTS ──
  // ═══════════════════════════════════════════════════════════
  Widget _buildBrainInsights(AnalyzeResponseModel analysis) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          // Divider
          Divider(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
            thickness: 1,
          ),
          const SizedBox(height: 24),

          // Section title
          Text(
            'analysis_explanation'.tr(),
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 18),

          // Insight items
          if (analysis.explanationItems.isNotEmpty)
            ...analysis.explanationItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _insightTile(
                  icon: Icons.insights_rounded,
                  title: item.title.isEmpty
                      ? 'analysis_explanation'.tr()
                      : item.title,
                  description: item.description,
                  isPositive: analysis.score >= 50,
                ),
              ),
            ),
          if (analysis.explanationItems.isEmpty) ...[
            _insightTile(
              icon: Icons.insights_rounded,
              title: 'algorithm_future_trend'.tr(),
              description: 'algorithm_future_desc'.tr(),
              isPositive: true,
            ),
            const SizedBox(height: 14),
            _insightTile(
              icon: Icons.insights_rounded,
              title: 'algorithm_history_compare'.tr(),
              description: 'algorithm_history_desc'.tr(),
              isPositive: true,
            ),
            const SizedBox(height: 14),
            _insightTile(
              icon: Icons.insights_rounded,
              title: 'Shrinkflation Check',
              description: 'shrinkflation_not_detected'.tr(),
              isPositive: true,
            ),
          ],

          const SizedBox(height: 24),

          // Footnote
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _accentGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: _accentGreen.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'disclaimer_text'.tr(),
                    style: GoogleFonts.urbanist(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _mutedText,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightTile({
    IconData? icon,
    required String title,
    required String description,
    bool isPositive = true,
  }) {
    final indicatorColor = isPositive
        ? const Color(0xFF304423) // Green
        : const Color(0xFFEF4444); // Red
    final bgColor = indicatorColor.withValues(alpha: 0.05);
    final tileIcon =
        icon ?? (isPositive ? Icons.insights_rounded : Icons.warning_rounded);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: indicatorColor.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color-coded icon container
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: indicatorColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(tileIcon, size: 20, color: indicatorColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _darkText,
                        ),
                      ),
                    ),
                    Icon(
                      isPositive
                          ? Icons.check_circle_rounded
                          : Icons.warning_rounded,
                      size: 18,
                      color: indicatorColor,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.urbanist(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _darkText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBuyConfirmationSheet(
    BuildContext context,
    AnalyzeResponseModel analysis,
  ) {
    int quantity = 1;
    final int itemPrice = analysis.scannedPrice.round();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext statefulCtx, StateSetter setModalState) {
            final int totalPrice = itemPrice * quantity;
            final String formattedTotal = totalPrice
                .toString()
                .replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]}.',
                );
            final String formattedItemPrice = itemPrice
                .toString()
                .replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]}.',
                );

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  top: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header
                    Text(
                      'how_many_buy'.tr(),
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quantity Picker (The Slide)
                    SizedBox(
                      height: 120,
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                          initialItem: quantity - 1,
                        ),
                        onSelectedItemChanged: (index) {
                          setModalState(() {
                            quantity = index + 1;
                          });
                        },
                        children: List.generate(99, (index) {
                          return Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.urbanist(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _darkText,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Calculation
                    Text(
                      'Total: $quantity x Rp $formattedItemPrice = Rp $formattedTotal',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _mutedText,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 32),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx); // Close sheet
                          await ref
                              .read(analyzeControllerProvider.notifier)
                              .buyProduct(quantity: quantity);
                          if (!context.mounted) return;
                          final state = ref.read(analyzeControllerProvider);
                          if (state.errorMessage != null) {
                            SnackbarHelper.showTopSnackbar(
                              context,
                              state.errorMessage!,
                              icon: Icons.warning_amber_rounded,
                            );
                            return;
                          }
                          await ref
                              .read(historyControllerProvider.notifier)
                              .fetchPurchases();
                          await ref
                              .read(historyControllerProvider.notifier)
                              .fetchScans();
                          await ref
                              .read(dashboardControllerProvider.notifier)
                              .fetchDashboard();
                          await ref
                              .read(trackerControllerProvider.notifier)
                              .fetchTracker();
                          if (!context.mounted) return;
                          SnackbarHelper.showTopSnackbar(
                            context,
                            'Berhasil dibeli!',
                            backgroundColor: const Color(0xFFC9E88A),
                            textColor: const Color(0xFF304423),
                            iconColor: const Color(0xFF304423),
                            icon: Icons.check_circle,
                          );
                          Navigator.pop(context); // Close screen
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'confirm_purchase'.tr(),
                          style: GoogleFonts.urbanist(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
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
}
