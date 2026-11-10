import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../shared/config/app_environment.dart';
import '../domain/avatar_repository.dart';

class DioAvatarRepository implements AvatarRepository {
  DioAvatarRepository({Dio? dio, String? baseUrl, this.accessToken})
    : _dio = dio ?? Dio() {
    final origin = Uri.parse(AppEnvironment.local().apiBaseUrl);
    const configured = String.fromEnvironment('AVATAR_BASE_URL');
    final url =
        baseUrl ??
        (configured.isEmpty
            ? origin.replace(port: 8093).toString()
            : configured);
    final uri = Uri.parse(url);
    // shortcut: loopback API has no account authorization; use IAM gateway before public deployment.
    if (kReleaseMode ||
        !['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host) ||
        uri.scheme != 'http' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw StateError(
        'Avatar reconstruction is available only in local development.',
      );
    }
    _dio.options = BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
    );
  }
  final Dio _dio;
  final Future<String> Function()? accessToken;
  Future<Options> _auth() async => Options(
    headers: accessToken == null
        ? null
        : {'Authorization': 'Bearer ${await accessToken!()}'},
  );
  String fitPreference = 'Regular';
  @override
  Future<Map<String, dynamic>> body(String id) async =>
      Map<String, dynamic>.from(
        (await _dio.get<Map<String, dynamic>>(
              '/api/reconstructions/$id',
            )).data?['body'] ??
            {},
      );
  @override
  Future<String?> openSaved() async {
    try {
      final r = (await _dio.post<Map<String, dynamic>>(
        '/api/avatar/open',
        options: await _auth(),
      )).data!;
      fitPreference = r['fitPreference'] as String;
      return r['id'] as String;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<String> adjust(
    String id,
    Map<String, double?> measurements,
    String fit,
  ) async =>
      (await _dio.post<Map<String, dynamic>>(
            '/api/reconstructions/$id/adjust',
            data: {'measurements': measurements, 'fitPreference': fit},
            options: await _auth(),
          )).data!['id']
          as String;
  @override
  Future<void> save(
    String id,
    Map<String, double?> measurements,
    String fit,
  ) async {
    await _dio.put<void>(
      '/api/reconstructions/$id/profile',
      data: {'measurements': measurements, 'fitPreference': fit},
      options: await _auth(),
    );
  }

  @override
  Future<String> submit(AvatarInput input) async {
    final bytes = input.photo;
    final type = bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8
        ? 'jpeg'
        : bytes.length > 4 && bytes[0] == 137 && bytes[1] == 80
        ? 'png'
        : 'webp';
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/reconstructions',
      options: await _auth(),
      data: FormData.fromMap({
        'photo': MultipartFile.fromBytes(
          bytes,
          filename: 'body.$type',
          contentType: DioMediaType('image', type),
        ),
        'height_cm': input.height,
        'weight_kg': input.weight,
      }),
    );
    final id = response.data?['id'];
    if (id is! String || !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)) {
      throw const FormatException('Invalid job');
    }
    return id;
  }

  @override
  Future<String> status(String id) async =>
      (await _dio.get<Map<String, dynamic>>(
            '/api/reconstructions/$id',
          )).data!['status']
          as String;
  @override
  Uri viewer(String id) => Uri.parse(
    '${_dio.options.baseUrl.replaceFirst(RegExp(r'/$'), '')}/view/$id',
  );
  @override
  Future<void> discard(String id) async {
    await _dio.delete<void>('/api/reconstructions/$id');
  }

  @override
  void close() => _dio.close(force: true);
}
