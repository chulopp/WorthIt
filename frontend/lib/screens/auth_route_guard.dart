import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import 'custom_splash_screen.dart';
import 'welcome_page.dart';

class AuthRouteGuard extends ConsumerWidget {
  const AuthRouteGuard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.initializing:
        return const CustomSplashScreen();
      case AuthStatus.authenticated:
        return const CustomSplashScreen();
      case AuthStatus.unauthenticated:
        return const WelcomePage();
    }
  }
}
