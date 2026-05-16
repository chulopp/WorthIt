import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const String kDecisionBuy = 'BUY';
const String kDecisionSubstitute = 'SUBSTITUTE';
const String kDecisionDontBuy = 'DONT_BUY';

const EdgeInsetsGeometry kFinalDecisionBadgePadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 8,
);
const double kFinalDecisionBadgeBorderRadius = 10;
const double kFinalDecisionBadgeFontSize = 13;
const double kFinalDecisionBadgeLetterSpacing = 0.8;

class DecisionBadgePalette {
  final Color backgroundColor;
  final Color textColor;

  const DecisionBadgePalette({
    required this.backgroundColor,
    required this.textColor,
  });
}

const Map<String, String> kDecisionLabelsId = {
  kDecisionBuy: 'status_worthit',
  kDecisionSubstitute: 'status_warning',
  kDecisionDontBuy: 'status_expensive',
};

const Map<String, String> kDecisionLabelsEn = {
  kDecisionBuy: 'status_worthit',
  kDecisionSubstitute: 'status_warning',
  kDecisionDontBuy: 'status_expensive',
};

const Map<String, DecisionBadgePalette> kDecisionBadgePalettes = {
  kDecisionBuy: DecisionBadgePalette(
    backgroundColor: Color(0xFF304423),
    textColor: Color(0xFFC9E88A),
  ),
  kDecisionSubstitute: DecisionBadgePalette(
    backgroundColor: Color(0xFFFFC107),
    textColor: Color(0xFFB45309),
  ),
  kDecisionDontBuy: DecisionBadgePalette(
    backgroundColor: Color(0xFFB91C1C),
    textColor: Color(0xFFFFFFFF),
  ),
};

String decisionCodeFromColor(String? color) {
  switch (color?.toLowerCase()) {
    case 'green':
      return kDecisionBuy;
    case 'yellow':
      return kDecisionSubstitute;
    case 'red':
      return kDecisionDontBuy;
    default:
      return kDecisionSubstitute;
  }
}

String decisionCodeFromScore(int score) {
  if (score >= 80) return kDecisionBuy;
  if (score >= 60) return kDecisionSubstitute;
  return kDecisionDontBuy;
}

String? normalizeDecisionCode(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;

  switch (raw.trim().toUpperCase()) {
    case kDecisionBuy:
    case 'WORTHIT':
    case 'WORTH IT':
    case 'HARGA WAJAR':
      return kDecisionBuy;
    case kDecisionSubstitute:
    case 'WARNING':
    case 'WASPADA':
      return kDecisionSubstitute;
    case kDecisionDontBuy:
    case 'EXPENSIVE':
    case 'MAHAL':
    case 'LEBIH MAHAL':
    case 'MORE EXPENSIVE':
      return kDecisionDontBuy;
    default:
      return null;
  }
}

String resolveDecisionCode({String? decisionCode, String? color, int? score}) {
  return normalizeDecisionCode(decisionCode) ??
      (color != null ? decisionCodeFromColor(color) : null) ??
      decisionCodeFromScore(score ?? 0);
}

DecisionBadgePalette decisionBadgePalette(String decisionCode) {
  final code = resolveDecisionCode(decisionCode: decisionCode);
  return kDecisionBadgePalettes[code] ??
      kDecisionBadgePalettes[kDecisionSubstitute]!;
}

String localizedDecisionBadgeLabel(BuildContext context, String decisionCode) {
  final code = resolveDecisionCode(decisionCode: decisionCode);
  final labels = context.locale.languageCode.toLowerCase() == 'id'
      ? kDecisionLabelsId
      : kDecisionLabelsEn;
  return (labels[code] ?? code).tr();
}

class DecisionBadge extends StatelessWidget {
  final String decisionCode;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;

  const DecisionBadge({
    super.key,
    required this.decisionCode,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.borderRadius = 999,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w800,
    this.letterSpacing = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    final palette = decisionBadgePalette(decisionCode);
    final label = localizedDecisionBadgeLabel(context, decisionCode);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          color: palette.textColor,
          height: 1,
        ),
      ),
    );
  }
}
