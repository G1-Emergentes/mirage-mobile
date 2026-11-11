import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/closet_repository.dart';
import '../domain/garment.dart';
import 'dio_closet_repository.dart';

class AccessoryModelApi {
  AccessoryModelApi({required this.accessToken, Dio? dio, String? baseUrl})
    : _dio = dio ?? Dio() {
    const configured = String.fromEnvironment('ACCESSORY_3D_BASE_URL');
    _dio.options = BaseOptions(
      baseUrl:
          baseUrl ??
          (configured.isEmpty
              ? '${serviceUrl('', 8000)}/try-on'
              : configured.replaceFirst(RegExp(r'/$'), '')),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(minutes: 5),
      followRedirects: false,
    );
  }

  final Dio _dio;
  final Future<String> Function() accessToken;

  String _path(String id) => '/garments/${Uri.encodeComponent(id)}/model';

  Future<Options> _auth({ResponseType? responseType}) async => Options(
    headers: {'Authorization': 'Bearer ${await accessToken()}'},
    responseType: responseType,
  );

  Future<String?> status(String id) async {
    try {
      return await guardCalls(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '${_path(id)}/info',
          options: await _auth(),
        );
        final model = response.data!;
        final status = model['status'] as String;
        return status == 'READY' && model['is_stale'] == true
            ? 'STALE'
            : status;
      });
    } on ClosetException catch (e) {
      if (e.code == 'MODEL_NOT_FOUND') return null;
      rethrow;
    }
  }

  Future<void> generate(
    Garment garment, {
    Uint8List? photo,
    String? contentType,
  }) => guardCalls(() async {
    final category = garment.model3dCategory;
    if (category == null) {
      throw const ClosetException('UNSUPPORTED_ACCESSORY');
    }
    FormData? form;
    if (photo != null) {
      const extensions = {
        'image/jpeg': 'jpg',
        'image/png': 'png',
        'image/webp': 'webp',
      };
      final extension = extensions[contentType];
      if (extension == null ||
          photo.isEmpty ||
          photo.length > 8 * 1024 * 1024) {
        throw const ClosetException('INVALID_PHOTO');
      }
      form = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          photo,
          filename: 'photo.$extension',
          contentType: DioMediaType.parse(contentType!),
        ),
      });
    }
    await _dio.post<Map<String, dynamic>>(
      _path(garment.id),
      queryParameters: {'category': category},
      data: form,
      options: await _auth(),
    );
  });

  Future<Uint8List> download(String id) => guardCalls(() async {
    try {
      final response = await _dio.get<Uint8List>(
        _path(id),
        options: await _auth(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null ||
          bytes.length < 12 ||
          String.fromCharCodes(bytes.take(4)) != 'glTF' ||
          ByteData.sublistView(bytes).getUint32(4, Endian.little) != 2 ||
          ByteData.sublistView(bytes).getUint32(8, Endian.little) !=
              bytes.length) {
        throw const ClosetException('INVALID_MODEL');
      }
      return bytes;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is List<int> && body.isNotEmpty) {
        try {
          final payload = jsonDecode(utf8.decode(body));
          final error = payload is Map ? payload['error'] : null;
          if (error is Map) throw ClosetException('${error['code']}');
        } on FormatException {
          // Preserve the HTTP error for non-JSON responses.
        }
      }
      rethrow;
    }
  });

  void close() => _dio.close(force: true);
}
