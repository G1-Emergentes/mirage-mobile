import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleIdentity;
import '../domain/account.dart';
import '../domain/google_identity.dart';

class NativeGoogleIdentity implements GoogleIdentity {
  // Public OAuth identifier verified against this project's Supabase provider.
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '537535263168-cm23je8hgpj19gqvu2jo0s8ccgple14g.apps.googleusercontent.com',
  );
  static Future<void>? _initialization;
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> authenticateIdToken() async {
    if (!supported) {
      throw const AuthFailure(
        'google_platform_unsupported',
        'Google sign-in is currently available on Android.',
      );
    }
    try {
      final google = GoogleSignIn.instance;
      await (_initialization ??= google.initialize(
        serverClientId: webClientId,
      ));
      // Let the user choose again after logging out of Mirage or canceling a login.
      await google.signOut();
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const AuthFailure(
          'google_token_missing',
          'Google could not complete sign-in. Please try again.',
        );
      }
      return token;
    } on GoogleSignInException catch (failure) {
      if (failure.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthFailure('google_sign_in_failed', switch (failure.code) {
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google sign-in is unavailable for this app version. Please use email for now.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is unavailable on this device. Check Google Play services or use email.',
        _ =>
          'Could not sign in with Google. Check your connection and try again.',
      });
    } catch (failure) {
      if (failure is AuthFailure) rethrow;
      throw const AuthFailure(
        'google_sign_in_failed',
        'Could not open Google sign-in. Restart the app and try again.',
      );
    }
  }
}
