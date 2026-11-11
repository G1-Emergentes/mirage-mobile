import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../domain/closet_repository.dart';
import '../domain/outfit.dart';
import 'dio_closet_repository.dart';

/// Saved outfits of Digital Closet (same service and token as the garments).
class DioOutfitRepository implements OutfitRepository {
  DioOutfitRepository({Dio? dio, String? baseUrl, required this.accessToken})
    : _dio = dio ?? Dio() {
    // shortcut: local development URL (loopback, no gateway); set CLOSET_BASE_URL to deploy.
    _dio.options = BaseOptions(
      baseUrl:
          baseUrl ??
          serviceUrl(const String.fromEnvironment('CLOSET_BASE_URL'), 8081),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 60),
    );
  }
  final Dio _dio;
  final Future<String> Function() accessToken;

  Future<Options> _auth() async =>
      Options(headers: {'Authorization': 'Bearer ${await accessToken()}'});

  @override
  Future<List<SavedOutfit>> list() => guardCalls(() async {
    final all = <SavedOutfit>[];
    String? cursor;
    do {
      final page = (await _dio.get<Map<String, dynamic>>(
        '/outfits',
        queryParameters: {'limit': 100, 'cursor': ?cursor},
        options: await _auth(),
      )).data!;
      all.addAll(
        (page['items'] as List).map(
          (item) => SavedOutfit.fromJson(item as Map<String, dynamic>),
        ),
      );
      cursor = page['next_cursor'] as String?;
    } while (cursor != null);
    return all;
  });

  @override
  Future<SavedOutfit> save(List<String> garmentIds, {String? name}) =>
      guardCalls(
        () async => SavedOutfit.fromJson(
          (await _dio.post<Map<String, dynamic>>(
            '/outfits',
            data: {'garment_ids': garmentIds, 'name': ?name},
            options: await _auth(),
          )).data!,
        ),
      );

  @override
  Future<SavedOutfit> attachImage(
    String id,
    Uint8List bytes,
    String contentType,
  ) => guardCalls(() async {
    final auth = await _auth();
    final upload = (await _dio.post<Map<String, dynamic>>(
      '/outfits/$id/image-upload',
      options: auth,
    )).data!;
    // The signed URL points straight at Storage and needs no bearer token.
    await Dio().put<void>(
      upload['upload_url'] as String,
      data: Stream.value(bytes),
      options: Options(
        headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
    return SavedOutfit.fromJson(
      (await _dio.put<Map<String, dynamic>>(
        '/outfits/$id/image',
        data: {'image_id': upload['image_id']},
        options: auth,
      )).data!,
    );
  });

  @override
  Future<String?> imageUrl(String id) async {
    try {
      return await guardCalls(() async {
        final access = (await _dio.get<Map<String, dynamic>>(
          '/outfits/$id/image-access',
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
  Future<void> remove(String id) => guardCalls(() async {
    await _dio.delete<void>('/outfits/$id', options: await _auth());
  });

  @override
  void close() => _dio.close();
}
