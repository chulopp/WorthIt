import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dashboard_data.dart';
import '../config/product_categories.dart';
import 'decision_badge.dart';
import 'product_analysis_sheet.dart';

enum RecentActivitySubtitleMode {
  full,
  timestampOnly,
  categoryOnly,
  decisionBadgeOnly,
}

class RecentActivityCard extends StatelessWidget {
  final RecentActivity item;
  final Widget? trailing;
  final VoidCallback? onTap;
  final RecentActivitySubtitleMode subtitleMode;

  const RecentActivityCard({
    super.key,
    required this.item,
    this.trailing,
    this.onTap,
    this.subtitleMode = RecentActivitySubtitleMode.full,
  });

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
    if (n.contains('keripik') || n.contains('snack') || n.contains('chitato')) {
      return Icons.cookie;
    }
    if (n.contains('minyak')) return Icons.water_drop;
    if (n.contains('kopi')) return Icons.coffee;
    if (n.contains('beras')) return Icons.rice_bowl;
    return Icons.shopping_bag;
  }

  String _formattedDate(BuildContext context) {
    final parsedDate = DateTime.tryParse(item.date);
    if (parsedDate == null) return item.date;
    return DateFormat(
      'E, d MMM HH:mm',
      context.locale.toString(),
    ).format(parsedDate);
  }

  String _localizedCategory() {
    if (officialProductCategories.contains(item.category)) return item.category;
    switch (item.category) {
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
        return item.category;
    }
  }

  Widget _buildSubtitle(BuildContext context, String decisionCode) {
    switch (subtitleMode) {
      case RecentActivitySubtitleMode.timestampOnly:
        return Text(
          _formattedDate(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 13,
            color: Colors.grey,
          ),
        );
      case RecentActivitySubtitleMode.categoryOnly:
        return Text(
          _localizedCategory(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 13,
            color: Colors.grey,
          ),
        );
      case RecentActivitySubtitleMode.decisionBadgeOnly:
        return Align(
          alignment: Alignment.centerLeft,
          child: DecisionBadge(
            decisionCode: decisionCode,
            padding: kFinalDecisionBadgePadding,
            borderRadius: kFinalDecisionBadgeBorderRadius,
            fontSize: kFinalDecisionBadgeFontSize,
            letterSpacing: kFinalDecisionBadgeLetterSpacing,
          ),
        );
      case RecentActivitySubtitleMode.full:
        return Row(
          children: [
            DecisionBadge(
              decisionCode: decisionCode,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              borderRadius: 999,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_localizedCategory()} - ${_formattedDate(context)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        );
    }
  }

  void _showDetail(BuildContext context) {
    final decisionCode = decisionCodeFromColor(item.color);
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
  }

  @override
  Widget build(BuildContext context) {
    final decisionCode = decisionCodeFromColor(item.color);
    const textPrimary = Color(0xFF1E293B);

    return InkWell(
      onTap: onTap ?? () => _showDetail(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
              child: item.imageUrl == null || item.imageUrl!.isEmpty
                  ? _buildImagePlaceholder()
                  : Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
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
                  _buildSubtitle(context, decisionCode),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null)
              trailing!
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: Text(
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF94A3B8),
        size: 22,
      ),
    );
  }
}
