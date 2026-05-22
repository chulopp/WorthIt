import 'dart:ui';
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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.of(context).padding.top;

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
          extendBodyBehindAppBar: true,
          backgroundColor: const Color(0xFF151E0E),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 1: Base Image (Tajam) ────────────────────────────────
              Positioned.fill(
                child: Image.asset(
                  'assets/images/welcome_bg_v.jpg',
                  fit: BoxFit.cover,
                ),
              ),

              // ── Layer 2: Blurred Image Mask (Double Image Masking) ─────────
              // Teknik: load gambar yg sama lagi, blur via ImageFiltered,
              // lalu masking gradient sehingga hanya bagian bawah yg blur.
              // Ini 100% muncul karena tidak bergantung pada BackdropFilter.
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0.45, 0.75],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                    child: Image.asset(
                      'assets/images/welcome_bg_v.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // ── Layer 3: Dark Tint (Untuk kontras teks) ────────────────────
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xFF304423).withValues(
                          alpha: 0.6,
                        ), // Transisi halus di bagian tengah-atas
                        Color(0xFF304423).withValues(
                          alpha: 0.95,
                        ), // Sangat pekat di belakang teks
                        Color(
                          0xFF304423,
                        ), // 100% Solid Hijau Gelap di area tombol
                      ],
                      stops: const [0.35, 0.55, 0.75, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Layer 4: Logo (Pas di atas kepala model) ───────────────────
              Positioned(
                top: paddingTop,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SvgPicture.asset(
                    'assets/svg/FULL LOGO.svg',
                    width: 170,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // ── Layer 5: Konten Bawah (Teks & Button) ─────────────────────
              Positioned(
                bottom: 70, // Dinaikkan agar lebih dekat ke focal point
                left: 24,
                right: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Headline
                    Text(
                      'smart_shopping'.tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFC9E88A),
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'welcome_subtitle'.tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Mini Feature Badges
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.qr_code_scanner,
                              size: 16,
                              color: Color(0xFFC9E88A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'scan_label'.tr(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          ' • ',
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.analytics_outlined,
                              size: 16,
                              color: Color(0xFFC9E88A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ai_analysis'.tr(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          ' • ',
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.savings_outlined,
                              size: 16,
                              color: Color(0xFFC9E88A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'save_more'.tr(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Tombol Mulai
                    ElevatedButton.icon(
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
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF304423),
                                strokeWidth: 2.5,
                              ),
                            )
                          : Image.asset(
                              'assets/images/google_logo.png',
                              height: 24,
                            ),
                      label: _isLoading
                          ? const SizedBox.shrink()
                          : Text(
                              'login_register'.tr(),
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF304423),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC9E88A),
                        disabledBackgroundColor: const Color(
                          0xFFC9E88A,
                        ).withOpacity(0.6),
                        minimumSize: const Size(double.infinity, 56),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Teks Guest
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
                      child: Text(
                        'explore_first'.tr(),
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFC9E88A),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
