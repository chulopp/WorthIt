import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/dialogs.dart';
import '../widgets/subscription_badge.dart';
import 'package:google_fonts/google_fonts.dart';
import 'about_screen.dart';
import 'account_details_screen.dart';
import 'budget_settings_screen.dart';
import 'contact_screen.dart';
import 'faq_screen.dart';
import 'privacy_screen.dart';
import 'subscription_screen.dart';
import 'terms_screen.dart';
import 'welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/snackbar_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isReminderOn = true;
  late bool isIndonesian;
  String _username = 'imameeee_if';

  @override
  void initState() {
    super.initState();
    _loadUsername();
    // Sync toggle with the actual active locale to prevent reset on re-enter
    isIndonesian = true; // will be corrected in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read the real active locale so the toggle is always in sync
    isIndonesian = context.locale.languageCode == 'id';
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'imameeee_if';
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'user_center'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / User Card
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountDetailsScreen()));
                _loadUsername();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFF304423),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          'IF',
                          style: GoogleFonts.bricolageGrotesque(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FALLAH IQBAL KUR...',
                            style: GoogleFonts.bricolageGrotesque(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@$_username',
                                  style: GoogleFonts.bricolageGrotesque(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const SubscriptionBadge(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 3D Upgrade to Pro Button
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 0),
                child: Stack(
                  children: [
                    // 3D bottom shadow layer
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const SizedBox(height: 20),
                    ),
                    // Main button layer
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF304423),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.bolt,
                            color: Color(0xFFC9E88A),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'upgrade_to_pro'.tr(),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFC9E88A),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFFC9E88A),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // GRUP 1: PENGATURAN BELANJA
            Text(
              'settings.shopping_settings'.tr(),
              style: GoogleFonts.bricolageGrotesque(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    Icons.account_balance_wallet_outlined,
                    'settings.budget'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BudgetSettingsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 52, color: Color(0xFFF1F5F9)),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFF1E293B),
                      size: 22,
                    ),
                    title: Text(
                      'settings.shopping_list_reminder'.tr(),
                      style: GoogleFonts.bricolageGrotesque(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Switch(
                      value: _isReminderOn,
                      onChanged: (val) {
                        setState(() {
                          _isReminderOn = val;
                        });
                        SnackbarHelper.showTopSnackbar(
                          context,
                          val ? 'reminder_activated_success'.tr() : 'reminder_deactivated'.tr(),
                        );
                      },
                      activeColor: const Color(0xFF304423),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // GRUP 2: PREFERENSI
            Text(
              'settings.preferences'.tr(),
              style: GoogleFonts.bricolageGrotesque(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.translate, color: textPrimary, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'language'.tr(), // top-level key, stays the same
                      style: GoogleFonts.bricolageGrotesque(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      final newIsIndonesian = !isIndonesian;
                      setState(() {
                        isIndonesian = newIsIndonesian;
                      });
                      if (newIsIndonesian) {
                        context.setLocale(const Locale('id', 'ID'));
                      } else {
                        context.setLocale(const Locale('en', 'US'));
                      }

                      final isEnglish = !newIsIndonesian;
                      final message = isEnglish
                          ? 'Language successfully changed to English'
                          : 'Bahasa berhasil diubah ke Indonesia';

                      SnackbarHelper.showTopSnackbar(
                        context,
                        message,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 30,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isIndonesian ? const Color(0xFF304423) : const Color(0xFFC9E88A),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: isIndonesian ? Alignment.centerLeft : Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                isIndonesian ? 'ID' : 'EN',
                                style: GoogleFonts.bricolageGrotesque(
                                  color: isIndonesian ? Colors.white : const Color(0xFF304423),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: isIndonesian ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // GRUP 3: LAINNYA
            Text(
              'settings.others'.tr(),
              style: GoogleFonts.bricolageGrotesque(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildGridItem(
                        'about_worthit'.tr(),
                        false,
                        iconWidget: SvgPicture.asset(
                          'assets/svg/ICON.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                            Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          );
                        },
                      ),
                      _buildGridItem(
                        'faq_menu'.tr(),
                        false,
                        icon: Icons.chat_bubble_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FaqScreen()),
                          );
                        },
                      ),
                      _buildGridItem(
                        'contact_us'.tr(),
                        false,
                        icon: Icons.headset_mic_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ContactScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildGridItem(
                        'terms_and_conditions'.tr(),
                        false,
                        icon: Icons.description_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TermsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildGridItem(
                        'privacy_menu'.tr(),
                        false,
                        icon: Icons.shield_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyScreen(),
                            ),
                          );
                        },
                      ),
                      _buildGridItem(
                        'logout_menu'.tr(),
                        true,
                        icon: Icons.logout,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                            ),
                            backgroundColor: Colors.white,
                            builder: (BuildContext context) {
                              return SafeArea(
                                top: false,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    16,
                                    24,
                                    24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 40,
                                          height: 4,
                                          margin: const EdgeInsets.only(
                                            bottom: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    SvgPicture.asset(
                                      'assets/svg/ILUSTRASI.svg',
                                      width: 180,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'logout_title'.tr(),
                                      style: GoogleFonts.bricolageGrotesque(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: const Color(0xFF1E293B),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'logout_desc'.tr(),
                                      style: GoogleFonts.bricolageGrotesque(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF304423,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              elevation: 0,
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              final prefs =
                                                  await SharedPreferences.getInstance();
                                              await prefs.setBool(
                                                'isLoggedIn',
                                                false,
                                              );
                                              if (!context.mounted) return;
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const WelcomePage(),
                                                ),
                                                (route) => false,
                                              );
                                            },
                                            child: Text(
                                              'btn_yes_logout'.tr(),
                                              style: GoogleFonts.bricolageGrotesque(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text(
                                              'btn_cancel'.tr(),
                                              style: GoogleFonts.bricolageGrotesque(
                                                color: const Color(
                                                  0xFF1E293B,
                                                ),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(icon, color: const Color(0xFF1E293B), size: 22),
      title: Text(
        title,
        style: GoogleFonts.bricolageGrotesque(
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
      onTap: onTap ?? () {},
    );
  }

  Widget _buildGridItem(
    String label,
    bool isLogout, {
    IconData? icon,
    Widget? iconWidget,
    VoidCallback? onTap,
  }) {
    final color = isLogout ? Colors.red : const Color(0xFF1E293B);
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget ?? Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
