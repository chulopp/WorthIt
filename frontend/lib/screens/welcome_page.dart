import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'custom_splash_screen.dart';
import '../services/auth_service.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  static const Color _darkGreen = Color(0xFF304423);
  static const Color _accentGreen = Color(0xFFC9E88A);

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    return ValueListenableBuilder<bool>(
      valueListenable: AuthService().isLoggedIn,
      builder: (context, isLoggedIn, _) {
        if (isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomSplashScreen(),
              ),
            );
          });
        }

        return Scaffold(
          backgroundColor: _darkGreen,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 44),

                  // ── Logo (Diturunkan) ─────────────────────────
                  SvgPicture.asset(
                    'assets/svg/FULL LOGO.svg',
                    width: 150,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 28),

                  // ── SVG Illustration ──────────────────────────────────
                  SvgPicture.asset(
                    'assets/svg/ICONLANDINGPAGE.svg',
                    width: 210,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 32),

                  // ── Headline (Outfit Sans-Serif Bold) ─────────────────
                  Text(
                    'Tau harga wajar,\nsebelum bayar',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Subtitle (Teks Revisi) ─────────────────────────────
                  Text(
                    'Scan label harga, lihat trennya,\nputuskan tanpa tebak-tebakan.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                    ),
                  ),

                  const Spacer(),

                  // ── Google Sign-In Button (Solid Lime Green) ───────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                await AuthService().nativeGoogleSignIn();
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        foregroundColor: _darkGreen,
                        disabledBackgroundColor: _accentGreen.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: _darkGreen,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/google_logo.png',
                                  height: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Masuk dengan Google',
                                  style: GoogleFonts.outfit(
                                    color: _darkGreen,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Guest Explore (Posisi Dinaikkan) ──────────────────
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const CustomSplashScreen(isGuest: true),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      overlayColor: Colors.white12,
                    ),
                    child: Text(
                      'Saya mau jelajahi dulu',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
