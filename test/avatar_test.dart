import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/avatar/domain/avatar_repository.dart';
import 'package:miragemobile/avatar/application/avatar_controller.dart';
import 'package:miragemobile/avatar/application/person_photo.dart';
import 'package:miragemobile/avatar/presentation/avatar_screen.dart';
import 'package:miragemobile/avatar/presentation/measurements_screen.dart';
import 'package:miragemobile/shared/theme/mirage_theme.dart';

class FakeAvatars extends AvatarRepository {
  bool failed = false;
  bool stored = false;
  int scans = 0;
  Map<String, double?> values = {
    'height': 170,
    'chest': 90,
    'waist': 75,
    'hip': 100,
  };
  String fit = 'Regular';
  @override
  Future<Map<String, dynamic>> body(String id) async => {
    'measurements': values,
    'fitPreference': fit,
  };
  @override
  Future<String?> openSaved() async => stored ? 'test-saved' : null;
  @override
  Future<String> adjust(
    String id,
    Map<String, double?> measurements,
    String preference,
  ) async {
    values = measurements;
    fit = preference;
    return 'test-refined';
  }

  @override
  Future<void> save(
    String id,
    Map<String, double?> measurements,
    String preference,
  ) async {
    stored = true;
    values = measurements;
    fit = preference;
  }

  @override
  Future<String> submit(AvatarInput input) async {
    scans++;
    return 'test-job';
  }

  @override
  Future<String> status(String id) async => failed ? 'failed' : 'succeeded';
  @override
  Uri viewer(String id) => Uri.parse('http://127.0.0.1:8093/view/$id');
  @override
  Future<void> discard(String id) async {}
  @override
  void close() {}
}

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
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  final input = AvatarInput(
    photo: Uint8List.fromList([1]),
    height: 170,
    weight: 65,
  );
  test('validates declarations and reports actual job failures', () async {
    expect(
      () => AvatarInput(photo: Uint8List(0), height: 170, weight: 65),
      throwsArgumentError,
    );
    expect(
      () => AvatarInput(photo: Uint8List(1), height: double.nan, weight: 65),
      throwsArgumentError,
    );
    final repository = FakeAvatars();
    final controller = AvatarController(repository);
    await controller.generate(input);
    expect(controller.model?.path, '/view/test-job');
    repository.failed = true;
    await controller.generate(input);
    expect(controller.model, isNull);
    expect(controller.error, isNotNull);
    expect(controller.busy, false);
    controller.dispose();
  });
  test(
    'refine, save and reopen preserve edited measurements and fit',
    () async {
      final repository = FakeAvatars();
      final first = AvatarController(repository);
      await first.generate(input);
      expect(
        await first.refine({
          'height': 175,
          'waist': 78,
          'shoulderWidth': null,
        }, 'Oversized'),
        true,
      );
      expect(first.saved, false);
      await first.save();
      expect(first.saved, true);
      first.dispose();
      final reopened = AvatarController(repository);
      await reopened.restore();
      expect(reopened.measurements['height'], 175);
      expect(reopened.fitPreference, 'Oversized');
      expect(reopened.saved, true);
      expect(repository.scans, 1);
      reopened.dispose();
    },
  );
  testWidgets('saved avatar continues without requesting another photo', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repository = FakeAvatars();
    final controller = AvatarController(repository);
    addTearDown(controller.dispose);
    await controller.generate(input);
    await controller.save();
    bool? completed;
    await tester.pumpWidget(
      MaterialApp(
        theme: mirageTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                completed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => AvatarScreen(controller: controller),
                  ),
                );
              },
              child: const Text('Open avatar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open avatar'));
    await tester.pumpAndSettle();
    expect(find.text('Full Body Photo'), findsNothing);
    await tester.ensureVisible(find.text('Continue to Home'));
    await tester.tap(find.text('Continue to Home'));
    await tester.pumpAndSettle();
    expect(completed, true);
    expect(repository.scans, 1);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('failed restoration offers retry instead of another scan', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final controller = AvatarController(FakeAvatars())
      ..restoreFailed = true
      ..error = 'Could not load your saved avatar.';
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: mirageTheme(),
        home: AvatarScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Full Body Photo'), findsNothing);
    // Without a saved avatar the user can still give a body photo for outfit previews,
    // but nothing is kept until a photo is chosen and consent is given.
    expect(find.text('Or use a photo of your body'), findsOneWidget);
    expect(find.text('Use a body photo instead'), findsOneWidget);
    expect(find.text('Use this photo'), findsNothing);
    expect(PersonPhoto.bytes, isNull);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'photo setup is disabled without consent and renders at mobile size',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AvatarController(FakeAvatars());
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: mirageTheme(),
            home: AvatarScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final create = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create avatar'),
      );
      expect(create.onPressed, isNull);
      expect(find.text('Full Body Photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/design/avatar-setup.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'measurement edits validate centimetres and preserve fit preference',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, double?>? result;
      String? fit;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: mirageTheme(),
            home: MeasurementsScreen(
              initial: const {
                'height': 170,
                'chest': 90,
                'waist': 75,
                'hip': 100,
              },
              fit: 'Regular',
              onContinue: (values, choice) async {
                result = values;
                fit = choice;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'output/design/measurements.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.enterText(find.byKey(const ValueKey('waist')), '-1');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.enterText(find.byKey(const ValueKey('waist')), '78');
      await tester.ensureVisible(find.text('Oversized'));
      await tester.tap(find.text('Oversized'));
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(result!['waist'], 78);
      expect(result!['shoulderWidth'], isNull);
      expect(fit, 'Oversized');
      expect(tester.takeException(), isNull);
    },
  );
}
