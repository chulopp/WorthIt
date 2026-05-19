import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  static const Color _bgDark = Color(0xFF304423);
  static const Color _worthItGreen = Color(0xFFC9E88A);
  static const Color _greenLight = Color(0xFFC9E88A);
  static const Color _textPrimary = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: CustomScrollView(
        slivers: [
          // ── APPBAR ──
          SliverAppBar(
            backgroundColor: _bgDark,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: SvgPicture.asset('assets/svg/FULL LOGO.svg', height: 28),
            centerTitle: true,
          ),

          // ── BODY ──
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════════════════════════════
                // SECTION 1: INTRO
                // ═══════════════════════════════
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'about.title'.tr().replaceAll('\n', ' '),
                    style: GoogleFonts.bricolageGrotesque(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      height: 1.15,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.bricolageGrotesque(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      children: _buildInlineLogoSpans('about.intro'.tr(), 14),
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
                const SizedBox(height: 24),

                // Hero image
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      'https://images.pexels.com/photos/5319558/pexels-photo-5319558.jpeg',
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _worthItGreen,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 48,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ═══════════════════════════════
                // SECTION 2: VISI & MISI (White Card)
                // ═══════════════════════════════
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'about.vision_mission_title'.tr(),
                        style: GoogleFonts.bricolageGrotesque(
                          color: _bgDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'about.vision_mission_body'.tr(),
                        textAlign: TextAlign.justify,
                        style: GoogleFonts.bricolageGrotesque(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          'https://images.pexels.com/photos/37234075/pexels-photo-37234075.jpeg',
                          fit: BoxFit.cover,
                          height: 220,
                          width: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: _worthItGreen,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Colors.grey.shade400,
                                  size: 48,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════
                // SECTION 3: KENAPA NAMANYA WORTHIT? (Dark)
                // ═══════════════════════════════
                Container(
                  width: double.infinity,
                  color: _bgDark,
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'about.why_worthit_title_prefix'.tr(),
                              style: GoogleFonts.bricolageGrotesque(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                                height: 1.25,
                              ),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: SvgPicture.asset(
                                'assets/svg/TEKS.svg',
                                height: 32 * 0.8,
                              ),
                            ),
                            TextSpan(
                              text: '?',
                              style: GoogleFonts.bricolageGrotesque(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.bricolageGrotesque(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            height: 1.5,
                          ),
                          children: _buildInlineLogoSpans(
                            'about.why_worthit_body'.tr(),
                            14,
                          ),
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 24),

                      // Accent quote card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _worthItGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border(
                            left: BorderSide(color: _worthItGreen, width: 3),
                          ),
                        ),
                        child: Text(
                          'about.quote'.tr(),
                          textAlign: TextAlign.justify,
                          style: GoogleFonts.bricolageGrotesque(
                            color: _greenLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════
                // SECTION 4: TIM WORTHIT (White Card)
                // ═══════════════════════════════
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: SvgPicture.asset(
                                'assets/svg/TEKS.svg',
                                height: 32 * 0.8,
                              ),
                            ),
                            TextSpan(
                              text: ' Team',
                              style: GoogleFonts.bricolageGrotesque(
                                color: _bgDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'about.team_subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bricolageGrotesque(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Team grid — equal columns, names align from top (photos line up)
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTeamMember(
                                svgPath: 'assets/svg/WENDI.svg',
                                name: 'Wendi Adi Ardiansyah',
                                role: 'Co-Founder & COO',
                              ),
                            ),
                            Expanded(
                              child: _buildTeamMember(
                                svgPath: 'assets/svg/FALLAH.svg',
                                name: 'Fallah Iqbal Kurnianto',
                                role: 'Founder & CEO',
                              ),
                            ),
                            Expanded(
                              child: _buildTeamMember(
                                svgPath: 'assets/svg/JOVAN.svg',
                                name: 'Jovan Amadeo Hutaluhung',
                                role: 'Co-Founder & CTO',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════
                // SECTION 5: CTA & FOOTER (Dark)
                // ═══════════════════════════════
                Container(
                  width: double.infinity,
                  color: _bgDark,
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
                  child: Column(
                    children: [
                      SvgPicture.asset('assets/svg/FULL LOGO.svg', width: 140),
                      const SizedBox(height: 16),
                      Text(
                        'about.cta_tagline'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bricolageGrotesque(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'about.cta_subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bricolageGrotesque(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Store button (Google Play only)
                      InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/google_play.png',
                          height: 50,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Divider
                      Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                      const SizedBox(height: 20),

                      // Copyright
                      Text(
                        'about.copyright'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bricolageGrotesque(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPER: Stat Pill ──
  Widget _buildStatPill(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _worthItGreen.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.bricolageGrotesque(
                color: _bgDark,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPER: Team Member ──
  Widget _buildTeamMember({
    required String svgPath,
    required String name,
    required String role,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF3F4F6),
          ),
          clipBehavior: Clip.antiAlias,
          child: SvgPicture.asset(svgPath, fit: BoxFit.cover),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          textAlign: TextAlign.center,
          softWrap: true,
          style: GoogleFonts.bricolageGrotesque(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          role,
          textAlign: TextAlign.center,
          softWrap: true,
          style: GoogleFonts.bricolageGrotesque(
            color: Colors.grey.shade500,
            fontSize: 12,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  // ── HELPER: Inline Logo Spans ──
  List<InlineSpan> _buildInlineLogoSpans(String text, double logoHeight) {
    final parts = text.split('WorthIt');
    if (parts.length == 1) {
      return [TextSpan(text: text)];
    }

    final spans = <InlineSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i]));
      }
      if (i < parts.length - 1) {
        final needsLeadingSpace = _needsInlineLeadingSpace(parts[i]);
        final needsTrailingSpace = _needsInlineTrailingSpace(parts[i + 1]);
        if (needsLeadingSpace) {
          spans.add(const TextSpan(text: ' '));
        }
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SvgPicture.asset(
              'assets/svg/TEKS.svg',
              height: logoHeight * 0.76,
            ),
          ),
        );
        if (needsTrailingSpace) {
          spans.add(const TextSpan(text: ' '));
        }
      }
    }
    return spans;
  }

  bool _needsInlineLeadingSpace(String text) {
    return text.isNotEmpty && !RegExp(r'\s$').hasMatch(text);
  }

  bool _needsInlineTrailingSpace(String text) {
    return text.isNotEmpty && !RegExp(r'^\s').hasMatch(text);
  }

  // ── HELPER: Social Icon ──
  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
    );
  }
}
