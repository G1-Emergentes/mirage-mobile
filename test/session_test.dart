import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/iam/application/iam_controller.dart';
import 'package:miragemobile/iam/domain/account.dart';
import 'package:miragemobile/iam/domain/session_store.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_google_identity.dart';

class MemorySessions implements SessionStore {
  String? token;
  int clears = 0;
  @override
  Future<String?> readRefreshToken() async => token;
  @override
  Future<void> writeRefreshToken(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    token = null;
  }
}

class RotatingRepository extends FakeAuthRepository {
  String? received;
  bool offline = false, invalidRefresh = false;
  @override
  Future<AuthSession> refresh(String token) async {
    received = token;
    if (invalidRefresh) {
      throw const AuthFailure('unauthorized', 'Session ended.');
    }
    return AuthSession(
      accessToken: 'new-access',
      refreshToken: '$token-next',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      account: FakeAuthRepository.user,
    );
  }

  @override
  Future<Account> currentAccount(String token) async {
    if (offline) throw const AuthFailure('timeout', 'Cannot connect.');
    return super.currentAccount(token);
  }
}

void main() {
  test(
    'Google identity is exchanged through IAM and remembered like password login',
    () async {
      final repository = FakeAuthRepository();
      final store = MemorySessions();
      final controller = IamController(
        repository,
        sessionStore: store,
        googleIdentity: FakeGoogleIdentity(),
      );
      expect(await controller.signInWithGoogle(), true);
      expect(repository.googleLogins, 1);
      expect(repository.googleIdToken, 'fake-google-id-token');
      expect(store.token, 'test-refresh');
      expect(controller.signedIn, true);
      await controller.signOut();
      expect(store.token, isNull);
      controller.dispose();
    },
  );
  test(
    'closing Google picker creates no IAM session or stored credential',
    () async {
      final repository = FakeAuthRepository();
      final store = MemorySessions();
      final identity = FakeGoogleIdentity()..token = null;
      final controller = IamController(
        repository,
        sessionStore: store,
        googleIdentity: identity,
      );
      expect(await controller.signInWithGoogle(), false);
      expect(controller.busy, false);
      expect(controller.error, isNull);
      expect(repository.googleLogins, 0);
      expect(store.token, isNull);
      identity.failure = const AuthFailure(
        'google_sign_in_failed',
        'Google unavailable.',
      );
      expect(await controller.signInWithGoogle(), false);
      expect(controller.error, 'Google unavailable.');
      expect(controller.signedIn, false);
      controller.dispose();
    },
  );
  test(
    'login survives controller recreation and logout removes the credential',
    () async {
      final store = MemorySessions();
      final repository = RotatingRepository();
      final first = IamController(repository, sessionStore: store);
      await first.signIn('mia@example.com', 'example-password');
      expect(store.token, 'test-refresh');
      first.dispose();
      final next = IamController(repository, sessionStore: store);
      await next.restoreSession();
      expect(repository.received, 'test-refresh');
      expect(store.token, 'test-refresh-next');
      expect(next.signedIn, true);
      expect(next.account?.id, FakeAuthRepository.user.id);
      await next.signOut();
      expect(store.token, isNull);
      final afterLogout = IamController(repository, sessionStore: store);
      await afterLogout.restoreSession();
      expect(afterLogout.signedIn, false);
      next.dispose();
      afterLogout.dispose();
    },
  );
  test(
    'rejected refresh and revoked server session clear saved credentials',
    () async {
      for (final revoked in [false, true]) {
        final store = MemorySessions()..token = 'old-token';
        final repository = RotatingRepository()
          ..invalidRefresh = !revoked
          ..rejectCurrent = revoked;
        final controller = IamController(repository, sessionStore: store);
        await controller.restoreSession();
        expect(controller.signedIn, false);
        expect(store.token, isNull);
        expect(controller.hasSavedSignIn, true);
        expect(controller.restoring, false);
        controller.dispose();
      }
    },
  );
  test(
    'network failure preserves the rotated credential for a later retry',
    () async {
      final store = MemorySessions()..token = 'old-token';
      final repository = RotatingRepository()..offline = true;
      final controller = IamController(repository, sessionStore: store);
      await controller.restoreSession();
      expect(controller.signedIn, false);
      expect(store.token, 'old-token-next');
      repository.offline = false;
      await controller.restoreSession();
      expect(controller.signedIn, true);
      expect(repository.received, 'old-token-next');
      controller.dispose();
    },
  );
  test('failed remote logout keeps persisted session for retry', () async {
    final store = MemorySessions();
    final repository = FakeAuthRepository();
    final controller = IamController(repository, sessionStore: store);
    await controller.signIn('mia@example.com', 'example-password');
    repository.failLogout = true;
    expect(await controller.signOut(), false);
    expect(store.token, 'test-refresh');
    repository.failLogout = false;
    expect(await controller.signOut(), true);
    expect(store.token, isNull);
    controller.dispose();
  });
}
