import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/snackbar_helper.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({Key? key}) : super(key: key);

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support.worthit.id@gmail.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Bantuan Support WorthIt',
      }),
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(
        emailLaunchUri,
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    if (!context.mounted) return;
    _showLaunchError(context);
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    final Uri webWhatsAppUri = Uri.parse('https://wa.me/6285865604599');

    if (await canLaunchUrl(webWhatsAppUri)) {
      await launchUrl(
        webWhatsAppUri,
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    if (!context.mounted) return;
    _showLaunchError(context);
  }

  void _showLaunchError(BuildContext context) {
    SnackbarHelper.showTopSnackbar(
      context,
      'launch_target_unavailable'.tr(),
      icon: Icons.warning_amber_rounded,
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    const Color textPrimary = Color(0xFF1E293B);
    const Color worthItGreen = Color(0xFFC9E88A);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: worthItGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: worthItGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.bricolageGrotesque(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.bricolageGrotesque(
                              color: Colors.grey.shade500,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color textPrimary = Color(0xFF1E293B);
    const Color worthItGreen = Color(0xFFC9E88A);
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
          'contact.title'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Deskripsi
          Text(
            'contact.description'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.grey.shade600,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Card 1 — Email Support
          _buildContactTile(
            icon: Icons.mail_outline_rounded,
            title: 'contact.email_support'.tr(),
            value: 'support.worthit.id@gmail.com',
            onTap: () => _launchEmail(context),
          ),

          const SizedBox(height: 12),

          // Card 2 — WhatsApp Official
          _buildContactTile(
            icon: Icons.chat_outlined,
            title: 'contact.whatsapp_official'.tr(),
            value: '+6285865604599',
            onTap: () => _launchWhatsApp(context),
          ),

          const SizedBox(height: 32),

          // Jam Operasional
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: worthItGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: worthItGreen.withValues(alpha: 0.7),
                  size: 28,
                ),
                const SizedBox(height: 10),
                Text(
                  'contact.operating_hours'.tr(),
                  style: GoogleFonts.bricolageGrotesque(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'contact.operating_hours_detail'.tr(),
                  style: GoogleFonts.bricolageGrotesque(
                    color: Colors.grey.shade600,
                    fontSize: 13,
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
