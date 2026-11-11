import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/avatar/application/person_photo.dart';
import 'package:miragemobile/closet/closet_module.dart';
import 'package:miragemobile/closet/domain/closet_repository.dart';
import 'package:miragemobile/closet/domain/outfit.dart';
import 'package:miragemobile/closet/presentation/add_item_screen.dart';
import 'package:miragemobile/closet/presentation/closet_screen.dart';
import 'package:miragemobile/closet/presentation/closet_widgets.dart';
import 'package:miragemobile/shared/theme/mirage_theme.dart';
import 'closet_fakes.dart';

Future<ClosetModule> openCloset(
  WidgetTester tester, {
  FakeCloset? closet,
  FakeTryOn? tryOn,
  FakeOutfits? outfits,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository =
      closet ??
      (FakeCloset()
        ..serveUrls = false
        ..items = [
          piece('a', name: 'Everyday tee', subcategory: 'T_SHIRT'),
          piece('b', name: 'Oversized shirt', colors: const ['WHITE']),
          piece('c', name: 'Wide jeans', category: 'BOTTOM', colors: const ['BLUE']),
          piece('d', name: 'Lime bag', category: 'ACCESSORY', colors: const ['GREEN']),
          piece('e', name: 'Old boots', category: 'FOOTWEAR', available: false),
        ]);
  final module = ClosetModule(
    accessToken: () async => 'token',
    closetRepository: repository,
    tryOnRepository:
        tryOn ?? FakeTryOn([TryOnState.pending, TryOnState.ready]),
    outfitRepository: outfits ?? FakeOutfits(),
  );
  addTearDown(module.dispose);
  await tester.pumpWidget(
    MaterialApp(theme: mirageTheme(), home: ClosetScreen(module: module)),
  );
  await tester.pumpAndSettle();
  return module;
}

void main() {
  setUpAll(() async {
    // Real fonts, so text measures like on a device (the test font is much wider).
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
  tearDown(() => PersonPhoto.bytes = null);

  testWidgets('My Closet shows the four groups with their counts', (tester) async {
    await openCloset(tester);
    expect(find.text('My Closet'), findsOneWidget);
    expect(find.text('5 pieces. Endless possibilities.'), findsOneWidget);
    expect(find.text('2 pieces'), findsOneWidget); // tops
    expect(find.text('1 pieces'), findsNWidgets(3)); // bottoms, shoes, accessories
    expect(find.text('Tops'), findsWidgets);
    expect(find.text('+ Add New Item'), findsOneWidget);
    // Choosing a chip shows only that group.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Shoes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('group-shoes')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-tops')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a group lists its pieces and search narrows them', (tester) async {
    await openCloset(tester);
    await tester.tap(find.byKey(const ValueKey('group-tops')));
    await tester.pumpAndSettle();
    expect(find.text('2 pieces in your closet'), findsOneWidget);
    expect(find.text('Everyday tee'), findsOneWidget);
    expect(find.text('Oversized shirt'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('search')), 'oversized');
    await tester.pumpAndSettle();
    expect(find.text('Everyday tee'), findsNothing);
    expect(find.text('Oversized shirt'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches your search.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a piece can be picked for the outfit, then tried on', (tester) async {
    final tryOn = FakeTryOn([TryOnState.pending, TryOnState.ready]);
    final module = await openCloset(tester, tryOn: tryOn);
    await tester.tap(find.byKey(const ValueKey('group-tops')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile-a')));
    await tester.pumpAndSettle();
    expect(find.text('Everyday tee'), findsOneWidget);
    expect(find.text('IN YOUR CLOSET'), findsOneWidget);
    expect(find.byKey(const ValueKey('armar')), findsOneWidget);
    // The tray is filled from a saved outfit (see the outfit tests below).
    module.tray.toggle(module.closet.garments.firstWhere((g) => g.id == 'a'));
    await tester.pumpAndSettle();
    // Back to My Closet: the outfit bar offers the try-on.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Outfit · 1 piece'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('try-on')));
    await tester.tap(find.byKey(const ValueKey('try-on')));
    await tester.pumpAndSettle();
    expect(find.text('Ready to Try'), findsOneWidget);
    // Generating needs the user's consent.
    final generate = find.byKey(const ValueKey('generate'));
    await tester.ensureVisible(generate);
    expect(tester.widget<FilledButton>(find.descendant(of: generate, matching: find.byType(FilledButton))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('consent')));
    await tester.pumpAndSettle();
    await tester.tap(generate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Creating your look'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Your AI Look'), findsOneWidget);
    expect(find.text('AI Preview'), findsOneWidget);
    expect(tryOn.startedWith, ['a']);
    // Compare shows both boards.
    await tester.ensureVisible(find.byKey(const ValueKey('compare')));
    await tester.tap(find.byKey(const ValueKey('compare')));
    await tester.pumpAndSettle();
    expect(find.text('Compare Look'), findsOneWidget);
    expect(find.text('AI Preview on You'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable pieces cannot join an outfit and the tray is capped', (tester) async {
    final module = await openCloset(tester);
    await tester.tap(find.byKey(const ValueKey('group-shoes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile-e')));
    await tester.pumpAndSettle();
    expect(find.text('UNAVAILABLE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('armar')));
    await tester.pumpAndSettle();
    expect(find.text('This piece is not available right now.'), findsOneWidget);
    expect(module.tray.isEmpty, isTrue);
  });

  testWidgets('Armar: create an outfit with name and style, then add another piece to it', (tester) async {
    final outfits = FakeOutfits();
    await openCloset(tester, outfits: outfits);
    await tester.tap(find.byKey(const ValueKey('group-tops')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('armar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('no outfits yet'), findsOneWidget);
    // The sticky button creates a new outfit with its details.
    await tester.tap(find.byKey(const ValueKey('crear-outfit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('outfit-form-save')));
    await tester.pumpAndSettle();
    expect(find.text('Give your outfit a name.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('outfit-name')), 'Oficina');
    await tester.tap(find.byKey(const ValueKey('style-CASUAL')));
    await tester.enterText(find.byKey(const ValueKey('outfit-occasion')), 'Trabajo');
    await tester.tap(find.byKey(const ValueKey('outfit-form-save')));
    await tester.pumpAndSettle();
    expect(outfits.saved, hasLength(1));
    expect(outfits.saved.single.name, 'Oficina');
    expect(outfits.saved.single.style, 'CASUAL');
    expect(outfits.saved.single.occasion, 'Trabajo');
    expect(outfits.saved.single.garmentIds, ['a']);
    // Another piece goes into that outfit from the list.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('armar')));
    await tester.pumpAndSettle();
    expect(find.text('Oficina'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('armar-o0')));
    await tester.pumpAndSettle();
    expect(outfits.saved.single.garmentIds, ['a', 'b']);
  });

  testWidgets('a saved outfit opens, drops a piece and keeps its look only while the pieces match', (tester) async {
    final outfits = FakeOutfits();
    await outfits.create(
      const OutfitDetails(name: 'Fiesta', style: 'FORMAL'),
      ['a', 'b'],
    );
    await outfits.attachImage('o0', Uint8List(1), 'image/png');
    final module = await openCloset(tester, outfits: outfits);
    await tester.ensureVisible(find.byKey(const ValueKey('saved-outfits')));
    await tester.tap(find.byKey(const ValueKey('saved-outfits')));
    await tester.pumpAndSettle();
    expect(find.text('Fiesta'), findsOneWidget);
    expect(find.text('LOOK SAVED'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('outfit-o0')));
    await tester.pumpAndSettle();
    expect(find.text('Formal'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('drop-b')));
    await tester.tap(find.byKey(const ValueKey('drop-b')));
    await tester.pumpAndSettle();
    expect(module.outfits.byId('o0')!.garmentIds, ['a']);
    expect(module.outfits.byId('o0')!.hasImage, isFalse);
  });

  testWidgets('a failed look explains what to do and can be retried', (tester) async {
    final module = await openCloset(
      tester,
      tryOn: FakeTryOn(
        [TryOnState.pending],
        startError: const ClosetException('PERSON_PHOTO_NOT_FOUND'),
      ),
    );
    module.tray.toggle(piece('a'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('try-on')));
    await tester.tap(find.byKey(const ValueKey('try-on')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consent')));
    await tester.pumpAndSettle();
    final generate = find.byKey(const ValueKey('generate'));
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(find.textContaining('full-body photo'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry')), findsOneWidget);
  });

  testWidgets('an empty closet and a server problem are explained', (tester) async {
    await openCloset(tester, closet: FakeCloset()..serveUrls = false);
    expect(find.textContaining('Your closet is empty'), findsOneWidget);
    expect(find.text('0 pieces. Endless possibilities.'), findsOneWidget);
  });

  testWidgets('a closet that cannot load shows the problem and a retry', (tester) async {
    final repository = FakeCloset()
      ..serveUrls = false
      ..listError = const ClosetException('NETWORK');
    await openCloset(tester, closet: repository);
    expect(find.textContaining('Could not reach the closet server'), findsOneWidget);
    repository
      ..listError = null
      ..items = [piece('a')];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('1 pieces. Endless possibilities.'), findsOneWidget);
  });

  testWidgets('Add New Item asks for what is missing before saving', (tester) async {
    final repository = FakeCloset()..serveUrls = false;
    final module = await openCloset(tester, closet: repository);
    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();
    expect(find.text('Add New Item'), findsOneWidget);
    expect(find.text('AI recognition is coming soon. For now, fill in the details.'), findsOneWidget);
    final save = find.byKey(const ValueKey('save-item'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Give it a name (up to 120 characters)'), findsOneWidget);
    expect(find.text('Choose a category'), findsOneWidget);
    expect(repository.created, isNull);
    expect(module.closet.garments, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('photo types are recognised by content, not by name', () {
    expect(sniffContentType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
    expect(sniffContentType(tinyPng), 'image/png');
    expect(
      sniffContentType(Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, 0])),
      'image/webp',
    );
    expect(sniffContentType(Uint8List.fromList('GIF89a....'.codeUnits)), isNull);
    expect(sniffContentType(Uint8List(0)), isNull);
  });

  testWidgets('editing keeps the piece photo and changes its details', (tester) async {
    final repository = FakeCloset()
      ..serveUrls = false
      ..items = [piece('a', name: 'Everyday tee')];
    final module = await openCloset(tester, closet: repository);
    await tester.tap(find.byKey(const ValueKey('group-tops')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-item')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Item'), findsWidgets);
    expect(find.byKey(const ValueKey('take-photo')), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'Renamed tee');
    final save = find.byKey(const ValueKey('save-item'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(module.closet.garments.single.name, 'Renamed tee');
    expect(find.byType(AddItemScreen), findsNothing);
  });
}
