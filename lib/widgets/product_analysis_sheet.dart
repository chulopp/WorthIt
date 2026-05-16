import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/favorite_service.dart';
import '../utils/snackbar_helper.dart';
import 'decision_badge.dart';
import 'skeleton_analysis_card.dart';
// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — Call this to show the Product Analysis sheet
// ═══════════════════════════════════════════════════════════════════════════════

void showProductAnalysisSheet(
  BuildContext context, {
  required Map<String, dynamic> item,
}) {
  final favoriteService = FavoriteService();
  bool isFavorite = favoriteService.contains(
    favoriteService.activityFromMap(item),
  );
  final String productName = item['name'] as String? ?? 'Produk';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (BuildContext innerCtx, StateSetter setSheetState) {
          return _ProductAnalysisSheet(
            item: item,
            productName: productName,
            isFavorite: isFavorite,
            onFavoriteToggle: () {
              setSheetState(() {
                isFavorite = !isFavorite;
              });
            },
            historyCtx: context,
          );
        },
      );
    },
  );
}

class _ProductAnalysisSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final String productName;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final BuildContext historyCtx;

  const _ProductAnalysisSheet({
    required this.item,
    required this.productName,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.historyCtx,
  });

  @override
  State<_ProductAnalysisSheet> createState() => _ProductAnalysisSheetState();
}

class _ProductAnalysisSheetState extends State<_ProductAnalysisSheet> {
  bool _isLoading = true;
  final FavoriteService _favoriteService = FavoriteService();

  String _localizedCategory(String rawCategory) {
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

  void _showGuestLoginSnackbar() {
    SnackbarHelper.showTopSnackbar(
      context,
      'must_login_first'.tr(),
      isDarkContext: false,
      icon: Icons.warning_amber_rounded,
    );
  }

  void _toggleFavorite(VoidCallback onFavoriteToggle, bool isFavorite) {
    final isGuest = !AuthService().isLoggedIn.value;
    if (isGuest) {
      _showGuestLoginSnackbar();
      return;
    }

    final activity = _favoriteService.activityFromMap(widget.item);
    _favoriteService.toggleFavorite(activity);
    onFavoriteToggle();
    if (!isFavorite) {
      SnackbarHelper.showTopSnackbar(
        context,
        'favorite_added_success'.tr(),
        isDarkContext: true,
      );
    } else {
      SnackbarHelper.showTopSnackbar(
        context,
        'favorite_removed_success'.tr(),
        isDarkContext: false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.productName;
    final isFavorite = widget.isFavorite;
    final onFavoriteToggle = widget.onFavoriteToggle;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── DRAG HANDLE ──
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── TOP BAR: Close | Title | Favorite ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 24),
                  color: const Color(0xFF1E293B),
                  splashRadius: 22,
                  tooltip: 'product_detail.close'.tr(),
                ),
                Expanded(
                  child: Text(
                    '${'analysis_header'.tr()} $productName',
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _toggleFavorite(onFavoriteToggle, isFavorite);
                  },
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    size: 26,
                    color: const Color(0xFFFBBF24),
                  ),
                  splashRadius: 22,
                  tooltip: isFavorite
                      ? 'product_detail.remove_from_favorites'.tr()
                      : 'product_detail.add_to_favorites'.tr(),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

          // ── SCROLLABLE CONTENT ──
          Expanded(
            child: _isLoading
                ? const SkeletonAnalysisCard()
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroImage(),
                        const SizedBox(height: 20),
                        _buildScoreBanner(),
                        const SizedBox(height: 28),
                        _buildProductDetails(),
                        const SizedBox(height: 8),
                        _buildBrainInsights(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),

          // ── STICKY BOTTOM: I Bought This ──
          if (!_isLoading)
            Container(
              padding: EdgeInsets.fromLTRB(
                24,
                14,
                24,
                14 + MediaQuery.of(context).padding.bottom,
              ),
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
                    _showBuyConfirmationSheet(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF304423),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'btn_confirm_buy'.tr(),
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showBuyConfirmationSheet(BuildContext sheetCtx) {
    final isGuest = !AuthService().isLoggedIn.value;
    if (isGuest) {
      _showGuestLoginSnackbar();
      return;
    }

    int quantity = 1;
    final int itemPrice =
        int.tryParse(widget.item['price'] as String? ?? '0') ?? 0;

    showModalBottomSheet(
      context: sheetCtx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (BuildContext pickerCtx) {
        return StatefulBuilder(
          builder: (BuildContext statefulCtx, StateSetter setModalState) {
            final int totalPrice = itemPrice * quantity;
            final String formattedTotal = totalPrice
                .toString()
                .replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (m) => '${m[1]}.',
                );
            final String formattedItem = itemPrice.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]}.',
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
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'how_many_buy'.tr(),
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 120,
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                          initialItem: quantity - 1,
                        ),
                        onSelectedItemChanged: (index) {
                          setModalState(() => quantity = index + 1);
                        },
                        children: List.generate(99, (i) {
                          return Center(
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.urbanist(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total: $quantity x Rp $formattedItem = Rp $formattedTotal',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(pickerCtx);
                          Navigator.pop(sheetCtx);
                          SnackbarHelper.showTopSnackbar(
                            widget.historyCtx,
                            'success_purchased'.tr(),
                            backgroundColor: const Color(0xFFC9E88A),
                            textColor: const Color(0xFF304423),
                            iconColor: const Color(0xFF304423),
                            icon: Icons.check_circle,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF304423),
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

  Widget _buildHeroImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Container(
        height: 250,
        width: double.infinity,
        color: Colors.grey.shade100,
        child: Image.asset(
          'assets/images/${(widget.productName.hashCode.abs() % 3) + 1}.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildScoreBanner() {
    final int score =
        int.tryParse(widget.item['score'] as String? ?? '78') ?? 78;
    const accentGreen = Color(0xFF304423);
    final decisionCode = resolveDecisionCode(
      decisionCode:
          widget.item['decisionCode'] as String? ??
          widget.item['decision'] as String?,
      color: widget.item['status'] as String?,
      score: score,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: accentGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentGreen.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
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

  Widget _buildProductDetails() {
    final name = widget.item['name'] as String? ?? 'Produk';
    final price = widget.item['price'] as String? ?? '0';
    final category = widget.item['category'] as String? ?? 'Umum';
    final urgency = widget.item['urgency'] as String? ?? 'Sedang';
    final weight = widget.item['weight'] as String? ?? '';

    final buf = StringBuffer();
    for (var i = 0; i < price.length; i++) {
      if (i > 0 && (price.length - i) % 3 == 0) buf.write('.');
      buf.write(price[i]);
    }
    final displayPrice = 'Rp $buf';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.urbanist(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
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
                      displayPrice,
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.urbanist(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF304423),
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
                    '${'product_detail.normal_price'.tr()}: Rp 14.500',
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                    softWrap: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            children: [
              Text(
                _localizedCategory(category),
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '•',
                  style: TextStyle(fontSize: 14, color: Color(0x9994A3B8)),
                ),
              ),
              Text(
                '${'urgency_level'.tr()}: ${_localizedUrgency(urgency)}',
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              if (weight.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '•',
                    style: TextStyle(fontSize: 14, color: Color(0x9994A3B8)),
                  ),
                ),
                Text(
                  weight,
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrainInsights() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Divider(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
            thickness: 1,
          ),
          const SizedBox(height: 24),
          Text(
            'analysis_explanation'.tr(),
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 18),
          _insightTile(
            emoji: '📈',
            title: 'algorithm_future_trend'.tr(),
            description: 'algorithm_future_desc'.tr(),
            isPositive: true,
          ),
          const SizedBox(height: 14),
          _insightTile(
            emoji: '📊',
            title: 'algorithm_history_compare'.tr(),
            description: 'algorithm_history_desc'.tr(),
            isPositive: true,
          ),
          const SizedBox(height: 14),
          _insightTile(
            emoji: '🛡️',
            title: 'Shrinkflation Check',
            description: 'shrinkflation_not_detected'.tr(),
            isPositive: true,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF304423).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: const Color(0xFF304423).withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'disclaimer_text'.tr(),
                    style: GoogleFonts.urbanist(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
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
    required String emoji,
    required String title,
    required String description,
    bool isPositive = true,
  }) {
    final indicatorColor = isPositive
        ? const Color(0xFF304423)
        : const Color(0xFFEF4444);
    final bgColor = indicatorColor.withValues(alpha: 0.05);

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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: indicatorColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
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
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
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
                    color: const Color(0xFF1E293B),
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
}
