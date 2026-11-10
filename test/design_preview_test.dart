import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/iam/application/iam_controller.dart';
import 'package:miragemobile/iam/presentation/screens/access_screen.dart';
import 'package:miragemobile/iam/presentation/screens/onboarding_screen.dart';
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
      for (final asset in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$asset'));
      }
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('renders the scoped Figma screens with local assets and fonts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final controller = IamController(FakeAuthRepository());
    addTearDown(controller.dispose);

    Future<void> show(Widget child) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: mirageTheme(),
            home: child,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final manifest =
            jsonDecode(await File('assets-manifest.json').readAsString())
                as Map;
        for (final asset in manifest['assets'] as List) {
          final path = asset['file'] as String;
          if (path.endsWith('.png')) {
            await precacheImage(AssetImage(path), boundaryKey.currentContext!);
          }
        }
      });
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/design/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await show(SplashScreen(onComplete: () {}));
    await capture('splash');
    await show(OnboardingScreen(onComplete: () {}));
    await capture('onboarding-1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await capture('onboarding-2');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await capture('onboarding-3');
    for (final mode in AccessMode.values) {
      await show(
        AccessScreen(
          key: ValueKey(mode),
          mode: mode,
          controller: controller,
          initialEmail: mode == AccessMode.confirmation
              ? 'mia@example.com'
              : '',
          onNavigate: (_, _) {},
        ),
      );
      await capture(mode.name);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
