import '../../shared/network/api_client.dart';
import '../domain/account.dart';
import '../domain/auth_repository.dart';

class DioAuthRepository implements AuthRepository {
  DioAuthRepository(this._client);
  final ApiClient _client;
  static const _base = '/api/v1/auth';

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiFailure catch (failure) {
      throw _mapFailure(failure);
    } on FormatException {
      throw const AuthFailure(
        'invalid_server_response',
        'The server returned an unexpected response. Try again.',
      );
    }
  }

  @override
  Future<AuthSession> signIn(EmailAddress email, String password) => _call(
    () async => _session(
      await _client.request(
        '$_base/login',
        data: {'email': email.value, 'password': password},
      ),
    ),
  );

  @override
  Future<AuthSession> signInWithGoogle(String idToken) => _call(
    () async => _session(
      await _client.request('$_base/google', data: {'id_token': idToken}),
    ),
  );

  @override
  Future<AuthSession?> register(
    String name,
    EmailAddress email,
    String password,
  ) => _call(() async {
    final json = await _client.request(
      '$_base/register',
      data: {'name': name, 'email': email.value, 'password': password},
    );
    return json['access_token'] == null ? null : _session(json);
  });

  @override
  Future<void> requestRecovery(EmailAddress email) => _call(() async {
    await _client.request(
      '$_base/forgot-password',
      data: {'email': email.value},
    );
  });

  @override
  Future<void> resendVerification(EmailAddress email) => _call(() async {
    await _client.request(
      '$_base/resend-verification',
      data: {'email': email.value},
    );
  });

  @override
  Future<AuthSession> refresh(String refreshToken) => _call(() async {
    try {
      return _session(
        await _client.request(
          '$_base/refresh',
          data: {'refresh_token': refreshToken},
        ),
      );
    } on ApiFailure catch (failure) {
      if (failure.status == 400 || failure.status == 401) {
        throw const AuthFailure(
          'unauthorized',
          'Your session has ended. Please sign in again.',
        );
      }
      rethrow;
    }
  });

  @override
  Future<Account> currentAccount(String accessToken) => _call(
    () async => _account(
      await _client.request('$_base/me', method: 'GET', bearer: accessToken),
    ),
  );

  @override
  Future<void> signOut(String accessToken) => _call(() async {
    await _client.request('$_base/logout', bearer: accessToken);
  });

  String _text(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw const FormatException('Missing required value');
    }
    return value;
  }

  Account _account(Map<String, dynamic> json) {
    final metadata = json['user_metadata'];
    final name = metadata is Map
        ? metadata['display_name'] ?? metadata['full_name'] ?? metadata['name']
        : null;
    return Account(
      id: _text(json, 'id'),
      email: _text(json, 'email'),
      displayName: name is String ? name : '',
      emailConfirmed: json['email_confirmed_at'] != null,
    );
  }

  AuthSession _session(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Missing user');
    }
    final expiresAt = json['expires_at'];
    final expiresIn = json['expires_in'];
    if (expiresAt is! num && expiresIn is! num) {
      throw const FormatException('Missing expiry');
    }
    return AuthSession(
      accessToken: _text(json, 'access_token'),
      refreshToken: _text(json, 'refresh_token'),
      expiresAt: expiresAt is num
          ? DateTime.fromMillisecondsSinceEpoch(expiresAt.toInt() * 1000)
          : DateTime.now().add(Duration(seconds: (expiresIn as num).toInt())),
      account: _account(user),
    );
  }

  AuthFailure _mapFailure(ApiFailure failure) {
    final message = switch (failure.code) {
      'invalid_credentials' || 'invalid_grant' || 'auth_request_rejected' =>
        'We couldn’t sign you in. Check your details and try again.',
      'email_not_confirmed' => 'Confirm your email before signing in.',
      'too_many_attempts' =>
        'Too many attempts. Please wait before trying again.',
      'connection_failed' || 'timeout' =>
        'We couldn’t reach Mirage. Check your connection and try again.',
      'session_revoked' ||
      'invalid_token' => 'Your session has ended. Please sign in again.',
      _ =>
        failure.status == 429
            ? 'Please wait before trying again.'
            : 'We couldn’t complete that request. Please try again.',
    };
    return AuthFailure(
      failure.status == 401 ? 'unauthorized' : failure.code,
      message,
    );
  }
}
