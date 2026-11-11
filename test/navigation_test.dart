import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/app/authenticated_shell.dart';
import 'package:miragemobile/closet/closet_module.dart';
import 'package:miragemobile/closet/domain/garment.dart';
import 'package:miragemobile/shared/theme/mirage_theme.dart';
import 'package:miragemobile/iam/application/iam_controller.dart';
import 'package:miragemobile/shared/widgets/mirage_bottom_navigation.dart';
import 'closet_fakes.dart';
import 'support/fake_auth_repository.dart';

class _AuthenticatedCloset extends FakeCloset {
  _AuthenticatedCloset(this.token);
  final Future<String> Function() token;

  @override
  Future<List<Garment>> list() async {
    await token();
    return super.list();
  }

  @override
  Future<String?> imageUrl(String id) async {
    await token();
    return super.imageUrl(id);
  }
}

void main() {
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
  testWidgets(
    'authenticated startup opens Home and navigates between feature tabs',
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
          child: MaterialApp(
            theme: mirageTheme(),
            debugShowCheckedModeBanner: false,
            home: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => AuthenticatedShell(
                controller: controller,
                createCloset: () => ClosetModule(
                  accessToken: controller.avatarAccessToken,
                  closetRepository:
                      _AuthenticatedCloset(controller.avatarAccessToken)
                        ..serveUrls = false
                        ..items = [piece('one', name: 'Linen shirt')],
                ),
              ),
            ),
          ),
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

      expect(find.text('What should we\nwear today?'), findsOneWidget);
      expect(find.text('Create your digital avatar'), findsNothing);
      expect(find.byType(MirageBottomNavigation), findsOneWidget);
      await capture('home-navigation');
      await tester.tap(find.byKey(const ValueKey('navigation-4')));
      await tester.pumpAndSettle();
      expect(find.text('Body Profile'), findsOneWidget);
      await tester.tap(find.byTooltip('Account Settings'));
      await tester.pumpAndSettle();
      expect(find.text('mia@example.com'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      final position = tester.getTopLeft(find.byType(MirageBottomNavigation));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(MirageBottomNavigation)), position);
      await capture('profile-navigation');
      await tester.tap(find.byKey(const ValueKey('navigation-2')));
      await tester.pumpAndSettle();
      expect(find.text('Create Outfit'), findsOneWidget);
      await capture('create-outfit');
      await tester.tap(find.byKey(const ValueKey('navigation-1')));
      await tester.pumpAndSettle();
      expect(find.text('My Closet'), findsOneWidget);
      await capture('my-closet');
      await tester.tap(find.byKey(ValueKey('group-${ClosetGroup.tops.name}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Linen shirt'));
      await tester.pumpAndSettle();
      final add = find.text('+ Add to Outfit');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('navigation-2')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3 pieces'), findsOneWidget);
      final tryOn = find.text('Try on Me');
      await tester.ensureVisible(tryOn);
      await tester.tap(tryOn);
      await tester.pumpAndSettle();
      expect(find.text('Ready to Try'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('navigation-3')));
      await tester.pumpAndSettle();
      expect(find.text('Matches Your Closet'), findsOneWidget);
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/design/editorial.png'),
          boundary.currentContext!,
        );
      });
      await tester.pumpAndSettle();
      await capture('explore');
      await tester.tap(find.byKey(const ValueKey('navigation-0')));
      await tester.pumpAndSettle();
      expect(find.text('What should we\nwear today?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
