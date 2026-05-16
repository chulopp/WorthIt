import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color textPrimary = Color(0xFF1E293B);
    const Color bgScaffold = Color(0xFFF8F9FA);

    final List<Map<String, String>> faqList = [
      {
        'question': 'faq.q1'.tr(),
        'answer': 'faq.a1'.tr(),
      },
      {
        'question': 'faq.q2'.tr(),
        'answer': 'faq.a2'.tr(),
      },
      {
        'question': 'faq.q3'.tr(),
        'answer': 'faq.a3'.tr(),
      },
      {
        'question': 'faq.q4'.tr(),
        'answer': 'faq.a4'.tr(),
      },
      {
        'question': 'faq.q5'.tr(),
        'answer': 'faq.a5'.tr(),
      },
      {
        'question': 'faq.q6'.tr(),
        'answer': 'faq.a6'.tr(),
      },
      {
        'question': 'faq.q7'.tr(),
        'answer': 'faq.a7'.tr(),
      },
      {
        'question': 'faq.q8'.tr(),
        'answer': 'faq.a8'.tr(),
      },
      {
        'question': 'faq_q_record_activity'.tr(),
        'answer': 'faq_a_record_activity'.tr(),
      },
      {
        'question': 'faq_q_export_pdf'.tr(),
        'answer': 'faq_a_export_pdf'.tr(),
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
          'faq.title'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqList.length,
        itemBuilder: (context, index) {
          final faq = faqList[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
            clipBehavior: Clip.antiAlias,
            child: Theme(
              // Hilangkan divider bawaan ExpansionTile
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                collapsedShape:
                    const RoundedRectangleBorder(side: BorderSide.none),
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                childrenPadding:
                    const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                iconColor: Colors.grey.shade500,
                collapsedIconColor: Colors.grey.shade400,
                title: Text(
                  faq['question']!,
                  style: GoogleFonts.bricolageGrotesque(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                children: [
                  Text(
                    faq['answer']!,
                    style: GoogleFonts.bricolageGrotesque(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
