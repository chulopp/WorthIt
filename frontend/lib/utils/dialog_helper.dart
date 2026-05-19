import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../screens/dashboard_screen.dart';
import '../services/auth_service.dart';

/// Shows a standardized Guest Login Bottom Sheet.
///
/// [featureName] is the human-readable name of the locked feature, e.g.
/// "Daftar Belanja", "Riwayat", "Scan Barcode".
///
/// On login success the navigation stack is reset and the user is routed
/// back to the main dashboard.
void showGuestLoginBottomSheet(BuildContext context, String featureName) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return _GuestLoginSheet(featureName: featureName);
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  GUARD ACTION
// ─────────────────────────────────────────────────────────────────────────────

/// Checks if the user is logged in.
/// - If **logged in**: executes [protectedAction] immediately.
/// - If **guest**: shows [showGuestLoginBottomSheet] and routes the user
///   back to the dashboard after a successful login.
///
/// [featureName] is shown in the sheet subtitle, e.g. "Scan Barcode".
void guardAction(
  BuildContext context,
  VoidCallback protectedAction, {
  String featureName = 'fitur ini',
}) {
  if (AuthService().isLoggedIn.value) {
    protectedAction();
    return;
  }
  showGuestLoginBottomSheet(context, featureName);
}

// ── Private Sheet Widget ──────────────────────────────────────────────────────

class _GuestLoginSheet extends StatelessWidget {
  final String featureName;

  const _GuestLoginSheet({required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ───────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Icon ──────────────────────────────────────────────────────
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF304423).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF304423),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Title ─────────────────────────────────────────────────────
          Text(
            'login_required_title'.tr(),
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),

          // ── Subtitle ─────────────────────────────────────────────────
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.6,
              ),
              children: [
                TextSpan(text: 'login_required_desc'.tr()),
                TextSpan(
                  text: featureName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF304423),
                  ),
                ),
                TextSpan(text: 'login_required_desc_suffix'.tr()),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Google Login Button ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await AuthService().nativeGoogleSignIn();
                  if (!context.mounted || !AuthService().isLoggedIn.value) {
                    return;
                  }
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DashboardScreen(),
                    ),
                    (route) => false,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              icon: Image.asset('assets/images/google_logo.png', height: 24),
              label: Text(
                'login_with_google'.tr(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF304423),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Dismiss ───────────────────────────────────────────────────
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'later'.tr(),
              style: GoogleFonts.outfit(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
