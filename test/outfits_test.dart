import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:miragemobile/closet/application/outfits_controller.dart';
import 'package:miragemobile/closet/domain/outfit.dart';

class _FakeOutfits implements OutfitRepository {
  final saved = <SavedOutfit>[];
  var imageUploads = 0;
  bool failImage = false;
  @override
  Future<List<SavedOutfit>> list() async => saved;
  @override
  Future<SavedOutfit> save(List<String> ids, {String? name}) async {
    final o = SavedOutfit(id: 'o${saved.length}', garmentIds: ids, hasImage: false, complete: true);
    saved.add(o);
    return o;
  }
  @override
  Future<SavedOutfit> attachImage(String id, Uint8List bytes, String type) async {
    if (failImage) throw Exception('upload');
    imageUploads++;
    final o = saved.firstWhere((o) => o.id == id);
    return SavedOutfit(id: id, garmentIds: o.garmentIds, hasImage: true, complete: true);
  }
  @override
  Future<String?> imageUrl(String id) async => null;
  @override
  Future<void> remove(String id) async {}
  @override
  void close() {}
}

void main() {
  test('saving the same pieces again reuses the outfit and only adds the picture', () async {
    final repo = _FakeOutfits();
    final controller = OutfitsController(repo);
    final first = await controller.save(['a', 'b']);
    expect(first.hasImage, isFalse);
    final again = await controller.save(['b', 'a'], image: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]));
    expect(again.id, first.id);
    expect(again.hasImage, isTrue);
    expect(repo.saved, hasLength(1));
    expect(controller.outfits, hasLength(1));
  });

  test('a failed picture upload still keeps the saved combination', () async {
    final repo = _FakeOutfits()..failImage = true;
    final controller = OutfitsController(repo);
    final saved = await controller.save(['a'], image: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]));
    expect(saved.hasImage, isFalse);
    expect(controller.outfits, hasLength(1));
  });

  test('picture type is detected from content', () {
    expect(OutfitsController.imageType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
    expect(OutfitsController.imageType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0, 0, 0, 0, 0])), 'image/png');
  });
}
