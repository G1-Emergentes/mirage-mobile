import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/app/mirage_app.dart';
import 'package:miragemobile/iam/application/iam_controller.dart';
import 'package:miragemobile/shared/widgets/mirage_bottom_navigation.dart';
import 'support/fake_auth_repository.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Lora': ['Lora-Regular.ttf', 'Lora-Italic.ttf'],
      'Inter': ['Inter.ttf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$name'));
      }
      await loader.load();
    }
  });
  testWidgets(
    'authenticated startup opens empty Home, fixed bar and account only in Profile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = IamController(FakeAuthRepository());
      addTearDown(controller.dispose);
      await controller.signIn('mia@example.com', 'example-password');
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MirageApp(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('output/design/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(find.byKey(const ValueKey('home-placeholder')), findsOneWidget);
      expect(find.text('Create your digital avatar'), findsNothing);
      expect(find.byType(MirageBottomNavigation), findsOneWidget);
      await capture('home-navigation');
      await tester.tap(find.byKey(const ValueKey('navigation-4')));
      await tester.pumpAndSettle();
      expect(find.text('Your profile.'), findsOneWidget);
      expect(find.text('mia@example.com'), findsOneWidget);
      final position = tester.getTopLeft(find.byType(MirageBottomNavigation));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(MirageBottomNavigation)), position);
      await capture('profile-navigation');
      await tester.tap(find.byKey(const ValueKey('navigation-3')));
      await tester.pumpAndSettle();
      expect(find.text('Your profile.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('navigation-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-placeholder')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
