import 'package:flutter/foundation.dart';
import '../domain/closet_repository.dart';
import '../domain/outfit.dart';

class OutfitsController extends ChangeNotifier {
  OutfitsController(this.repository);
  final OutfitRepository repository;
  List<SavedOutfit> outfits = const [];
  bool loading = false, loaded = false, _closed = false;
  String? error;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      outfits = await repository.list();
      loaded = true;
    } on ClosetException catch (e) {
      error = describe(e);
    } catch (_) {
      error = 'Could not load your outfits.';
    } finally {
      loading = false;
      if (!_closed) notifyListeners();
    }
  }

  /// Saves the combination. When `image` is given (a look already generated for these very
  /// pieces) it is stored too. Saving the same pieces again does not duplicate the outfit:
  /// it reuses the saved one and only adds or replaces its picture. If the picture fails the
  /// combination stays saved and `hasImage` tells the caller.
  Future<SavedOutfit> save(List<String> garmentIds, {Uint8List? image}) async {
    final wanted = garmentIds.toSet();
    final existing = outfits
        .where(
          (o) =>
              o.garmentIds.length == wanted.length &&
              o.garmentIds.toSet().containsAll(wanted),
        )
        .firstOrNull;
    var saved = existing ?? await repository.save(garmentIds);
    if (image != null) {
      try {
        saved = await repository.attachImage(saved.id, image, imageType(image));
      } catch (_) {
        // The combination is saved; the caller reports the missing picture.
      }
    }
    outfits = [
      for (final o in outfits)
        if (o.id != saved.id) o,
      saved,
    ];
    notifyListeners();
    return saved;
  }

  Future<void> remove(String id) async {
    await repository.remove(id);
    outfits = outfits.where((o) => o.id != id).toList();
    notifyListeners();
  }

  Future<String?> imageUrl(String id) =>
      repository.imageUrl(id).catchError((_) => null);

  /// Storage only accepts JPEG, PNG and WebP; the worker may return either of the first two.
  static String imageType(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes.length > 11 && bytes[0] == 0x52 && bytes[8] == 0x57) {
      return 'image/webp';
    }
    return 'image/png';
  }

  static String describe(ClosetException e) => switch (e.code) {
    'NETWORK' => 'Could not reach the closet server. Check that it is running.',
    'UNAUTHENTICATED' => 'Your session ended. Sign in again.',
    'GARMENT_NOT_FOUND' => 'One of the pieces no longer exists.',
    'OUTFIT_NOT_FOUND' => 'This outfit no longer exists.',
    'INVALID_ARGUMENT' =>
      'This outfit is not valid. Use 1 to 3 available pieces.',
    'SERVICE_UNAVAILABLE' => 'The closet is temporarily unavailable.',
    _ => 'Could not save the outfit. Try again.',
  };

  @override
  void dispose() {
    _closed = true;
    repository.close();
    super.dispose();
  }
}
