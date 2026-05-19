import 'package:flutter/material.dart';
import '../widgets/dialogs.dart';
import '../widgets/subscription_badge.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/snackbar_helper.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';
import 'welcome_page.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({Key? key}) : super(key: key);

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  String _username = 'imameeee_if';

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'imameeee_if';
    });
  }

  void _showEditUsernameDialog() {
    final TextEditingController editController = TextEditingController(text: _username);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'account.edit_username_title'.tr(),
            style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: TextField(
              controller: editController,
              decoration: InputDecoration(
                hintText: 'account.edit_username_hint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF304423), width: 2),
                ),
              ),
              style: GoogleFonts.bricolageGrotesque(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'auth.cancel'.tr(),
                style: GoogleFonts.bricolageGrotesque(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('username', editController.text);
                if (!mounted) return;
                setState(() {
                  _username = editController.text;
                });
                Navigator.pop(context);

                SnackbarHelper.showTopSnackbar(
                  context,
                  'account.username_changed_success'.tr(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF304423),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                'account.save'.tr(),
                style: GoogleFonts.bricolageGrotesque(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color textPrimary = Color(0xFF1E293B);
    final auth = AuthService();
    final displayName = auth.displayName ?? 'Pengguna WorthIt';
    final email = auth.currentUser?.email ?? '-';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'account.title'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Avatar
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFF304423),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    auth.initials,
                    style: GoogleFonts.bricolageGrotesque(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Name
            Text(
              displayName,
              style: GoogleFonts.bricolageGrotesque(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const SubscriptionBadge(),
            const SizedBox(height: 40),

            // Info Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      'account.username'.tr(),
                      style: GoogleFonts.bricolageGrotesque(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        _username,
                        style: GoogleFonts.bricolageGrotesque(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, color: textPrimary, size: 20),
                      onPressed: _showEditUsernameDialog,
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'account.email'.tr(),
                      style: GoogleFonts.bricolageGrotesque(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        email,
                        style: GoogleFonts.bricolageGrotesque(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Delete Account Button
            TextButton(
              onPressed: () async {
                final confirm = await showDeleteAccountDialog(context);
                if (confirm == true) {
                  final result = await AuthRepository().deleteAccount();
                  if (result.isFailure) {
                    if (!context.mounted) return;
                    SnackbarHelper.showTopSnackbar(
                      context,
                      result.error?.message ?? 'Gagal menghapus akun.',
                      icon: Icons.warning_amber_rounded,
                    );
                    return;
                  }
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', false);
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const WelcomePage()),
                    (route) => false,
                  );
                }
              },
              child: Text(
                'account.delete_account'.tr(),
                style: GoogleFonts.bricolageGrotesque(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
