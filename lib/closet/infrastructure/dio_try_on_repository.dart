import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../domain/closet_repository.dart';
import 'dio_closet_repository.dart';

/// Talks to the visualization worker of Digital Closet.
class DioTryOnRepository implements TryOnRepository {
  DioTryOnRepository({Dio? dio, String? baseUrl, required this.accessToken})
    : _dio = dio ?? Dio() {
    // shortcut: local development URL (loopback, no gateway); set TRYON_BASE_URL to deploy.
    _dio.options = BaseOptions(
      baseUrl:
          baseUrl ??
          serviceUrl(const String.fromEnvironment('TRYON_BASE_URL'), 8082),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
    );
  }
  final Dio _dio;
  final Future<String> Function() accessToken;

  Future<Options> _auth({ResponseType? responseType}) async => Options(
    headers: {'Authorization': 'Bearer ${await accessToken()}'},
    responseType: responseType,
  );

  TryOnJob _job(Map<String, dynamic> json) => TryOnJob(
    json['id'] as String,
    switch (json['status']) {
      'READY' => TryOnState.ready,
      'FAILED' => TryOnState.failed,
      'PROCESSING' => TryOnState.processing,
      _ => TryOnState.pending,
    },
    json['error'] as String?,
  );

  @override
  Future<TryOnJob> start(List<String> garmentIds, Uint8List? personPhoto) =>
      guardCalls(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/outfit-visualizations',
          data: {
            'garment_ids': garmentIds,
            if (personPhoto != null) 'person_photo': base64Encode(personPhoto),
          },
          options: await _auth(),
        );
        return _job(response.data!);
      });

  @override
  Future<TryOnJob> status(String id) => guardCalls(
    () async => _job(
      (await _dio.get<Map<String, dynamic>>(
        '/outfit-visualizations/$id',
        options: await _auth(),
      )).data!,
    ),
  );

  @override
  Future<Uint8List> image(String id) => guardCalls(() async {
    final response = await _dio.get<List<int>>(
      '/outfit-visualizations/$id/image',
      options: await _auth(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  });

  @override
  void close() => _dio.close();
}
