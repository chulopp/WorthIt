import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../controllers/analyze_controller.dart';
import '../models/product_analysis.dart';

void showDecisionBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DecisionSheet(),
  );
}

class _DecisionSheet extends ConsumerWidget {
  const _DecisionSheet();

  Color _statusColor(String c) => switch (c) {
        'green' => const Color(0xFF22C55E),
        'red' => const Color(0xFFEF4444),
        _ => const Color(0xFFFBBF24),
      };

  String _statusLabel(BuildContext context, String d) => switch (d) {
        'BUY' => 'decision_sheet.status_worth_it'.tr(),
        'DONT_BUY' => 'decision_sheet.status_not_worth_it'.tr(),
        _ => 'decision_sheet.status_substitute'.tr(),
      };

  IconData _statusIcon(String d) => switch (d) {
        'BUY' => Icons.check_circle_rounded,
        'DONT_BUY' => Icons.cancel_rounded,
        _ => Icons.swap_horiz_rounded,
      };

  ProductAnalysis _analysisFromState(WidgetRef ref) {
    final analysis = ref.watch(analyzeControllerProvider).data;
    if (analysis == null) {
      return ProductAnalysis(
        decision: 'DONT_BUY',
        color: 'red',
        score: 0,
        insights: const <String>[],
        reasoning: 'Belum ada hasil analisis dari backend.',
      );
    }

    final decision = analysis.score >= 70
        ? 'BUY'
        : analysis.score >= 40
        ? 'SUBSTITUTE'
        : 'DONT_BUY';
    final color = decision == 'BUY'
        ? 'green'
        : decision == 'SUBSTITUTE'
        ? 'yellow'
        : 'red';
    return ProductAnalysis(
      decision: decision,
      color: color,
      score: analysis.score,
      insights: analysis.explanations,
      reasoning: analysis.explanations.isEmpty
          ? analysis.decision
          : analysis.explanations.join('\n'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = _analysisFromState(ref);
    final color = _statusColor(a.color);
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: maxH,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF172533),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        // Column + Expanded need a definite height (SizedBox above).
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _badge(context, a, color),
                    const SizedBox(height: 20),
                    _gauge(a, color),
                    const SizedBox(height: 24),
                    _insights(a),
                    const SizedBox(height: 16),
                    _reasoning(a),
                    if (a.substitution != null && a.color != 'green') ...[
                      const SizedBox(height: 16),
                      _subCard(a.substitution!),
                    ],
                    const SizedBox(height: 24),
                    _actions(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, ProductAnalysis a, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(40), border: Border.all(color: c.withValues(alpha: 0.4))),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Icon(_statusIcon(a.decision), color: c, size: 22),
            Text(
              _statusLabel(context, a.decision),
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: c, letterSpacing: 1.2),
              softWrap: true,
            ),
          ],
        ),
      );

  Widget _gauge(ProductAnalysis a, Color c) => Container(
        width: 120, height: 120,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withValues(alpha: 0.25), Colors.transparent], radius: 0.85), border: Border.all(color: c.withValues(alpha: 0.5), width: 3)),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${a.score}', style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.w800, color: c, height: 1)),
          Text('/ 100', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54)),
        ]),
      );

  Widget _insights(ProductAnalysis a) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('decision_sheet.insights'.tr(), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 8),
        ...a.insights.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Text(
                      t,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ]);

  Widget _reasoning(ProductAnalysis a) => Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('decision_sheet.reasoning'.tr(), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70), softWrap: true),
            ),
          ]),
          const SizedBox(height: 8),
          Text(a.reasoning, style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white70, height: 1.55)),
        ]),
      );

  Widget _subCard(Substitution s) {
    const ac = Color(0xFF38BDF8);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [ac.withValues(alpha: 0.12), ac.withValues(alpha: 0.04)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: ac.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.swap_horiz_rounded, color: ac, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('decision_sheet.substitute_suggestion'.tr(), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: ac), softWrap: true),
          ),
        ]),
        const SizedBox(height: 12),
        _r('decision_sheet.product'.tr(), s.productName),
        _r('decision_sheet.price'.tr(), 'Rp${s.price.toStringAsFixed(0)}'),
        _r('decision_sheet.weight'.tr(), '${s.weightGram.toStringAsFixed(0)}g'),
        _r('decision_sheet.price_per_gram'.tr(), 'Rp${s.pricePerGram.toStringAsFixed(2)}/g'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '💰 Save ${s.savingsPercent.toStringAsFixed(1)}%',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF22C55E),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _r(String l, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l,
                style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white54),
                softWrap: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                v,
                textAlign: TextAlign.end,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                softWrap: true,
              ),
            ),
          ],
        ),
      );

  Widget _actions(BuildContext ctx) => Row(children: [
        Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
          child: Text('decision_sheet.add_to_cart'.tr(), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444), width: 1.5), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text('decision_sheet.cancel'.tr(), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)))),
      ]);
}
