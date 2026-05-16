import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textPrimary = Color(0xFF1E293B);
    const Color bgScaffold = Color(0xFFF8F9FA);

    final List<Map<String, String>> sections = [
      {
        'title': 'terms.s1_title'.tr(),
        'body': 'terms.s1_body'.tr(),
      },
      {
        'title': 'terms.s2_title'.tr(),
        'body': 'terms.s2_body'.tr(),
      },
      {
        'title': 'terms.s3_title'.tr(),
        'body': 'terms.s3_body'.tr(),
      },
      {
        'title': 'terms.s4_title'.tr(),
        'body': 'terms.s4_body'.tr(),
      },
    ];

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
          'terms.app_bar_title'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul di body
            Text(
              'terms.page_title'.tr(),
              style: GoogleFonts.bricolageGrotesque(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'terms.last_updated'.tr(),
              style: GoogleFonts.bricolageGrotesque(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),

            // Card konten
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(sections.length, (index) {
                  final section = sections[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < sections.length - 1 ? 24 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section['title']!,
                          style: GoogleFonts.bricolageGrotesque(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section['body']!,
                          style: GoogleFonts.bricolageGrotesque(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        if (index < sections.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
