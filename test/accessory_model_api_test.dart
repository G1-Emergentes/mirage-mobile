import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/closet/domain/closet_repository.dart';
import 'package:miragemobile/closet/domain/garment.dart';
import 'package:miragemobile/closet/infrastructure/accessory_model_api.dart';

const garment = Garment(
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Chrome Shades',
  category: 'ACCESSORY',
  subcategory: 'SUNGLASSES',
  description: '',
  available: true,
  hasImage: true,
  revision: 1,
);

void main() {
  test(
    'requests the model as the signed-in user and downloads GLB bytes',
    () async {
      final dio = Dio();
      final calls = <RequestOptions>[];
      final bytes = Uint8List.fromList([
        0x67,
        0x6c,
        0x54,
        0x46,
        2,
        0,
        0,
        0,
        12,
        0,
        0,
        0,
      ]);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls.add(request);
            final data = request.responseType == ResponseType.bytes
                ? bytes
                : <String, dynamic>{'status': 'READY', 'is_stale': false};
            handler.resolve(Response(requestOptions: request, data: data));
          },
        ),
      );
      final api = AccessoryModelApi(
        dio: dio,
        accessToken: () async => 'session',
      );
      addTearDown(api.close);

      await api.generate(garment);
      expect(await api.status(garment.id), 'READY');
      expect(await api.download(garment.id), bytes);
      expect(calls.map((r) => r.method), ['POST', 'GET', 'GET']);
      expect(
        calls.first.uri.path,
        '/api/v1/try-on/garments/${garment.id}/model',
      );
      expect(calls.first.queryParameters, {'category': 'glasses'});
      expect(calls.first.data, isNull);
      expect(
        calls.map((r) => r.headers['Authorization']),
        List.filled(3, 'Bearer session'),
      );
    },
  );

  test('sends a selected photo as multipart in local upload mode', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          final part = (request.data as FormData).files.single;
          expect(part.key, 'image');
          expect(part.value.filename, 'photo.jpg');
          expect(part.value.contentType.toString(), 'image/jpeg');
          handler.resolve(
            Response<Map<String, dynamic>>(requestOptions: request, data: {}),
          );
        },
      ),
    );
    final api = AccessoryModelApi(dio: dio, accessToken: () async => 'session');
    addTearDown(api.close);
    await api.generate(garment, photo: Uint8List(3), contentType: 'image/jpeg');
    await expectLater(
      api.generate(garment, photo: Uint8List(3), contentType: 'image/gif'),
      throwsA(
        isA<ClosetException>().having((e) => e.code, 'code', 'INVALID_PHOTO'),
      ),
    );
  });
}
