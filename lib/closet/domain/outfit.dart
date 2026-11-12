import 'dart:typed_data';

/// What the user types when creating or editing an outfit.
class OutfitDetails {
  const OutfitDetails({this.name, this.occasion, this.style});
  final String? name, occasion, style;
}

/// An outfit the user keeps: its pieces and, when a look was generated for exactly those
/// pieces, the picture. Recommendation keeps its own proposals; these live in Digital Closet.
class SavedOutfit {
  const SavedOutfit({
    required this.id,
    required this.garmentIds,
    required this.hasImage,
    required this.complete,
    this.name,
    this.occasion,
    this.style,
    this.imageVersion = 0,
  });

  factory SavedOutfit.fromJson(Map<String, dynamic> json) => SavedOutfit(
    id: json['id'] as String,
    name: json['name'] as String?,
    occasion: json['occasion'] as String?,
    style: json['style'] as String?,
    imageVersion: (json['image'] as Map?)?['version'] as int? ?? 0,
    garmentIds: [for (final id in json['garment_ids'] as List) '$id'],
    hasImage: json['image'] != null,
    complete: json['complete'] as bool? ?? true,
  );

  final String id;
  final String? name, occasion, style;
  final List<String> garmentIds;
  final bool hasImage;

  /// Grows when the look picture is replaced, so a screen knows to fetch it again.
  final int imageVersion;

  /// False when a piece of the outfit was removed from the closet afterwards.
  final bool complete;
}

abstract class OutfitRepository {
  Future<List<SavedOutfit>> list();
  Future<SavedOutfit> create(OutfitDetails details, List<String> garmentIds);

  /// Replaces details and pieces. Changing the pieces clears the look picture.
  Future<SavedOutfit> update(
    String id,
    OutfitDetails details,
    List<String> garmentIds,
  );

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
