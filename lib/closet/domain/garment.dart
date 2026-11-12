import 'package:flutter/foundation.dart';

/// The four groups shown in the closet. The API has six categories: outerwear and
/// one-piece garments are listed with the tops.
enum ClosetGroup {
  tops('Tops', ['TOP', 'OUTERWEAR', 'ONE_PIECE']),
  bottoms('Bottoms', ['BOTTOM']),
  shoes('Shoes', ['FOOTWEAR']),
  accessories('Accessories', ['ACCESSORY']);

  const ClosetGroup(this.label, this.categories);
  final String label;
  final List<String> categories;

  static ClosetGroup of(String category) => values.firstWhere(
    (group) => group.categories.contains(category),
    orElse: () => tops,
  );
}

// Closed vocabularies of the Digital Closet contract.
const closetCategories = [
  'TOP',
  'BOTTOM',
  'ONE_PIECE',
  'OUTERWEAR',
  'FOOTWEAR',
  'ACCESSORY',
];
const closetColors = [
  'BLACK',
  'WHITE',
  'GRAY',
  'BLUE',
  'RED',
  'GREEN',
  'YELLOW',
  'ORANGE',
  'PURPLE',
  'PINK',
  'BROWN',
  'BEIGE',
  'MULTICOLOR',
];
const closetStyles = [
  'CASUAL',
  'FORMAL',
  'SPORT',
  'STREETWEAR',
  'MINIMALIST',
  'CLASSIC',
  'BOHEMIAN',
];

/// `ONE_PIECE` -> `One piece`.
String humanize(String code) {
  final text = code.toLowerCase().replaceAll('_', ' ');
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

@immutable
class Garment {
  const Garment({
    required this.id,
    required this.name,
    required this.category,
    this.subcategory,
    this.colors = const [],
    this.styles = const [],
    required this.description,
    required this.available,
    required this.hasImage,
    required this.revision,
  });

  /// GarmentReadModel of the Digital Closet contract (snake_case).
  factory Garment.fromJson(Map<String, dynamic> json) => Garment(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    subcategory: json['subcategory'] as String?,
    colors: List<String>.from(json['colors'] as List),
    styles: List<String>.from(json['styles'] as List),
    description: json['description'] as String,
    available: json['availability'] == 'AVAILABLE',
    hasImage: json['image'] != null,
    revision: json['revision'] as int,
  );

  final String id, name, category, description;
  final String? subcategory;
  final List<String> colors, styles;
  final bool available, hasImage;
  final int revision;

  ClosetGroup get group => ClosetGroup.of(category);
  String get kind => humanize(subcategory ?? category);
  String get colorLabel => colors.isEmpty ? '' : humanize(colors.first);
  String get subtitle => [kind, if (colors.isNotEmpty) colorLabel].join(' · ');

  String? get model3dCategory {
    if (category != 'ACCESSORY') return null;
    return switch (subcategory?.toUpperCase()) {
      'GLASSES' || 'EYEGLASSES' || 'SUNGLASSES' => 'glasses',
      'HAT' ||
      'CAP' ||
      'BASEBALL_CAP' ||
      'BUCKET_HAT' ||
      'BEANIE' ||
      'FEDORA' => 'hat',
      _ => null,
    };
  }
}

/// Editable attributes: what the API accepts when creating or replacing a garment.
@immutable
class GarmentDraft {
  const GarmentDraft({
    required this.name,
    required this.category,
    this.subcategory,
    this.colors = const [],
    this.styles = const [],
    required this.description,
    this.available = true,
  });

  factory GarmentDraft.from(Garment garment) => GarmentDraft(
    name: garment.name,
    category: garment.category,
    subcategory: garment.subcategory,
    colors: garment.colors,
    styles: garment.styles,
    description: garment.description,
    available: garment.available,
  );

  final String name, category, description;
  final String? subcategory;
  final List<String> colors, styles;
  final bool available;

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    if (subcategory != null) 'subcategory': subcategory,
    'colors': colors,
    'styles': styles,
    'description': description,
    'availability': available ? 'AVAILABLE' : 'UNAVAILABLE',
  };
}
