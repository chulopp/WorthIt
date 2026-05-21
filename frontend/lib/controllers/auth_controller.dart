import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AppAuthState {
  final AuthStatus status;
  final User? user;
  final Session? session;

  const AppAuthState({required this.status, this.user, this.session});

  bool get isInitializing => status == AuthStatus.initializing;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
}

class AuthNotifier extends Notifier<AppAuthState> {
  @override
  AppAuthState build() {
    _init();
    return const AppAuthState(status: AuthStatus.initializing);
  }

  void _init() {
    // Listen to Supabase auth state changes in real-time
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final user = data.session?.user;

      // Sync with legacy AuthService to maintain backward compatibility
      AuthService().isLoggedIn.value = session != null;
      AuthService().userEmail.value = session?.user.email;

      if (session != null && user != null) {
        state = AppAuthState(
          status: AuthStatus.authenticated,
          user: user,
          session: session,
        );
      } else {
        state = const AppAuthState(status: AuthStatus.unauthenticated);
      }
    });

    // Check immediately if we already have a session
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null) {
      state = AppAuthState(
        status: AuthStatus.authenticated,
        user: currentSession.user,
        session: currentSession,
      );
    } else {
      state = const AppAuthState(status: AuthStatus.unauthenticated);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AppAuthState>(
  AuthNotifier.new,
);
