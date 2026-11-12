import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/iam/application/iam_controller.dart';
import 'package:miragemobile/iam/infrastructure/dio_profile_repository.dart';
import 'package:miragemobile/iam/presentation/screens/account_screen.dart';
import 'package:miragemobile/shared/network/api_client.dart';
import 'package:miragemobile/shared/theme/mirage_theme.dart';

import 'support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Lora': ['Lora-Regular.ttf', 'Lora-Italic.ttf'],
      'Inter': ['Inter.ttf'],
      'MirageSymbols': ['MirageSymbols.ttf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$name'));
      }
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('profile uses default photo and preserves birth date on edit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final iam = IamController(FakeAuthRepository());
    addTearDown(iam.dispose);
    await iam.signIn('mia@example.com', 'Example-password-123');
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: options.path.endsWith('/measurements')
                  ? options.data
                  : <String, dynamic>{
                      'displayName': 'Mia',
                      'birthDate': '2000-01-01',
                      'profileImageUrl': null,
                      if (options.data case final Map<String, dynamic> changes)
                        ...changes,
                    },
            ),
          );
        },
      ),
    );
    final client = ApiClient('http://127.0.0.1:8080', dio: dio);
    addTearDown(client.close);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: mirageTheme(),
          home: AccountScreen(
            controller: iam,
            profileRepository: DioProfileRepository(
              client,
              () async => 'test-token',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mia'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/design/editorial.png',
      ),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/design/editorial.png'),
        boundary.currentContext!,
      );
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('output/design/profile-w32.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.byTooltip('Edit Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Mia Chen');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Mia Chen'), findsOneWidget);
    expect(requests.map((request) => request.method), ['GET', 'PUT']);
    expect(requests.last.path, '/api/v1/profiles/${iam.account!.id}');
    expect(requests.last.headers['Authorization'], 'Bearer test-token');
    expect(requests.last.data, {
      'displayName': 'Mia Chen',
      'birthDate': '2000-01-01',
      'profileImageUrl': null,
    });
    await tester.tap(find.text('Measurements'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    final fields = find.byType(TextFormField);
    for (var index = 0; index < 5; index++) {
      await tester.enterText(fields.at(index), '100');
    }
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(
      requests.last.path,
      '/api/v1/profiles/${iam.account!.id}/measurements',
    );
    expect(requests.last.data, {
      'height': 100.0,
      'shoulderWidth': 100.0,
      'chest': 100.0,
      'waist': 100.0,
      'hip': 100.0,
    });
    expect(tester.takeException(), isNull);
  });
}
