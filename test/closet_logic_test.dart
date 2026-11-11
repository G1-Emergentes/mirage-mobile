import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/closet/application/closet_controller.dart';
import 'package:miragemobile/closet/application/outfit_tray.dart';
import 'package:miragemobile/closet/application/try_on_controller.dart';
import 'package:miragemobile/closet/domain/closet_repository.dart';
import 'package:miragemobile/closet/domain/garment.dart';
import 'closet_fakes.dart';

void main() {
  test('garments map from the contract JSON and group like the closet UI', () {
    final garment = Garment.fromJson({
      'id': 'g1',
      'name': 'Denim jacket',
      'category': 'OUTERWEAR',
      'subcategory': 'DENIM_JACKET',
      'colors': ['BLUE', 'WHITE'],
      'styles': ['CASUAL'],
      'description': 'Blue denim',
      'availability': 'UNAVAILABLE',
      'image': {'id': 'i', 'version': 1},
      'revision': 3,
    });
    expect(garment.group, ClosetGroup.tops);
    expect(garment.kind, 'Denim jacket');
    expect(garment.subtitle, 'Denim jacket · Blue');
    expect(garment.available, isFalse);
    expect(garment.hasImage, isTrue);
    expect(ClosetGroup.of('ONE_PIECE'), ClosetGroup.tops);
    expect(ClosetGroup.of('BOTTOM'), ClosetGroup.bottoms);
    expect(ClosetGroup.of('FOOTWEAR'), ClosetGroup.shoes);
    expect(ClosetGroup.of('ACCESSORY'), ClosetGroup.accessories);
    expect(piece('x', colors: const []).subtitle, 'Top');
    expect(humanize('ONE_PIECE'), 'One piece');
  });

  test('a draft sends only what the API accepts', () {
    const draft = GarmentDraft(
      name: 'Tee',
      category: 'TOP',
      colors: ['BLACK'],
      description: 'Black top',
    );
    expect(draft.toJson(), {
      'name': 'Tee',
      'category': 'TOP',
      'colors': ['BLACK'],
      'styles': <String>[],
      'description': 'Black top',
      'availability': 'AVAILABLE',
    });
    expect(
      GarmentDraft.from(piece('a', subcategory: 'T_SHIRT')).toJson(),
      containsPair('subcategory', 'T_SHIRT'),
    );
  });

  test('the closet loads, counts per group and reports server problems', () async {
    final repository = FakeCloset()
      ..items = [
        piece('a'),
        piece('b', category: 'OUTERWEAR'),
        piece('c', category: 'BOTTOM'),
        piece('d', category: 'ACCESSORY'),
      ];
    final closet = ClosetController(repository);
    await closet.load();
    expect(closet.loaded, isTrue);
    expect(closet.count(ClosetGroup.tops), 2);
    expect(closet.count(ClosetGroup.bottoms), 1);
    expect(closet.count(ClosetGroup.shoes), 0);
    expect(closet.count(ClosetGroup.accessories), 1);
    repository.listError = const ClosetException('NETWORK');
    await closet.load();
    expect(closet.error, contains('Could not reach the closet server'));
    expect(closet.loading, isFalse);
  });

  test('photo links are reused for four minutes and then renewed', () async {
    var now = DateTime(2026, 11, 10, 12);
    final repository = FakeCloset();
    final closet = ClosetController(repository, clock: () => now);
    final shirt = piece('a');
    final first = await closet.imageUrl(shirt);
    expect(await closet.imageUrl(shirt), first);
    expect(repository.urlCalls, 1);
    now = now.add(const Duration(minutes: 3, seconds: 59));
    await closet.imageUrl(shirt);
    expect(repository.urlCalls, 1);
    now = now.add(const Duration(seconds: 2));
    expect(await closet.imageUrl(shirt), isNot(first));
    expect(repository.urlCalls, 2);
    expect(await closet.imageUrl(piece('none', hasImage: false)), isNull);
    expect(repository.urlCalls, 2);
  });

  test('adding keeps the piece, but a failed photo upload leaves nothing behind', () async {
    final repository = FakeCloset();
    final closet = ClosetController(repository);
    const draft = GarmentDraft(
      name: 'Tee',
      category: 'TOP',
      description: 'Top',
    );
    final photo = Uint8List.fromList([1]);
    await closet.add(draft, photo, 'image/jpeg');
    expect(closet.garments.single.id, 'new-1');
    repository.failAttach = true;
    await expectLater(
      closet.add(draft, photo, 'image/jpeg'),
      throwsA(isA<ClosetException>()),
    );
    expect(repository.removed, ['new-1']);
    expect(closet.garments.length, 1);
  });

  test('saving replaces the piece and removing drops it', () async {
    final repository = FakeCloset()..items = [piece('a'), piece('b')];
    final closet = ClosetController(repository);
    await closet.load();
    await closet.save(
      'a',
      const GarmentDraft(name: 'Renamed', category: 'TOP', description: 'x'),
    );
    expect(closet.garments.first.name, 'Renamed');
    expect(closet.garments.first.revision, 2);
    await closet.remove('b');
    expect(closet.garments.map((g) => g.id), ['a']);
    expect(repository.removed, ['b']);
  });

  test('the outfit tray holds three available pieces with a photo', () {
    final tray = OutfitTray();
    expect(tray.toggle(piece('a')), isTrue);
    expect(tray.toggle(piece('b')), isTrue);
    expect(tray.toggle(piece('c')), isTrue);
    expect(tray.isFull, isTrue);
    expect(tray.toggle(piece('d')), isFalse);
    expect(tray.toggle(piece('b')), isTrue); // toggling a member removes it
    expect(tray.items.map((g) => g.id), ['a', 'c']);
    expect(tray.toggle(piece('x', available: false)), isFalse);
    expect(tray.toggle(piece('y', hasImage: false)), isFalse);
    tray.clear();
    expect(tray.isEmpty, isTrue);
  });

  test('a look is created by following the job until it is ready', () async {
    final repository = FakeTryOn([
      TryOnState.pending,
      TryOnState.processing,
      TryOnState.ready,
    ]);
    final tryOn = TryOnController(repository, pollEvery: Duration.zero);
    final seen = <TryOnState>[];
    tryOn.addListener(() => seen.add(tryOn.state));
    final photo = Uint8List.fromList([9]);
    await tryOn.start([piece('a'), piece('b')], photo);
    expect(tryOn.phase, TryOnPhase.ready);
    expect(tryOn.result, isNotNull);
    expect(tryOn.progress, 1);
    expect(repository.startedWith, ['a', 'b']);
    expect(repository.photoSent, photo);
    expect(seen, containsAllInOrder([TryOnState.pending, TryOnState.processing]));
  });

  test('look failures are explained in plain words', () async {
    final noPhoto = TryOnController(
      FakeTryOn([TryOnState.pending], startError: const ClosetException('PERSON_PHOTO_NOT_FOUND')),
      pollEvery: Duration.zero,
    );
    await noPhoto.start([piece('a')], null);
    expect(noPhoto.phase, TryOnPhase.failed);
    expect(noPhoto.error, contains('full-body photo'));
    expect(noPhoto.progress, 0);

    final provider = TryOnController(
      FakeTryOn([TryOnState.pending, TryOnState.failed]),
      pollEvery: Duration.zero,
    );
    await provider.start([piece('a')], null);
    expect(provider.error, contains('image service'));

    // The worker's own reason reaches the user: a flagged print is not a server fault.
    final flagged = TryOnController(
      FakeTryOn(
        [TryOnState.pending, TryOnState.failed],
        jobError: 'CONTENT_FLAGGED',
      ),
      pollEvery: Duration.zero,
    );
    await flagged.start([piece('a')], null);
    expect(flagged.error, contains('flagged'));
    expect(flagged.error, contains('Try another piece'));

    final slow = TryOnController(
      FakeTryOn([TryOnState.pending, TryOnState.processing]),
      pollEvery: Duration.zero,
      timeout: const Duration(milliseconds: 20),
    );
    await slow.start([piece('a')], null);
    expect(slow.phase, TryOnPhase.failed);
    expect(slow.error, contains('too long'));
    slow.reset();
    expect(slow.phase, TryOnPhase.idle);
  });
}

