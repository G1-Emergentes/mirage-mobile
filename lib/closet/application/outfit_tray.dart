import 'package:flutter/foundation.dart';
import '../domain/garment.dart';

/// Pieces picked for a look. The image provider takes the person plus three garments.
class OutfitTray extends ChangeNotifier {
  static const maxPieces = 3;
  final _items = <Garment>[];
  List<Garment> get items => List.unmodifiable(_items);
  bool get isFull => _items.length >= maxPieces;
  bool get isEmpty => _items.isEmpty;
  bool contains(String id) => _items.any((garment) => garment.id == id);

  /// Validate the whole selection before replacing the current draft.
  bool replace(List<Garment> garments) {
    if (garments.isEmpty ||
        garments.length > maxPieces ||
        garments.map((g) => g.id).toSet().length != garments.length ||
        garments.any((g) => !g.available || !g.hasImage)) {
      return false;
    }
    _items
      ..clear()
      ..addAll(garments);
    notifyListeners();
    return true;
  }

  /// Adds or removes the piece. Returns false when it could not be added: the tray is
  /// full, or the piece is not available.
  bool toggle(Garment garment) {
    if (contains(garment.id)) {
      _items.removeWhere((item) => item.id == garment.id);
    } else {
      if (isFull || !garment.available || !garment.hasImage) return false;
      _items.add(garment);
    }
    notifyListeners();
    return true;
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
