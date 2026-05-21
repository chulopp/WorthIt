import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../utils/snackbar_helper.dart';
import 'package:easy_localization/easy_localization.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isPro = false; // false = Free, true = Pro
  bool _isYearly = false; // false = Bulanan, true = Tahunan
  double _previousPrice = 0;

  double get _currentPrice {
    if (!_isPro) return 0;
    return _isYearly ? 190000 : 19000;
  }

  String _formatPrice(double value) {
    final s = value.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  void _setPro(bool value) {
    setState(() {
      _previousPrice = _currentPrice;
      _isPro = value;
    });
  }

  void _setYearly(bool value) {
    setState(() {
      _previousPrice = _currentPrice;
      _isYearly = value;
    });
  }

  String get _cycleText {
    if (!_isPro) return '';
    return _isYearly ? 'per_year'.tr() : 'per_month'.tr();
  }

  bool get _showBestSeller => _isPro && !_isYearly;

  @override
  Widget build(BuildContext context) {
    const Color darkGreen = Color(0xFF304423);
    const Color lightGreen = Color(0xFFC9E88A);
    const Color textPrimary = Color(0xFF1E293B);
    const Color bgScaffold = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: bgScaffold,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'subscription'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Text(
              'choose_best_plan'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                color: darkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 32,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'premium_access_desc'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Main Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Plan Toggle (Free / Pro)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _buildToggleButton(
                            label: 'free'.tr(),
                            isSelected: !_isPro,
                            onTap: () => _setPro(false),
                          ),
                          _buildToggleButton(
                            label: 'pro'.tr(),
                            isSelected: _isPro,
                            onTap: () => _setPro(true),
                            icon: Icons.workspace_premium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cycle Toggle (Bulanan / Tahunan)
                    AnimatedOpacity(
                      opacity: _isPro ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !_isPro,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              _buildToggleButton(
                                label: 'monthly'.tr(),
                                isSelected: !_isYearly,
                                onTap: () => _setYearly(false),
                              ),
                              _buildToggleButton(
                                label: 'yearly'.tr(),
                                isSelected: _isYearly,
                                onTap: () => _setYearly(true),
                                badge: 'save_17_percent'.tr(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Price Area with Best Seller Badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: _isPro ? darkGreen : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: _previousPrice,
                                  end: _currentPrice,
                                ),
                                duration: const Duration(milliseconds: 400),
                                builder: (context, value, child) => Text(
                                  _formatPrice(value),
                                  style: GoogleFonts.bricolageGrotesque(
                                    color: _isPro ? lightGreen : textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 40,
                                  ),
                                ),
                              ),
                              if (_isPro)
                                Text(
                                  _cycleText,
                                  style: GoogleFonts.outfit(
                                    color: lightGreen.withValues(alpha: 0.7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (!_isPro) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'free_forever'.tr(),
                                  style: GoogleFonts.outfit(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // "Paling Laris" Badge
                        if (_showBestSeller)
                          Positioned(
                            top: -12,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF9800),
                                    Color(0xFFFFC107),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF9800,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'best_seller'.tr(),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Benefits List
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isPro ? 'all_you_get'.tr() : 'basic_features'.tr(),
                        style: GoogleFonts.outfit(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isPro) ...[
                      _buildBenefitItem('unlimited_scan'.tr(), true),
                      _buildBenefitItem('premium_ai_analysis'.tr(), true),
                      _buildBenefitItem(
                        'smart_product_recommendation'.tr(),
                        true,
                      ),
                      _buildBenefitItem('export_pdf_report'.tr(), true),
                      _buildBenefitItem('priority_access'.tr(), true),
                    ] else ...[
                      _buildBenefitItem('limited_scan'.tr(), false),
                      _buildBenefitItem('basic_price_analysis'.tr(), false),
                      _buildBenefitItem('shopping_list'.tr(), false),
                    ],
                    const SizedBox(height: 28),

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_isPro) {
                            AuthService().isPro.value = true;
                            SnackbarHelper.showTopSnackbar(
                              context,
                              'upgrade_success'.tr(),
                              icon: Icons.workspace_premium,
                            );
                          } else {
                            AuthService().isPro.value = false;
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lightGreen,
                          foregroundColor: darkGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isPro ? 'subscribe_pro'.tr() : 'continue_free'.tr(),
                          style: GoogleFonts.bricolageGrotesque(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    String? badge,
  }) {
    const Color darkGreen = Color(0xFF304423);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? darkGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: darkGreen.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: isSelected
                          ? const Color(0xFFC9E88A)
                          : Colors.grey.shade500,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFC9E88A).withValues(alpha: 0.2)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.outfit(
                          color: isSelected
                              ? const Color(0xFFC9E88A)
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.w700,
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String text, bool isPro) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isPro
                  ? const Color(0xFFC9E88A).withValues(alpha: 0.2)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              color: isPro ? const Color(0xFF304423) : Colors.grey.shade400,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
