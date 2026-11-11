import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/closet/application/outfits_controller.dart';
import 'package:miragemobile/closet/domain/closet_repository.dart';
import 'package:miragemobile/closet/domain/outfit.dart';
import 'closet_fakes.dart';

void main() {
  const details = OutfitDetails(name: 'Oficina', style: 'CASUAL', occasion: 'Trabajo');

  test('an outfit keeps its name, style and occasion', () async {
    final controller = OutfitsController(FakeOutfits());
    final saved = await controller.create(details, ['a']);
    expect(saved.name, 'Oficina');
    expect(saved.style, 'CASUAL');
    expect(saved.occasion, 'Trabajo');
    expect(controller.outfits, hasLength(1));
  });

  test('adding and removing pieces rewrites the outfit and clears a stale look', () async {
    final controller = OutfitsController(FakeOutfits());
    var outfit = await controller.create(details, ['a']);
    outfit = await controller.saveLook(outfit.id, Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]));
    expect(outfit.hasImage, isTrue);
    outfit = await controller.addGarment(outfit, 'b');
    expect(outfit.garmentIds, ['a', 'b']);
    expect(outfit.hasImage, isFalse); // the look showed another combination
    expect(outfit.name, 'Oficina'); // details survive a change of pieces
    outfit = await controller.removeGarment(outfit, 'a');
    expect(outfit.garmentIds, ['b']);
    expect(controller.outfits, hasLength(1));
  });

  test('a failed look upload is reported and the outfit stays as it was', () async {
    final repo = FakeOutfits()..failImage = true;
    final controller = OutfitsController(repo);
    final outfit = await controller.create(details, ['a']);
    await expectLater(
      controller.saveLook(outfit.id, Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
      throwsA(isA<ClosetException>()),
    );
    expect(controller.byId(outfit.id)!.hasImage, isFalse);
  });

  test('picture type is detected from content', () {
    expect(OutfitsController.imageType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
    expect(
      OutfitsController.imageType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0, 0, 0, 0, 0])),
      'image/png',
    );
  });
}
