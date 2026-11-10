import 'package:miragemobile/iam/domain/account.dart';
import 'package:miragemobile/iam/domain/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  int logins = 0,
      registrations = 0,
      recoveries = 0,
      resends = 0,
      refreshes = 0,
      logouts = 0;
  int googleLogins = 0;
  String? googleIdToken;
  @override
  Future<AuthSession> signInWithGoogle(String idToken) async {
    googleLogins++;
    googleIdToken = idToken;
    return session();
  }

  bool expired = false, rejectCurrent = false, failLogout = false;
  static const user = Account(
    id: 'test-user',
    email: 'mia@example.com',
    displayName: 'Mia',
    emailConfirmed: true,
  );
  AuthSession session() => AuthSession(
    accessToken: 'test-access',
    refreshToken: 'test-refresh',
    expiresAt: DateTime.now().add(Duration(seconds: expired ? -1 : 3600)),
    account: user,
  );
  @override
  Future<AuthSession> signIn(EmailAddress email, String password) async {
    logins++;
    return session();
  }

  @override
  Future<AuthSession?> register(
    String name,
    EmailAddress email,
    String password,
  ) async {
    registrations++;
    return null;
  }

  @override
  Future<void> requestRecovery(EmailAddress email) async {
    recoveries++;
  }

  @override
  Future<void> resendVerification(EmailAddress email) async {
    resends++;
  }

  @override
  Future<AuthSession> refresh(String token) async {
    refreshes++;
    expired = false;
    return session();
  }

  @override
  Future<Account> currentAccount(String token) async {
    if (rejectCurrent) {
      throw const AuthFailure('unauthorized', 'Session ended.');
    }
    return user;
  }

  @override
  Future<void> signOut(String token) async {
    logouts++;
    if (failLogout) {
      throw const AuthFailure('timeout', 'Could not reach Mirage.');
    }
  }
}
