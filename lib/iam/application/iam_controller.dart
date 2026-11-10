import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/account.dart';
import '../domain/auth_repository.dart';
import '../domain/session_store.dart';
import '../domain/google_identity.dart';

class IamController extends ChangeNotifier {
  IamController(
    this._repository, {
    SessionStore? sessionStore,
    GoogleIdentity? googleIdentity,
  }) : _sessionStore = sessionStore,
       _googleIdentity = googleIdentity;
  final AuthRepository _repository;
  final SessionStore? _sessionStore;
  final GoogleIdentity? _googleIdentity;
  bool get canUseGoogle => _googleIdentity?.supported ?? false;
  AuthSession? _session;
  Account? _account;
  bool _disposed = false;
  bool busy = false;
  bool restoring = false, hasSavedSignIn = false;
  String? error;
  Account? get account => _account;
  bool get signedIn => _session != null;

  Future<String> avatarAccessToken() async {
    if (!await queryCurrentAccount() || _session == null) {
      throw const AuthFailure(
        'unauthorized',
        'Sign in again to save your avatar.',
      );
    }
    return _session!.accessToken;
  }

  Future<bool> _run(Future<void> Function() command) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await command();
      return true;
    } on AuthFailure catch (failure) {
      error = failure.message;
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _setSession(AuthSession? session) async {
    if (session == null) {
      _session = null;
      _account = null;
      await _sessionStore?.clear();
      return;
    }
    await _sessionStore?.writeRefreshToken(session.refreshToken);
    _session = session;
    _account = session.account;
  }

  Future<void> restoreSession() async {
    if (busy || _disposed || _sessionStore == null) return;
    restoring = true;
    try {
      await _run(() async {
        final token = await _sessionStore.readRefreshToken();
        if (token == null || token.isEmpty) return;
        hasSavedSignIn = true;
        try {
          final session = await _repository.refresh(token);
          // Persist rotation before a subsequent network request can fail.
          await _sessionStore.writeRefreshToken(session.refreshToken);
          final account = await _repository.currentAccount(session.accessToken);
          _session = session;
          _account = account;
        } on AuthFailure catch (failure) {
          if (failure.code == 'unauthorized') await _setSession(null);
          rethrow;
        }
      });
    } finally {
      restoring = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) => _run(() async {
    final address = EmailAddress(email);
    validatePassword(password);
    await _setSession(await _repository.signIn(address, password));
  });

  Future<bool> signInWithGoogle() async {
    final completed = await _run(() async {
      if (!canUseGoogle) {
        throw const AuthFailure(
          'google_platform_unsupported',
          'Google sign-in is unavailable on this device.',
        );
      }
      final token = await _googleIdentity!.authenticateIdToken();
      if (token == null) return;
      await _setSession(await _repository.signInWithGoogle(token));
    });
    return completed && signedIn;
  }

  Future<bool> register(String name, String email, String password) =>
      _run(() async {
        final displayName = name.trim();
        if (displayName.isEmpty || utf8.encode(displayName).length > 100) {
          throw const AuthFailure(
            'invalid_name',
            'Enter your name. If it is very long, try a shorter version.',
          );
        }
        final address = EmailAddress(email);
        validatePassword(password, registering: true);
        await _setSession(
          await _repository.register(displayName, address, password),
        );
      });

  Future<bool> requestRecovery(String email) =>
      _run(() => _repository.requestRecovery(EmailAddress(email)));
  Future<bool> resendVerification(String email) =>
      _run(() => _repository.resendVerification(EmailAddress(email)));

  Future<bool> queryCurrentAccount() => _run(() async {
    var session = _session;
    if (session == null) return;
    try {
      if (session.needsRefresh) {
        session = await _repository.refresh(session.refreshToken);
        await _setSession(session);
      }
      _account = await _repository.currentAccount(session.accessToken);
    } on AuthFailure catch (failure) {
      if (failure.code == 'unauthorized') await _setSession(null);
      rethrow;
    }
  });

  Future<bool> signOut() => _run(() async {
    var session = _session;
    if (session == null) return;
    try {
      if (session.needsRefresh) {
        session = await _repository.refresh(session.refreshToken);
        await _setSession(session);
      }
      await _repository.signOut(session.accessToken);
    } on AuthFailure catch (failure) {
      if (failure.code != 'unauthorized') rethrow;
    }
    await _setSession(null);
  });

  void clearError() {
    error = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
