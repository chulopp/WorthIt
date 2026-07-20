import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/repository_providers.dart';
import '../services/auth_service.dart';
import '../utils/snackbar_helper.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isPro = false; // false = Free, true = Pro
  bool _isYearly = false; // false = Bulanan, true = Tahunan
  double _previousPrice = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isPro = AuthService().isPro.value;
  }

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

  Future<void> _handleUpgradeOrContinue() async {
    if (!_isPro) {
      await AuthService().setProStatus(false);
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final result = await userRepo.upgradeToProTier();

      if (!mounted) return;

      if (result.isSuccess && result.requireData == true) {
        await AuthService().setProStatus(true);
        SnackbarHelper.showTopSnackbar(
          context,
          'upgrade_success'.tr(),
          icon: Icons.workspace_premium,
        );
        Navigator.pop(context);
      } else {
        SnackbarHelper.showTopSnackbar(
          context,
          'Gagal melakukan upgrade. Silakan coba lagi.',
          icon: Icons.error_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showTopSnackbar(
          context,
          'Gagal upgrade: $e',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),

            // Tier Switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                    icon: Icons.workspace_premium,
                    onTap: () => _setPro(true),
                  ),
                ],
              ),
            ),

            if (_isPro) ...[
              const SizedBox(height: 16),
              // Cycle Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                      badge: 'save_17_percent'.tr(),
                      onTap: () => _setYearly(true),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Main Pricing Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isPro
                      ? darkGreen.withValues(alpha: 0.3)
                      : Colors.grey.shade200,
                  width: _isPro ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isPro
                        ? darkGreen.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    if (_showBestSeller)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: const BoxDecoration(
                            color: darkGreen,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: lightGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'best_seller'.tr(),
                                style: GoogleFonts.outfit(
                                  color: lightGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          // Badge Title
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _isPro
                                      ? darkGreen
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _isPro
                                      ? Icons.workspace_premium
                                      : Icons.flash_on,
                                  color: _isPro
                                      ? lightGreen
                                      : Colors.grey.shade600,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isPro
                                        ? 'WorthIt Pro'
                                        : 'WorthIt Starter',
                                    style: GoogleFonts.bricolageGrotesque(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                  ),
                                  Text(
                                    _isPro
                                        ? (_isYearly
                                              ? 'Paket Hemat Tahunan'
                                              : 'Paket Fleksibel Bulanan')
                                        : 'free_forever'.tr(),
                                    style: GoogleFonts.outfit(
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Animated Price Counter
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: _previousPrice,
                                  end: _currentPrice,
                                ),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                builder: (context, val, child) {
                                  return Text(
                                    _formatPrice(val),
                                    style: GoogleFonts.bricolageGrotesque(
                                      color: darkGreen,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 36,
                                      letterSpacing: -1,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _cycleText,
                                style: GoogleFonts.outfit(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          const Divider(height: 1),
                          const SizedBox(height: 24),

                          // Benefits List
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _isPro
                                  ? 'all_you_get'.tr()
                                  : 'basic_features'.tr(),
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
                            _buildBenefitItem(
                              'premium_ai_analysis'.tr(),
                              true,
                            ),
                            _buildBenefitItem(
                              'smart_product_recommendation'.tr(),
                              true,
                            ),
                            _buildBenefitItem('export_pdf_report'.tr(), true),
                            _buildBenefitItem('priority_access'.tr(), true),
                          ] else ...[
                            _buildBenefitItem('limited_scan'.tr(), false),
                            _buildBenefitItem(
                              'basic_price_analysis'.tr(),
                              false,
                            ),
                            _buildBenefitItem(
                              'smart_product_recommendation'.tr(),
                              false,
                            ),
                            _buildBenefitItem('shopping_list'.tr(), false),
                          ],
                          const SizedBox(height: 28),

                          // CTA Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _handleUpgradeOrContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: lightGreen,
                                foregroundColor: darkGreen,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: darkGreen,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      _isPro
                                          ? 'subscribe_pro'.tr()
                                          : 'continue_free'.tr(),
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
