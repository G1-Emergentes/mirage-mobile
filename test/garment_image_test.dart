import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/closet/application/accessory_models_controller.dart';
import 'package:miragemobile/closet/application/closet_controller.dart';
import 'package:miragemobile/closet/application/outfit_tray.dart';
import 'package:miragemobile/closet/closet_module.dart';
import 'package:miragemobile/closet/domain/closet_repository.dart';
import 'package:miragemobile/closet/domain/garment.dart';
import 'package:miragemobile/closet/infrastructure/accessory_model_api.dart';
import 'package:miragemobile/closet/presentation/closet_widgets.dart';
import 'package:miragemobile/closet/presentation/item_detail_screen.dart';

import 'closet_fakes.dart';

/// What a garment card and the detail header show:
/// 1. photo, no 3D model  -> the photo of Digital Closet;
/// 2. READY model         -> the background-free thumbnail and the badge (detail: viewer);
/// 3. thumbnail fails     -> the photo;
/// 4. no photo            -> the placeholder (and nothing is requested).

const shadesId = '11111111-1111-4111-8111-111111111111';
const base = 'http://10.0.2.2:8000/api/v1/try-on';

final shades = piece(
  shadesId,
  name: 'Lentes negros',
  category: 'ACCESSORY',
  subcategory: 'GLASSES',
);

/// 3D service double. [ready] gives the accessory a READY model with a thumbnail;
/// [thumbnailFails] makes the PNG request fail; the GLB never arrives, so the detail
/// keeps the thumbnail while "downloading" (the WebView viewer is not built in tests).
AccessoryModelApi service({bool ready = false, bool thumbnailFails = false}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path.endsWith('/thumbnail')) {
          return thumbnailFails
              ? handler.reject(
                  DioException.badResponse(
                    statusCode: 404,
                    requestOptions: request,
                    response: Response(
                      requestOptions: request,
                      statusCode: 404,
                    ),
                  ),
                )
              : handler.resolve(
                  Response(requestOptions: request, data: tinyPng),
                );
        }
        if (request.responseType == ResponseType.bytes) return; // GLB: pending
        handler.resolve(
          Response(
            requestOptions: request,
            data: {
              'items': [
                {
                  'garment_id': shadesId,
                  'found': true,
                  'status': ready ? 'READY' : null,
                  'badge': ready ? 'AR_READY' : null,
                  'thumbnail_url': ready
                      ? '/api/v1/try-on/garments/$shadesId/model/thumbnail'
                      : null,
                },
              ],
            },
          ),
        );
      },
    ),
  );
  return AccessoryModelApi(
    dio: dio,
    baseUrl: base,
    accessToken: () async => 's',
  );
}

Finder networkPhoto() => find.byWidgetPredicate(
  (w) => w is Image && w.image is NetworkImage,
  description: 'photo from Digital Closet',
);
Finder thumbnail() => find.byKey(const ValueKey('garment-thumbnail'));
Finder placeholder() => find.byIcon(Icons.checkroom_outlined);

Future<void> pumpTile(
  WidgetTester tester, {
  required AccessoryModelApi api,
  required ClosetController closet,
  required Garment garment,
}) async {
  final models = AccessoryModelsController(api);
  final tray = OutfitTray();
  addTearDown(models.dispose);
  addTearDown(tray.dispose);
  addTearDown(api.close);
  await tester.runAsync(() => models.ensure([garment.id]));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 180,
          height: 260,
          child: GarmentTile(
            garment: garment,
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
  // Photo links and thumbnails resolve in the real zone: let them finish, then build.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  late ClosetController closet;
  setUp(() => closet = ClosetController(FakeCloset()));
  tearDown(() => closet.dispose());

  testWidgets('1. photo and no 3D model: the Digital Closet photo', (
    tester,
  ) async {
    await pumpTile(tester, api: service(), closet: closet, garment: shades);
    expect(networkPhoto(), findsOneWidget);
    expect(thumbnail(), findsNothing);
    expect(find.byKey(const ValueKey('badge-AR READY')), findsNothing);
  });

  testWidgets('2. READY model: thumbnail and badge', (tester) async {
    await pumpTile(
      tester,
      api: service(ready: true),
      closet: closet,
      garment: shades,
    );
    expect(thumbnail(), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-AR READY')), findsOneWidget);
    expect(networkPhoto(), findsNothing);
  });

  testWidgets('3. the thumbnail fails: back to the photo', (tester) async {
    await pumpTile(
      tester,
      api: service(ready: true, thumbnailFails: true),
      closet: closet,
      garment: shades,
    );
    expect(networkPhoto(), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-AR READY')), findsOneWidget);
  });

  testWidgets('4. no photo: placeholder, and no link is requested', (
    tester,
  ) async {
    final repo = FakeCloset();
    final noPhoto = ClosetController(repo);
    addTearDown(noPhoto.dispose);
    await pumpTile(
      tester,
      api: service(),
      closet: noPhoto,
      garment: piece('22222222-2222-4222-8222-222222222222', hasImage: false),
    );
    expect(placeholder(), findsOneWidget);
    expect(networkPhoto(), findsNothing);
    expect(repo.urlCalls, 0);
  });

  testWidgets('2. detail of a READY accessory: 3D header and badge', (
    tester,
  ) async {
    final repo = FakeCloset()..items = [shades];
    final module = ClosetModule(
      accessToken: () async => 's',
      closetRepository: repo,
      tryOnRepository: FakeTryOn(const []),
      accessoryModelApi: service(ready: true),
    );
    addTearDown(module.dispose);
    await tester.runAsync(module.closet.load);
    await tester.pumpWidget(
      MaterialApp(
        home: ItemDetailScreen(module: module, garmentId: shadesId),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      find.byKey(const ValueKey('model-header-$shadesId')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('badge-AR READY')), findsOneWidget);
    expect(thumbnail(), findsOneWidget); // while the GLB downloads
  });

  test(
    'a failed photo link is not cached: the next build asks again',
    () async {
      final repo = _FlakyCloset();
      final controller = ClosetController(repo);
      addTearDown(controller.dispose);
      expect(await controller.imageUrl(shades), isNull); // first request fails
      expect(await controller.imageUrl(shades), 'https://example.com/ok');
      expect(repo.calls, 2);
      expect(await controller.imageUrl(shades), 'https://example.com/ok');
      expect(repo.calls, 2); // a good link is reused
    },
  );
}

class _FlakyCloset extends FakeCloset {
  int calls = 0;
  @override
  Future<String?> imageUrl(String id) async {
    calls++;
    if (calls == 1) throw const ClosetException('NETWORK');
    return 'https://example.com/ok';
  }
}
