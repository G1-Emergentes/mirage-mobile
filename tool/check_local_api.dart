import 'dart:io';
import 'package:miragemobile/shared/network/api_client.dart';

Future<void> main(List<String> arguments) async {
  final baseUrl = arguments.isEmpty
      ? 'http://127.0.0.1:8080'
      : arguments.single;
  final client = ApiClient(baseUrl);
  try {
    await client.request('/api/v1/auth/me', method: 'GET');
    stderr.writeln('Unexpected success: /me must require a bearer token.');
    exitCode = 1;
  } on ApiFailure catch (failure) {
    if (failure.status == 401 && failure.code == 'bearer_token_required') {
      stdout.writeln(
        'Dio reached the local IAM; /me correctly denied a request without a token.',
      );
    } else {
      stderr.writeln(
        'Local IAM check failed (${failure.status ?? failure.code}). Start the backend first.',
      );
      exitCode = 1;
    }
  } finally {
    client.close();
  }
}
