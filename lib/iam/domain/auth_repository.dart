import 'account.dart';

abstract interface class AuthRepository {
  Future<AuthSession> signIn(EmailAddress email, String password);
  Future<AuthSession> signInWithGoogle(String idToken);
  Future<AuthSession?> register(
    String name,
    EmailAddress email,
    String password,
  );
  Future<void> requestRecovery(EmailAddress email);
  Future<void> resendVerification(EmailAddress email);
  Future<AuthSession> refresh(String refreshToken);
  Future<Account> currentAccount(String accessToken);
  Future<void> signOut(String accessToken);
}
