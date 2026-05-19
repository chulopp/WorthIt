import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/welcome_page.dart';
import 'screens/loading_page.dart';
import 'screens/scanner_screen.dart';
import 'services/notification_service.dart';
import 'services/privacy_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await EasyLocalization.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }
  await AuthService().init();
  await PrivacyService().init();
  await NotificationService().init();
  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('id', 'ID'),
        useOnlyLangCode: true,
        child: const WorthItApp(),
      ),
    ),
  );
}

class WorthItApp extends StatelessWidget {
  const WorthItApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ── New Design System Colors ─────────────────────────────────────
    const Color darkGreen = Color(0xFF304423);
    const Color lightGreen = Color(0xFFC9E88A);

    // Light Theme Colors
    const Color bgLight = Color(0xFFF8F9FA);
    const Color textLight = Color(0xFF1E293B);

    // Dark Theme Colors
    const Color bgDark = Color(0xFF0F172A);
    const Color textDark = Color(0xFFF8F9FA);

    return MaterialApp(
      title: 'WorthIt',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,

      // ── Light Theme ──────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: bgLight,
        primaryColor: darkGreen,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkGreen,
          brightness: Brightness.light,
          surface: bgLight,
        ),
        textTheme: GoogleFonts.bricolageGrotesqueTextTheme(
          ThemeData(brightness: Brightness.light).textTheme,
        ).apply(bodyColor: textLight, displayColor: textLight),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgLight,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: textLight),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      // ── Dark Theme ───────────────────────────────────────────────────
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        primaryColor: darkGreen,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkGreen,
          brightness: Brightness.dark,
          surface: bgDark,
        ),
        textTheme: GoogleFonts.bricolageGrotesqueTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ).apply(bodyColor: textDark, displayColor: textDark),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: textDark),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      // ── Routing ──────────────────────────────────────────────────────
      initialRoute: '/welcome',
      routes: {
        '/welcome': (_) => const WelcomePage(),
        '/loading': (_) => const LoadingPage(),
        '/': (_) => const DashboardScreen(),
        '/scanner': (_) => const ScannerScreen(),
      },
    );
  }
}
