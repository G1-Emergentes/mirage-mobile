import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../shared/config/app_environment.dart';
import '../domain/closet_repository.dart';
import '../domain/garment.dart';

/// Origin of a sibling service next to IAM (same host, another port). Can be overridden
/// with `--dart-define` for a deployment.
String serviceUrl(String override, int port) {
  if (override.isNotEmpty) return override;
  final origin = Uri.parse(AppEnvironment.local().apiBaseUrl);
  return origin.replace(port: port, path: '/api/v1').toString();
}

Future<T> guardCalls<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    final data = e.response?.data;
    final error = data is Map ? data['error'] : null;
    if (error is Map) {
      throw ClosetException(
        '${error['code']}',
        '${error['message'] ?? ''}',
      );
    }
    throw ClosetException(e.response == null ? 'NETWORK' : 'UNKNOWN');
  }
}

class DioClosetRepository implements ClosetRepository {
  DioClosetRepository({Dio? dio, String? baseUrl, required this.accessToken})
    : _dio = dio ?? Dio() {
    // shortcut: local development URL (loopback, no gateway); set CLOSET_BASE_URL to deploy.
    _dio.options = BaseOptions(
      baseUrl:
          baseUrl ??
          serviceUrl(const String.fromEnvironment('CLOSET_BASE_URL'), 8081),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
    );
  }
  final Dio _dio;
  final Future<String> Function() accessToken;

  Future<Options> _auth() async =>
      Options(headers: {'Authorization': 'Bearer ${await accessToken()}'});

  Garment _garment(Response<Map<String, dynamic>> response) =>
      Garment.fromJson(response.data!);

  @override
  Future<List<Garment>> list() => guardCalls(() async {
    final all = <Garment>[];
    String? cursor;
    do {
      final page = (await _dio.get<Map<String, dynamic>>(
        '/garments',
        queryParameters: {'limit': 100, 'cursor': ?cursor},
        options: await _auth(),
      )).data!;
      all.addAll(
        (page['items'] as List).map(
          (item) => Garment.fromJson(item as Map<String, dynamic>),
        ),
      );
      cursor = page['next_cursor'] as String?;
    } while (cursor != null);
    return all;
  });

  @override
  Future<Garment> create(GarmentDraft draft) => guardCalls(
    () async => _garment(
      await _dio.post<Map<String, dynamic>>(
        '/garments',
        data: draft.toJson(),
        options: await _auth(),
      ),
    ),
  );

  @override
  Future<Garment> update(String id, GarmentDraft draft) => guardCalls(
    () async => _garment(
      await _dio.put<Map<String, dynamic>>(
        '/garments/$id',
        data: draft.toJson(),
        options: await _auth(),
      ),
    ),
  );

  @override
  Future<void> remove(String id) => guardCalls(() async {
    await _dio.delete<void>('/garments/$id', options: await _auth());
  });

  @override
  Future<Garment> attachImage(
    String id,
    Uint8List bytes,
    String contentType,
  ) => guardCalls(() async {
    final auth = await _auth();
    final upload = (await _dio.post<Map<String, dynamic>>(
      '/garments/$id/image-upload',
      options: auth,
    )).data!;
    // The signed URL points straight at Storage and needs no bearer token.
    await Dio().put<void>(
      upload['upload_url'] as String,
      data: Stream.fromIterable(bytes.map((byte) => [byte])),
      options: Options(
        headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
    return _garment(
      await _dio.put<Map<String, dynamic>>(
        '/garments/$id/image',
        data: {'image_id': upload['image_id']},
        options: auth,
      ),
    );
  });

  @override
  Future<String?> imageUrl(String id) async {
    try {
      return await guardCalls(() async {
        final access = (await _dio.get<Map<String, dynamic>>(
          '/garments/$id/image-access',
          options: await _auth(),
        )).data!;
        return access['url'] as String;
      });
    } on ClosetException catch (e) {
      if (e.code == 'IMAGE_NOT_FOUND') return null;
      rethrow;
    }
  }

  @override
  void close() => _dio.close();
}
