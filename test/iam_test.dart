import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/iam/application/iam_controller.dart';
import 'package:miragemobile/iam/domain/account.dart';
import 'package:miragemobile/iam/infrastructure/dio_auth_repository.dart';
import 'package:miragemobile/shared/network/api_client.dart';
import 'support/fake_auth_repository.dart';

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Map<String, dynamic> response = {
    'access_token': 'test-access',
    'refresh_token': 'test-refresh',
    'expires_in': 3600,
    'user': {
      'id': 'test-user',
      'email': 'mia@example.com',
      'email_confirmed_at': '2026-11-09T00:00:00Z',
      'user_metadata': {'display_name': 'Mia'},
    },
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'Google posts only its ID token to IAM and parses the Mirage session',
    () async {
      final adapter = RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = ApiClient('http://127.0.0.1:8080', dio: dio);
      addTearDown(client.close);
      final repository = DioAuthRepository(client);
      (adapter.response['user'] as Map<String, dynamic>)['user_metadata'] = {
        'full_name': 'Mia Google',
      };
      final session = await repository.signInWithGoogle('fake-google-id-token');
      expect(session.account.displayName, 'Mia Google');
      expect(adapter.requests.single.path, '/api/v1/auth/google');
      expect(adapter.requests.single.data, {
        'id_token': 'fake-google-id-token',
      });
      expect(adapter.requests.single.headers['Authorization'], isNull);
      expect(session.refreshToken, 'test-refresh');
      adapter.status = 401;
      adapter.response = {'error': 'invalid_google_token'};
      await expectLater(
        repository.signInWithGoogle('bad-token'),
        throwsA(isA<AuthFailure>()),
      );
    },
  );
  test(
    'Dio implements the backend contract and keeps bearer headers request-scoped',
    () async {
      final adapter = RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = ApiClient('http://127.0.0.1:8080', dio: dio);
      addTearDown(client.close);
      final repository = DioAuthRepository(client);
      final session = await repository.signIn(
        EmailAddress(' mia@example.com '),
        'Example-password-123',
      );
      expect(session.account.displayName, 'Mia');
      expect(adapter.requests.last.path, '/api/v1/auth/login');
      expect(adapter.requests.last.data, {
        'email': 'mia@example.com',
        'password': 'Example-password-123',
      });
      adapter.response = adapter.response['user'] as Map<String, dynamic>;
      await repository.currentAccount(session.accessToken);
      expect(adapter.requests.last.method, 'GET');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer test-access',
      );
      await repository.requestRecovery(EmailAddress('mia@example.com'));
      expect(adapter.requests.last.path, '/api/v1/auth/forgot-password');
      expect(adapter.requests.last.headers.containsKey('Authorization'), false);
    },
  );

  test(
    'server failures and malformed sessions do not leak raw responses',
    () async {
      final adapter = RecordingAdapter();
      final client = ApiClient(
        'http://127.0.0.1:8080',
        dio: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.close);
      final repository = DioAuthRepository(client);
      adapter.status = 401;
      adapter.response = {'error': 'untrusted-message-test-secret'};
      await expectLater(
        repository.signIn(EmailAddress('mia@example.com'), 'password'),
        throwsA(
          isA<AuthFailure>()
              .having((e) => e.code, 'code', 'unauthorized')
              .having(
                (e) => e.message.contains('test-secret'),
                'no raw secret',
                false,
              ),
        ),
      );
      adapter.status = 200;
      adapter.response = {'access_token': 'incomplete'};
      await expectLater(
        repository.signIn(EmailAddress('mia@example.com'), 'password'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            'invalid_server_response',
          ),
        ),
      );
    },
  );

  test(
    'domain validation prevents invalid requests and signup creates no fake session',
    () async {
      final repository = FakeAuthRepository();
      final controller = IamController(repository);
      addTearDown(controller.dispose);
      expect(await controller.signIn('bad', 'pw'), false);
      expect(repository.logins, 0);
      expect(
        await controller.register('Mia', 'mia@example.com', 'short'),
        false,
      );
      expect(repository.registrations, 0);
      expect(
        await controller.register(
          'Mia',
          'mia@example.com',
          'Example-password-123',
        ),
        true,
      );
      expect(controller.signedIn, false);
      expect(controller.account, isNull);
    },
  );

  test(
    'expired session refreshes and a revoked session returns to signed out',
    () async {
      final repository = FakeAuthRepository()..expired = true;
      final controller = IamController(repository);
      addTearDown(controller.dispose);
      await controller.signIn('mia@example.com', 'Example-password-123');
      expect(await controller.queryCurrentAccount(), true);
      expect(repository.refreshes, 1);
      repository.rejectCurrent = true;
      expect(await controller.queryCurrentAccount(), false);
      expect(controller.signedIn, false);
    },
  );

  test(
    'invalid refresh is terminal but server failures remain retryable',
    () async {
      final adapter = RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = ApiClient('http://127.0.0.1:8080', dio: dio);
      addTearDown(client.close);
      final repository = DioAuthRepository(client);
      adapter.status = 400;
      adapter.response = {'error': 'auth_request_rejected'};
      await expectLater(
        repository.refresh('fake-refresh'),
        throwsA(
          isA<AuthFailure>().having((e) => e.code, 'code', 'unauthorized'),
        ),
      );
      adapter.status = 500;
      await expectLater(
        repository.refresh('fake-refresh'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            'auth_request_rejected',
          ),
        ),
      );
    },
  );
  test('network failure during logout preserves session for retry', () async {
    final repository = FakeAuthRepository();
    final controller = IamController(repository);
    addTearDown(controller.dispose);
    await controller.signIn('mia@example.com', 'Example-password-123');
    repository.failLogout = true;
    expect(await controller.signOut(), false);
    expect(controller.signedIn, true);
    repository.failLogout = false;
    expect(await controller.signOut(), true);
    expect(controller.signedIn, false);
  });
}
