import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/closet_repository.dart';
import '../domain/garment.dart';
import 'dio_closet_repository.dart';

/// One row of `GET /garments/models?ids=…`: what a card or picker needs.
class AccessoryModelSummary {
  const AccessoryModelSummary({
    required this.garmentId,
    required this.found,
    this.status,
    this.category,
    this.badge,
    this.isStale = false,
    this.arFit,
    this.thumbnailUrl,
    this.arModelUrl,
  });

  factory AccessoryModelSummary.fromJson(Map<String, dynamic> json) =>
      AccessoryModelSummary(
        garmentId: json['garment_id'] as String,
        found: json['found'] as bool? ?? false,
        status: json['status'] as String?,
        category: json['category'] as String?,
        badge: json['badge'] as String?,
        isStale: json['is_stale'] as bool? ?? false,
        arFit: json['ar_fit'] is Map<String, dynamic>
            ? json['ar_fit'] as Map<String, dynamic>
            : null,
        thumbnailUrl: json['thumbnail_url'] as String?,
        arModelUrl: json['ar_model_url'] as String?,
      );

  final String garmentId;
  final bool found;
  final String? status, category, badge;
  final bool isStale;

  /// Face placement sent by the service for AR-ready models; null until it provides one.
  final Map<String, dynamic>? arFit;

  /// Service path of the background-free PNG (needs the bearer token), or null.
  final String? thumbnailUrl;

  /// Service path of the temple-less GLB for the AR try-on; null on models generated
  /// before the service had that variant (the full model is used instead).
  final String? arModelUrl;

  bool get ready => found && status == 'READY';
  bool get arReady => ready && badge == 'AR_READY';

  /// Card label: AR_READY → "AR READY", MODEL_3D → "3D", no model → null.
  String? get badgeLabel => switch (badge) {
    'AR_READY' => 'AR READY',
    'MODEL_3D' => '3D',
    _ => null,
  };
}

/// Variants of a garment's GLB served by the 3D service.
enum ModelVariant {
  /// Complete model, with temples: the 3D viewer.
  full,

  /// Cut at the hinges: the AR try-on (temples would float behind the head).
  ar,
}

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

  /// Status of several garments in one call (the service accepts up to 100 ids).
  Future<List<AccessoryModelSummary>> listModels(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final result = <AccessoryModelSummary>[];
    for (var start = 0; start < ids.length; start += 100) {
      final chunk = ids.sublist(start, (start + 100).clamp(0, ids.length));
      final items = await guardCalls(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/garments/models',
          queryParameters: {'ids': chunk.join(',')},
          options: await _auth(),
        );
        return (response.data?['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AccessoryModelSummary.fromJson);
      });
      result.addAll(items);
    }
    return result;
  }

  /// Saves how this model sits on the face (calibrated on the phone). Returns the
  /// `ar_fit` the service now serves for it.
  Future<Map<String, dynamic>> saveArFit(
    String id, {
    required List<double> offsetM,
    required double scale,
    required double pitchDeg,
  }) => guardCalls(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${_path(id)}/ar-fit',
      data: {'offset_m': offsetM, 'scale': scale, 'pitch_deg': pitchDeg},
      options: await _auth(),
    );
    final fit = response.data?['ar_fit'];
    if (fit is! Map<String, dynamic>) {
      throw const ClosetException('INVALID_AR_FIT');
    }
    return fit;
  });

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

  /// The GLB of [variant]. For [ModelVariant.ar] the service falls back to the full
  /// model when it has no temple-less variant yet.
  Future<Uint8List> download(
    String id, {
    ModelVariant variant = ModelVariant.full,
  }) => guardCalls(() async {
    try {
      final response = await _dio.get<Uint8List>(
        _path(id),
        queryParameters: variant == ModelVariant.ar ? {'variant': 'ar'} : null,
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

  /// PNG bytes of a summary's [AccessoryModelSummary.thumbnailUrl] (a service path,
  /// resolved against the service origin). Null when it cannot be loaded: the
  /// thumbnail is optional and callers show the original photo instead.
  Future<Uint8List?> thumbnail(String thumbnailUrl) async {
    try {
      return await guardCalls(() async {
        final response = await _dio.get<Uint8List>(
          Uri.parse(_dio.options.baseUrl).resolve(thumbnailUrl).toString(),
          options: await _auth(responseType: ResponseType.bytes),
        );
        final bytes = response.data;
        return bytes == null || bytes.isEmpty ? null : bytes;
      });
    } catch (_) {
      // Any failure (network, HTTP, or no token) falls back to the photo.
      return null;
    }
  }

  void close() => _dio.close(force: true);
}
