import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/closet/application/accessory_models_controller.dart';
import 'package:miragemobile/closet/application/closet_controller.dart';
import 'package:miragemobile/closet/application/outfit_tray.dart';
import 'package:miragemobile/closet/infrastructure/accessory_model_api.dart';
import 'package:miragemobile/closet/presentation/closet_widgets.dart';
import 'package:miragemobile/face_try_on/application/ports.dart';
import 'package:miragemobile/face_try_on/domain/glasses.dart';
import 'package:miragemobile/face_try_on/infrastructure/closet_glasses_catalog.dart';
import 'package:miragemobile/face_try_on/presentation/glasses_try_on_screen.dart';

import 'closet_fakes.dart';

/// 3D improvements: badges and thumbnails of the list, the temple-less AR variant, the
/// cache shared by the closet screens and "Create 3D model" in the try-on.

const shadesId = '11111111-1111-4111-8111-111111111111';
const capId = '33333333-3333-4333-8333-333333333333';
const base = 'http://10.0.2.2:8000/api/v1/try-on';

final glb = Uint8List.fromList([
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

Map<String, dynamic> row(String id, {String? badge, bool thumbnail = true}) => {
  'garment_id': id,
  'found': true,
  'status': badge == null ? null : 'READY',
  'badge': badge,
  'thumbnail_url': thumbnail && badge != null
      ? '/api/v1/try-on/garments/$id/model/thumbnail'
      : null,
  'ar_model_url': badge == 'AR_READY'
      ? '/api/v1/try-on/garments/$id/model?variant=ar'
      : null,
};

/// A 3D service answering from [rows]; every request is recorded in [calls].
(AccessoryModelApi, List<RequestOptions>) fakeService(
  List<Map<String, dynamic>> rows, {
  bool offline = false,
}) {
  final calls = <RequestOptions>[];
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        calls.add(request);
        if (offline) {
          return handler.reject(
            DioException.connectionError(requestOptions: request, reason: 'x'),
          );
        }
        final data = request.responseType == ResponseType.bytes
            ? (request.path.endsWith('/thumbnail') ? tinyPng : glb)
            : {
                'items': [
                  for (final id in '${request.queryParameters['ids']}'.split(
                    ',',
                  ))
                    rows.firstWhere((r) => r['garment_id'] == id),
                ],
              };
        handler.resolve(Response(requestOptions: request, data: data));
      },
    ),
  );
  return (
    AccessoryModelApi(dio: dio, baseUrl: base, accessToken: () async => 's'),
    calls,
  );
}

void main() {
  group('AccessoryModelSummary', () {
    test('reads thumbnail and AR variant paths and labels the badge', () {
      final ar = AccessoryModelSummary.fromJson(
        row(shadesId, badge: 'AR_READY'),
      );
      expect(
        ar.thumbnailUrl,
        '/api/v1/try-on/garments/$shadesId/model/thumbnail',
      );
      expect(ar.arModelUrl, contains('variant=ar'));
      expect(ar.badgeLabel, 'AR READY');
      expect(ar.arReady, isTrue);
      expect(
        AccessoryModelSummary.fromJson(
          row(capId, badge: 'MODEL_3D'),
        ).badgeLabel,
        '3D',
      );
      final none = AccessoryModelSummary.fromJson(row(capId));
      expect(none.badgeLabel, isNull);
      expect(none.ready, isFalse);
    });
  });

  group('AccessoryModelApi', () {
    test(
      'asks for the AR variant and resolves thumbnails on the origin',
      () async {
        final (api, calls) = fakeService([]);
        addTearDown(api.close);

        expect(await api.download(shadesId, variant: ModelVariant.ar), glb);
        expect(
          calls.last.uri.toString(),
          '$base/garments/$shadesId/model?variant=ar',
        );
        await api.download(shadesId);
        expect(calls.last.uri.query, isEmpty);

        final png = await api.thumbnail(
          '/api/v1/try-on/garments/$shadesId/model/thumbnail',
        );
        expect(png, tinyPng);
        expect(
          calls.last.uri.toString(),
          'http://10.0.2.2:8000/api/v1/try-on/garments/$shadesId/model/thumbnail',
        );
        expect(calls.last.headers['Authorization'], 'Bearer s');
      },
    );

    test('a thumbnail that cannot be loaded is null', () async {
      final (api, _) = fakeService([], offline: true);
      addTearDown(api.close);
      expect(await api.thumbnail('/x/thumbnail'), isNull);
    });
  });

  group('AccessoryModelsController', () {
    test('loads the whole list in one call and caches it', () async {
      final (api, calls) = fakeService([
        row(shadesId, badge: 'AR_READY'),
        row(capId, badge: 'MODEL_3D'),
      ]);
      final models = AccessoryModelsController(api);
      addTearDown(api.close);
      addTearDown(models.dispose);
      var notified = 0;
      models.addListener(() => notified++);

      await models.ensure([shadesId, capId]);
      await models.ensure([capId, shadesId]);
      expect(calls, hasLength(1));
      expect(calls.single.queryParameters['ids'], '$shadesId,$capId');
      expect(models.summary(shadesId)?.badgeLabel, 'AR READY');
      expect(models.summary(capId)?.badgeLabel, '3D');
      expect(notified, 1);

      expect(await models.thumbnail(shadesId), tinyPng);
      expect(await models.thumbnail(shadesId), tinyPng);
      expect(calls.where((c) => c.path.endsWith('/thumbnail')), hasLength(1));

      await models.refresh(shadesId); // generated again: asked anew
      expect(calls.last.queryParameters['ids'], shadesId);
    });

    test('a failure keeps the photo and is not retried at once', () async {
      final (api, calls) = fakeService([], offline: true);
      final models = AccessoryModelsController(api);
      addTearDown(api.close);
      addTearDown(models.dispose);
      await models.ensure([shadesId]);
      await models.ensure([shadesId]);
      expect(calls, hasLength(1));
      expect(models.summary(shadesId), isNull);
      expect(models.thumbnail(shadesId), isNull);
    });
  });

  test(
    'the try-on downloads the temple-less variant of closet glasses',
    () async {
      final (api, calls) = fakeService([]);
      final closet = ClosetController(FakeCloset());
      addTearDown(api.close);
      addTearDown(closet.dispose);
      final catalog = ClosetGlassesCatalog(closet: closet, models: api);
      await catalog.model(
        const GlassesOption.garment(garmentId: shadesId, name: 'S'),
      );
      expect(calls.single.queryParameters, {'variant': 'ar'});
    },
  );

  test(
    'default fit is the service default on the nose bridge (landmark 6)',
    () {
      const fit = GlassesFit();
      expect([fit.offsetX, fit.offsetY, fit.offsetZ], [0, 0.0015, 0.002]);
      expect(fit.scale, 1);
      expect(fit.pitchDeg, 0);
    },
  );

  testWidgets('accessory cards show the 3D badge', (
    tester,
  ) async {
    final (api, _) = fakeService([row(shadesId, badge: 'AR_READY')]);
    final models = AccessoryModelsController(api);
    final closet = ClosetController(FakeCloset());
    final tray = OutfitTray();
    addTearDown(api.close);
    addTearDown(models.dispose);
    addTearDown(closet.dispose);
    addTearDown(tray.dispose);
    await tester.runAsync(() => models.ensure([shadesId]));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 260,
            child: GarmentTile(
              garment: piece(
                shadesId,
                category: 'ACCESSORY',
                subcategory: 'SUNGLASSES',
              ),
              closet: closet,
              tray: tray,
              tint: Colors.white,
              onTap: () {},
              models: models,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('badge-AR READY')), findsOneWidget);
    // The card also asks for the thumbnail: let that request finish.
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('offers to create the missing model and reloads the glasses', (
    tester,
  ) async {
    final catalog = _CountingCatalog();
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        home: GlassesTryOnScreen(
          engine: _Engine(),
          catalog: catalog,
          initialGarmentId: shadesId,
          onCreateModel: (context, id) async => created = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no AR-ready 3D model'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('try-on-create-model')));
    await tester.pumpAndSettle();
    expect(created, shadesId);
    expect(catalog.loads, 2);
    expect(find.byKey(const ValueKey('try-on-create-model')), findsNothing);
  });
}

class _CountingCatalog implements GlassesCatalog {
  var loads = 0;

  @override
  Future<List<GlassesOption>> options() async {
    loads++;
    // After creating the model the accessory is AR-ready.
    return loads == 1
        ? const []
        : const [GlassesOption.garment(garmentId: shadesId, name: 'Shades')];
  }

  @override
  Future<Uint8List> model(GlassesOption option) async => glb;

  @override
  Future<GlassesFit> saveFit(GlassesOption option, GlassesFit fit) async => fit;
}

class _Engine implements FaceTryOnEngine {
  @override
  bool get isSupported => true;

  @override
  Future<CameraPermission> cameraPermission({bool request = false}) async =>
      CameraPermission.granted;

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> saveToGallery(Uint8List jpeg) async {}

  @override
  Widget buildView({required ValueChanged<FaceTryOnSession> onCreated}) =>
      const ColoredBox(color: Colors.black);
}
