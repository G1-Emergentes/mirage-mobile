import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/closet/application/closet_controller.dart';
import 'package:miragemobile/closet/infrastructure/accessory_model_api.dart';
import 'package:miragemobile/face_try_on/application/glasses_try_on_controller.dart';
import 'package:miragemobile/face_try_on/application/ports.dart';
import 'package:miragemobile/face_try_on/domain/glasses.dart';
import 'package:miragemobile/face_try_on/infrastructure/closet_glasses_catalog.dart';
import 'package:miragemobile/face_try_on/presentation/glasses_try_on_screen.dart';

import 'closet_fakes.dart';

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

const black = GlassesOption.sample(
  id: 'sample:a',
  name: 'Black',
  asset: 'a.glb',
);
const gold = GlassesOption.sample(id: 'sample:b', name: 'Gold', asset: 'b.glb');
const mine = GlassesOption.garment(
  garmentId: 'g-1',
  name: 'My Shades',
  fit: GlassesFit(offsetY: 0.001),
);

class FakeSession implements FaceTryOnSession {
  final controller = StreamController<TrackingUpdate>.broadcast();
  final loaded = <(Uint8List, GlassesFit)>[];
  final fits = <GlassesFit>[];
  bool debug = false;

  @override
  Stream<TrackingUpdate> get updates => controller.stream;

  @override
  Future<void> loadModel(Uint8List glb, GlassesFit fit) async =>
      loaded.add((glb, fit));

  @override
  Future<void> updateFit(GlassesFit fit) async => fits.add(fit);

  @override
  Future<void> setDebug(bool enabled) async => debug = enabled;

  @override
  Future<Uint8List> capture() async => tinyPng;
}

class FakeEngine implements FaceTryOnEngine {
  FakeEngine({this.permission = CameraPermission.granted});
  CameraPermission permission;
  final session = FakeSession();
  final saved = <Uint8List>[];
  var permissionRequests = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CameraPermission> cameraPermission({bool request = false}) async {
    if (request) permissionRequests++;
    return permission;
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> saveToGallery(Uint8List jpeg) async => saved.add(jpeg);

  @override
  Widget buildView({required ValueChanged<FaceTryOnSession> onCreated}) =>
      _FakeView(onCreated: () => onCreated(session));
}

class _FakeView extends StatefulWidget {
  const _FakeView({required this.onCreated});
  final VoidCallback onCreated;
  @override
  State<_FakeView> createState() => _FakeViewState();
}

class _FakeViewState extends State<_FakeView> {
  @override
  void initState() {
    super.initState();
    // Like the platform view, the session is ready after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onCreated());
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

class FakeCatalog implements GlassesCatalog {
  FakeCatalog(this.items);
  final List<GlassesOption> items;
  final requested = <String>[];
  final gates = <String, Completer<void>>{};

  @override
  Future<List<GlassesOption>> options() async => items;

  @override
  Future<Uint8List> model(GlassesOption option) async {
    requested.add(option.id);
    await gates[option.id]?.future;
    return Uint8List.fromList([...glb, option.id.length]);
  }

  final savedFits = <String, GlassesFit>{};

  @override
  Future<GlassesFit> saveFit(GlassesOption option, GlassesFit fit) async =>
      savedFits[option.id] = fit;
}

void main() {
  group('GlassesFit', () {
    test('reads the service ar_fit and keeps defaults for bad values', () {
      final fit = GlassesFit.fromJson({
        'anchor': 'nose_bridge',
        'offset_m': [0.001, -0.002, 0.004],
        'scale': 1.05,
        'pitch_deg': 3,
      });
      expect(
        fit,
        const GlassesFit(
          offsetX: 0.001,
          offsetY: -0.002,
          offsetZ: 0.004,
          scale: 1.05,
          pitchDeg: 3,
        ),
      );
      expect(
        GlassesFit.fromJson({'offset_m': 'x', 'scale': 9}),
        const GlassesFit(),
      );
      expect(GlassesFit.fromJson(fit.toJson().cast()), fit);
    });
  });

  group('GlassesTryOnController', () {
    test(
      'selects the opened accessory and puts its model on the face',
      () async {
        final engine = FakeEngine();
        final catalog = FakeCatalog([black, mine]);
        final c = GlassesTryOnController(
          engine: engine,
          catalog: catalog,
          initialGarmentId: 'g-1',
        );
        await c.start();
        c.attach(engine.session);
        await pumpEventQueue();

        expect(c.ready, isTrue);
        expect(c.selected, mine);
        expect(c.notice, isNull);
        expect(engine.session.loaded.single.$2, mine.fit);
        c.dispose();
      },
    );

    test(
      'falls back to available glasses when the accessory is not AR-ready',
      () async {
        final engine = FakeEngine();
        final c = GlassesTryOnController(
          engine: engine,
          catalog: FakeCatalog([black]),
          initialGarmentId: 'missing',
        );
        await c.start();
        expect(c.selected, black);
        expect(c.notice, contains('no AR-ready 3D model'));
        c.dispose();
      },
    );

    test('only the last of quick selections reaches the renderer', () async {
      final engine = FakeEngine();
      final catalog = FakeCatalog([black, gold, mine]);
      final c = GlassesTryOnController(engine: engine, catalog: catalog);
      await c.start();
      final slow = catalog.gates[gold.id] = Completer<void>();
      c.attach(engine.session);
      await pumpEventQueue();
      engine.session.loaded.clear();

      unawaited(c.select(gold));
      await c.select(mine);
      slow.complete();
      await pumpEventQueue();

      expect(engine.session.loaded, hasLength(1));
      expect(c.selected, mine);
      expect(c.loadingModel, isFalse);
      c.dispose();
    });

    test('tracks the face, captures and saves the photo', () async {
      final engine = FakeEngine();
      final c = GlassesTryOnController(
        engine: engine,
        catalog: FakeCatalog([black]),
      );
      await c.start();
      c.attach(engine.session);
      engine.session.controller.add(const TrackingUpdate(face: true, fps: 30));
      await pumpEventQueue();
      expect(c.faceVisible, isTrue);

      await c.capture();
      expect(c.photo, tinyPng);
      await c.savePhoto();
      expect(engine.saved.single, tinyPng);
      expect(c.saved, isTrue);
      c.discardPhoto();
      expect(c.photo, isNull);
      c.dispose();
    });

    test('reports native errors with a readable message', () async {
      final engine = FakeEngine();
      final c = GlassesTryOnController(
        engine: engine,
        catalog: FakeCatalog([black]),
      );
      await c.start();
      c.attach(engine.session);
      engine.session.controller.add(
        const TrackingUpdate(error: 'NO_FRONT_CAMERA'),
      );
      await pumpEventQueue();
      expect(c.error, 'This device has no front camera.');
      c.dispose();
    });
  });

  group('Calibration', () {
    test(
      'saves the fit of a closet accessory and keeps it when switching back',
      () async {
        final engine = FakeEngine();
        final catalog = FakeCatalog([mine, black]);
        final c = GlassesTryOnController(engine: engine, catalog: catalog);
        await c.start();
        c.attach(engine.session);
        await pumpEventQueue();

        const calibrated = GlassesFit(
          offsetY: 0.005,
          offsetZ: 0.008,
          scale: 1.03,
        );
        await c.adjustFit(calibrated);
        expect(engine.session.fits.last, calibrated);
        expect(c.canSaveFit, isTrue);
        await c.saveFit();
        expect(catalog.savedFits[mine.id], calibrated);
        expect(c.fitSaved, isTrue);

        await c.select(black);
        expect(c.canSaveFit, isFalse); // demo models are not saved
        await c.select(c.options.first);
        expect(c.fit, calibrated);
        expect(engine.session.loaded.last.$2, calibrated);
        c.dispose();
      },
    );

    test('sends the calibration to the 3D service', () async {
      final dio = Dio();
      late RequestOptions sent;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            sent = request;
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'ar_fit': {
                    'anchor': 'nose_bridge',
                    'offset_m': [0.0, 0.005, 0.008],
                    'scale': 1.03,
                    'pitch_deg': 0.0,
                    'source': 'calibrated',
                  },
                },
              ),
            );
          },
        ),
      );
      final api = AccessoryModelApi(dio: dio, accessToken: () async => 's');
      final closet = ClosetController(FakeCloset());
      addTearDown(api.close);
      addTearDown(closet.dispose);
      final catalog = ClosetGlassesCatalog(closet: closet, models: api);

      final saved = await catalog.saveFit(
        mine,
        const GlassesFit(offsetY: 0.005, offsetZ: 0.008, scale: 1.03),
      );
      expect(sent.method, 'PUT');
      expect(sent.uri.path, '/api/v1/try-on/garments/g-1/model/ar-fit');
      expect(sent.data, {
        'offset_m': [0.0, 0.005, 0.008],
        'scale': 1.03,
        'pitch_deg': 0.0,
      });
      expect(sent.headers['Authorization'], 'Bearer s');
      expect(
        saved,
        const GlassesFit(offsetY: 0.005, offsetZ: 0.008, scale: 1.03),
      );
      await expectLater(
        catalog.saveFit(black, const GlassesFit()),
        throwsA(isA<FaceTryOnException>()),
      );
    });
  });

  group('ClosetGlassesCatalog', () {
    test('lists AR-ready glasses of the closet before the test models', () async {
      final closetRepo = FakeCloset()
        ..items = [
          piece(
            '11111111-1111-4111-8111-111111111111',
            name: 'Shades',
            category: 'ACCESSORY',
            subcategory: 'SUNGLASSES',
          ),
          piece(
            '22222222-2222-4222-8222-222222222222',
            name: 'Reading',
            category: 'ACCESSORY',
            subcategory: 'GLASSES',
          ),
          piece(
            '33333333-3333-4333-8333-333333333333',
            name: 'Cap',
            category: 'ACCESSORY',
            subcategory: 'CAP',
          ),
          piece('44444444-4444-4444-8444-444444444444', name: 'Tee'),
        ];
      final dio = Dio();
      final queries = <Map<String, dynamic>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            queries.add(request.queryParameters);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'items': [
                    {
                      'garment_id': '11111111-1111-4111-8111-111111111111',
                      'found': true,
                      'status': 'READY',
                      'badge': 'AR_READY',
                      'ar_fit': {
                        'offset_m': [0, 0.002, 0.005],
                      },
                    },
                    {
                      'garment_id': '22222222-2222-4222-8222-222222222222',
                      'found': true,
                      'status': 'PROCESSING',
                      'badge': null,
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      final api = AccessoryModelApi(dio: dio, accessToken: () async => 's');
      final closet = ClosetController(closetRepo);
      addTearDown(api.close);
      addTearDown(closet.dispose);

      final catalog = ClosetGlassesCatalog(
        closet: closet,
        models: api,
        includeSamples: true,
      );
      final options = await catalog.options();

      expect(
        queries.single['ids'],
        '11111111-1111-4111-8111-111111111111,22222222-2222-4222-8222-222222222222',
      );
      expect(options.first.name, 'Shades');
      expect(options.first.fit.offsetZ, 0.005);
      expect(options.skip(1).every((o) => o.isSample), isTrue);
      expect(options, hasLength(1 + sampleGlasses.length));
    });

    test('keeps the test models when the 3D service is down', () async {
      final closetRepo = FakeCloset()
        ..items = [
          piece(
            '11111111-1111-4111-8111-111111111111',
            category: 'ACCESSORY',
            subcategory: 'GLASSES',
          ),
        ];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.reject(
            DioException.connectionError(
              requestOptions: request,
              reason: 'offline',
            ),
          ),
        ),
      );
      final api = AccessoryModelApi(dio: dio, accessToken: () async => 's');
      final closet = ClosetController(closetRepo);
      addTearDown(api.close);
      addTearDown(closet.dispose);

      final options = await ClosetGlassesCatalog(
        closet: closet,
        models: api,
        includeSamples: true,
      ).options();
      expect(options, sampleGlasses);
    });

    test('the bundled test models are valid glTF binaries', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final closet = ClosetController(FakeCloset());
      final api = AccessoryModelApi(dio: Dio(), accessToken: () async => 's');
      addTearDown(api.close);
      addTearDown(closet.dispose);
      final catalog = ClosetGlassesCatalog(closet: closet, models: api);
      for (final option in sampleGlasses) {
        final bytes = await catalog.model(option);
        final header = ByteData.sublistView(bytes);
        expect(String.fromCharCodes(bytes.take(4)), 'glTF');
        expect(header.getUint32(4, Endian.little), 2);
        expect(header.getUint32(8, Endian.little), bytes.length);
      }
    });
  });

  group('GlassesTryOnScreen', () {
    testWidgets('switches glasses, takes a photo and saves it', (tester) async {
      final engine = FakeEngine();
      final catalog = FakeCatalog([black, gold]);
      await tester.pumpWidget(
        MaterialApp(
          home: GlassesTryOnScreen(engine: engine, catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Try on glasses'), findsOneWidget);
      expect(find.text('Look at the camera'), findsOneWidget);
      engine.session.controller.add(const TrackingUpdate(face: true, fps: 30));
      await tester.pumpAndSettle();
      expect(find.text('Look at the camera'), findsNothing);

      await tester.tap(find.byKey(ValueKey('glasses-${gold.id}')));
      await tester.pumpAndSettle();
      expect(catalog.requested.last, gold.id);

      await tester.tap(find.byKey(const ValueKey('try-on-shutter')));
      await tester.pumpAndSettle();
      expect(find.text('Retake'), findsOneWidget);
      await tester.tap(find.text('Save photo'));
      await tester.pumpAndSettle();
      expect(engine.saved, hasLength(1));
      expect(find.text('Saved to Pictures/Mirage'), findsOneWidget);
    });

    testWidgets('explains how to enable a blocked camera', (tester) async {
      final engine = FakeEngine(permission: CameraPermission.permanentlyDenied);
      await tester.pumpWidget(
        MaterialApp(
          home: GlassesTryOnScreen(engine: engine, catalog: FakeCatalog([])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open Settings'), findsOneWidget);
    });
  });
}
