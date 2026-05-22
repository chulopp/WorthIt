import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class AuthConfigurationException implements Exception {
  final String message;
  const AuthConfigurationException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _googleWebClientId =
      '59508100320-vqc1ubfj7dktapaed5ds6ec02qehgdkn.apps.googleusercontent.com';

  final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId: _googleWebClientId,
  );

  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPro = ValueNotifier<bool>(false);
  final ValueNotifier<String?> userEmail = ValueNotifier<String?>(null);

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<void> init() async {
    _syncSession(_client?.auth.currentSession);
    _client?.auth.onAuthStateChange.listen((data) {
      _syncSession(data.session);
    });
  }

  Future<AuthResponse?> nativeGoogleSignIn() async {
    final client = _client;
    if (client == null) {
      throw const AuthConfigurationException(
        'Konfigurasi Supabase belum tersedia. Jalankan Flutter dengan --dart-define=SUPABASE_URL dan --dart-define=SUPABASE_ANON_KEY.',
      );
    }

    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AuthConfigurationException(
          'Google tidak mengembalikan ID Token. Pastikan Web Client ID yang dipakai adalah OAuth Web Client ID.',
        );
      }

      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      _syncSession(response.session);
      return response;
    } catch (error) {
      throw AuthConfigurationException('Gagal login Google native: $error');
    }
  }

  Future<bool> signInWithGoogle() async => await nativeGoogleSignIn() != null;

  void refreshAuthState() => _syncSession(_client?.auth.currentSession);

  void loginAsGuest() {
    isLoggedIn.value = false;
    userEmail.value = null;
  }

  Future<void> logout() async {
    try {
      try {
        await googleSignIn.signOut();
      } finally {
        await Supabase.instance.client.auth.signOut();
      }
    } finally {
      isLoggedIn.value = false;
      isPro.value = false;
      userEmail.value = null;
    }
  }

  String? get accessToken => _client?.auth.currentSession?.accessToken;

  User? get currentUser => _client?.auth.currentUser;

  String? get displayName {
    final user = currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final value = metadata['full_name'] ?? metadata['name'];
    final fromMetadata = value?.toString().trim();
    if (fromMetadata != null && fromMetadata.isNotEmpty) return fromMetadata;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return email;
  }

  String get initials {
    final name = displayName ?? userEmail.value ?? 'U';
    final words = name
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'U';
    return words.take(2).map((part) => part[0].toUpperCase()).join();
  }

  void _syncSession(Session? session) {
    final user = _client?.auth.currentUser;
    isLoggedIn.value = user != null;
    userEmail.value = user?.email;
  }
}
