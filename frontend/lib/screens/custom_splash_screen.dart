import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'welcome_page.dart';

/// Premium Custom Splash Screen with animated blurred glowing blobs.
///
/// Checks Supabase auth after the animation and routes to the right entry page.
class CustomSplashScreen extends StatefulWidget {
  final bool isGuest;
  const CustomSplashScreen({Key? key, this.isGuest = false}) : super(key: key);

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with TickerProviderStateMixin {
  // ── Color Scheme ──────────────────────────────────────────────────────
  static const Color _darkGreen = Color(0xFF304423);
  static const Color _accentGreen = Color(0xFFC9E88A);

  // ── Animation Controllers ─────────────────────────────────────────────
  late final List<AnimationController> _controllers;
  late final List<Animation<Offset>> _positions;

  // Blob definitions: color, size, initial offset, target offset
  final List<_BlobDef> _blobs = [
    _BlobDef(
      color: _accentGreen.withValues(alpha: 0.08),
      size: 350,
      begin: const Offset(-0.3, -0.4),
      end: const Offset(0.2, -0.1),
      duration: const Duration(seconds: 10),
    ),
    _BlobDef(
      color: _accentGreen.withValues(alpha: 0.05),
      size: 400,
      begin: const Offset(0.4, 0.3),
      end: const Offset(-0.1, 0.1),
      duration: const Duration(seconds: 9),
    ),
    _BlobDef(
      color: _accentGreen.withValues(alpha: 0.06),
      size: 320,
      begin: const Offset(0.3, -0.2),
      end: const Offset(-0.3, 0.3),
      duration: const Duration(seconds: 8),
    ),
  ];

  // ── Logo fade-in ──────────────────────────────────────────────────────
  late final AnimationController _logoController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    // TUGAS 2: HAPUS PRESERVE NATIVE SPLASH
    // Pastikan native splash dihapus agar UI Flutter digambarkan sepenuhnya.
    FlutterNativeSplash.remove();

    if (widget.isGuest) {
      AuthService().loginAsGuest();
    } else {
      AuthService().refreshAuthState();
    }

    // Initialize blob animation controllers
    _controllers = [];
    _positions = [];

    for (final blob in _blobs) {
      final controller = AnimationController(
        vsync: this,
        duration: blob.duration,
      );

      final position = Tween<Offset>(
        begin: blob.begin,
        end: blob.end,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

      _controllers.add(controller);
      _positions.add(position);

      controller.repeat(reverse: true);
    }

    // Logo entrance animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
      ),
    );

    // Start logo animation after a tiny delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _logoController.forward();
    });

    // Keep the animation visible briefly, then make the auth decision from
    // Supabase currentUser. Only the explicit guest CTA may continue without it.
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) {
              if (widget.isGuest) return const DashboardScreen();
              return currentUser == null
                  ? const WelcomePage()
                  : const DashboardScreen();
            },
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _darkGreen,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Animated Blobs Layer ─────────────────────────────────────
          ...List.generate(_blobs.length, (index) {
            return AnimatedBuilder(
              animation: _positions[index],
              builder: (context, child) {
                final offset = _positions[index].value;
                return Positioned(
                  left:
                      size.width / 2 +
                      offset.dx * size.width -
                      _blobs[index].size / 2,
                  top:
                      size.height / 2 +
                      offset.dy * size.height -
                      _blobs[index].size / 2,
                  child: child!,
                );
              },
              child: Container(
                width: _blobs[index].size,
                height: _blobs[index].size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _blobs[index].color,
                ),
              ),
            );
          }),

          // ── Blur Filter (makes blobs look like liquid gradient) ──────
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),

          // ── Center Logo (SVG) ──────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(scale: _logoScale.value, child: child),
                );
              },
              child: SvgPicture.asset(
                'assets/svg/FULL LOGO.svg',
                width: 170,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Blob Definition Helper ───────────────────────────────────────────────────

class _BlobDef {
  final Color color;
  final double size;
  final Offset begin;
  final Offset end;
  final Duration duration;

  const _BlobDef({
    required this.color,
    required this.size,
    required this.begin,
    required this.end,
    required this.duration,
  });
}
