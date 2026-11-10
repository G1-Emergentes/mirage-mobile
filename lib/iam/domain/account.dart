import 'dart:convert';

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);
  final String code;
  final String message;
}

class EmailAddress {
  EmailAddress(String input) : value = input.trim() {
    if (utf8.encode(value).length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      throw const AuthFailure('invalid_email', 'Enter a valid email address.');
    }
  }
  final String value;
}

class Account {
  const Account({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailConfirmed,
  });
  final String id;
  final String email;
  final String displayName;
  final bool emailConfirmed;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.account,
  });
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final Account account;
  bool get needsRefresh =>
      DateTime.now().add(const Duration(seconds: 30)).isAfter(expiresAt);
}

void validatePassword(String password, {bool registering = false}) {
  final length = utf8.encode(password).length;
  if (length < (registering ? 8 : 1) || length > 128) {
    throw AuthFailure(
      'invalid_password',
      registering
          ? 'Use at least 8 characters. If your password is very long, try a shorter one.'
          : 'Enter your password. If it is very long, try a shorter one.',
    );
  }
}
