import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class SubscriptionBadge extends StatelessWidget {
  const SubscriptionBadge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService().isPro,
      builder: (context, isPro, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: isPro ? const Color(0xFF304423) : Colors.white,
            borderRadius: BorderRadius.circular(6.0),
            border: isPro
                ? null
                : Border.all(color: const Color(0xFFC9E88A), width: 1.5),
          ),
          child: Text(
            isPro ? 'PRO' : 'FREE',
            style: GoogleFonts.outfit(
              color: const Color(0xFFC9E88A),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        );
      },
    );
  }
}
