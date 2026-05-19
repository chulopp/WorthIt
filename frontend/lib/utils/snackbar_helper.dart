import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/top_notification.dart';

class SnackbarHelper {
  /// Munculkan notifikasi snackbar dari atas dengan styling standar WorthIt.
  static void showTopSnackbar(
    BuildContext context,
    String message, {
    bool isDarkContext = false,
    Color? backgroundColor,
    Color? textColor,
    Color? iconColor,
    IconData icon = Icons.check_circle_rounded,
  }) {
    final resolvedBackgroundColor =
        backgroundColor ?? const Color(0xFFC9E88A);
    final resolvedForegroundColor = textColor ?? const Color(0xFF304423);

    TopNotification.show(
      context: context,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: resolvedBackgroundColor,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: resolvedBackgroundColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor ?? resolvedForegroundColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: GoogleFonts.bricolageGrotesque(
                  color: resolvedForegroundColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
