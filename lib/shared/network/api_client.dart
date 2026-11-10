import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.code, this.status);
  final String code;
  final int? status;
}

class ApiClient {
  ApiClient(String baseUrl, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
      contentType: Headers.jsonContentType,
    );
  }
  final Dio _dio;

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? data,
    String? bearer,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: bearer == null ? null : {'Authorization': 'Bearer $bearer'},
        ),
      );
      if (response.data is! Map<String, dynamic>) {
        throw const ApiFailure('invalid_server_response', null);
      }
      return response.data! as Map<String, dynamic>;
    } on DioException catch (error) {
      final body = error.response?.data;
      final code = body is Map && body['error'] is String
          ? body['error'] as String
          : null;
      throw ApiFailure(
        code ??
            switch (error.type) {
              DioExceptionType.connectionTimeout ||
              DioExceptionType.sendTimeout ||
              DioExceptionType.receiveTimeout => 'timeout',
              DioExceptionType.connectionError => 'connection_failed',
              _ => 'request_failed',
            },
        error.response?.statusCode,
      );
    }
  }

  void close() => _dio.close();
}
