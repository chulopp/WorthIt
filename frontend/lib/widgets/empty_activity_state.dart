import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyActivityState extends StatelessWidget {
  const EmptyActivityState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFEDF2F7),
                shape: BoxShape.circle,
              ),
              child: const FittedBox(
                fit: BoxFit.contain,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 32,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'empty_activity_title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'empty_activity_desc'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
