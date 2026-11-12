import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/app/mirage_app.dart';
import 'package:miragemobile/iam/application/iam_controller.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_google_identity.dart';

void main() {
  Future<IamController> start(
    WidgetTester tester,
    FakeAuthRepository repository, {
    FakeGoogleIdentity? googleIdentity,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = IamController(
      repository,
      googleIdentity: googleIdentity,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(MirageApp(controller: controller));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'onboarding uses three distinct illustrations and reaches login',
    (tester) async {
      await start(tester, FakeAuthRepository());
      expect(find.text('Your closet.\nDigital.'), findsOneWidget);
      await tap(tester, 'Continue');
      expect(find.text('Style what you\nalready own.'), findsOneWidget);
      await tap(tester, 'Continue');
      expect(find.text('See more. Try\nmore.'), findsOneWidget);
      await tap(tester, 'Get Started');
      expect(find.text('Your style.\nYour space.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('validation, real command boundary, account, and logout', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await start(tester, repository);
    await tap(tester, 'Skip');
    await tap(tester, 'Log In');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(repository.logins, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'mia@example.com');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Example-password-123',
    );
    await tap(tester, 'Log In');
    expect(repository.logins, 1);
    expect(find.text('What should we\nwear today?'), findsOneWidget);
    await tap(tester, 'Profile');
    expect(find.text('Body Profile'), findsOneWidget);
    await tester.tap(find.byTooltip('Account Settings'));
    await tester.pumpAndSettle();
    await tap(tester, 'Log Out');
    expect(repository.logouts, 1);
    expect(find.text('Your style.\nYour space.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Google button signs in without validating the password form', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await start(tester, repository, googleIdentity: FakeGoogleIdentity());
    await tap(tester, 'Skip');
    await tap(tester, 'Continue with Google');
    expect(repository.googleLogins, 1);
    expect(find.text('What should we\nwear today?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'registration requires matching passwords and email confirmation',
    (tester) async {
      final repository = FakeAuthRepository();
      await start(tester, repository);
      await tap(tester, 'Skip');
      await tap(tester, 'Create Account');
      await tester.enterText(find.byType(TextFormField).at(0), 'Mia');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'mia@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Example-password-123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'different-password',
      );
      await tap(tester, 'Create Account');
      expect(repository.registrations, 0);
      expect(find.text('Your passwords don’t match.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Example-password-123',
      );
      await tap(tester, 'Create Account');
      expect(repository.registrations, 1);
      expect(find.text('Your space\nis almost ready.'), findsOneWidget);
      await tap(tester, 'Resend confirmation');
      expect(repository.resends, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery keeps a generic response and supports small screens with keyboard',
    (tester) async {
      final repository = FakeAuthRepository();
      await start(tester, repository);
      tester.view.physicalSize = const Size(320, 600);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tap(tester, 'Skip');
      await tap(tester, 'Forgot password?');
      await tester.enterText(
        find.byType(TextFormField).first,
        'mia@example.com',
      );
      await tap(tester, 'Send reset link');
      expect(repository.recoveries, 1);
      expect(
        find.textContaining('If an account uses this email'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
