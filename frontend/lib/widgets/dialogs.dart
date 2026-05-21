import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

// ── Brand Colors ─────────────────────────────────────────────────────────────
const Color _darkGreen = Color(0xFF304423);
const Color _accentGreen = Color(0xFFC9E88A);

// ═════════════════════════════════════════════════════════════════════════════
//  LOGOUT DIALOG
// ═════════════════════════════════════════════════════════════════════════════

/// Shows a confirmation dialog before the user logs out.
///
/// Returns `true` when the user confirms logout, `null` / `false` otherwise.
Future<bool?> showLogoutDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
        actionsPadding: const EdgeInsets.fromLTRB(28, 0, 28, 24),

        // ── Icon ────────────────────────────────────────────────────────
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🚪', style: TextStyle(fontSize: 32)),
          ),
        ),

        // ── Title ───────────────────────────────────────────────────────
        title: Text(
          'auth.logout_title'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),

        // ── Content ─────────────────────────────────────────────────────
        content: Text(
          'auth.logout_message'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.grey.shade600,
            fontSize: 15,
            height: 1.5,
          ),
        ),

        // ── Actions ─────────────────────────────────────────────────────
        actions: [
          Row(
            children: [
              // Cancel
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _darkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'auth.cancel'.tr(),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Confirm logout
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'auth.yes_logout'.tr(),
                      style: GoogleFonts.outfit(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  DELETE ACCOUNT DIALOG
// ═════════════════════════════════════════════════════════════════════════════

/// Shows a destructive‑action confirmation dialog for permanent account
/// deletion.
///
/// Returns `true` when the user confirms deletion, `null` / `false` otherwise.
Future<bool?> showDeleteAccountDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
        actionsPadding: const EdgeInsets.fromLTRB(28, 8, 28, 24),

        // ── Title Row (Warning icon + text) ─────────────────────────────
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'delete_account_title'.tr(),
                style: GoogleFonts.outfit(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ),
          ],
        ),

        // ── Content ─────────────────────────────────────────────────────
        content: Text(
          'delete_account_desc'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.grey.shade700,
            fontSize: 14,
            height: 1.55,
          ),
        ),

        // ── Actions (stacked vertically) ────────────────────────────────
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cancel (primary safe action)
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'btn_cancel_go_back'.tr(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Confirm deletion (destructive action)
              SizedBox(
                height: 50,
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'btn_yes_delete'.tr(),
                    style: GoogleFonts.outfit(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
