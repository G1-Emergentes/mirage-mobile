import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/iam/application/iam_controller.dart';
import 'package:miragemobile/iam/domain/account.dart';

import 'support/fake_auth_repository.dart';

/// IAM's current account check, counted, so the test sees how many times the token
/// is validated.
class CountingRepository extends FakeAuthRepository {
  int checks = 0;
  @override
  Future<Account> currentAccount(String token) async {
    checks++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return super.currentAccount(token);
  }
}

void main() {
  test(
    'concurrent screens all get the token (one IAM check is shared)',
    () async {
      final repository = CountingRepository();
      final iam = IamController(repository);
      addTearDown(iam.dispose);
      expect(await iam.signIn('mia@example.com', 'Correct-horse-1'), isTrue);

      // Six cards of "My Closet" asking for their photo at the same time.
      final tokens = await Future.wait(
        List.generate(6, (_) => iam.avatarAccessToken()),
      );
      expect(tokens, everyElement('test-access'));
      expect(repository.checks, 1);
    },
  );

  test('a rejected session still fails every waiting request', () async {
    final repository = CountingRepository();
    final iam = IamController(repository);
    addTearDown(iam.dispose);
    await iam.signIn('mia@example.com', 'Correct-horse-1');
    repository.rejectCurrent = true;
    final results = await Future.wait(
      List.generate(
        3,
        (_) => iam.avatarAccessToken().then<Object>(
          (t) => t,
          onError: (Object e) => e,
        ),
      ),
    );
    expect(results, everyElement(isA<AuthFailure>()));
    expect(iam.signedIn, isFalse);
  });
}
