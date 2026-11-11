import 'dart:typed_data';

/// An outfit the user chose to keep: the combination of pieces and, when a look was already
/// generated for it, the picture. Recommendation keeps its own proposals; these live in
/// Digital Closet.
class SavedOutfit {
  const SavedOutfit({
    required this.id,
    required this.garmentIds,
    required this.hasImage,
    required this.complete,
    this.name,
  });

  factory SavedOutfit.fromJson(Map<String, dynamic> json) => SavedOutfit(
    id: json['id'] as String,
    name: json['name'] as String?,
    garmentIds: [for (final id in json['garment_ids'] as List) '$id'],
    hasImage: json['image'] != null,
    complete: json['complete'] as bool? ?? true,
  );

  final String id;
  final String? name;
  final List<String> garmentIds;
  final bool hasImage;

  /// False when a piece of the outfit was removed from the closet afterwards.
  final bool complete;
}

abstract class OutfitRepository {
  Future<List<SavedOutfit>> list();
  Future<SavedOutfit> save(List<String> garmentIds, {String? name});

  /// Uploads the look through a signed URL and registers it on the outfit.
  Future<SavedOutfit> attachImage(
    String id,
    Uint8List bytes,
    String contentType,
  );

  /// Temporary signed URL of the look, or null when the outfit has none.
  Future<String?> imageUrl(String id);
  Future<void> remove(String id);
  void close();
}
