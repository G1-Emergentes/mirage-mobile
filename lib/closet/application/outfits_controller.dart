import 'package:flutter/foundation.dart';
import '../domain/closet_repository.dart';
import '../domain/outfit.dart';

class OutfitsController extends ChangeNotifier {
  OutfitsController(this.repository);
  static const maxPieces = 3;
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

  SavedOutfit? byId(String id) => outfits.where((o) => o.id == id).firstOrNull;

  void _put(SavedOutfit saved) {
    outfits = [
      for (final o in outfits)
        if (o.id != saved.id) o,
      saved,
    ]..sort((a, b) => a.id.compareTo(b.id)); // same order as the server's listing
    notifyListeners();
  }

  Future<SavedOutfit> create(OutfitDetails details, List<String> ids) async {
    final saved = await repository.create(details, ids);
    _put(saved);
    return saved;
  }

  Future<SavedOutfit> update(
    SavedOutfit outfit, {
    OutfitDetails? details,
    List<String>? garmentIds,
  }) async {
    final saved = await repository.update(
      outfit.id,
      details ??
          OutfitDetails(
            name: outfit.name,
            occasion: outfit.occasion,
            style: outfit.style,
          ),
      garmentIds ?? outfit.garmentIds,
    );
    _put(saved);
    return saved;
  }

  Future<SavedOutfit> addGarment(SavedOutfit outfit, String garmentId) =>
      update(outfit, garmentIds: [...outfit.garmentIds, garmentId]);

  Future<SavedOutfit> removeGarment(SavedOutfit outfit, String garmentId) =>
      update(
        outfit,
        garmentIds: [
          for (final id in outfit.garmentIds)
            if (id != garmentId) id,
        ],
      );

  /// Stores the generated look as the outfit's picture.
  Future<SavedOutfit> saveLook(String id, Uint8List image) async {
    final saved = await repository.attachImage(id, image, imageType(image));
    _put(saved);
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
      'Outfits take 1 to 3 pieces, and new pieces must be available.',
    'SERVICE_UNAVAILABLE' => 'The closet is temporarily unavailable.',
    _ => 'Something went wrong. Try again.',
  };

  @override
  void dispose() {
    _closed = true;
    repository.close();
    super.dispose();
  }
}
